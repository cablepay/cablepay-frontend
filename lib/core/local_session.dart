import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalSession {
  static const String _key = 'cablepay_session';

  static Future<void> save(Map<String, dynamic> session) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_key, jsonEncode(session));
  }

  static Future<Map<String, dynamic>?> load() async {
    final sp = await SharedPreferences.getInstance();
    final s = sp.getString(_key);
    if (s == null) return null;
    return jsonDecode(s);
  }

  static Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_key);
  }
}
