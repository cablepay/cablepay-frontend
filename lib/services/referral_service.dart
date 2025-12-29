// lib/services/referral_service.dart
import 'dart:async';
import '../core/api_config.dart';

class ReferralService {
  /// Apply a referral code to a customer account.
  /// Expects body: { customerId, referralCode }
  /// Server requires session.
  static Future<Map<String, dynamic>> claimReferral(String customerId, String referralCode) async {
    final payload = {
      'customerId': customerId,
      'referralCode': referralCode.trim(),
    };
    final res = await ApiConfig.post('/api/referrals/claim', payload);
    return {'statusCode': res['statusCode'], 'data': res['body']};
  }

  /// Fetch referrals where the provided id is the referrer.
  /// GET /api/referrals/referrer/:id
  /// Returns { referrals: [ { _id, referrer, referred, status, rewardPoints, createdAt, completedAt, referredCustomer: { name, phone } } ] }
  /// This endpoint is optional on the server; this function tolerates 404/empty responses.
  static Future<Map<String, dynamic>> getReferralsForReferrer(String referrerId) async {
    final res = await ApiConfig.get('/api/referrals/referrer/${Uri.encodeComponent(referrerId)}');
    return {'statusCode': res['statusCode'], 'data': res['body']};
  }
}
