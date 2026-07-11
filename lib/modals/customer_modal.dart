import 'dart:async';
import 'package:flutter/material.dart';
import 'package:zipzap_pos_self_orders/models/customer_model.dart';
import 'package:zipzap_pos_self_orders/widgets/customer_order_history.dart';
import 'package:zipzap_pos_self_orders/providers/data_provider.dart';
import 'package:zipzap_pos_self_orders/services/customers_service.dart';
import 'package:zipzap_pos_self_orders/core/services/auth_service.dart';
import 'package:zipzap_pos_self_orders/widgets/app_toast.dart';
import 'package:zipzap_pos_self_orders/models/order_model.dart' as order_models;

class CustomerModal extends StatefulWidget {
  final Customer? selectedCustomer;
  final Function(Customer?) onConfirm;
  final VoidCallback onCancel;
  final Function(List<order_models.OrderItem>)? onReorder;
  final bool isRequired;
  final String? orderType;

  const CustomerModal({
    super.key,
    this.selectedCustomer,
    required this.onConfirm,
    required this.onCancel,
    this.onReorder,
    this.isRequired = false,
    this.orderType,
  });

  @override
  State<CustomerModal> createState() => _CustomerModalState();
}

class _CustomerModalState extends State<CustomerModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _zipController;
  late TextEditingController _noteController;
  late TextEditingController _searchController;

  final DataProvider _dataProvider = DataProvider();
  final CustomersService _customersService = CustomersService();
  final AuthService _authService = AuthService();
  List<Customer> _allCustomers = [];
  List<Customer> _searchResults = [];
  Customer? _selectedCustomer;
  bool _isLoading = true;
  bool _isCreatingCustomer = false;
  bool _isUpdatingCustomer = false;

  Timer? _searchDebounceTimer;

  // Check if any field has been modified from the selected customer's original values
  bool get _hasFieldsModified {
    if (_selectedCustomer == null || _selectedCustomer!.id.isEmpty) {
      return false;
    }

    final originalName = _selectedCustomer!.fullName;
    final originalEmail = _selectedCustomer!.email ?? '';
    final originalPhone = _selectedCustomer!.phone ?? '';
    final originalAddress = _selectedCustomer!.address?.street ?? '';
    final originalCity = _selectedCustomer!.address?.city ?? '';
    final originalState = _selectedCustomer!.address?.state ?? '';
    final originalZip = _selectedCustomer!.address?.zipCode ?? '';
    final originalNote = _selectedCustomer!.note ?? '';

    return _nameController.text.trim() != originalName ||
        _emailController.text.trim() != originalEmail ||
        _phoneController.text.trim() != originalPhone ||
        _addressController.text.trim() != originalAddress ||
        _cityController.text.trim() != originalCity ||
        _stateController.text.trim() != originalState ||
        _zipController.text.trim() != originalZip ||
        _noteController.text.trim() != originalNote;
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _addressController = TextEditingController();
    _cityController = TextEditingController();
    _stateController = TextEditingController();
    _zipController = TextEditingController();
    _noteController = TextEditingController();
    _searchController = TextEditingController();

    _selectedCustomer = widget.selectedCustomer;
    _setupDataProviderListener();
    _setupTextControllerListeners();
    _loadCustomers();
    _updateFormFromCustomer();
  }

  void _setupDataProviderListener() {
    _dataProvider.addListener(_onDataUpdate);
  }

  void _setupTextControllerListeners() {
    // Add listeners to trigger rebuild when fields change (for button text update)
    _nameController.addListener(_onFieldChanged);
    _emailController.addListener(_onFieldChanged);
    _phoneController.addListener(_onFieldChanged);
    _addressController.addListener(_onFieldChanged);
    _cityController.addListener(_onFieldChanged);
    _stateController.addListener(_onFieldChanged);
    _zipController.addListener(_onFieldChanged);
    _noteController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    // Trigger rebuild to update button text
    if (mounted) {
      setState(() {});
    }
  }

  void _onDataUpdate() {
    // Update customers when DataProvider notifies
    if (mounted) {
      _updateCustomersFromProvider();
    }
  }

  void _updateCustomersFromProvider() {
    setState(() {
      _allCustomers = _dataProvider.customersList;
      _isLoading = false;
      debugPrint('Loaded ${_allCustomers.length} customers from DataProvider');
    });
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _dataProvider.removeListener(_onDataUpdate);
    // Remove text controller listeners
    _nameController.removeListener(_onFieldChanged);
    _emailController.removeListener(_onFieldChanged);
    _phoneController.removeListener(_onFieldChanged);
    _addressController.removeListener(_onFieldChanged);
    _cityController.removeListener(_onFieldChanged);
    _stateController.removeListener(_onFieldChanged);
    _zipController.removeListener(_onFieldChanged);
    _noteController.removeListener(_onFieldChanged);
    // Dispose controllers
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipController.dispose();
    _noteController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers({bool forceRefresh = false}) async {
    try {
      setState(() {
        _isLoading = true;
      });

      if (forceRefresh) {
        await _dataProvider.loadCustomers(forceRefresh: true);
      }

      // Update from provider
      _updateCustomersFromProvider();
    } catch (e) {
      debugPrint('Error loading customers: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _updateFormFromCustomer() {
    if (_selectedCustomer != null) {
      _nameController.text = _selectedCustomer!.fullName;
      _emailController.text = _selectedCustomer!.email ?? '';
      _phoneController.text = _selectedCustomer!.phone ?? '';
      _addressController.text = _selectedCustomer!.address?.street ?? '';
      _cityController.text = _selectedCustomer!.address?.city ?? '';
      _stateController.text = _selectedCustomer!.address?.state ?? '';
      _zipController.text = _selectedCustomer!.address?.zipCode ?? '';
      _noteController.text = _selectedCustomer!.note ?? '';
    }
  }

  void _handleSearch(String term) {
    // Cancel any pending timer
    _searchDebounceTimer?.cancel();

    // Short debounce for local filtering (feels instant but reduces rebuilds)
    _searchDebounceTimer = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;

      setState(() {
        if (term.isEmpty) {
          _searchResults = [];
        } else {
          final searchTerm = term.toLowerCase().trim();
          _searchResults = _allCustomers.where((customer) {
            final firstName = customer.firstName.toLowerCase();
            final lastName = customer.lastName.toLowerCase();
            final email = (customer.email ?? '').toLowerCase();
            final phone = (customer.phone ?? '').toLowerCase();

            final matches =
                firstName.contains(searchTerm) ||
                lastName.contains(searchTerm) ||
                email.contains(searchTerm) ||
                phone.contains(searchTerm);

            return matches;
          }).toList();
          debugPrint(
            'Search for "$term" found ${_searchResults.length} results',
          );
          if (_searchResults.isNotEmpty) {
            debugPrint('First result: ${_searchResults.first.fullName}');
          }
        }
      });
    });
  }

  void _handleSelectCustomer(Customer customer) {
    setState(() {
      _selectedCustomer = customer;
      _searchResults = [];
      _searchController.clear();
      _updateFormFromCustomer();
    });
  }

  void _handleClear() {
    setState(() {
      _selectedCustomer = null;
      _searchController.clear();
      _searchResults = [];
      _nameController.clear();
      _emailController.clear();
      _phoneController.clear();
      _addressController.clear();
      _cityController.clear();
      _stateController.clear();
      _zipController.clear();
      _noteController.clear();
    });
    // Clear validation errors
    _formKey.currentState?.reset();
    // Notify parent that customer is cleared
    widget.onConfirm(null);
  }

  Future<void> _handleConfirm() async {
    // If customer is selected and no fields modified, just use existing customer
    if (_selectedCustomer != null &&
        _selectedCustomer!.id.isNotEmpty &&
        !_hasFieldsModified) {
      widget.onConfirm(_selectedCustomer);
      Navigator.of(context).pop();
      return;
    }

    // If customer is selected and fields are modified, update the customer
    if (_selectedCustomer != null &&
        _selectedCustomer!.id.isNotEmpty &&
        _hasFieldsModified) {
      await _handleUpdateCustomer();
      return;
    }

    // Check if user has entered any data
    final hasName = _nameController.text.trim().isNotEmpty;
    final hasPhone = _phoneController.text.trim().isNotEmpty;
    final hasEmail = _emailController.text.trim().isNotEmpty;
    final hasAddress =
        _addressController.text.trim().isNotEmpty ||
        _cityController.text.trim().isNotEmpty ||
        _stateController.text.trim().isNotEmpty ||
        _zipController.text.trim().isNotEmpty;
    final hasNote = _noteController.text.trim().isNotEmpty;

    final hasAnyData = hasName || hasPhone || hasEmail || hasAddress || hasNote;

    // If customer is required (e.g., delivery), don't allow proceeding without data
    if (widget.isRequired && !hasAnyData) {
      AppToast.warning(
        context: context,
        title: 'Customer Required',
        description: 'Customer information is required for this order type',
      );
      return;
    }

    // If no customer selected and no data entered, allow to proceed (optional customer)
    if (!hasAnyData) {
      widget.onConfirm(null);
      Navigator.of(context).pop();
      return;
    }

    // If user has entered data, validate required fields
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate that if any data is entered, name and phone are required
    if (hasAnyData && (!hasName || !hasPhone)) {
      AppToast.warning(
        context: context,
        title: 'Incomplete Information',
        description: 'Name and phone are required when creating a new customer',
      );
      return;
    }

    // Create new customer via API
    setState(() {
      _isCreatingCustomer = true;
    });

    try {
      // Use the active store (same source as order creation in new_order_page)
      final storeId =
          _dataProvider.store?.id ?? _authService.getProfile()?.storeId;

      // Build address object if any address field is filled
      Map<String, dynamic>? address;
      if (hasAddress) {
        address = {};
        if (_addressController.text.trim().isNotEmpty) {
          address['street'] = _addressController.text.trim();
        }
        if (_cityController.text.trim().isNotEmpty) {
          address['city'] = _cityController.text.trim();
        }
        if (_stateController.text.trim().isNotEmpty) {
          address['state'] = _stateController.text.trim();
        }
        if (_zipController.text.trim().isNotEmpty) {
          address['zipCode'] = _zipController.text.trim();
        }
      }

      // Create customer via API
      final newCustomer = await _customersService.createCustomer(
        firstName: _nameController.text.trim(),
        lastName: null, // We only have one name field
        isReturning: false,
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        address: address,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        store: storeId,
      );

      // Add optimistic customer to DataProvider
      _dataProvider.addOptimisticCustomer(newCustomer);

      // Show success message
      if (mounted) {
        AppToast.success(
          context: context,
          title: 'Customer Created',
          description: 'Customer ${newCustomer.fullName} created successfully',
        );

        // Return the created customer
        widget.onConfirm(newCustomer);
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('Error creating customer: $e');
      final errorMsg = e.toString().replaceAll('Exception: ', '');

      // If the customer already exists (e.g. created via web/AI order),
      // find them locally and auto-select instead of showing a hard error.
      if (mounted && errorMsg.toLowerCase().contains('already exists')) {
        final phone = _phoneController.text.trim();
        final existing = _allCustomers.cast<Customer?>().firstWhere(
          (c) =>
              c != null &&
              c.phone != null &&
              c.phone!.replaceAll(RegExp(r'[\s\-\(\)\+]'), '') ==
                  phone.replaceAll(RegExp(r'[\s\-\(\)\+]'), ''),
          orElse: () => null,
        );

        if (existing != null) {
          AppToast.success(
            context: context,
            title: 'Existing Customer Found',
            description:
                '${existing.fullName} already exists — selected automatically',
          );
          widget.onConfirm(existing);
          Navigator.of(context).pop();
          return;
        }
      }

      if (mounted) {
        AppToast.error(
          context: context,
          title: 'Failed to Create Customer',
          description: errorMsg,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingCustomer = false;
        });
      }
    }
  }

  Future<void> _handleUpdateCustomer() async {
    // Validate required fields
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final hasName = _nameController.text.trim().isNotEmpty;
    final hasPhone = _phoneController.text.trim().isNotEmpty;

    if (!hasName || !hasPhone) {
      AppToast.warning(
        context: context,
        title: 'Incomplete Information',
        description: 'Name and phone are required',
      );
      return;
    }

    setState(() {
      _isUpdatingCustomer = true;
    });

    try {
      // Build address object
      final hasAddress =
          _addressController.text.trim().isNotEmpty ||
          _cityController.text.trim().isNotEmpty ||
          _stateController.text.trim().isNotEmpty ||
          _zipController.text.trim().isNotEmpty;

      Map<String, dynamic>? address;
      if (hasAddress) {
        address = {
          'street': _addressController.text.trim(),
          'city': _cityController.text.trim(),
          'state': _stateController.text.trim(),
          'zipCode': _zipController.text.trim(),
        };
      }

      // Update customer via API
      final updatedCustomer = await _customersService.updateCustomer(
        customerId: _selectedCustomer!.id,
        firstName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        address: address,
        note: _noteController.text.trim(),
      );

      // Update in DataProvider
      _dataProvider.updateCustomerInMemory(updatedCustomer);

      // Show success message
      if (mounted) {
        AppToast.success(
          context: context,
          title: 'Customer Updated',
          description:
              'Customer ${updatedCustomer.fullName} updated successfully',
        );

        // Return the updated customer
        widget.onConfirm(updatedCustomer);
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('Error updating customer: $e');
      if (mounted) {
        AppToast.error(
          context: context,
          title: 'Failed to Update Customer',
          description: e.toString().replaceAll('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingCustomer = false;
        });
      }
    }
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return null;
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    if (!emailRegex.hasMatch(value)) {
      return 'Invalid email address';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    // Check if user has entered any data
    final hasAnyData =
        _nameController.text.trim().isNotEmpty ||
        _phoneController.text.trim().isNotEmpty ||
        _emailController.text.trim().isNotEmpty ||
        _addressController.text.trim().isNotEmpty ||
        _cityController.text.trim().isNotEmpty ||
        _stateController.text.trim().isNotEmpty ||
        _zipController.text.trim().isNotEmpty ||
        _noteController.text.trim().isNotEmpty;

    // Only validate if user has entered any data
    if (!hasAnyData) return null;

    if (value == null || value.isEmpty) return 'Phone is required';
    final cleanedPhone = value.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (cleanedPhone.length < 10 || cleanedPhone.length > 15) {
      return 'Invalid phone number';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 768;
    final modalWidth = isSmallScreen
        ? screenWidth * 0.95
        : (screenWidth < 1024 ? 600.0 : 700.0);
    final modalHeight = isSmallScreen
        ? MediaQuery.of(context).size.height * 0.9
        : MediaQuery.of(context).size.height * 0.7;
    final constrainedHeight = modalHeight > 500 ? modalHeight : 500.0;

    return PopScope(
      canPop: !widget.isRequired,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (!didPop && widget.isRequired && mounted) {
          AppToast.warning(
            context: context,
            title: 'Customer Required',
            description: 'Customer information is required for this order type',
          );
        }
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: modalWidth,
          constraints: BoxConstraints(
            minHeight: 500,
            maxHeight: constrainedHeight,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(context),
              if (widget.isRequired) _buildRequiredWarning(context),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildContent(context),
              ),
              _buildFooter(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.person_add,
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
                  'Add Customer',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                if (widget.orderType != null)
                  Text(
                    'For ${widget.orderType} order',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
              ],
            ),
          ),
          if (!widget.isRequired)
            IconButton(
              icon: const Icon(Icons.close, size: 24),
              onPressed: widget.onCancel,
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

  Widget _buildRequiredWarning(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.errorContainer.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.error.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_rounded,
            size: 20,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.orderType == 'delivery'
                  ? 'Customer information is required for delivery orders'
                  : 'Customer information is required',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search section with white background
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Colors.black.withAlpha(25), width: 1),
                ),
              ),
              child: _buildSearchSection(context),
            ),
            // Tabs and content
            Expanded(child: _buildTabs(context)),
          ],
        ),
        if (_searchController.text.isNotEmpty && _searchResults.isNotEmpty)
          Positioned(
            top: 50,
            left: 14,
            right: 60,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 240),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.3),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _searchResults.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.1),
                  ),
                  itemBuilder: (context, index) {
                    final customer = _searchResults[index];
                    return InkWell(
                      onTap: () => _handleSelectCustomer(customer),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.person,
                                size: 20,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    customer.fullName.isEmpty
                                        ? 'Guest'
                                        : customer.fullName,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  if (customer.phone != null)
                                    Text(
                                      customer.phone!,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.6),
                                          ),
                                    ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.4),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSearchSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search by name, email, or phone...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            _handleSearch('');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  isDense: true,
                  fillColor: Theme.of(
                    context,
                  ).colorScheme.surface.withValues(alpha: 0.5),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                onChanged: _handleSearch,
                onSubmitted: (value) {
                  if (value.isNotEmpty) {
                    if (RegExp(r'^\d+$').hasMatch(value)) {
                      _phoneController.text = value;
                    } else if (value.contains('@')) {
                      _emailController.text = value;
                    } else {
                      _nameController.text = value;
                    }
                    _searchController.clear();
                    _handleSearch('');
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _handleClear,
              icon: const Icon(Icons.refresh, size: 20),
              tooltip: 'Clear & Refresh',
              style: IconButton.styleFrom(
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.error.withValues(alpha: 0.1),
                foregroundColor: Theme.of(context).colorScheme.error,
                padding: const EdgeInsets.all(10),
              ),
            ),
          ],
        ),
        if (_searchController.text.isNotEmpty && _searchResults.isEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.person_search,
                  size: 40,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 12),
                Text(
                  'No customers found',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'Create a new customer profile',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () {
                    if (_searchController.text.isNotEmpty) {
                      final searchText = _searchController.text;

                      // Reset form validation first
                      _formKey.currentState?.reset();

                      setState(() {
                        // Clear selected customer first
                        _selectedCustomer = null;

                        // Clear search results and search controller
                        _searchResults = [];
                        _searchController.clear();

                        // Clear all form fields
                        _nameController.clear();
                        _emailController.clear();
                        _phoneController.clear();
                        _addressController.clear();
                        _cityController.clear();
                        _stateController.clear();
                        _zipController.clear();
                        _noteController.clear();

                        // Then populate the appropriate field from search
                        if (RegExp(r'^\d+$').hasMatch(searchText)) {
                          _phoneController.text = searchText;
                        } else if (searchText.contains('@')) {
                          _emailController.text = searchText;
                        } else {
                          _nameController.text = searchText;
                        }
                      });
                    }
                  },
                  icon: const Icon(Icons.person_add, size: 18),
                  label: const Text('Create New Customer'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTabs(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white),
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(color: Colors.white),
              child: TabBar(
                labelPadding: const EdgeInsets.symmetric(horizontal: 16),
                isScrollable: false,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 3,
                    ),
                  ),
                ),
                labelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                labelColor: Theme.of(context).colorScheme.primary,
                unselectedLabelColor: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_outline, size: 18),
                        const SizedBox(width: 8),
                        Text('Customer Info'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history, size: 18),
                        const SizedBox(width: 8),
                        Text('Order History'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildCustomerInfoTab(context),
                  CustomerOrderHistory(
                    customerId: _selectedCustomer?.id,
                    customerName: _selectedCustomer?.fullName,
                    onReorder: widget.onReorder,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerInfoTab(BuildContext context) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 6,
          children: [
            TextFormField(
              controller: _nameController,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Name',
                labelStyle: const TextStyle(fontSize: 13),
                prefixIcon: const Icon(Icons.person_outline, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              validator: (value) {
                // Only validate if user has entered any data
                final hasAnyData =
                    _nameController.text.trim().isNotEmpty ||
                    _phoneController.text.trim().isNotEmpty ||
                    _emailController.text.trim().isNotEmpty ||
                    _addressController.text.trim().isNotEmpty ||
                    _cityController.text.trim().isNotEmpty ||
                    _stateController.text.trim().isNotEmpty ||
                    _zipController.text.trim().isNotEmpty ||
                    _noteController.text.trim().isNotEmpty;

                if (hasAnyData && (value == null || value.trim().isEmpty)) {
                  return 'Name is required';
                }
                return null;
              },
            ),
            TextFormField(
              controller: _emailController,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Email',
                labelStyle: const TextStyle(fontSize: 13),
                prefixIcon: const Icon(Icons.email_outlined, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: _validateEmail,
            ),
            TextFormField(
              controller: _phoneController,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Phone *',
                labelStyle: const TextStyle(fontSize: 13),
                prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              keyboardType: TextInputType.phone,
              validator: _validatePhone,
              onChanged: (value) {
                // If user manually changes phone and it differs from selected customer,
                // clear the selection to indicate we're creating a new customer
                if (_selectedCustomer != null &&
                    _selectedCustomer!.phone != null &&
                    _selectedCustomer!.phone != value.trim()) {
                  setState(() {
                    _selectedCustomer = null;
                  });
                }
              },
            ),
            TextFormField(
              controller: _addressController,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Address',
                labelStyle: const TextStyle(fontSize: 13),
                prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
            Row(
              spacing: 6,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _cityController,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'City',
                      labelStyle: const TextStyle(fontSize: 13),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Theme.of(
                            context,
                          ).colorScheme.outline.withValues(alpha: 0.3),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: TextFormField(
                    controller: _stateController,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'State',
                      labelStyle: const TextStyle(fontSize: 13),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Theme.of(
                            context,
                          ).colorScheme.outline.withValues(alpha: 0.3),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: TextFormField(
                    controller: _zipController,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Zip',
                      labelStyle: const TextStyle(fontSize: 13),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Theme.of(
                            context,
                          ).colorScheme.outline.withValues(alpha: 0.3),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            TextFormField(
              controller: _noteController,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Note',
                labelStyle: const TextStyle(fontSize: 13),
                prefixIcon: const Icon(Icons.note_alt_outlined, size: 20),
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              minLines: 1,
              maxLines: 4,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Row(
        spacing: 12,
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: widget.onCancel,
              icon: Icon(
                widget.isRequired ? Icons.arrow_back : Icons.close,
                size: 20,
              ),
              label: Text(widget.isRequired ? 'Go Back' : 'Cancel'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
                padding: const EdgeInsets.all(16),
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
          Expanded(
            child: FilledButton.icon(
              onPressed: (_isCreatingCustomer || _isUpdatingCustomer)
                  ? null
                  : _handleConfirm,
              icon: (_isCreatingCustomer || _isUpdatingCustomer)
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Icon(
                      _selectedCustomer != null &&
                              _selectedCustomer!.id.isNotEmpty
                          ? (_hasFieldsModified
                                ? Icons.save
                                : Icons.check_circle)
                          : Icons.add_circle,
                      size: 20,
                    ),
              label: Text(
                _isCreatingCustomer
                    ? 'Creating...'
                    : _isUpdatingCustomer
                    ? 'Updating...'
                    : _selectedCustomer != null &&
                          _selectedCustomer!.id.isNotEmpty
                    ? (_hasFieldsModified ? 'Update Customer' : 'Use Customer')
                    : 'Create & Use',
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.all(16),
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
