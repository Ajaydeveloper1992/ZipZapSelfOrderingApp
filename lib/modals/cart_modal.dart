import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:zipzap_pos_self_orders/models/product_model.dart';
import 'package:zipzap_pos_self_orders/models/cart_item_model.dart';
import 'package:zipzap_pos_self_orders/models/modifier_group_model.dart';
import 'package:zipzap_pos_self_orders/providers/data_provider.dart';

class CartModal extends StatefulWidget {
  final Product? product;
  final CartItem? cartItem;
  final Function(CartItem) onConfirm;
  final VoidCallback onCancel;
  final String? guestGroup; // Guest group for dine-in orders

  const CartModal({
    super.key,
    this.product,
    this.cartItem,
    required this.onConfirm,
    required this.onCancel,
    this.guestGroup,
  });

  @override
  State<CartModal> createState() => _CartModalState();
}

class _CartModalState extends State<CartModal> {
  final DataProvider _dataProvider = DataProvider();
  int _quantity = 1;
  String _notes = '';
  Map<String, List<String>> _selectedModifiers = {};
  List<ModifierGroup> _modifierGroups = [];
  bool _isLoading = true;
  bool _hasErrors = false;
  ItemDiscount? _itemDiscount;
  late TextEditingController _discountController;

  @override
  void initState() {
    super.initState();
    _discountController = TextEditingController(
      text: widget.cartItem?.itemDiscount?.value.toString() ?? '',
    );
    _initializeData();
  }

  @override
  void dispose() {
    _discountController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    if (widget.cartItem != null) {
      _quantity = widget.cartItem!.quantity;
      _notes = widget.cartItem!.itemNote;
      _selectedModifiers = Map.from(widget.cartItem!.modifiers);
      _itemDiscount = widget.cartItem!.itemDiscount;
      _discountController.text = _itemDiscount?.value.toString() ?? '';
    }

    final product = widget.product ?? widget.cartItem?.product;
    if (product == null) return;

    // Extract IDs from modifiersGroup (could be strings or objects with _id)
    final modifierGroupIds = product.modifiersGroup.map((e) {
      if (e is String) {
        return e;
      } else if (e is Map) {
        return e['_id']?.toString() ?? e.toString();
      } else {
        return e.toString();
      }
    }).toList();

    if (modifierGroupIds.isEmpty) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    await _loadModifierGroups(modifierGroupIds);
  }

