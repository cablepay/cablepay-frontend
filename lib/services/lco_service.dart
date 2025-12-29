// lib/services/lco_service.dart
import 'dart:async';
import '../core/api_config.dart';
import '../core/money_utils.dart';

class LcoService {
  // Login (create-or-get) for LCOs
  // On success, will set ApiConfig.sessionKey automatically using returned session.sessionKey
  static Future<Map<String, dynamic>> login({
    required String phone,
  }) async {
    final payload = {
      'phone': phone,
    };

    final res = await ApiConfig.post('/api/lcos/login', payload);

    return {
      'statusCode': res['statusCode'],
      'data': res['body'],
    };
  }



  static Future<Map<String, dynamic>> searchNetworks(String q, {int limit = 50}) async {
    final qEnc = Uri.encodeQueryComponent(q);
    final res = await ApiConfig.get('/api/lcos/search?q=$qEnc&limit=$limit');
    // ApiConfig.get returns {'statusCode':..., 'body':...}
    return {'statusCode': res['statusCode'], 'data': res['body']};
  }

  // Get LCO by id or by network lcoId (backend allows both)
  static Future<Map<String, dynamic>> getLco(String idOrNetworkId) async {
    final res = await ApiConfig.get('/api/lcos/$idOrNetworkId');
    final status = res['statusCode'] as int? ?? 500;
    return {'statusCode': status, 'data': res['body']};
  }

  // Create or update lco details (profile)
  static Future<Map<String, dynamic>> upsertLco(String lcoId, {required Map<String, dynamic> body}) async {
    if (lcoId == 'new') {
      final res = await ApiConfig.post('/api/lcos', body);
      return {'statusCode': res['statusCode'], 'data': res['body']};
    }
    final res = await ApiConfig.put('/api/lcos/$lcoId', body);
    return {'statusCode': res['statusCode'], 'data': res['body']};
  }

  /// List boxes registered under an LCO. Uses backend endpoint:
  /// GET /api/lcos/:id/boxes[?networkId=...]
  static Future<Map<String, dynamic>> listBoxesForLco(String lcoId, {String? networkId}) async {
    var path = '/api/lcos/$lcoId/boxes';
    if (networkId != null && networkId.trim().isNotEmpty) {
      path += '?networkId=${Uri.encodeComponent(networkId.trim())}';
    }
    final res = await ApiConfig.get(path);
    return {'statusCode': res['statusCode'], 'data': res['body']};
  }

  /// GET /api/lcos/:id/stats
  static Future<Map<String, dynamic>> getLcoStats(String lcoId) async {
    final res = await ApiConfig.get('/api/lcos/$lcoId/stats');
    return {'statusCode': res['statusCode'], 'data': res['body']};
  }

  /// GET /api/lcos/:id/finance
  static Future<Map<String, dynamic>> getLcoFinancials(
      String lcoId, {
        String? period,
      }) async {
    var path = '/api/lcos/$lcoId/finance';
    if (period != null && period.trim().isNotEmpty) {
      final enc = Uri.encodeComponent(period.trim());
      path += '?period=$enc';
    }

    final res = await ApiConfig.get(path);
    return {'statusCode': res['statusCode'], 'data': res['body']};
  }


  /// GET /api/lcos/:id/networks/:networkId/customers
  /// lcoId can be either LCO._id (ObjectId string) or the LCO's network identifier string.
  static Future<Map<String, dynamic>> getNetworkCustomers(String lcoId, String networkCode, {String? period}) async {
    final encodedNetwork = Uri.encodeComponent(networkCode);
    var path = '/api/lcos/$lcoId/networks/$encodedNetwork/customers';
    if (period != null && period.trim().isNotEmpty) {
      path += '?period=${Uri.encodeComponent(period.trim())}';
    }
    final res = await ApiConfig.get(path);
    return {'statusCode': res['statusCode'], 'data': res['body']};
  }


  /// Set per-box price.
  ///
  /// Preferred: provide amountPaise (integer). If you provide amountRupees (double), function
  /// converts to paise using rounding.
  ///
  /// POST /api/lcos/:lcoId/boxes/:boxId/price
  /// Body will include either amountPaise or amountRupees (server supports both). We prefer amountPaise.
  static Future<Map<String, dynamic>> setBoxPrice(
      String lcoId,
      String boxId, {
        int? amountPaise,
        double? amountRupees,
        String? note,
        DateTime? effectiveFrom, // optional; backend may ignore if not supported
      }) async {
    if (amountPaise == null && amountRupees == null) {
      return {'statusCode': 400, 'error': 'amountPaise or amountRupees required'};
    }

    final payload = <String, dynamic>{};

    // prefer sending integer paise if available
    if (amountPaise != null) {
      payload['amountPaise'] = amountPaise;
    } else {
      // convert rupees -> paise safely
      payload['amountPaise'] = rupeesToPaiseDoubleSafe(amountRupees!);
      // include friendly field optionally for backend/records (not required)
      payload['amountRupees'] = amountRupees;
    }

    if (note != null && note.trim().isNotEmpty) payload['note'] = note.trim();
    if (effectiveFrom != null) payload['effectiveFrom'] = effectiveFrom.toIso8601String();

    final res = await ApiConfig.post('/api/lcos/$lcoId/boxes/$boxId/price', payload);
    final status = res['statusCode'] as int? ?? 500;
    return {'statusCode': status, 'data': res['body']};
  }

  /// Remove per-box price override.
  /// DELETE /api/lcos/:lcoId/boxes/:boxId/price
  static Future<Map<String, dynamic>> removeBoxPrice(String lcoId, String boxId) async {
    final res = await ApiConfig.delete('/api/lcos/$lcoId/boxes/$boxId/price');
    final status = res['statusCode'] as int? ?? 500;
    return {'statusCode': status, 'data': res['body']};
  }
}
