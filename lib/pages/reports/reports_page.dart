import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:zipzap_pos_self_orders/widgets/header/widget.dart';
import 'package:zipzap_pos_self_orders/widgets/app_drawer.dart';
import 'package:zipzap_pos_self_orders/models/report_model.dart';
import 'package:zipzap_pos_self_orders/services/reports_service.dart';
import 'package:zipzap_pos_self_orders/core/services/auth_service.dart';
import 'package:zipzap_pos_self_orders/services/printer_service.dart';
import 'package:zipzap_pos_self_orders/models/printer_model.dart';
import 'package:zipzap_pos_self_orders/widgets/app_toast.dart';
import 'package:zipzap_pos_self_orders/providers/data_provider.dart';
import 'package:csv/csv.dart';
import 'package:zipzap_pos_self_orders/utils/download_helper.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final ReportsService _reportsService = ReportsService();
  final AuthService _authService = AuthService();
  final DataProvider _dataProvider = DataProvider();

  ReportModel? _report;
  bool _isLoading = false;
  String? _errorMessage;
  String _reportType = 'daily'; // 'daily' or 'custom'
  DateTimeRange? _dateRange;
  bool _isPrinting = false;
  bool _isSendingEmail = false;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    // Load daily report for today on initial load
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get store ID and timezone from DataProvider (source of truth)
      final dataProvider = DataProvider();
      final storeId =
          dataProvider.store?.id ?? _authService.getProfile()?.storeId;
      // Get store timezone - use store address timezone if available
      final storeTimezone = dataProvider.store?.address?.timezone;

      ReportModel report;

      if (_reportType == 'daily') {
        // Use selected date range start date, or today's date
        final date = _dateRange?.start ?? DateTime.now();
        report = await _reportsService.getDailyReport(
          date: date,
          storeId: storeId,
          storeTimezone: storeTimezone,
        );
      } else {
        // Custom range - use date range or default to today
        final startDate = _dateRange?.start ?? DateTime.now();
        final endDate = _dateRange?.end ?? DateTime.now();
        report = await _reportsService.getCustomReport(
          startDate: startDate,
          endDate: endDate,
          storeId: storeId,
          storeTimezone: storeTimezone,
        );
      }

      setState(() {
        _report = report;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      debugPrint('Error loading report: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _report = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 1024;

    return Scaffold(
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Builder(
              builder: (context) => HeaderWidget(
                logoUrl: 'https://zipzappos.com',
                onDrawerPressed: () {
                  Scaffold.of(context).openDrawer();
                },
                onSearchChanged: (query) {
                  // Handle search
                },
                serverStatus: true,
              ),
            ),
            // Main content
            Expanded(
              child: Stack(
                children: [
                  SingleChildScrollView(
                    padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1400),
                        child: _errorMessage != null && _report == null
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      size: 64,
                                      color: Colors.red.shade300,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _errorMessage!,
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey.shade600,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton.icon(
                                      onPressed: _isLoading
                                          ? null
                                          : _loadReport,
                                      icon: _isLoading
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(Icons.refresh),
                                      label: const Text('Retry'),
                                    ),
                                  ],
                                ),
                              )
                            : _report == null && !_isLoading
                            ? const Center(
                                child: Text('No report data available'),
                              )
                            : Column(
                                spacing: 12,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header Section
                                  _buildHeaderSection(),
                                  // Summary Cards
                                  _buildSummaryCards(),
                                  // Two Column Layout
                                  isSmallScreen
                                      ? _buildMobileLayout()
                                      : _buildDesktopLayout(),
                                ],
                              ),
                      ),
                    ),
                  ),
                  // Loading overlay
                  if (_isLoading && _report != null)
                    Container(
                      color: Colors.black.withValues(alpha: 0.3),
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDateRange() async {
    final isDaily = _reportType == 'daily';

    final List<DateTime?>? picked = await showCalendarDatePicker2Dialog(
      context: context,
      config: CalendarDatePicker2WithActionButtonsConfig(
        calendarType: isDaily
            ? CalendarDatePicker2Type.single
            : CalendarDatePicker2Type.range,
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
      value: isDaily
          ? (_dateRange != null ? [_dateRange!.start] : [])
          : (_dateRange != null ? [_dateRange!.start, _dateRange!.end] : []),
      borderRadius: BorderRadius.circular(12),
    );

    if (isDaily) {
      // Single date selection for daily reports
      if (picked != null && picked.isNotEmpty && picked[0] != null) {
        final selectedDate = picked[0]!;
        setState(() {
          _dateRange = DateTimeRange(start: selectedDate, end: selectedDate);
        });
        _loadReport();
      } else if (picked != null && picked.isEmpty) {
        setState(() {
          _dateRange = null;
        });
        _loadReport();
      }
    } else {
      // Range selection for custom reports
      if (picked != null &&
          picked.length >= 2 &&
          picked[0] != null &&
          picked[1] != null) {
        setState(() {
          _dateRange = DateTimeRange(start: picked[0]!, end: picked[1]!);
        });
        _loadReport();
      } else if (picked != null && picked.isEmpty) {
        setState(() {
          _dateRange = null;
        });
        _loadReport();
      }
    }
  }

  Widget _buildHeaderSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isSmallScreen = constraints.maxWidth < 768;
          final isVerySmallScreen = constraints.maxWidth < 500;
          return isSmallScreen
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Reports',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        // Action buttons row
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildIconButton(
                              icon: Icons.refresh,
                              onPressed: _isLoading ? null : _loadReport,
                              tooltip: 'Refresh report',
                              isLoading: _isLoading,
                            ),
                            _buildIconButton(
                              icon: Icons.print,
                              onPressed:
                                  _isLoading || _isPrinting || _report == null
                                  ? null
                                  : _handlePrintReport,
                              tooltip: 'Print report',
                              isLoading: _isPrinting,
                            ),
                            _buildIconButton(
                              icon: Icons.download,
                              onPressed:
                                  _isLoading ||
                                      _isDownloading ||
                                      _report == null
                                  ? null
                                  : _handleDownloadReport,
                              tooltip: 'Download CSV',
                              isLoading: _isDownloading,
                            ),
                            _buildIconButton(
                              icon: Icons.email,
                              onPressed:
                                  _isLoading ||
                                      _isSendingEmail ||
                                      _report == null
                                  ? null
                                  : _handleSendReportEmail,
                              tooltip: 'Send report',
                              isLoading: _isSendingEmail,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Report type and date picker
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        // Report type segmented control
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildReportTypeButton('Daily', 'daily'),
                              _buildReportTypeButton('Custom Range', 'custom'),
                            ],
                          ),
                        ),
                        // Date picker
                        SizedBox(
                          width: isVerySmallScreen ? double.infinity : 260,
                          height: 40,
                          child: OutlinedButton.icon(
                            onPressed: _selectDateRange,
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: Text(
                              _dateRange != null
                                  ? _reportType == 'daily'
                                        ? DateFormat(
                                            'MMM dd, yyyy',
                                          ).format(_dateRange!.start)
                                        : '${DateFormat('MMM dd').format(_dateRange!.start)} - ${DateFormat('MMM dd, yyyy').format(_dateRange!.end)}'
                                  : 'Choose Date',
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              side: BorderSide(color: Colors.grey.shade300),
                              alignment: Alignment.centerLeft,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'Reports',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    _buildHeaderActions(),
                  ],
                );
        },
      ),
    );
  }

  Widget _buildHeaderActions() {
    return Row(
      spacing: 8,
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Report type segmented control
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(6),
          ),
          // child: Row(
          //   mainAxisSize: MainAxisSize.min,
          //   children: [
          //     _buildReportTypeButton('Daily', 'daily'),
          //     _buildReportTypeButton('Custom Range', 'custom'),
          //   ],
          // ),
        ),
        // Date picker (single for daily, range for custom)
        // SizedBox(
        //   width: 280,
        //   height: 40,
        //   child: OutlinedButton.icon(
        //     onPressed: _selectDateRange,
        //     icon: const Icon(Icons.calendar_today, size: 16),
        //     label: Text(
        //       _dateRange != null
        //           ? _reportType == 'daily'
        //                 ? DateFormat('MMM dd, yyyy').format(_dateRange!.start)
        //                 : '${DateFormat('MMM dd').format(_dateRange!.start)} - ${DateFormat('MMM dd, yyyy').format(_dateRange!.end)}'
        //           : 'Choose Date',
        //       style: const TextStyle(fontSize: 13),
        //       overflow: TextOverflow.ellipsis,
        //     ),
        //     style: OutlinedButton.styleFrom(
        //       shape: RoundedRectangleBorder(
        //         borderRadius: BorderRadius.circular(6),
        //       ),
        //       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        //       side: BorderSide(color: Colors.grey.shade300),
        //       alignment: Alignment.centerLeft,
        //     ),
        //   ),
        // ),
        // Action buttons
        _buildIconButton(
          icon: Icons.refresh,
          onPressed: _isLoading ? null : _loadReport,
          tooltip: 'Refresh report',
          isLoading: _isLoading,
        ),
        _buildIconButton(
          icon: Icons.print,
          onPressed: _isLoading || _isPrinting || _report == null
              ? null
              : _handlePrintReport,
          tooltip: 'Print report',
          isLoading: _isPrinting,
        ),
        _buildIconButton(
          icon: Icons.download,
          onPressed: _isLoading || _isDownloading || _report == null
              ? null
              : _handleDownloadReport,
          tooltip: 'Download CSV',
          isLoading: _isDownloading,
        ),
        _buildIconButton(
          icon: Icons.email,
          onPressed: _isLoading || _isSendingEmail || _report == null
              ? null
              : _handleSendReportEmail,
          tooltip: 'Send report',
          isLoading: _isSendingEmail,
        ),
      ],
    );
  }

  Widget _buildReportTypeButton(String label, String value) {
    final isSelected = _reportType == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _reportType = value;
          if (value == 'daily') {
            _dateRange = null;
          }
        });
        // Reload report based on type
        _loadReport();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          borderRadius: BorderRadius.horizontal(
            left: value == 'daily' ? const Radius.circular(6) : Radius.zero,
            right: value == 'custom' ? const Radius.circular(6) : Radius.zero,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required String tooltip,
    bool isLoading = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 40,
        height: 40,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: isLoading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                )
              : Icon(icon, size: 18),
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    if (_report == null) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 600;
        final crossAxisCount = isSmallScreen ? 2 : 4;

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: constraints.maxWidth < 600
              ? 1.25
              : constraints.maxWidth < 1024
              ? 1.5
              : 2.5,
          children: [
            _buildStatCard(
              'Net Sale',
              '\$${_report!.netSale.toStringAsFixed(2)}',
              Icons.attach_money,
              Colors.green,
            ),
            _buildStatCard(
              'Gross Sale',
              '\$${_report!.grossSale.toStringAsFixed(2)}',
              Icons.trending_up,
              Colors.blue,
            ),
            _buildStatCard(
              'Total Orders',
              '${_report!.totalOrders}',
              Icons.shopping_cart,
              Colors.orange,
            ),
            _buildStatCard(
              'Average Order',
              '\$${_report!.averageOrderValue.toStringAsFixed(2)}',
              Icons.analytics,
              Colors.purple,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    if (_report == null) return const SizedBox.shrink();

    final cards = <Widget>[];

    // Always show these cards (they have data even if zeros)
    cards.add(_buildFinancialDetailsCard());
    cards.add(const SizedBox(height: 12));
    cards.add(_buildOrderStatsCard());

    // Conditionally add cards that might be empty
    if (_report!.topSellingItems.isNotEmpty) {
      cards.add(const SizedBox(height: 12));
      cards.add(_buildTopSellingItemsCard());
    }

    if (_report!.paymentMethods.isNotEmpty) {
      cards.add(const SizedBox(height: 12));
      cards.add(_buildPaymentMethodsCard());
    }

    // Hourly breakdown always shows (either data or "No activity" message)
    cards.add(const SizedBox(height: 12));
    cards.add(_buildHourlyBreakdownCard());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: cards,
    );
  }

  Widget _buildDesktopLayout() {
    if (_report == null) return const SizedBox.shrink();

    final leftColumnCards = <Widget>[];
    final rightColumnCards = <Widget>[];

    // Left column: Top selling items and hourly breakdown
    if (_report!.topSellingItems.isNotEmpty) {
      leftColumnCards.add(_buildTopSellingItemsCard());
      leftColumnCards.add(const SizedBox(height: 12));
    }

    // Hourly breakdown always shows (either data or "No activity" message)
    leftColumnCards.add(_buildHourlyBreakdownCard());

    // Right column: Financial details, order stats, payment methods
    rightColumnCards.add(_buildFinancialDetailsCard());
    rightColumnCards.add(const SizedBox(height: 12));
    rightColumnCards.add(_buildOrderStatsCard());

    if (_report!.paymentMethods.isNotEmpty) {
      rightColumnCards.add(const SizedBox(height: 12));
      rightColumnCards.add(_buildPaymentMethodsCard());
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column
        Expanded(flex: 2, child: Column(children: leftColumnCards)),
        const SizedBox(width: 12),
        // Right Column
        Expanded(flex: 1, child: Column(children: rightColumnCards)),
      ],
    );
  }

  Widget _buildFinancialDetailsCard() {
    if (_report == null) return const SizedBox.shrink();

    return _buildCard(
      title: 'Financial Details',
      child: Column(
        children: [
          _buildInfoRow('Net Sale', '\$${_report!.netSale.toStringAsFixed(2)}'),
          _buildInfoRow(
            'Gross Sale',
            '\$${_report!.grossSale.toStringAsFixed(2)}',
          ),
          _buildInfoRow('Tax', '\$${_report!.tax.toStringAsFixed(2)}'),
          _buildInfoRow('Refund', '\$${_report!.refund.toStringAsFixed(2)}'),
          _buildInfoRow(
            'Discount',
            '\$${_report!.discount.toStringAsFixed(2)}',
          ),
          _buildInfoRow('Tip', '\$${_report!.tip.toStringAsFixed(2)}'),
          _buildInfoRow(
            'Collected by Cash',
            '\$${_report!.totalCollectedInCash.toStringAsFixed(2)}',
          ),
          _buildInfoRow(
            'Collected by Card',
            '\$${_report!.totalCollectedInCard.toStringAsFixed(2)}',
          ),
          if (_report!.voidOrders > 0) ...[
            _buildInfoRow('Void Orders', '${_report!.voidOrders}'),
            _buildInfoRow(
              'Void Total',
              '\$${_report!.voidOrdersTotal.toStringAsFixed(2)}',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOrderStatsCard() {
    if (_report == null) return const SizedBox.shrink();

    return _buildCard(
      title: 'Order Statistics',
      child: Column(
        children: [
          _buildInfoRow('Total Items', '${_report!.totalItems}'),
          _buildInfoRow(
            'Avg Items/Order',
            _report!.averageItemsPerOrder.toStringAsFixed(1),
          ),
        ],
      ),
    );
  }

  Widget _buildTopSellingItemsCard() {
    if (_report == null || _report!.topSellingItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return _buildCard(
      title: 'Top Selling Items',
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(3),
          1: FlexColumnWidth(1),
          2: FlexColumnWidth(1.5),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            children: [
              _buildTableHeader('Item Name', TextAlign.left),
              _buildTableHeader('Qty', TextAlign.right),
              _buildTableHeader('Revenue', TextAlign.right),
            ],
          ),
          ..._report!.topSellingItems.map((item) {
            return TableRow(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 8,
                  ),
                  child: Text(
                    item.itemName,
                    style: const TextStyle(fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 8,
                  ),
                  child: Text(
                    '${item.quantity}',
                    style: const TextStyle(fontSize: 13),
                    textAlign: TextAlign.right,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 8,
                  ),
                  child: Text(
                    '\$${item.revenue.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodsCard() {
    if (_report == null || _report!.paymentMethods.isEmpty) {
      return const SizedBox.shrink();
    }

    return _buildCard(
      title: 'Payment Methods',
      child: Column(
        children: _report!.paymentMethods.map((method) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _getPaymentMethodColor(method.method),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        method.method,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${method.count} orders',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(width: 16),
                Text(
                  '\$${method.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHourlyBreakdownCard() {
    if (_report == null || _report!.hourlyBreakdown.isEmpty) {
      return const SizedBox.shrink();
    }

    final hoursWithData = _report!.hourlyBreakdown
        .where((h) => h.orders > 0 || h.revenue > 0)
        .toList();

    if (hoursWithData.isEmpty) {
      return _buildCard(
        title: 'Hourly Breakdown',
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.schedule_outlined,
                  size: 48,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No activity for this period',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'There were no orders or transactions during any hour of the selected period.',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return _buildCard(
      title: 'Hourly Breakdown',
      child: SizedBox(
        width: double.infinity,
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(1),
            1: FlexColumnWidth(1),
            2: FlexColumnWidth(1.5),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              children: [
                _buildTableHeader('Hour', TextAlign.left),
                _buildTableHeader('Orders', TextAlign.right),
                _buildTableHeader('Revenue', TextAlign.right),
              ],
            ),
            ...hoursWithData.map((hour) {
              return TableRow(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade100),
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 8,
                    ),
                    child: Text(
                      '${hour.hour}:00',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 8,
                    ),
                    child: Text(
                      '${hour.orders}',
                      style: const TextStyle(fontSize: 13),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 8,
                    ),
                    child: Text(
                      '\$${hour.revenue.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(String text, [TextAlign align = TextAlign.left]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }

  Color _getPaymentMethodColor(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return Colors.green;
      case 'card':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Future<void> _handlePrintReport() async {
    if (_report == null) {
      return;
    }

    try {
      // Get receipt printers (receipt group) only
      final printers = await PrinterService.getSavedPrinters();
      final receiptPrinters = printers
          .where((p) => p.group == PrinterGroup.receipt)
          .where((p) => p.status != PrinterStatus.error)
          .toList();

      if (receiptPrinters.isEmpty) {
        AppToast.warning(
          context: context,
          title: 'No Receipt Printers Found',
          description: 'Please add a receipt printer (Receipt group) first.',
        );
        return;
      }

      setState(() {
        _isPrinting = true;
      });

      // Format report data for printing
      final reportData = _formatReportDataForPrinting();

      // Print to all receipt printers
      bool allSuccess = true;
      for (final printer in receiptPrinters) {
        try {
          final interfaceType = _printerTypeToString(printer.type);
          final success = await PrinterService.printReport(
            interfaceType: interfaceType,
            identifier: printer.identifier,
            reportData: reportData,
          );
          if (!success) {
            allSuccess = false;
          }
        } catch (e) {
          debugPrint('Error printing to ${printer.name}: $e');
          allSuccess = false;
        }
      }

      setState(() {
        _isPrinting = false;
      });

      if (allSuccess) {
        AppToast.success(
          context: context,
          title: 'Report Printed',
          description: 'Financial report printed successfully',
        );
      } else {
        AppToast.error(
          context: context,
          title: 'Printing Failed',
          description: 'Some printers failed. Please check printer status.',
        );
      }
    } catch (e) {
      setState(() {
        _isPrinting = false;
      });
      AppToast.error(
        context: context,
        title: 'Printing Error',
        description: 'Error printing: $e',
      );
    }
  }

  Future<void> _handleSendReportEmail() async {
    if (_report == null) {
      return;
    }

    setState(() {
      _isSendingEmail = true;
    });

    try {
      final dataProvider = DataProvider();
      final storeId =
          dataProvider.store?.id ?? _authService.getProfile()?.storeId;
      final storeTimezone = dataProvider.store?.address?.timezone;

      if (_reportType == 'daily') {
        final date = _dateRange?.start ?? DateTime.now();
        await _reportsService.sendReportEmail(
          reportType: 'daily',
          date: date,
          storeId: storeId,
          storeTimezone: storeTimezone,
          includeVoided: 'true',
        );
      } else {
        final startDate = _dateRange?.start ?? DateTime.now();
        final endDate = _dateRange?.end ?? DateTime.now();
        await _reportsService.sendReportEmail(
          reportType: 'custom',
          startDate: startDate,
          endDate: endDate,
          storeId: storeId,
          storeTimezone: storeTimezone,
        );
      }

      if (mounted) {
        setState(() {
          _isSendingEmail = false;
        });

        AppToast.success(
          context: context,
          title: 'Report Sent',
          description: 'Financial report sent to your email successfully',
        );
      }
    } catch (e) {
      debugPrint('Error sending report email: $e');
      if (mounted) {
        setState(() {
          _isSendingEmail = false;
        });

        AppToast.error(
          context: context,
          title: 'Failed to Send',
          description: e.toString().replaceAll('Exception: ', ''),
        );
      }
    }
  }

  Future<void> _handleDownloadReport() async {
    if (_report == null) {
      return;
    }

    setState(() {
      _isDownloading = true;
    });

    try {
      // Generate CSV content
      final csvContent = _generateCsvContent();

      // Generate filename with date
      final dateFormat = DateFormat('yyyy-MM-dd');
      final formattedDate = _reportType == 'daily'
          ? dateFormat.format(_dateRange?.start ?? DateTime.now())
          : '${dateFormat.format(_dateRange?.start ?? DateTime.now())}_to_${dateFormat.format(_dateRange?.end ?? DateTime.now())}';

      final fileName = 'ZipZap_Report_${_reportType}_$formattedDate.csv';

      // Use platform-agnostic download helper
      final path = await downloadFile(csvContent, fileName);

      if (mounted) {
        setState(() {
          _isDownloading = false;
        });

        AppToast.success(
          context: context,
          title: 'Report Downloaded',
          description: kIsWeb
              ? 'Check your browser downloads folder'
              : 'Report saved to: ${path ?? 'Downloads'}',
        );
      }
    } catch (e) {
      debugPrint('Error downloading report: $e');
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });

        AppToast.error(
          context: context,
          title: 'Download Failed',
          description: e.toString().replaceAll('Exception: ', ''),
        );
      }
    }
  }

  String _generateCsvContent() {
    if (_report == null) return '';

    List<List<dynamic>> rows = [];
    final currencyFormat = NumberFormat.currency(symbol: '\$');

    // Get store information
    final storeName = _dataProvider.store?.name ?? 'Store';
    final date = _dateRange?.start ?? DateTime.now();
    final reportDate = _formatDateWithOrdinal(date);
    final reportType = _reportType == 'daily'
        ? 'DAILY SALES REPORT'
        : 'CUSTOM SALES REPORT';

    // Header
    rows.add([storeName]);
    rows.add([reportDate]);
    rows.add([reportType]);
    rows.add([]); // Empty row

    // Financial metrics (matching print receipt format)
    rows.add(['Metric', 'Amount']);
    rows.add(['Gross Sale', currencyFormat.format(_report!.grossSale)]);
    rows.add(['Net Sale', currencyFormat.format(_report!.netSale)]);
    rows.add(['Tax', currencyFormat.format(_report!.tax)]);
    rows.add(['Refund', currencyFormat.format(_report!.refund)]);
    rows.add(['Order Discount', currencyFormat.format(_report!.orderDiscount)]);
    rows.add(['Item Discount', currencyFormat.format(_report!.itemDiscount)]);
    rows.add(['Void Orders', '${_report!.voidOrders}']);
    rows.add(['Void Total', currencyFormat.format(_report!.voidOrdersTotal)]);
    rows.add(['Tip', currencyFormat.format(_report!.tip)]);
    rows.add([
      'Total Cash Collected',
      currencyFormat.format(_report!.totalCollectedInCash),
    ]);
    rows.add([
      'Total Card Collected',
      currencyFormat.format(_report!.totalCollectedInCard),
    ]);

    // Convert to CSV string
    return const ListToCsvConverter().convert(rows);
  }

  Map<String, dynamic> _formatReportDataForPrinting() {
    // Get store information from DataProvider
    final store = _dataProvider.store;
    final storeName = store?.name ?? 'Store';

    // Format report date with ordinal suffix (e.g., "16th July, 2025")
    final date = _dateRange?.start ?? DateTime.now();
    String reportDate = _formatDateWithOrdinal(date);

    // Determine report type label
    String reportType = '';
    if (_reportType == 'daily') {
      reportType = 'DAILY SALES REPORT';
    } else {
      reportType = 'CUSTOM SALES REPORT';
    }

    // Format financial details in the exact order from the image
    final items = <Map<String, dynamic>>[
      {'name': 'Gross Sale', 'price': _report!.grossSale},
      {'name': 'Net Sale', 'price': _report!.netSale},
      {'name': 'Tax', 'price': _report!.tax},
      {'name': 'Refund', 'price': _report!.refund},
      {'name': 'Order Discount', 'price': _report!.orderDiscount},
      {'name': 'Item Discount', 'price': _report!.itemDiscount},
      {'name': 'Void', 'price': _report!.voidOrdersTotal},
      {'name': 'Tip', 'price': _report!.tip},
      {'name': 'Total Cash Collected', 'price': _report!.totalCollectedInCash},
      {'name': 'Total Card Collected', 'price': _report!.totalCollectedInCard},
    ];

    return {
      'storeName': storeName,
      'reportDate': reportDate,
      'reportType': reportType,
      'items': items,
    };
  }

  String _formatDateWithOrdinal(DateTime date) {
    // Get day with ordinal suffix (1st, 2nd, 3rd, 4th, etc.)
    String day = date.day.toString();
    String suffix = 'th';

    if (date.day == 1 || date.day == 21 || date.day == 31) {
      suffix = 'st';
    } else if (date.day == 2 || date.day == 22) {
      suffix = 'nd';
    } else if (date.day == 3 || date.day == 23) {
      suffix = 'rd';
    }

    // Full month name and year
    String month = DateFormat('MMMM').format(date);
    String year = date.year.toString();

    return '$day$suffix $month, $year';
  }

  String _printerTypeToString(PrinterType type) {
    switch (type) {
      case PrinterType.lan:
        return 'Lan';
      case PrinterType.usb:
        return 'Usb';
      case PrinterType.bluetooth:
        return 'Bluetooth';
      case PrinterType.wifi:
        return 'Lan'; // WiFi uses LAN interface
    }
  }
}
