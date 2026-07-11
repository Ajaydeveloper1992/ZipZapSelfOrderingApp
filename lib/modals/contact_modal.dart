import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:zipzap_pos_self_orders/models/customer_model.dart';
import 'package:zipzap_pos_self_orders/services/customers_service.dart';
import 'package:zipzap_pos_self_orders/widgets/app_toast.dart';

enum ContactType { email, sms, both }

enum MessageTemplate { orderReady, delayNotice, pickupReminder, custom }

class ContactModal extends StatefulWidget {
  final Customer? customer;
  final String? orderNumber;
  final String? storeName;
  final DateTime? currentPickupTime;
  final VoidCallback onCancel;
  final Function({
    required ContactType contactType,
    required String message,
    DateTime? pickupTime,
  })?
  onSend;

  const ContactModal({
    super.key,
    this.customer,
    this.orderNumber,
    this.storeName,
    this.currentPickupTime,
    required this.onCancel,
    this.onSend,
  });

  @override
  State<ContactModal> createState() => _ContactModalState();
}

class _ContactModalState extends State<ContactModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _messageController;
  final CustomersService _customersService = CustomersService();
  ContactType _selectedContactType = ContactType.both;
  DateTime? _selectedPickupTime;
  MessageTemplate _currentTemplate = MessageTemplate.orderReady;
  bool _isSending = false;

  final Map<MessageTemplate, String> _templateTitles = {
    MessageTemplate.orderReady: 'Order Ready',
    MessageTemplate.delayNotice: 'Delay Notice',
    MessageTemplate.pickupReminder: 'Pickup Reminder',
    MessageTemplate.custom: 'Custom Message',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _messageController = TextEditingController();
    _selectedPickupTime = widget.currentPickupTime;

    // Set initial template
    _updateMessageFromTemplate(MessageTemplate.orderReady);

    // Listen to tab changes
    _tabController.addListener(_handleTabChange);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (!_tabController.indexIsChanging) {
      setState(() {
        _currentTemplate = MessageTemplate.values[_tabController.index];
        _updateMessageFromTemplate(_currentTemplate);
      });
    }
  }

  String _getTemplateMessage(MessageTemplate template) {
    final customerName = widget.customer?.fullName ?? 'Customer';
    final orderNum = widget.orderNumber ?? 'N/A';
    final pickupTimeStr = _selectedPickupTime != null
        ? _formatPickupTime(_selectedPickupTime!)
        : '[Select Time]';
    final storeName = widget.storeName ?? 'Our Store';

    switch (template) {
      case MessageTemplate.orderReady:
        return '''Hi $customerName,

Your order #$orderNum is ready for pickup.
Please come by at your convenience to collect your order.

Thank you for choosing us!
$storeName''';

      case MessageTemplate.delayNotice:
        return '''Hi $customerName,

We apologize for the inconvenience. Your order #$orderNum is taking a bit longer than expected.
New estimated pickup time: $pickupTimeStr
We appreciate your patience and understanding.

Thanks,
$storeName''';

      case MessageTemplate.pickupReminder:
        return '''Hi $customerName,

This is a friendly reminder that your order #$orderNum is ready for pickup.
Pickup time: $pickupTimeStr
We look forward to seeing you soon!''';

      case MessageTemplate.custom:
        return '''Hi $customerName,

Your order #$orderNum update:
[Type your custom message here]

Thank you!''';
    }
  }

  void _updateMessageFromTemplate(MessageTemplate template) {
    _messageController.text = _getTemplateMessage(template);
  }

  String _formatPickupTime(DateTime time) {
    final hour = time.hour == 0
        ? 12
        : time.hour > 12
        ? time.hour - 12
        : time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Future<void> _showTimePicker() async {
    final now = DateTime.now();
    final initialTime = _selectedPickupTime ?? now;

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => Container(
        height: 280,
        padding: const EdgeInsets.only(top: 6.0),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: const BoxDecoration(
          color: CupertinoColors.systemBackground,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: CupertinoColors.separator,
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const Text(
                      'Select Pickup Time',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        Navigator.of(context).pop();
                        // Update template message with new time
                        _updateMessageFromTemplate(_currentTemplate);
                      },
                      child: const Text(
                        'Done',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.time,
                      initialDateTime: initialTime,
                      use24hFormat: false,
                      onDateTimeChanged: (DateTime newTime) {
                        setState(() {
                          _selectedPickupTime = newTime;
                        });
                      },
                    ),
                    Center(
                      child: Transform.translate(
                        offset: const Offset(-30, -2),
                        child: const Text(
                          ':',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w300,
                            color: CupertinoColors.label,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _canSend() {
    if (_messageController.text.trim().isEmpty) return false;

    // Check if customer has the required contact info
    if (_selectedContactType == ContactType.email ||
        _selectedContactType == ContactType.both) {
      if (widget.customer?.email == null || widget.customer!.email!.isEmpty) {
        return false;
      }
    }

    if (_selectedContactType == ContactType.sms ||
        _selectedContactType == ContactType.both) {
      if (widget.customer?.phone == null || widget.customer!.phone!.isEmpty) {
        return false;
      }
    }

    return true;
  }

  String? _getValidationMessage() {
    if (widget.customer == null) {
      return 'No customer selected';
    }

    if (_selectedContactType == ContactType.email ||
        _selectedContactType == ContactType.both) {
      if (widget.customer?.email == null || widget.customer!.email!.isEmpty) {
        return 'Customer has no email address';
      }
    }

    if (_selectedContactType == ContactType.sms ||
        _selectedContactType == ContactType.both) {
      if (widget.customer?.phone == null || widget.customer!.phone!.isEmpty) {
        return 'Customer has no phone number';
      }
    }

    return null;
  }

  // Convert ContactType enum to API string
  String _getContactTypeString(ContactType type) {
    switch (type) {
      case ContactType.email:
        return 'email';
      case ContactType.sms:
        return 'sms';
      case ContactType.both:
        return 'both';
    }
  }

  // Convert MessageTemplate enum to API template type string
  String _getTemplateTypeString(MessageTemplate template) {
    switch (template) {
      case MessageTemplate.orderReady:
        return 'order_ready';
      case MessageTemplate.delayNotice:
        return 'delay';
      case MessageTemplate.pickupReminder:
        return 'reminder';
      case MessageTemplate.custom:
        return 'custom';
    }
  }

  // Get email subject based on template
  String _getEmailSubject(MessageTemplate template) {
    final orderNum = widget.orderNumber ?? 'N/A';
    switch (template) {
      case MessageTemplate.orderReady:
        return 'Your Order #$orderNum is Ready!';
      case MessageTemplate.delayNotice:
        return 'Update on Your Order #$orderNum';
      case MessageTemplate.pickupReminder:
        return 'Reminder: Your Order #$orderNum is Waiting';
      case MessageTemplate.custom:
        return 'Update on Your Order #$orderNum';
    }
  }

  // Get GHL tags based on template type (API supports: order_ready, delayed_order, completed_order)
  List<String>? _getTagsForTemplate(MessageTemplate template) {
    switch (template) {
      case MessageTemplate.orderReady:
        return ['order_ready'];
      case MessageTemplate.delayNotice:
        return ['delayed_order'];
      case MessageTemplate.pickupReminder:
      case MessageTemplate.custom:
        return null; // No tags for these templates
    }
  }

  Future<void> _handleSend() async {
    final validationMessage = _getValidationMessage();
    if (validationMessage != null) {
      AppToast.warning(
        context: context,
        title: 'Cannot Send',
        description: validationMessage,
      );
      return;
    }

    if (_messageController.text.trim().isEmpty) {
      AppToast.warning(
        context: context,
        title: 'Empty Message',
        description: 'Please enter a message to send',
      );
      return;
    }

    // Check if customer ID is available
    if (widget.customer?.id == null || widget.customer!.id.isEmpty) {
      AppToast.error(
        context: context,
        title: 'Cannot Send',
        description: 'Customer ID is not available',
      );
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      // Call the customers service to send the notification
      final result = await _customersService.contactCustomer(
        customerId: widget.customer!.id,
        contactType: _getContactTypeString(_selectedContactType),
        templateType: _getTemplateTypeString(_currentTemplate),
        messageBody: _messageController.text.trim(),
        orderNumber: widget.orderNumber,
        subject:
            (_selectedContactType == ContactType.email ||
                _selectedContactType == ContactType.both)
            ? _getEmailSubject(_currentTemplate)
            : null,
        orderInfo: widget.orderNumber != null
            ? {'orderNumber': widget.orderNumber}
            : null,
        tags: _getTagsForTemplate(_currentTemplate),
      );

      // Also call the onSend callback if provided (for additional handling)
      await widget.onSend?.call(
        contactType: _selectedContactType,
        message: _messageController.text.trim(),
        pickupTime: _selectedPickupTime,
      );

      if (mounted) {
        // Build success message based on results
        String successDescription = 'Your message has been sent successfully';
        final results = result['results'] as Map<String, dynamic>?;
        if (results != null) {
          final emailSent = results['email']?['sent'] as bool? ?? false;
          final smsSent = results['sms']?['sent'] as bool? ?? false;

          if (_selectedContactType == ContactType.both) {
            final sentMethods = <String>[];
            if (emailSent) sentMethods.add('email');
            if (smsSent) sentMethods.add('SMS');
            if (sentMethods.isNotEmpty) {
              successDescription =
                  'Message sent via ${sentMethods.join(' and ')}';
            }
          } else if (_selectedContactType == ContactType.email && emailSent) {
            successDescription = 'Email sent successfully';
          } else if (_selectedContactType == ContactType.sms && smsSent) {
            successDescription = 'SMS sent successfully';
          }
        }

        AppToast.success(
          context: context,
          title: 'Message Sent',
          description: successDescription,
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(
          context: context,
          title: 'Failed to Send',
          description: e.toString().replaceAll('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 768;
    final modalWidth = isSmallScreen
        ? screenWidth * 0.95
        : (screenWidth < 1024 ? 650.0 : 750.0);
    final modalHeight = isSmallScreen
        ? MediaQuery.of(context).size.height * 0.9
        : MediaQuery.of(context).size.height * 0.75;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: modalWidth,
        constraints: BoxConstraints(maxHeight: modalHeight),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context),
            _buildContactTypeSelector(context),
            Expanded(child: _buildContent(context)),
            _buildFooter(context),
          ],
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
              Icons.send_rounded,
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
                  'Contact Customer',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                if (widget.customer != null)
                  Text(
                    widget.customer!.fullName,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
              ],
            ),
          ),
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

  Widget _buildContactTypeSelector(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.black.withAlpha(25), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contact Method',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildContactTypeChip(
                  context,
                  ContactType.email,
                  Icons.email_outlined,
                  'Email',
                  widget.customer?.email != null &&
                      widget.customer!.email!.isNotEmpty,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildContactTypeChip(
                  context,
                  ContactType.sms,
                  Icons.sms_outlined,
                  'SMS',
                  widget.customer?.phone != null &&
                      widget.customer!.phone!.isNotEmpty,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildContactTypeChip(
                  context,
                  ContactType.both,
                  Icons.mark_email_read_outlined,
                  'Both',
                  (widget.customer?.email != null &&
                          widget.customer!.email!.isNotEmpty) &&
                      (widget.customer?.phone != null &&
                          widget.customer!.phone!.isNotEmpty),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContactTypeChip(
    BuildContext context,
    ContactType type,
    IconData icon,
    String label,
    bool isAvailable,
  ) {
    final isSelected = _selectedContactType == type;

    return InkWell(
      onTap: isAvailable
          ? () {
              setState(() {
                _selectedContactType = type;
              });
            }
          : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: !isAvailable
              ? Colors.grey.shade100
              : isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: !isAvailable
                ? Colors.grey.shade300
                : isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: !isAvailable
                  ? Colors.grey.shade400
                  : isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey.shade600,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: !isAvailable
                    ? Colors.grey.shade400
                    : isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white),
      child: Column(
        children: [
          // Tabs
          Container(
            decoration: BoxDecoration(color: Colors.white),
            child: TabBar(
              controller: _tabController,
              labelPadding: const EdgeInsets.symmetric(horizontal: 8),
              isScrollable: true,
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
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
              tabs: [
                Tab(
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline, size: 16),
                      const SizedBox(width: 6),
                      Text('Order Ready'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    children: [
                      Icon(Icons.access_time, size: 16),
                      const SizedBox(width: 6),
                      Text('Delay Notice'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    children: [
                      Icon(Icons.notifications_outlined, size: 16),
                      const SizedBox(width: 6),
                      Text('Reminder'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 16),
                      const SizedBox(width: 6),
                      Text('Custom'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pickup Time Selector (shown for relevant templates)
                  if (_currentTemplate == MessageTemplate.delayNotice ||
                      _currentTemplate == MessageTemplate.pickupReminder) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Pickup Time',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        OutlinedButton.icon(
                          onPressed: _showTimePicker,
                          icon: const Icon(Icons.edit, size: 16),
                          label: Text(
                            _selectedPickupTime != null
                                ? _formatPickupTime(_selectedPickupTime!)
                                : 'Select Time',
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  // Message Input
                  Text(
                    'Message',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _messageController,
                    maxLines: 12,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Type your message here...',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
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
                      filled: true,
                      fillColor: Theme.of(
                        context,
                      ).colorScheme.surface.withValues(alpha: 0.5),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Character count
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Template: ${_templateTitles[_currentTemplate]}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${_messageController.text.length} characters',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final validationMessage = _getValidationMessage();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (validationMessage != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.errorContainer.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.error.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_rounded,
                    size: 18,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      validationMessage,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            spacing: 12,
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.onCancel,
                  icon: const Icon(Icons.close, size: 20),
                  label: const Text('Cancel'),
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
                  onPressed: (_isSending || !_canSend()) ? null : _handleSend,
                  icon: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(Icons.send, size: 20),
                  label: Text(_isSending ? 'Sending...' : 'Send Message'),
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
        ],
      ),
    );
  }
}
