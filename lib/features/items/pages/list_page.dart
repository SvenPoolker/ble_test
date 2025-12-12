import 'package:firsdt_app/features/items/models/my_item.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'detail_page.dart';
import '../state/items_state.dart';

class ListPage extends StatefulWidget {
  const ListPage({super.key});

  @override
  State<ListPage> createState() => _ListPageState();
}

class _ListPageState extends State<ListPage> {
  late TextEditingController titleController;
  late TextEditingController subtitleController;

  final List<String> availableIcons = ['icon1.jpg', 'icon2.jpg', 'icon3.jpg'];
  String? selectedIcon;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController();
    subtitleController = TextEditingController();
    selectedIcon = availableIcons.first;

    Future.microtask(() async {
      final state = context.read<ItemsState>();
      await state.loadFromPrefs();
      await state.loadFromApi();
    });
  }

  @override
  void dispose() {
    titleController.dispose();
    subtitleController.dispose();
    super.dispose();
  }

  Future<void> _showAddItemDialog() async {
    titleController.clear();
    subtitleController.clear();
    selectedIcon = availableIcons.first;

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Ajouter un item"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Titre',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: subtitleController,
                  decoration: const InputDecoration(
                    labelText: 'Sous-titre',
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedIcon,
                  decoration: const InputDecoration(
                    labelText: 'Icône',
                  ),
                  items: availableIcons
                      .map(
                        (icon) => DropdownMenuItem(
                          value: icon,
                          child: Text(icon),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedIcon = value;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Annuler"),
            ),
            TextButton(
              onPressed: () {
                final newItem = MyItem(
                  title: titleController.text.trim(),
                  subtitle: subtitleController.text.trim(),
                  icon: selectedIcon ?? availableIcons.first,
                );

                context.read<ItemsState>().addItem(newItem);

                titleController.clear();
                subtitleController.clear();
                selectedIcon = availableIcons.first;

                Navigator.pop(ctx);
              },
              child: const Text("Ajouter"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(ItemsState itemsState) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          "Items",
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
    );
  }

  Widget _buildList(List<MyItem> items) {
    if (items.isEmpty) {
      return const Center(
        child: Text("Aucun item pour l’instant."),
      );
    }

    return ListView.separated(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: AssetImage('assets/${item.icon}'),
          ),
          title: Text(item.title),
          subtitle: Text(item.subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DetailPage(item: item),
              ),
            );
          },
        );
      },
      separatorBuilder: (context, index) => Divider(
        height: 1,
        thickness: 0.5,
        color: Colors.grey.shade400,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final itemsState = context.watch<ItemsState>();
    final items = itemsState.items;

    Widget body;
    if (itemsState.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (itemsState.error != null) {
      body = Center(child: Text('Erreur : ${itemsState.error}'));
    } else {
      body = Column(
        children: [
          _buildHeader(itemsState),
          Expanded(child: _buildList(items)),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Liste des items'),
      ),
      body: body,
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddItemDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
