import 'package:flutter/material.dart';

enum DataItemStatus { loading, completed, error }

class DataItemProgress {
  final String name;
  DataItemStatus status;
  double progress; // 0.0 to 1.0

  DataItemProgress({
    required this.name,
    this.status = DataItemStatus.loading,
    this.progress = 0.0,
  });
}

class DataLoadingProgressDialog extends StatefulWidget {
  final Map<String, DataItemProgress> items;
  final VoidCallback? onComplete;

  const DataLoadingProgressDialog({
    super.key,
    required this.items,
    this.onComplete,
  });

  @override
  State<DataLoadingProgressDialog> createState() =>
      _DataLoadingProgressDialogState();
}

class _DataLoadingProgressDialogState extends State<DataLoadingProgressDialog>
    with TickerProviderStateMixin {
  late List<AnimationController> _dotControllers;
  late List<Animation<double>> _dotAnimations;
  bool _hasCalledComplete = false; // Prevent multiple onComplete calls

  @override
  void initState() {
    super.initState();
    _dotControllers = List.generate(
      3,
      (index) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      ),
    );
    _dotAnimations = _dotControllers
        .map(
          (controller) => Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(parent: controller, curve: Curves.easeInOut),
          ),
        )
        .toList();

    // Start animations with delays
    for (int i = 0; i < _dotControllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted) {
          _dotControllers[i].repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _dotControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final completedCount = widget.items.values
        .where((item) => item.status == DataItemStatus.completed)
        .length;
    final totalCount = widget.items.length;
    final overallProgress = totalCount > 0 ? completedCount / totalCount : 0.0;
    final overallProgressPercent = (overallProgress * 100).round();

    final allDone = widget.items.values.every(
      (item) =>
          item.status == DataItemStatus.completed ||
          item.status == DataItemStatus.error,
    );

    if (allDone && widget.onComplete != null && !_hasCalledComplete) {
      _hasCalledComplete = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onComplete!();
        }
      });
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Spinner with loader icon
            _buildSpinner(),
            const SizedBox(height: 16),

            // Title
            Text(
              'Please wait for a moment',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),

            // Subtitle
            Text(
              "We're preparing everything for you",
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Overall progress
            _buildOverallProgress(overallProgressPercent),
            const SizedBox(height: 16),

            // Individual items
            _buildItemsList(),
            const SizedBox(height: 16),

            // Loading dots
            _buildLoadingDots(),
          ],
        ),
      ),
    );
  }

  Widget _buildSpinner() {
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 64,
          height: 64,
          child: CircularProgressIndicator(
            strokeWidth: 4,
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary,
            ),
            backgroundColor: Colors.grey.shade200,
          ),
        ),
        Icon(
          Icons.refresh,
          size: 24,
          color: Theme.of(context).colorScheme.primary,
        ),
      ],
    );
  }

  Widget _buildOverallProgress(int percent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Overall Progress',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
                fontSize: 12,
              ),
            ),
            Text(
              '$percent%',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percent / 100,
            minHeight: 8,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.primary.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItemsList() {
    return Column(
      children: widget.items.entries.map((entry) {
        final item = entry.value;
        final isCompleted = item.status == DataItemStatus.completed;
        final isLoading = item.status == DataItemStatus.loading;
        final progressPercent = (item.progress * 100).round();

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              // Icon
              SizedBox(
                width: 16,
                height: 16,
                child: isCompleted
                    ? Icon(
                        Icons.check_circle,
                        size: 16,
                        color: Colors.green.shade600,
                      )
                    : isLoading
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      )
                    : Icon(Icons.error, size: 16, color: Colors.red.shade600),
              ),
              const SizedBox(width: 8),

              // Name
              Expanded(
                child: Text(
                  item.name,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: isCompleted
                        ? Colors.green.shade600
                        : isLoading
                        ? Colors.grey.shade700
                        : Colors.red.shade600,
                    fontSize: 12,
                  ),
                ),
              ),

              // Progress bar
              SizedBox(
                width: 96,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: item.progress,
                    minHeight: 6,
                    backgroundColor: isCompleted
                        ? Colors.green.shade100
                        : Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isCompleted
                          ? Colors.green.shade600
                          : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Percent
              SizedBox(
                width: 40,
                child: Text(
                  '$progressPercent%',
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isCompleted
                        ? Colors.green.shade600
                        : isLoading
                        ? Theme.of(context).colorScheme.primary
                        : Colors.red.shade600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLoadingDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        3,
        (index) => AnimatedBuilder(
          animation: _dotAnimations[index],
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, -(_dotAnimations[index].value * 4)),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
