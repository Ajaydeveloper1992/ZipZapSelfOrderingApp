import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zipzap_pos_self_orders/models/cart_item_model.dart';
import 'package:zipzap_pos_self_orders/models/product_model.dart';
import 'package:zipzap_pos_self_orders/providers/data_provider.dart';

class CustomItemModal extends StatefulWidget {
  final Function(Map<String, dynamic> customItemData)? onAdd;
  final CartItem? cartItem; // For editing existing custom item
  final Function(CartItem)? onUpdate; // Called when editing

  const CustomItemModal({super.key, this.onAdd, this.cartItem, this.onUpdate});

  bool get isEditing => cartItem != null;

  @override
  State<CustomItemModal> createState() => _CustomItemModalState();
}

class _CustomItemModalState extends State<CustomItemModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _noteController = TextEditingController();
  final DataProvider _dataProvider = DataProvider();
  int _quantity = 1;
  TaxRule? _selectedTaxRule;

  // Get tax rules from DataProvider
  List<TaxRule> get _taxRules => _dataProvider.taxRulesList;

  @override
  void initState() {
    super.initState();

    // If editing, populate fields with existing values
    if (widget.isEditing) {
      final item = widget.cartItem!;
      _nameController.text = item.product.name;
      _priceController.text = item.product.posEffectivePrice.toStringAsFixed(2);
      _noteController.text = item.itemNote;
      _quantity = item.quantity;

      // Set tax rule from product
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (item.product.taxRule != null && _taxRules.isNotEmpty) {
          setState(() {
            _selectedTaxRule = _taxRules.firstWhere(
              (rule) => rule.id == item.product.taxRule!.id,
              orElse: () => item.product.taxRule!,
            );
          });
        } else if (!item.product.taxEnable) {
          setState(() {
            _selectedTaxRule = null;
          });
        }
      });
    } else {
      // Set default tax rule to HST (or first available) for new items
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_taxRules.isNotEmpty) {
          setState(() {
            _selectedTaxRule = _taxRules.firstWhere(
              (rule) => rule.taxClass == 'HST',
              orElse: () => _taxRules.first,
            );
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _handleQuantityChange(int change) {
    setState(() {
      _quantity = (_quantity + change).clamp(1, 999);
    });
  }

  void _handleConfirm() {
    if (_formKey.currentState?.validate() ?? false) {
      if (widget.isEditing) {
        // Update existing cart item
        final updatedProduct = widget.cartItem!.product.copyWith(
          name: _nameController.text.trim(),
          price: double.parse(_priceController.text),
          posPrice: double.parse(_priceController.text),
          taxEnable: _selectedTaxRule != null,
          taxRule: _selectedTaxRule,
        );

        final updatedCartItem = widget.cartItem!.copyWith(
          product: updatedProduct,
          quantity: _quantity,
          itemNote: _noteController.text.trim(),
        );

        widget.onUpdate?.call(updatedCartItem);
        Navigator.of(context).pop();
      } else {
        // Add new custom item
        final customItemData = {
          'customItem': _nameController.text.trim(),
          'quantity': _quantity,
          'price': double.parse(_priceController.text),
          'taxEnable': _selectedTaxRule != null,
          'taxRule': _selectedTaxRule != null
              ? {
                  '_id': _selectedTaxRule!.id,
                  'name': _selectedTaxRule!.name,
                  'taxClass': _selectedTaxRule!.taxClass,
                  'amount': _selectedTaxRule!.amount,
                  'taxType': _selectedTaxRule!.taxType,
                }
              : null,
          'itemNote': _noteController.text.trim(),
          'modifiers': [],
          'modifierGroups': [],
        };

        widget.onAdd?.call(customItemData);
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 768;
    final modalWidth = isSmallScreen ? screenWidth * 0.9 : 650.00;

    // Safely calculate total price, default to 0 if invalid
    final pricePerUnit = double.tryParse(_priceController.text) ?? 0.0;
    final totalPrice = _quantity * pricePerUnit;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: modalWidth,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              _buildHeader(context, totalPrice),
              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name Field
                      _buildTextField(
                        controller: _nameController,
                        label: 'Item Name',
                        hint: 'Enter the name of the item',
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Item name is required';
                          }
                          if (value.trim().length < 2) {
                            return 'Name must be at least 2 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // Price, Tax Rule, and Quantity Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Price Field
                          Expanded(
                            flex: 2,
                            child: _buildTextField(
                              controller: _priceController,
                              label: 'Price',
                              hint: '\$0.00',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*\.?\d{0,2}'),
                                ),
                              ],
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Price is required';
                                }
                                final price = double.tryParse(value);
                                if (price == null) {
                                  return 'Enter a valid price';
                                }
                                if (price < 0) {
                                  return 'Price cannot be negative';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Tax Rule Selector
                          Expanded(flex: 3, child: _buildTaxRuleSelector()),
                          const SizedBox(width: 12),
                          // Quantity Selector
                          Expanded(
                            flex: 2,
                            child: _buildCompactQuantitySelector(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Note Field
                      _buildTextField(
                        controller: _noteController,
                        label: 'Notes',
                        hint: 'Any special requests?',
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),
              // Footer Actions
              _buildFooter(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, double totalPrice) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              widget.isEditing ? Icons.edit : Icons.add_shopping_cart,
              color: Theme.of(context).colorScheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isEditing ? 'Edit Custom Item' : 'Add Custom Item',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                if (totalPrice >= 0)
                  Text(
                    '$_quantity x \$${totalPrice.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 24),
            onPressed: () => Navigator.of(context).pop(),
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(
                context,
              ).colorScheme.error.withValues(alpha: 0.1),
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade400),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.error,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildTaxRuleSelector() {
    final selectedLabel = _selectedTaxRule == null
        ? 'No Tax'
        : '${_selectedTaxRule!.name} (${_selectedTaxRule!.amount.toStringAsFixed(0)}%)';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tax Rule',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        PopupMenuButton<String>(
          offset: const Offset(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          onSelected: (value) {
            setState(() {
              if (value == 'no_tax') {
                _selectedTaxRule = null;
              } else {
                _selectedTaxRule = _taxRules.firstWhere(
                  (rule) => rule.id == value,
                  orElse: () => _taxRules.first,
                );
              }
            });
          },
          itemBuilder: (context) => [
            // No Tax option
            PopupMenuItem<String>(
              value: 'no_tax',
              height: 40,
              child: Row(
                children: [
                  Icon(
                    _selectedTaxRule == null
                        ? Icons.check_circle
                        : Icons.circle_outlined,
                    size: 16,
                    color: _selectedTaxRule == null
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  const Text('No Tax', style: TextStyle(fontSize: 14)),
                ],
              ),
            ),
            // Tax rules from API
            ..._taxRules.map((rule) {
              final isSelected = _selectedTaxRule?.id == rule.id;
              return PopupMenuItem<String>(
                value: rule.id,
                height: 40,
                child: Row(
                  children: [
                    Icon(
                      isSelected ? Icons.check_circle : Icons.circle_outlined,
                      size: 16,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${rule.name} (${rule.amount.toStringAsFixed(0)}%)',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              );
            }),
          ],
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selectedLabel,
                    style: const TextStyle(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactQuantitySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quantity',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Container(
          height: 48,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              InkWell(
                onTap: _quantity > 1 ? () => _handleQuantityChange(-1) : null,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(7),
                  bottomLeft: Radius.circular(7),
                ),
                child: Container(
                  width: 40,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: _quantity > 1
                        ? Colors.grey.shade100
                        : Colors.grey.shade50,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(7),
                      bottomLeft: Radius.circular(7),
                    ),
                  ),
                  child: Icon(
                    Icons.remove,
                    size: 18,
                    color: _quantity > 1
                        ? Colors.black87
                        : Colors.grey.shade400,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  '$_quantity',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              InkWell(
                onTap: () => _handleQuantityChange(1),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(7),
                  bottomRight: Radius.circular(7),
                ),
                child: Container(
                  width: 40,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(7),
                      bottomRight: Radius.circular(7),
                    ),
                  ),
                  child: const Icon(Icons.add, size: 18, color: Colors.black87),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, size: 20),
              label: const Text('Cancel'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                side: BorderSide(
                  color: Theme.of(
                    context,
                  ).colorScheme.error.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: _handleConfirm,
              icon: Icon(
                widget.isEditing ? Icons.check : Icons.shopping_cart,
                size: 20,
              ),
              label: Text(widget.isEditing ? 'Update Item' : 'Add to Cart'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
