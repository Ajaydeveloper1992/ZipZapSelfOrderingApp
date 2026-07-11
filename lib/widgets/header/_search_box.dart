import 'dart:async';
import 'package:flutter/material.dart';

class HeaderSearchBox extends StatefulWidget {
  final Function(String)? onChanged;

  const HeaderSearchBox({super.key, this.onChanged});

  @override
  State<HeaderSearchBox> createState() => _HeaderSearchBoxState();
}

class _HeaderSearchBoxState extends State<HeaderSearchBox> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

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
      widget.onChanged?.call(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: TextField(
          controller: _searchController,
          textAlignVertical: TextAlignVertical.center,
          decoration: InputDecoration(
            hintText: 'Search...',
            prefixIcon: const Icon(Icons.search, size: 20),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 0,
            ),
            isDense: true,
          ),
          onChanged: _onSearchChanged,
        ),
      ),
    );
  }
}
