// lib/services/customer_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../core/api_config.dart';

class CustomerService {

  static Future<Map<String, dynamic>> requestOtp(String phone) async {
    final res = await ApiConfig.post('/api/auth/request-otp', {
      'phone': phone.trim(),
    });

    return {
      'statusCode': res['statusCode'],
      'data': res['body'],
    };
  }

  /// STEP 2: Verify OTP + Login/Create Customer
  static Future<Map<String, dynamic>> verifyOtp({
    required String phone,
    required String otp,
    String? name,
    String? referralCode,
  }) async {
    final res = await ApiConfig.post('/api/auth/verify-otp', {
      'phone': phone.trim(),
      'otp': otp.trim(),
      if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
      if (referralCode != null && referralCode.trim().isNotEmpty)
        'referralCode': referralCode.trim(),
    });

    return {
      'statusCode': res['statusCode'],
      'data': res['body'],
    };
  }

  static Future<Map<String, dynamic>> claimReferral({
    required String customerId,
    required String referralCode,
  }) async {
    final res = await ApiConfig.post('/api/referral/claim', {
      'customerId': customerId,
      'referralCode': referralCode.trim(),
    });

    return {
      'statusCode': res['statusCode'],
      'data': res['body'],
    };
  }



  // Get customer by id
  static Future<Map<String, dynamic>> getCustomer(String id) async {
    final res = await ApiConfig.get('/api/customers/$id');
    return {'statusCode': res['statusCode'], 'data': res['body']};
  }
  // Update customer fields
  static Future<Map<String, dynamic>> updateCustomer(
      String id, Map<String, dynamic> payload) async {
    final res = await ApiConfig.patch('/api/customers/$id', payload);
    return {
      'statusCode': res['statusCode'],
      'data': res['body'],
    };
  }


  static Future<Map<String, dynamic>> getOperatorPhone(String customerId) async {
    final res = await ApiConfig.get('/api/customers/$customerId/operator-phone');
    return {
      'statusCode': res['statusCode'],
      'data': res['body'],
    };
  }



  /// Create Box (accepts XFile for cross-platform compatibility)
  /// imageFile: XFile? (from image_picker). If null, sending JSON payload.
  static Future<Map<String, dynamic>> createBox(String customerId,
      {required String setupBoxNumber,
        String? vcNumber,
        String? network,
        String? lcoId,
        String? lcoRef,
        XFile? imageFile}) async {
    // client-side quick validations
    if (setupBoxNumber.trim().isEmpty) {
      return {'statusCode': 400, 'data': {'error': 'setupBoxNumber required'}};
    }
    if (lcoId == null || lcoId.trim().isEmpty) {
      return {'statusCode': 400, 'data': {'error': 'lcoId (network identifier) required'}};
    }

    // If no image, send JSON payload via ApiConfig.post (includes session headers)
    if (imageFile == null) {
      final payload = {
        'setupBoxNumber': setupBoxNumber.trim(),
        if (vcNumber != null && vcNumber.trim().isNotEmpty) 'vcNumber': vcNumber.trim(),
        if (network != null && network.trim().isNotEmpty) 'network': network.trim(),
        'lcoId': lcoId.trim(),
        if (lcoRef != null && lcoRef.trim().isNotEmpty) 'lcoRef': lcoRef.trim(),
      };
      final res = await ApiConfig.post('/api/customers/$customerId/boxes', payload);
      return {'statusCode': res['statusCode'], 'data': res['body']};
    }

    // Multipart upload when image provided (works on web & mobile)
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/customers/$customerId/boxes');
    final request = http.MultipartRequest('POST', uri);

    final headers = <String, String>{
      'Accept': 'application/json',
      'User-Agent': 'CablePayClient/1.0',
    };
    if (ApiConfig.sessionKey != null) {
      headers['Authorization'] = 'Bearer ${ApiConfig.sessionKey}';
    }
    request.headers.addAll(headers);

    request.fields['setupBoxNumber'] = setupBoxNumber.trim();
    if (vcNumber != null && vcNumber.trim().isNotEmpty) request.fields['vcNumber'] = vcNumber.trim();
    if (network != null && network.trim().isNotEmpty) request.fields['network'] = network.trim();
    request.fields['lcoId'] = lcoId.trim();
    if (lcoRef != null && lcoRef.trim().isNotEmpty) request.fields['lcoRef'] = lcoRef.trim();

    try {
      // Read bytes from XFile (works both on web and mobile)
      final bytes = await imageFile.readAsBytes();
      final filename = imageFile.name.isNotEmpty ? imageFile.name : 'barcode.jpg';
      final multipartFile = http.MultipartFile.fromBytes('barcodeImage', bytes, filename: filename);
      request.files.add(multipartFile);

      final streamed = await request.send();
      final resp = await http.Response.fromStream(streamed);
      try {
        final body = resp.body.isNotEmpty ? jsonDecode(resp.body) : null;
        return {'statusCode': resp.statusCode, 'data': body};
      } catch (e) {
        return {'statusCode': resp.statusCode, 'data': resp.body};
      }
    } catch (e) {
      return {'statusCode': 500, 'data': {'error': 'Failed to attach image: $e'}};
    }
  }

  // List boxes for customer
  static Future<Map<String, dynamic>> listBoxes(String customerId) async {
    final res = await ApiConfig.get('/api/customers/$customerId/boxes');
    return {'statusCode': res['statusCode'], 'data': res['body']};
  }


  /// Activate box (creates a Payment and activates the box).
  static Future<Map<String, dynamic>> payNow(
      String customerId,
      String boxId, {
        String? period,
        String? providerPaymentId,
      }) async {
    final payload = <String, dynamic>{
      if (period != null && period.isNotEmpty) 'period': period,
      if (providerPaymentId != null && providerPaymentId.isNotEmpty) 'providerPaymentId': providerPaymentId,
    };

    final res = await ApiConfig.post(
      '/api/customers/$customerId/boxes/$boxId/activate',
      payload,
    );

    return {'statusCode': res['statusCode'], 'data': res['body']};
  }

  /// Fetch payment history for a customer (optionally filtered by boxId and date window)
  static Future<Map<String, dynamic>> getPaymentHistory(String customerId, {String? boxId, String? from, String? to}) async {
    final query = <String, String>{};
    if (boxId != null && boxId.trim().isNotEmpty) query['boxId'] = boxId.trim();
    if (from != null && from.trim().isNotEmpty) query['from'] = from.trim();
    if (to != null && to.trim().isNotEmpty) query['to'] = to.trim();

    final qs = query.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&');
    final path = '/api/customers/$customerId/history${qs.isNotEmpty ? '?$qs' : ''}';
    final res = await ApiConfig.get(path);
    return {'statusCode': res['statusCode'], 'data': res['body']};
  }

  /// Get wallet summary for a customer
  static Future<Map<String, dynamic>> getWallet(String customerId) async {
    final res = await ApiConfig.get('/api/customers/$customerId/wallet');
    return {'statusCode': res['statusCode'], 'data': res['body']};
  }

  /// Get wallet transaction history (paginated)
  static Future<Map<String, dynamic>> getWalletHistory(String customerId, {int page = 1, int limit = 20}) async {
    final qs = '?page=${page.toString()}&limit=${limit.toString()}';
    final res = await ApiConfig.get('/api/customers/$customerId/wallet/history$qs');
    return {'statusCode': res['statusCode'], 'data': res['body']};
  }


}
