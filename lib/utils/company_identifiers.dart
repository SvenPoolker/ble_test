import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';

class CompanyIdentifiers {
  static Map<int, String>? _cache;

  static Future<Map<int, String>> load() async {
    if (_cache != null) return _cache!;

    final raw = await rootBundle.loadString('assets/company_identifiers.yaml');
    final yaml = loadYaml(raw);

    final list = yaml['company_identifiers'] as YamlList;

    _cache = {
      for (var item in list)
        item['value'] is String
            ? int.parse(item['value'])
            : item['value'] as int: item['name'] as String
    };

    return _cache!;
  }

  static String? lookup(int mfgId) {
    return _cache?[mfgId];
  }
}
