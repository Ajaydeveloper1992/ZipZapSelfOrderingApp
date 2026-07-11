import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';

class ProductsFilters extends StatefulWidget {
  final String selectedStatus;
  final Map<String, int> statusCounts;
  final String searchQuery;
  final DateTimeRange? dateRange;
  final Function(String) onStatusChanged;
  final Function(String) onSearchChanged;
  final Function(DateTimeRange?) onDateRangeChanged;

  const ProductsFilters({
    super.key,
    required this.selectedStatus,
    required this.statusCounts,
    required this.searchQuery,
    required this.dateRange,
    required this.onStatusChanged,
    required this.onSearchChanged,
    required this.onDateRangeChanged,
  });

  @override
  State<ProductsFilters> createState() => _ProductsFiltersState();
}

class _ProductsFiltersState extends State<ProductsFilters> {
  late TextEditingController _searchController;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.searchQuery);
  }

  @override
  void didUpdateWidget(ProductsFilters oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only update if the external search query changed and differs from current text
    if (oldWidget.searchQuery != widget.searchQuery &&
        widget.searchQuery != _searchController.text) {
      _searchController.text = widget.searchQuery;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    // Cancel any pending timer
    _debounceTimer?.cancel();

    // Short debounce for local filtering (feels instant but reduces rebuilds)
    _debounceTimer = Timer(const Duration(milliseconds: 150), () {
      widget.onSearchChanged(value);
    });
  }

  Future<void> _selectDateRange() async {
    final List<DateTime?>? picked = await showCalendarDatePicker2Dialog(
      context: context,
      config: CalendarDatePicker2WithActionButtonsConfig(
        calendarType: CalendarDatePicker2Type.range,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
        selectedDayHighlightColor: Theme.of(context).colorScheme.primary,
        selectedRangeDayTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        selectedRangeHighlightColor: Theme.of(
          context,
        ).colorScheme.primary.withOpacity(0.3),
        centerAlignModePicker: true,
        disableModePicker: false,
        dayTextStyle: const TextStyle(fontSize: 13),
        weekdayLabelTextStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        controlsHeight: 40,
        dayBorderRadius: BorderRadius.circular(6),
        yearBorderRadius: BorderRadius.circular(6),
        closeDialogOnOkTapped: true,
        closeDialogOnCancelTapped: true,
        gapBetweenCalendarAndButtons: 8,
        okButtonTextStyle: const TextStyle(fontSize: 13),
        cancelButtonTextStyle: const TextStyle(fontSize: 13),
        buttonPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      ),
      dialogSize: const Size(340, 400),
      value: widget.dateRange != null
          ? [widget.dateRange!.start, widget.dateRange!.end]
          : [],
      borderRadius: BorderRadius.circular(12),
    );

    if (picked != null &&
        picked.length >= 2 &&
        picked[0] != null &&
        picked[1] != null) {
      widget.onDateRangeChanged(
        DateTimeRange(start: picked[0]!, end: picked[1]!),
      );
    } else if (picked != null && picked.isEmpty) {
      widget.onDateRangeChanged(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedStatus = widget.selectedStatus;
    final statusOptions = <String, Widget>{
      'all': _buildSegmentLabel(
        'All',
        widget.statusCounts['all'] ?? 0,
        selectedStatus == 'all',
      ),
      'active': _buildSegmentLabel(
        'Active',
        widget.statusCounts['active'] ?? 0,
        selectedStatus == 'active',
      ),
      'inactive': _buildSegmentLabel(
        'Inactive',
        widget.statusCounts['inactive'] ?? 0,
        selectedStatus == 'inactive',
      ),
      'lowstock': _buildSegmentLabel(
        'Low Stock',
        widget.statusCounts['lowstock'] ?? 0,
        selectedStatus == 'lowstock',
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status filter segmented control
        CupertinoSlidingSegmentedControl<String>(
          groupValue: widget.selectedStatus,
          onValueChanged: (value) {
            if (value != null) {
              widget.onStatusChanged(value);
            }
          },
          children: statusOptions,
          thumbColor: Theme.of(context).colorScheme.primary,
          backgroundColor: Colors.grey.shade200,
          padding: const EdgeInsets.all(2),
        ),
        const SizedBox(height: 10),
        // Search and date range
        Row(
          children: [
            // Search field
            Expanded(
              child: SizedBox(
                height: 40,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search...',
                    hintStyle: const TextStyle(fontSize: 14),
                    prefixIcon: const Icon(Icons.search, size: 24),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _debounceTimer?.cancel();
                              _searchController.clear();
                              widget.onSearchChanged('');
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 40,
                            ),
                            visualDensity: VisualDensity.compact,
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 12),
                  onChanged: _onSearchChanged,
                ),
              ),
            ),
            const Spacer(),
            if (widget.dateRange != null) ...[
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () => widget.onDateRangeChanged(null),
                color: Theme.of(context).colorScheme.error,
                tooltip: 'Clear date range',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                visualDensity: VisualDensity.compact,
              ),
            ],
            // Date range picker
            SizedBox(
              height: 40,
              child: OutlinedButton.icon(
                onPressed: _selectDateRange,
                icon: const Icon(Icons.calendar_today, size: 14),
                label: Text(
                  widget.dateRange != null
                      ? '${DateFormat('MMM dd').format(widget.dateRange!.start)} - ${DateFormat('MMM dd').format(widget.dateRange!.end)}'
                      : 'Choose Date',
                  style: const TextStyle(fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 6,
                  ),
                  side: BorderSide(color: Colors.grey.shade300),
                  minimumSize: const Size(120, 40),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSegmentLabel(String label, int count, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(
        '$label ($count)',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: isSelected ? Colors.white : Colors.black87,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

