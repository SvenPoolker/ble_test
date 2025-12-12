import 'dart:convert';

import 'package:firsdt_app/services/items_api.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/my_item.dart';

class ItemsState extends ChangeNotifier {
  final List<MyItem> _items = [
  MyItem(title: "Item 1", subtitle: "Sous-titre 1",icon:"icon1.jpg"),
  MyItem(title: "Item 2", subtitle: "Sous-titre 2",icon:"icon2.jpg"),
  MyItem(title: "Item 3", subtitle: "Sous-titre 3",icon:"icon3.jpg"),
  ];

  bool isLoading = false;
  String? error;

  List<MyItem> get items => List.unmodifiable(_items);

  void addItem(MyItem item) {
    _items.add(item);
    saveToPrefs();
    notifyListeners();
  }

  void removeItem(MyItem item) {
    _items.remove(item);
    saveToPrefs();
    notifyListeners();
  }

  void updateItem(MyItem oldItem, MyItem newItem) {
    final index = _items.indexOf(oldItem);
    if (index >=0){
      _items[index]= newItem;
      saveToPrefs();
      notifyListeners();
    }
  }

  Future<void> loadFromApi() async {
    isLoading = true;
    error = null;
    notifyListeners();
    if (_items.isNotEmpty) {
      isLoading = false;
      notifyListeners();
      return;
    }

    try {
      final fetched = await ItemsApi.fetchItems();
      _items.clear();
      _items.addAll(fetched);
      saveToPrefs();
      isLoading = false;
      notifyListeners();
    } catch (e)  {
      isLoading = false;
      error = e.toString();
      notifyListeners();
    }
  }

  Future <void> saveToPrefs () async {
    final prefs = await SharedPreferences.getInstance();
    final list = _items.map((i) => i.toJson()).toList();
    final jsonString = jsonEncode(list);
    prefs.setString('items', jsonString);
  }

  Future <void> loadFromPrefs () async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('items');
    if (jsonString == null) return;
    final decodedList = jsonDecode(jsonString) as List;
    _items.clear();
    _items.addAll( decodedList.map((data) => MyItem.fromJson(data)).toList());
      notifyListeners();
  }
}
