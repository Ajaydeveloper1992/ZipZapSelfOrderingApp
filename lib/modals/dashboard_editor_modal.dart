import 'package:flutter/material.dart';
import 'package:zipzap_pos_self_orders/models/dashboard_item_model.dart';

class DashboardEditorModal extends StatefulWidget {
  final List<DashboardItem> items;
  final Function(List<DashboardItem>) onSave;

  const DashboardEditorModal({
    super.key,
    required this.items,
    required this.onSave,
  });

  @override
  State<DashboardEditorModal> createState() => _DashboardEditorModalState();
}

class _DashboardEditorModalState extends State<DashboardEditorModal> {
  late List<DashboardItem> _items;
  int? _editingIndex;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.items);
  }

  void _handleReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _items.removeAt(oldIndex);
      _items.insert(newIndex, item);
    });
  }

  void _toggleEnabled(int index) {
    setState(() {
      _items[index] = _items[index].copyWith(enabled: !_items[index].enabled);
    });
  }

  void _startEditing(int index) {
    setState(() {
      _editingIndex = index;
    });
  }

  void _cancelEditing() {
    setState(() {
      _editingIndex = null;
      _items = List.from(widget.items);
    });
  }

  void _saveItem(int index, DashboardItem updatedItem) {
    setState(() {
      _items[index] = updatedItem;
      _editingIndex = null;
    });
  }

  void _handleSave() {
    widget.onSave(_items);
    Navigator.of(context).pop();
  }

  Widget _buildItemTile(int index, DashboardItem item) {
    final isEditing = _editingIndex == index;

    if (isEditing) {
      return _EditItemCard(
        item: item,
        onSave: (updatedItem) => _saveItem(index, updatedItem),
        onCancel: _cancelEditing,
      );
    }

    return Card(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: item.borderColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: ListTile(
        dense: false,
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: item.backgroundColor.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: item.borderColor, width: 2),
          ),
          child: Icon(item.icon, color: Colors.grey.shade900, size: 24),
        ),
        title: Text(
          item.title,
          style: TextStyle(
            decoration: item.enabled ? null : TextDecoration.lineThrough,
            color: item.enabled ? null : Colors.grey,
          ),
        ),
        subtitle: Text(
          item.description,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        trailing: Row(
          spacing: 8,
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: item.enabled,
              onChanged: (value) => _toggleEnabled(index),
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _startEditing(index),
              tooltip: 'Edit',
            ),
            SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 768;
    final modalWidth = isSmallScreen
        ? screenWidth * 0.9
        : (screenWidth < 1024 ? 600.0 : 650.0);
    final modalHeight = MediaQuery.of(context).size.height * 0.8;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
            // Header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                color: Colors.white,
              ),
              child: Row(
                children: [
                  const Icon(Icons.dashboard, size: 24),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Edit Dashboard Cards',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: _items.length,
                onReorder: _handleReorder,
                itemBuilder: (context, index) {
                  return Container(
                    key: ValueKey('${_items[index].title}_$index'),
                    child: _buildItemTile(index, _items[index]),
                  );
                },
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                color: Colors.white,
              ),
              child: Row(
                spacing: 8,
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      label: const Text('Cancel'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        minimumSize: const Size(0, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _handleSave,
                      icon: const Icon(Icons.check),
                      label: const Text('Save Changes'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        minimumSize: const Size(0, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
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
    );
  }
}

class _EditItemCard extends StatefulWidget {
  final DashboardItem item;
  final Function(DashboardItem) onSave;
  final VoidCallback onCancel;

  const _EditItemCard({
    required this.item,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<_EditItemCard> createState() => _EditItemCardState();
}

class _EditItemCardState extends State<_EditItemCard> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late IconData _selectedIcon;
  late Color _selectedBackgroundColor;
  late Color _selectedBorderColor;

  // Common icons for dashboard
  final List<IconData> _commonIcons = [
    Icons.shopping_bag,
    Icons.shopping_cart,
    Icons.inventory_2,
    Icons.checklist,
    Icons.list,
    Icons.people,
    Icons.description,
    Icons.settings,
    Icons.person,
    Icons.print,
    Icons.add,
    Icons.home,
    Icons.dashboard,
    Icons.menu,
    Icons.star,
    Icons.favorite,
    Icons.notifications,
    Icons.history,
    Icons.payment,
    Icons.receipt,
  ];

  // Common color options
  final List<Color> _colorOptions = [
    Colors.yellow.shade100,
    Colors.orange.shade100,
    Colors.pink.shade100,
    Colors.blue.shade100,
    Colors.green.shade100,
    Colors.purple.shade100,
    Colors.indigo.shade100,
    Colors.grey.shade100,
    Colors.amber.shade100,
    Colors.teal.shade100,
    Colors.red.shade100,
    Colors.cyan.shade100,
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.item.title);
    _descriptionController = TextEditingController(
      text: widget.item.description,
    );
    _selectedIcon = widget.item.icon;
    _selectedBackgroundColor = widget.item.backgroundColor;
    _selectedBorderColor = widget.item.borderColor;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Color _getBorderColorForBackground(Color bgColor) {
    // Return a darker version of the background color for the border
    if (bgColor == Colors.yellow.shade100) return Colors.yellow.shade300;
    if (bgColor == Colors.orange.shade100) return Colors.orange.shade300;
    if (bgColor == Colors.pink.shade100) return Colors.pink.shade300;
    if (bgColor == Colors.blue.shade100) return Colors.blue.shade300;
    if (bgColor == Colors.green.shade100) return Colors.green.shade300;
    if (bgColor == Colors.purple.shade100) return Colors.purple.shade300;
    if (bgColor == Colors.indigo.shade100) return Colors.indigo.shade300;
    if (bgColor == Colors.grey.shade100) return Colors.grey.shade300;
    if (bgColor == Colors.amber.shade100) return Colors.amber.shade300;
    if (bgColor == Colors.teal.shade100) return Colors.teal.shade300;
    if (bgColor == Colors.red.shade100) return Colors.red.shade300;
    if (bgColor == Colors.cyan.shade100) return Colors.cyan.shade300;
    return Colors.grey.shade300;
  }

  void _handleSave() {
    final updatedItem = widget.item.copyWith(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      icon: _selectedIcon,
      backgroundColor: _selectedBackgroundColor,
      borderColor: _selectedBorderColor,
    );
    widget.onSave(updatedItem);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: Colors.white,
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Edit ${widget.item.title} Card',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: widget.onCancel,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Title field
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            // Description field
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
                hintText: 'Short description of this card',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            // Icon selection
            const Text('Icon', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _commonIcons.map((icon) {
                final isSelected = icon == _selectedIcon;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedIcon = icon;
                    });
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _selectedBackgroundColor.withValues(alpha: 0.85)
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? _selectedBorderColor
                            : Colors.grey.shade400,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Icon(
                      icon,
                      color: isSelected
                          ? Colors.grey.shade900
                          : Colors.grey.shade600,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            // Color selection
            const Text(
              'Background Color',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _colorOptions.map((color) {
                final isSelected = color == _selectedBackgroundColor;
                final borderColor = _getBorderColorForBackground(color);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedBackgroundColor = color;
                      _selectedBorderColor = borderColor;
                    });
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? borderColor : Colors.grey.shade400,
                        width: isSelected ? 3 : 1,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            // Preview
            const Text(
              'Preview',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: _selectedBorderColor.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _selectedBackgroundColor.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _selectedIcon,
                            size: 25,
                            color: Colors.grey.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _titleController.text.isEmpty
                          ? 'Preview'
                          : _titleController.text,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Colors.grey.shade900,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Save button
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: widget.onCancel,
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _handleSave,
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
