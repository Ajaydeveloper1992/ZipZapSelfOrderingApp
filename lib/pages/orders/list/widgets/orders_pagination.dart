import 'package:flutter/material.dart';

class OrdersPagination extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final int rowsPerPage;
  final List<int> rowsPerPageOptions;
  final int totalItems;
  final Function(int) onPageChanged;
  final Function(int) onRowsPerPageChanged;
  final bool isLoading;
  final String? loadingAction; // 'first', 'prev', 'next', 'last', 'rowsPerPage'

  const OrdersPagination({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.rowsPerPage,
    required this.rowsPerPageOptions,
    required this.totalItems,
    required this.onPageChanged,
    required this.onRowsPerPageChanged,
    this.isLoading = false,
    this.loadingAction,
  });

  @override
  Widget build(BuildContext context) {
    final startItem = (currentPage - 1) * rowsPerPage + 1;
    final endItem = currentPage * rowsPerPage > totalItems
        ? totalItems
        : currentPage * rowsPerPage;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Rows per page selector
          Row(
            children: [
              const Text('Rows per page:', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 6),
              isLoading && loadingAction == 'rowsPerPage'
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$rowsPerPage',
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(width: 4),
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ],
                    )
                  : PopupMenuButton<int>(
                      enabled: !isLoading,
                      initialValue: rowsPerPage,
                      color: Colors.white,
                      offset: const Offset(0, 40),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$rowsPerPage',
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_drop_down, size: 18),
                        ],
                      ),
                      onSelected: (value) {
                        onRowsPerPageChanged(value);
                      },
                      itemBuilder: (context) =>
                          rowsPerPageOptions.map((int value) {
                        return PopupMenuItem<int>(
                          value: value,
                          height: 28,
                          child: Text(
                            '$value',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: value == rowsPerPage
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: value == rowsPerPage
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.black87,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
            ],
          ),
          // Item count
          Text(
            'Items: $startItem-$endItem of $totalItems',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          // Page navigation
          Row(
            children: [
              IconButton(
                icon: isLoading && loadingAction == 'first'
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.first_page, size: 18),
                onPressed: currentPage > 1 && !isLoading
                    ? () => onPageChanged(1)
                    : null,
                tooltip: 'First page',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                icon: isLoading && loadingAction == 'prev'
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chevron_left, size: 18),
                onPressed: currentPage > 1 && !isLoading
                    ? () => onPageChanged(currentPage - 1)
                    : null,
                tooltip: 'Previous page',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                visualDensity: VisualDensity.compact,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'Page $currentPage of $totalPages',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              IconButton(
                icon: isLoading && loadingAction == 'next'
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chevron_right, size: 18),
                onPressed: currentPage < totalPages && !isLoading
                    ? () => onPageChanged(currentPage + 1)
                    : null,
                tooltip: 'Next page',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                icon: isLoading && loadingAction == 'last'
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.last_page, size: 18),
                onPressed: currentPage < totalPages && !isLoading
                    ? () => onPageChanged(totalPages)
                    : null,
                tooltip: 'Last page',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
