import 'dart:convert';
import 'dart:html' as html;

import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  static const String _customerKey = 'cablepay_customer';
  static const String _lcoKey = 'cablepay_lco';
  static const String _sessionKey = 'cablepay_session';
  static const String _termsAcceptedKey = 'cablepay_terms_accepted';

  static Future<void> setTermsAccepted(bool value) async {
    html.window.localStorage[_termsAcceptedKey] = value ? '1' : '0';
  }

  static Future<bool> isTermsAccepted() async {
    return html.window.localStorage[_termsAcceptedKey] == '1';
  }


  static Future<void> saveCustomer(Map<String, dynamic> customer) async {
    try {
      html.window.localStorage[_customerKey] = jsonEncode(customer);
    } catch (_) {}
  }

  static Future<Map<String, dynamic>?> getCustomer() async {
    try {
      final s = html.window.localStorage[_customerKey];
      if (s == null) return null;
      return jsonDecode(s) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearCustomer() async {
    try {
      html.window.localStorage.remove(_customerKey);
    } catch (_) {}
  }

  static Future<void> saveLco(Map<String, dynamic> lco) async {
    try {
      html.window.localStorage[_lcoKey] = jsonEncode(lco);
    } catch (_) {}
  }

  static Future<Map<String, dynamic>?> getLco() async {
    try {
      final s = html.window.localStorage[_lcoKey];
      if (s == null) return null;
      return jsonDecode(s) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearLco() async {
    try {
      html.window.localStorage.remove(_lcoKey);
    } catch (_) {}
  }

  // --- Session helpers (NEW) ---
  static Future<void> saveSession(Map<String, dynamic> session) async {
    try {
      html.window.localStorage[_sessionKey] = jsonEncode(session);
    } catch (_) {}
  }

  static Future<Map<String, dynamic>?> getSession() async {
    try {
      final s = html.window.localStorage[_sessionKey];
      if (s == null) return null;
      return jsonDecode(s) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearSession() async {
    try {
      html.window.localStorage.remove(_sessionKey);
    } catch (_) {}
  }




  // static Future<void> setTermsAccepted(bool value) async {
  //   try {
  //     final sp = await SharedPreferences.getInstance();
  //     await sp.setBool(_termsAcceptedKey, value);
  //   } catch (_) {}
  // }
  //
  // static Future<bool> isTermsAccepted() async {
  //   try {
  //     final sp = await SharedPreferences.getInstance();
  //     return sp.getBool(_termsAcceptedKey) ?? false;
  //   } catch (_) {
  //     return false;
  //   }
  // }

}
