import 'dart:convert';
import 'package:http/http.dart' as http;
import '../features/items/models/my_item.dart';

class ItemsApi {
  static const String baseUrl = "https://jsonplaceholder.typicode.com";

  static Future<List<MyItem>> fetchItems() async {
    final response = await http.get(Uri.parse("$baseUrl/posts"));

      if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as List;
      return decoded
      .map((data) => MyItem.fromJson(data))
      .toList();
    } else {
      throw Exception("API error: ${response.statusCode}");
    }
  }
}
