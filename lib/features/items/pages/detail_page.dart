import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/my_item.dart';
import '../state/items_state.dart';

class DetailPage extends StatefulWidget {
  final MyItem item;

  const DetailPage({super.key, required this.item});

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  bool _isEditing = false;

  late MyItem _currentItem;
  late TextEditingController _titleController;
  late TextEditingController _subtitleController;

  final List<String> _availableIcons = ['icon1.jpg', 'icon2.jpg', 'icon3.jpg'];
  String? _selectedIcon;

  @override
  void initState() {
    super.initState();
    _currentItem = widget.item;

    _titleController = TextEditingController(text: _currentItem.title);
    _subtitleController = TextEditingController(text: _currentItem.subtitle);

    _selectedIcon = _currentItem.icon;
    if (_selectedIcon != null &&
        !_availableIcons.contains(_selectedIcon)) {
      _availableIcons.insert(0, _selectedIcon!);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    super.dispose();
  }

  void _toggleEditOrSave() {
    if (_isEditing) {
      // SAVE
      final updated = MyItem(
        title: _titleController.text.trim(),
        subtitle: _subtitleController.text.trim(),
        icon: _selectedIcon ?? _currentItem.icon,
      );

      context.read<ItemsState>().updateItem(_currentItem, updated);

      setState(() {
        _currentItem = updated;
        _isEditing = false;
      });
    } else {
      // ENTER EDIT MODE
      setState(() {
        _isEditing = true;
      });
    }
  }

  Widget _buildImage() {
    return SizedBox(
      height: 200,
      width: double.infinity,
      child: Image.asset(
        'assets/${_selectedIcon ?? _currentItem.icon}',
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.broken_image, size: 48),
        ),
      ),
    );
  }

  Widget _buildViewMode() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _currentItem.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _currentItem.subtitle,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditMode() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Édition",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: "Titre",
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _subtitleController,
              decoration: const InputDecoration(
                labelText: "Sous-titre",
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedIcon,
              decoration: const InputDecoration(
                labelText: "Icône",
              ),
              items: _availableIcons
                  .map(
                    (icon) => DropdownMenuItem(
                      value: icon,
                      child: Text(icon),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedIcon = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _currentItem.title.isNotEmpty
        ? _currentItem.title
        : "Détails";

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildImage(),
            const SizedBox(height: 16),
            _isEditing ? _buildEditMode() : _buildViewMode(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _toggleEditOrSave,
        child: Icon(_isEditing ? Icons.save : Icons.edit),
      ),
    );
  }
}
