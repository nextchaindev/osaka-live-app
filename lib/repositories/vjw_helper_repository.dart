import 'dart:convert';

import 'package:osaka_app/models/vjw_helper_values.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VjwHelperRepository {
  static const storageKey = 'vjw_helper_values_v1';

  Future<VjwHelperValues> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return const VjwHelperValues();
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic>
          ? VjwHelperValues.fromJson(decoded)
          : const VjwHelperValues();
    } on FormatException {
      return const VjwHelperValues();
    }
  }

  Future<void> save(VjwHelperValues values) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, jsonEncode(values.toJson()));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(storageKey);
  }
}