  Future<void> _loadModifierGroups(List<String> groupIds) async {
    try {
      // Get modifier groups from DataProvider
      final allModifierGroups = _dataProvider.modifierGroupsList;

      // Get modifiers from DataProvider
      final allModifiers = _dataProvider.modifiersList
          .where((m) => m.isActive && m.posEnabled)
          .toList();

      // Filter and match modifier groups
      final allGroups =
          allModifierGroups
              .where(
                (group) =>
                    group.isActive &&
                    group.enabled &&
                    groupIds.contains(group.id),
              )
              .map((group) {
                // Get modifiers for this group from the separate modifiers list
                final groupModifiers = allModifiers
                    .where(
                      (modifier) =>
                          modifier.modifierGroupId == group.id &&
                          modifier.isActive &&
                          modifier.posEnabled,
                    )
                    .toList();

                // If we have nested modifiers, use those; otherwise use matched modifiers
                if (group.modifiers.isNotEmpty) {
                  return group;
                } else if (groupModifiers.isNotEmpty) {
                  return group.copyWithModifiers(groupModifiers);
                } else {
                  return group;
                }
              })
              .toList()
            ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      setState(() {
        _modifierGroups = allGroups;
        _isLoading = false;

        if (_selectedModifiers.isEmpty) {
          _initializeDefaultModifiers();
        }
        _validateModifiers();
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _initializeDefaultModifiers() {
    for (final group in _modifierGroups) {
      if (group.requiredModifiersCount > 0) {
        final activeModifiers = group.modifiers
            .where((m) => m.isActive)
            .take(group.requiredModifiersCount)
            .map((m) => m.id)
            .toList();
        if (activeModifiers.isNotEmpty) {
          _selectedModifiers[group.name] = activeModifiers;
        }
      } else {
        _selectedModifiers[group.name] = [];
      }
    }
  }

  void _validateModifiers() {
    bool hasErrors = false;
    for (final group in _modifierGroups) {
      final selectedCount = _selectedModifiers[group.name]?.length ?? 0;
      if (group.requiredModifiersCount > 0 &&
          selectedCount < group.requiredModifiersCount) {
        hasErrors = true;
        break;
      }
      if (group.allowedModifiersCount > 0 &&
          selectedCount > group.allowedModifiersCount) {
        hasErrors = true;
        break;
      }
    }
    setState(() {
      _hasErrors = hasErrors;
    });
  }

  void _handleModifierToggle(
    String groupName,
    String modifierId,
    bool isRadio,
  ) {
    setState(() {
      if (isRadio) {
        _selectedModifiers[groupName] = [modifierId];
      } else {
        final current = _selectedModifiers[groupName] ?? [];
        if (current.contains(modifierId)) {
          _selectedModifiers[groupName] = current
              .where((id) => id != modifierId)
              .toList();
        } else {
          final group = _modifierGroups.firstWhere((g) => g.name == groupName);
          if (group.allowedModifiersCount == 0 ||
              current.length < group.allowedModifiersCount) {
            _selectedModifiers[groupName] = [...current, modifierId];
          }
        }
      }
      _validateModifiers();
    });
  }

  void _handleConfirm() {
    if (_hasErrors || _quantity <= 0) return;

    final product = widget.product ?? widget.cartItem?.product;
    if (product == null) return;

    final cartItem = widget.cartItem != null
        ? widget.cartItem!.copyWith(
            quantity: _quantity,
            itemNote: _notes,
            modifiers: _selectedModifiers,
            itemDiscount: _itemDiscount,
          )
        : CartItem(
            id: const Uuid().v4(),
            product: product,
            quantity: _quantity,
            modifiers: _selectedModifiers,
            itemNote: _notes,
            itemDiscount: _itemDiscount,
            guestGroup: widget.guestGroup ?? 'whole_table',
          );

    widget.onConfirm(cartItem);
  }

  double _calculateBaseTotal() {
    final product = widget.product ?? widget.cartItem?.product;
    if (product == null) return 0.0;

    double basePrice = product.posEffectivePrice;
    double modifierPrice = 0.0;

    for (final entry in _selectedModifiers.entries) {
      final group = _modifierGroups.firstWhere(
        (g) => g.name == entry.key,
        orElse: () => ModifierGroup(
          id: '',
          name: entry.key,
          description: '',
          isActive: true,
          enabled: true,
          requiredModifiersCount: 0,
          allowedModifiersCount: 0,
          modifiers: [],
          products: [],
          sortOrder: 0,
        ),
      );

      for (final modifierId in entry.value) {
        final modifier = group.modifiers.firstWhere(
          (m) => m.id == modifierId,
          orElse: () => Modifier(
            id: modifierId,
            name: '',
            priceAdjustment: 0,
            isActive: true,
          ),
        );
        modifierPrice += modifier.priceAdjustment;
      }
    }

    return (basePrice + modifierPrice) * _quantity;
  }

  double _calculateTotalPrice() {
    double baseTotal = _calculateBaseTotal();

    // Apply item discount if any
    if (_itemDiscount != null && _itemDiscount!.value > 0) {
      if (_itemDiscount!.type == '%') {
        return baseTotal * (1 - _itemDiscount!.value / 100);
      } else {
        return baseTotal - _itemDiscount!.value;
      }
    }

    return baseTotal;
  }

  Widget _buildPriceDisplay(BuildContext context) {
    final baseTotal = _calculateBaseTotal();
    final discountedTotal = _calculateTotalPrice();
    final hasDiscount = _itemDiscount != null && _itemDiscount!.value > 0;

    if (hasDiscount && baseTotal != discountedTotal) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '\$${baseTotal.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.lineThrough,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '\$${discountedTotal.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    return Text(
      '\$${discountedTotal.toStringAsFixed(2)}',
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: Theme.of(context).colorScheme.error,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product ?? widget.cartItem?.product;
    if (product == null) return const SizedBox.shrink();

    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 768;
    final modalWidth = isSmallScreen
        ? screenWidth * 0.95
        : (screenWidth < 1024 ? 500.0 : 600.0);

    return Dialog(
      child: Container(
        width: modalWidth,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context, product),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildContent(context),
            ),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Product product) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              product.name,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove, size: 18),
                onPressed: _quantity > 1
                    ? () {
                        setState(() {
                          _quantity--;
                        });
                      }
                    : null,
                style: IconButton.styleFrom(
                  padding: const EdgeInsets.all(8),
                  minimumSize: const Size(32, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              SizedBox(
                width: 40,
                child: TextField(
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  controller: TextEditingController(text: _quantity.toString())
                    ..selection = TextSelection.collapsed(
                      offset: _quantity.toString().length,
                    ),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                  onChanged: (value) {
                    final qty = int.tryParse(value) ?? 1;
                    setState(() {
                      _quantity = qty > 0 ? qty : 1;
                    });
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 18),
                onPressed: () {
                  setState(() {
                    _quantity++;
                  });
                },
                style: IconButton.styleFrom(
                  padding: const EdgeInsets.all(8),
                  minimumSize: const Size(32, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          _buildPriceDisplay(context),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.cartItem != null) ...[
            _buildDiscountSection(context),
            const SizedBox(height: 16),
          ],
          if (_modifierGroups.isNotEmpty) ...[
            Text(
              'Choose your options:',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            ..._modifierGroups.map(
              (group) => _buildModifierGroup(context, group),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            'Notes:',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            minLines: 2,
            maxLines: null,
            textInputAction: TextInputAction.newline,
            keyboardType: TextInputType.multiline,
            decoration: const InputDecoration(
              hintText: 'Any special requests?',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            controller: TextEditingController(text: _notes)
              ..selection = TextSelection.collapsed(offset: _notes.length),
            onChanged: (value) {
              setState(() {
                _notes = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDiscountSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Discount',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                decoration: InputDecoration(
                  hintText: 'Enter discount (${_itemDiscount?.type ?? '%'})',
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                controller: _discountController,
                onChanged: (value) {
                  final inputValue = value;
                  double parsedValue;
                  if (inputValue.isEmpty) {
                    parsedValue = 0.0;
                  } else if (inputValue.startsWith('.')) {
                    parsedValue = double.tryParse('0$inputValue') ?? 0.0;
                  } else {
                    parsedValue = double.tryParse(inputValue) ?? 0.0;
                  }
                  setState(() {
                    _itemDiscount = ItemDiscount(
                      type: _itemDiscount?.type ?? '%',
                      value: parsedValue.isNaN ? 0.0 : parsedValue,
                    );
                  });
                },
              ),
            ),
            const SizedBox(width: 4),
            ToggleButtons(
              isSelected: [
                (_itemDiscount?.type ?? '%') == '%',
                (_itemDiscount?.type ?? '%') == '\$',
              ],
              onPressed: (index) {
                setState(() {
                  _itemDiscount = ItemDiscount(
                    type: index == 0 ? '%' : '\$',
                    value: _itemDiscount?.value ?? 0.0,
                  );
                });
              },
              borderRadius: BorderRadius.circular(8),
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              selectedColor: Colors.white,
              fillColor: Theme.of(context).colorScheme.primary,
              color: Theme.of(context).colorScheme.onSurface,
              children: const [Text('%'), Text('\$')],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModifierGroup(BuildContext context, ModifierGroup group) {
    final isRadio = group.allowedModifiersCount == 1;
    final selectedCount = _selectedModifiers[group.name]?.length ?? 0;
    final isRequired = group.requiredModifiersCount > 0;
    final hasError = isRequired && selectedCount < group.requiredModifiersCount;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                group.name,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: hasError
                      ? Theme.of(context).colorScheme.error
                      : Colors.grey.shade700,
                ),
              ),
              if (isRequired) ...[
                const SizedBox(width: 4),
                Text(
                  '(Required: ${group.requiredModifiersCount})',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
              if (group.allowedModifiersCount > 0) ...[
                const SizedBox(width: 4),
                Text(
                  '(Max: ${group.allowedModifiersCount})',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          isRadio
              ? RadioGroup<String>(
                  groupValue: _selectedModifiers[group.name]?.firstOrNull,
                  onChanged: (value) {
                    if (value != null) {
                      _handleModifierToggle(group.name, value, true);
                    }
                  },
                  child: Column(
                    children: group.modifiers.map((modifier) {
                      return InkWell(
                        onTap: () {
                          _handleModifierToggle(group.name, modifier.id, true);
                        },
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 0),
                          child: Row(
                            children: [
                              Radio<String>(
                                value: modifier.id,
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  modifier.priceAdjustment > 0
                                      ? '${modifier.name} (+\$${modifier.priceAdjustment.toStringAsFixed(2)})'
                                      : modifier.name,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodySmall?.copyWith(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                )
              : Column(
                  children: group.modifiers.map((modifier) {
                    final isSelected =
                        _selectedModifiers[group.name]?.contains(modifier.id) ??
                        false;
                    return InkWell(
                      onTap: () {
                        _handleModifierToggle(group.name, modifier.id, false);
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 0),
                        child: Row(
                          children: [
                            Checkbox(
                              value: isSelected,
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              onChanged: (checked) {
                                if (checked != null) {
                                  _handleModifierToggle(
                                    group.name,
                                    modifier.id,
                                    false,
                                  );
                                }
                              },
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                modifier.priceAdjustment > 0
                                    ? '${modifier.name} (+\$${modifier.priceAdjustment.toStringAsFixed(2)})'
                                    : modifier.name,
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.copyWith(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: widget.onCancel,
              icon: const Icon(Icons.close),
              label: const Text('Cancel'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.icon(
              onPressed: (_hasErrors || _quantity <= 0) ? null : _handleConfirm,
              icon: Icon(
                widget.cartItem != null ? Icons.check : Icons.shopping_cart,
              ),
              label: Text(widget.cartItem != null ? 'Confirm' : 'Add to Cart'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
