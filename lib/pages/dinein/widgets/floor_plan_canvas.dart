import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:zipzap_pos_self_orders/models/floor_plan_model.dart';

class FloorPlanCanvas extends StatefulWidget {
  final FloorPlan floorPlan;
  final Function(FloorItem)? onTableTap;
  final bool isInteractive;

  const FloorPlanCanvas({
    super.key,
    required this.floorPlan,
    this.onTableTap,
    this.isInteractive = true,
  });

  @override
  State<FloorPlanCanvas> createState() => _FloorPlanCanvasState();
}

class _FloorPlanCanvasState extends State<FloorPlanCanvas> {
  String? _selectedItemId;
  Timer? _timerUpdateTimer;

  @override
  void initState() {
    super.initState();
    // Update every minute to refresh elapsed time display
    _timerUpdateTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timerUpdateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate scale to fit canvas in available space
        final scaleX = constraints.maxWidth / widget.floorPlan.width;
        final scaleY = constraints.maxHeight / widget.floorPlan.height;
        final scale = math.min(math.min(scaleX, scaleY), 1.0); // Don't scale up

        final scaledWidth = widget.floorPlan.width * scale;
        final scaledHeight = widget.floorPlan.height * scale;

        return Center(
          child: Container(
            width: scaledWidth,
            height: scaledHeight,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F4), // stone-100
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFD6D3D1), // stone-300
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CustomPaint(
                painter: _GridPainter(),
                child: Stack(
                  children: [
                    // Dimension indicator
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                        child: Text(
                          '${widget.floorPlan.width.toInt()}×${widget.floorPlan.height.toInt()}',
                          style: TextStyle(
                            fontSize: 10,
                            fontFamily: 'monospace',
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),

                    // Floor items
                    ...widget.floorPlan.items.map((item) {
                      return Positioned(
                        left: item.x * scale,
                        top: item.y * scale,
                        child: _buildFloorItem(item, scale),
                      );
                    }),

                    // Empty state
                    if (widget.floorPlan.items.isEmpty)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFD6D3D1),
                              width: 2,
                              strokeAlign: BorderSide.strokeAlignCenter,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F5F4),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Icon(
                                  Icons.grid_view_rounded,
                                  size: 24,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Empty Canvas',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'No tables configured yet',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFloorItem(FloorItem item, double scale) {
    final isSelected = _selectedItemId == item.id;
    final width = item.width * scale;
    final height = item.height * scale;

    return GestureDetector(
      onTap: widget.isInteractive && item.type.isTable
          ? () {
              setState(() {
                _selectedItemId = isSelected ? null : item.id;
              });
              widget.onTableTap?.call(item);
            }
          : null,
      child: Transform.rotate(
        angle: item.rotation * math.pi / 180,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Theme.of(
                        context,
                      ).primaryColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              _buildItemContent(item, width, height, scale),

              // Selection indicator
              if (isSelected)
                Positioned(
                  left: -6,
                  top: -6,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemContent(
    FloorItem item,
    double width,
    double height,
    double scale,
  ) {
    // Cash register
    if (item.type == FloorItemType.cashRegister) {
      return _buildCashRegister(width, height);
    }

    // Wall
    if (item.type == FloorItemType.wall) {
      return _buildWall(width, height);
    }

    // Bar stool
    if (item.type == FloorItemType.barStool) {
      return _buildBarStool(item, width, height);
    }

    // Tables (rectangular, square, circular)
    return _buildTable(item, width, height, scale);
  }

  Widget _buildCashRegister(double width, double height) {
    return Container(
      width: width,
      height: height,
      child: Column(
        children: [
          // Main Register Body
          Expanded(
            flex: 75,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF52525B), // zinc-600
                    Color(0xFF3F3F46), // zinc-700
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
                border: Border.all(
                  color: const Color(0xFF27272A), // zinc-800
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  // Display Screen (LCD style)
                  Container(
                    height: height * 0.22,
                    margin: const EdgeInsets.fromLTRB(6, 6, 6, 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD9F99D), // lime-200
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(
                        color: const Color(0xFF71717A), // zinc-500
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Text(
                          '\$0.00',
                          style: TextStyle(
                            fontSize: math.min(width, height) * 0.10,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF27272A), // zinc-800
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Button Grid
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(6, 2, 6, 6),
                      child: GridView.count(
                        crossAxisCount: 3,
                        mainAxisSpacing: 2,
                        crossAxisSpacing: 2,
                        physics: const NeverScrollableScrollPhysics(),
                        children: List.generate(
                          9,
                          (i) => Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF71717A), // zinc-500
                              borderRadius: BorderRadius.circular(2),
                              border: Border.all(
                                color: const Color(0xFF52525B), // zinc-600
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 1,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Cash Drawer
          Expanded(
            flex: 25,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF71717A), // zinc-500
                    Color(0xFF52525B), // zinc-600
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
                border: const Border(
                  left: BorderSide(color: Color(0xFF3F3F46), width: 2),
                  right: BorderSide(color: Color(0xFF3F3F46), width: 2),
                  bottom: BorderSide(color: Color(0xFF3F3F46), width: 2),
                ),
              ),
              child: Center(
                child: Container(
                  width: width * 0.7,
                  height: height * 0.12,
                  decoration: BoxDecoration(
                    color: const Color(0xFFA1A1AA), // zinc-400
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(
                      color: const Color(0xFF71717A), // zinc-500
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWall(double width, double height) {
    final isHorizontal = width > height;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF57534E), // stone-600
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: const Color(0xFF44403C), // stone-700
        ),
      ),
      child: CustomPaint(
        painter: _WallPatternPainter(isHorizontal: isHorizontal),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF78716C).withValues(alpha: 0.5), // stone-500
                Colors.transparent,
              ],
              stops: const [0, 0.1],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBarStool(FloorItem item, double width, double height) {
    final colors = _getStatusColors(item.status);

    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      child: Container(
        width: width * 0.85,
        height: height * 0.85,
        decoration: BoxDecoration(
          color: colors.background,
          shape: BoxShape.circle,
          border: Border.all(color: colors.border, width: 2),
        ),
        child: Center(
          child: Container(
            width: width * 0.6,
            height: height * 0.6,
            decoration: BoxDecoration(
              color: colors.cushion,
              shape: BoxShape.circle,
              border: Border.all(color: colors.cushionBorder),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTable(
    FloorItem item,
    double width,
    double height,
    double scale,
  ) {
    final colors = _getStatusColors(item.status);
    final isCircular = item.type == FloorItemType.circular;
    final borderRadius = isCircular
        ? BorderRadius.circular(width / 2)
        : BorderRadius.circular(8);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Chairs
        ..._buildChairs(item, width, height, scale),

        // Table surface
        Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: borderRadius,
            border: Border.all(color: colors.border, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Table surface pattern
              Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: isCircular
                      ? BorderRadius.circular((width - 8) / 2)
                      : BorderRadius.circular(4),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
              ),
              // Content
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: item.status == TableStatus.occupied
                      ? _buildReservedTableContent(item, width, height, colors)
                      : _buildAvailableTableContent(
                          item,
                          width,
                          height,
                          colors,
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build content for available tables
  Widget _buildAvailableTableContent(
    FloorItem item,
    double width,
    double height,
    _StatusColors colors,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          item.name,
          style: TextStyle(
            fontSize: math.min(width, height) * 0.14,
            fontWeight: FontWeight.w600,
            color: colors.text,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        if (item.seats != null && item.seats! > 0)
          Text(
            '${item.seats} seats',
            style: TextStyle(
              fontSize: math.min(width, height) * 0.11,
              color: colors.subtext,
            ),
          ),
      ],
    );
  }

  /// Build content for reserved tables with order info
  Widget _buildReservedTableContent(
    FloorItem item,
    double width,
    double height,
    _StatusColors colors,
  ) {
    final orderInfo = item.orderInfo;
    final hasOrderInfo = orderInfo != null;
    final minDim = math.min(width, height);

    // Format elapsed time (use occupiedAt for occupied tables, reservedAt for reserved tables)
    String? timerText;
    final timestampToUse = item.status == TableStatus.occupied
        ? item.occupiedAt
        : item.reservedAt;
    if (timestampToUse != null) {
      final elapsed = DateTime.now().difference(timestampToUse);
      timerText = _formatElapsedTime(elapsed);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Table name
        Text(
          item.name,
          style: TextStyle(
            fontSize: minDim * 0.13,
            fontWeight: FontWeight.w600,
            color: colors.text,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        const SizedBox(height: 2),
        // Total and Timer in single row: $15.99 | 32m
        if (hasOrderInfo && orderInfo.orderTotal != null || timerText != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasOrderInfo && orderInfo.orderTotal != null)
                Text(
                  '\$${orderInfo.orderTotal!.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: minDim * 0.13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFB45309), // amber-700
                  ),
                ),
              if (hasOrderInfo &&
                  orderInfo.orderTotal != null &&
                  timerText != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Text(
                    '|',
                    style: TextStyle(
                      fontSize: minDim * 0.13,
                      color: colors.subtext.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              if (timerText != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: minDim * 0.14,
                      color: const Color(0xFFB45309), // amber-700
                    ),
                    const SizedBox(width: 1),
                    Text(
                      timerText,
                      style: TextStyle(
                        fontSize: minDim * 0.13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFB45309), // amber-700
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
            ],
          ),
        // Staff name
        if (hasOrderInfo && orderInfo.staffName != null)
          Text(
            orderInfo.staffName!,
            style: TextStyle(fontSize: minDim * 0.11, color: colors.subtext),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
      ],
    );
  }

  String _formatElapsedTime(Duration elapsed) {
    final hours = elapsed.inHours;
    final minutes = elapsed.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  List<Widget> _buildChairs(
    FloorItem item,
    double width,
    double height,
    double scale,
  ) {
    if (item.seats == null || item.seats! < 1) return [];

    final seats = item.seats!;
    final chairOffset = 8.0 * scale;
    final chairWidth = 12.0 * scale;
    final chairHeight = 8.0 * scale;
    final chairs = <Widget>[];

    if (item.type == FloorItemType.circular) {
      // Circular arrangement
      for (int i = 0; i < seats; i++) {
        final angle = (i * 360 / seats - 90) * math.pi / 180;
        final radius = math.min(width, height) / 2 + chairOffset;
        final x = math.cos(angle) * radius + width / 2 - 5 * scale;
        final y = math.sin(angle) * radius + height / 2 - 5 * scale;

        chairs.add(
          Positioned(
            left: x,
            top: y,
            child: Container(
              width: 10 * scale,
              height: 10 * scale,
              decoration: BoxDecoration(
                color: Colors.grey.shade600,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade700),
              ),
            ),
          ),
        );
      }
    } else if (item.type == FloorItemType.rectangular) {
      // Top and bottom distribution
      final topSeats = (seats / 2).ceil();
      final bottomSeats = seats - topSeats;

      // Top chairs
      for (int i = 0; i < topSeats; i++) {
        final leftPercent = (i + 1) / (topSeats + 1);
        chairs.add(
          Positioned(
            left: width * leftPercent - chairWidth / 2,
            top: -chairOffset,
            child: _buildChair(chairWidth, chairHeight),
          ),
        );
      }

      // Bottom chairs
      for (int i = 0; i < bottomSeats; i++) {
        final leftPercent = (i + 1) / (bottomSeats + 1);
        chairs.add(
          Positioned(
            left: width * leftPercent - chairWidth / 2,
            bottom: -chairOffset,
            child: _buildChair(chairWidth, chairHeight),
          ),
        );
      }
    } else {
      // Square - distribute on all sides
      final sides = ['top', 'right', 'bottom', 'left'];
      for (int i = 0; i < seats; i++) {
        final side = sides[i % 4];
        final seatOnSide = i ~/ 4;
        final seatsOnThisSide = ((seats - (i % 4)) / 4).ceil();
        final position = (seatOnSide + 1) / (seatsOnThisSide + 1);

        Widget chair;
        double? left, right, top, bottom;

        if (side == 'top') {
          left = width * position - chairWidth / 2;
          top = -chairOffset;
          chair = _buildChair(chairWidth, chairHeight);
        } else if (side == 'bottom') {
          left = width * position - chairWidth / 2;
          bottom = -chairOffset;
          chair = _buildChair(chairWidth, chairHeight);
        } else if (side == 'left') {
          left = -chairOffset;
          top = height * position - chairHeight / 2;
          chair = _buildChair(chairHeight, chairWidth);
        } else {
          right = -chairOffset;
          top = height * position - chairHeight / 2;
          chair = _buildChair(chairHeight, chairWidth);
        }

        chairs.add(
          Positioned(
            left: left,
            right: right,
            top: top,
            bottom: bottom,
            child: chair,
          ),
        );
      }
    }

    return chairs;
  }

  Widget _buildChair(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade600,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: Colors.grey.shade700),
      ),
    );
  }

  _StatusColors _getStatusColors(TableStatus status) {
    switch (status) {
      case TableStatus.available:
        return _StatusColors(
          background: const Color(0xFFECFDF5), // emerald-50
          surface: const Color(
            0xFFD1FAE5,
          ).withValues(alpha: 0.5), // emerald-100
          border: const Color(0xFF6EE7B7), // emerald-300
          text: const Color(0xFF064E3B), // emerald-900
          subtext: const Color(0xFF047857), // emerald-700
          cushion: const Color(0xFF059669), // emerald-600
          cushionBorder: const Color(0xFF047857), // emerald-700
        );
      case TableStatus.occupied:
        return _StatusColors(
          background: const Color(0xFFFFF7ED), // orange-50
          surface: const Color(0xFFFFEDD5).withValues(alpha: 0.5), // orange-100
          border: const Color(0xFFFDBA74), // orange-300
          text: const Color(0xFF7C2D12), // orange-900
          subtext: const Color(0xFFC2410C), // orange-700
          cushion: const Color(0xFFEA580C), // orange-600
          cushionBorder: const Color(0xFFC2410C), // orange-700
        );
      case TableStatus.reserved:
        return _StatusColors(
          background: const Color(0xFFFFFBEB), // amber-50
          surface: const Color(0xFFFEF3C7).withValues(alpha: 0.5), // amber-100
          border: const Color(0xFFFCD34D), // amber-300
          text: const Color(0xFF78350F), // amber-900
          subtext: const Color(0xFFB45309), // amber-700
          cushion: const Color(0xFFD97706), // amber-600
          cushionBorder: const Color(0xFFB45309), // amber-700
        );
    }
  }
}

class _StatusColors {
  final Color background;
  final Color surface;
  final Color border;
  final Color text;
  final Color subtext;
  final Color cushion;
  final Color cushionBorder;

  _StatusColors({
    required this.background,
    required this.surface,
    required this.border,
    required this.text,
    required this.subtext,
    required this.cushion,
    required this.cushionBorder,
  });
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.04)
      ..strokeWidth = 1;

    const gridSize = 20.0;

    // Vertical lines
    for (double x = 0; x <= size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Horizontal lines
    for (double y = 0; y <= size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WallPatternPainter extends CustomPainter {
  final bool isHorizontal;

  _WallPatternPainter({required this.isHorizontal});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.15)
      ..strokeWidth = 1;

    const spacing = 8.0;

    if (isHorizontal) {
      for (double x = spacing; x < size.width; x += spacing) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      }
    } else {
      for (double y = spacing; y < size.height; y += spacing) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
