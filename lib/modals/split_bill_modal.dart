import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zipzap_pos_self_orders/widgets/app_toast.dart';

class SplitBillModal extends StatefulWidget {
  final int currentSplitQty;
  final Function(int) onConfirm;
  final VoidCallback onCancel;

  const SplitBillModal({
    super.key,
    required this.currentSplitQty,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<SplitBillModal> createState() => _SplitBillModalState();
}

class _SplitBillModalState extends State<SplitBillModal> {
  late TextEditingController _splitQtyController;
  late double _sliderValue;

  @override
  void initState() {
    super.initState();
    _sliderValue = widget.currentSplitQty.toDouble();
    _splitQtyController = TextEditingController(
      text: widget.currentSplitQty.toString(),
    );
    _splitQtyController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _splitQtyController.removeListener(_onTextChanged);
    _splitQtyController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final value = int.tryParse(_splitQtyController.text);
    if (value != null && value >= 1 && value <= 20) {
      if (_sliderValue != value.toDouble()) {
        setState(() {
          _sliderValue = value.toDouble();
        });
      }
    }
  }

  void _updateValue(int value) {
    if (value >= 1 && value <= 20) {
      setState(() {
        _sliderValue = value.toDouble();
        _splitQtyController.text = value.toString();
      });
    }
  }

  void _handleDecrement() {
    final currentValue = int.tryParse(_splitQtyController.text) ?? 1;
    if (currentValue > 1) {
      _updateValue(currentValue - 1);
    }
  }

  void _handleIncrement() {
    final currentValue = int.tryParse(_splitQtyController.text) ?? 1;
    if (currentValue < 20) {
      _updateValue(currentValue + 1);
    }
  }

  void _handleConfirm() {
    final value = int.tryParse(_splitQtyController.text) ?? 1;
    if (value >= 1 && value <= 20) {
      widget.onConfirm(value);
      Navigator.of(context).pop();
    } else {
      AppToast.warning(
        context: context,
        title: 'Invalid Number',
        description: 'Please enter a number between 1 and 20',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 768;
    final modalWidth = isSmallScreen
        ? screenWidth * 0.95
        : (screenWidth < 1024 ? 400.0 : 450.0);

    return Dialog(
      child: Container(
        width: modalWidth,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context),
            _buildContent(context),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 12),
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
              'Split Bill',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(icon: const Icon(Icons.close), onPressed: widget.onCancel),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Number of Splits',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                onPressed: _handleDecrement,
                icon: const Icon(Icons.remove),
                style: IconButton.styleFrom(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: 'Enter number (1-20)',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  controller: _splitQtyController,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _handleIncrement,
                icon: const Icon(Icons.add),
                style: IconButton.styleFrom(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Quick Select',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Slider(
            value: _sliderValue,
            min: 1,
            max: 20,
            divisions: 19,
            label: _sliderValue.round().toString(),
            onChanged: (value) {
              _updateValue(value.round());
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '1',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
              ),
              Text(
                '20',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
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
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.icon(
              onPressed: _handleConfirm,
              icon: const Icon(Icons.check),
              label: const Text('Apply'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
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
