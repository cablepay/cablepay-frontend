import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  static const String _customerKey = 'cablepay_customer';
  static const String _lcoKey = 'cablepay_lco';
  static const String _sessionKey = 'cablepay_session';

  // Customer helpers (unchanged)
  static Future<void> saveCustomer(Map<String, dynamic> customer) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_customerKey, jsonEncode(customer));
    } catch (_) {}
  }

  static Future<Map<String, dynamic>?> getCustomer() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final s = sp.getString(_customerKey);
      if (s == null) return null;
      return jsonDecode(s) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearCustomer() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.remove(_customerKey);
    } catch (_) {}
  }

  // LCO helpers (unchanged)
  static Future<void> saveLco(Map<String, dynamic> lco) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_lcoKey, jsonEncode(lco));
    } catch (_) {}
  }

  static Future<Map<String, dynamic>?> getLco() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final s = sp.getString(_lcoKey);
      if (s == null) return null;
      return jsonDecode(s) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearLco() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.remove(_lcoKey);
    } catch (_) {}
  }

  // --- Session helpers (NEW) ---
  /// Save session object returned from backend:
  /// { sessionKey, userType, expiresAt, user }
  static Future<void> saveSession(Map<String, dynamic> session) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_sessionKey, jsonEncode(session));
    } catch (_) {}
  }

  static Future<Map<String, dynamic>?> getSession() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final s = sp.getString(_sessionKey);
      if (s == null) return null;
      return jsonDecode(s) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearSession() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.remove(_sessionKey);
    } catch (_) {}
  }
}
