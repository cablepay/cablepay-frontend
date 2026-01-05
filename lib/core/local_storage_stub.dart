
class LocalStorage {
  // static const String _customerKey = 'cablepay_customer';
  // static const String _lcoKey = 'cablepay_lco';
  // static const String _sessionKey = 'cablepay_session';
  // static const String _termsAcceptedKey = 'cablepay_terms_accepted';


  static Future<void> setTermsAccepted(bool value) async {}
  static Future<bool> isTermsAccepted() async => false;


  static Future<void> saveCustomer(Map<String, dynamic> customer) async {
    // no-op fallback
  }

  static Future<Map<String, dynamic>?> getCustomer() async {
    return null;
  }

  static Future<void> clearCustomer() async {}

  static Future<void> saveLco(Map<String, dynamic> lco) async {}

  static Future<Map<String, dynamic>?> getLco() async {
    return null;
  }

  static Future<void> clearLco() async {}

  // session fallbacks (no-op)
  static Future<void> saveSession(Map<String, dynamic> session) async {}
  static Future<Map<String, dynamic>?> getSession() async => null;
  static Future<void> clearSession() async {}


}
