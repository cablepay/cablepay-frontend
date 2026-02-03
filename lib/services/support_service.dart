import '../core/api_config.dart';
import '../core/api_error.dart';
import '../core/api_safe.dart';

class SupportService {
  /* ───────── CUSTOMER ───────── */

  static Future<List<dynamic>> listQuestions() async {
    final res =
    await ApiConfig.get('/api/support/customer/questions');
    return res['body'] ?? [];
  }

  static Future<Map<String, dynamic>> createTicket({
    required String boxId,
    required String questionId,
  }) async {
    final res = await ApiConfig.post(
      '/api/support/customer/tickets',
      {
        'boxId': boxId,
        'questionId': questionId,
      },
    );
    return Map<String, dynamic>.from(res['body']);
  }

  static Future<List<dynamic>> customerTickets() async {
    final res =
    await ApiConfig.get('/api/support/customer/tickets');
    return res['body'] ?? [];
  }

  static Future<List<dynamic>> ticketMessages(
      String ticketId) async {
    final res = await ApiConfig.get(
      '/api/support/customer/tickets/$ticketId/messages',
    );
    return res['body'] ?? [];
  }

  static Future<void> customerReply({
    required String ticketId,
    required String message,
  }) async {
    await ApiConfig.post(
      '/api/support/customer/tickets/$ticketId/reply',
      {'message': message},
    );
  }

  /* ───────── LCO ───────── */

  // static Future<List<dynamic>> lcoTickets({
  //   String? networkCode,
  // }) async {
  //   final path = networkCode == null
  //       ? '/api/support/lco/tickets'
  //       : '/api/support/lco/tickets?networkCode=$networkCode';
  //
  //   final res = await ApiConfig.get(path);
  //   return res['body'] ?? [];
  // }

  static Future<List<dynamic>> lcoTickets({
    String? networkCode,
    void Function(ApiError e)? onError,
  }) async {
    final path = networkCode == null
        ? '/api/support/lco/tickets'
        : '/api/support/lco/tickets?networkCode=$networkCode';

    final res = await ApiSafe.run(
          () => ApiConfig.get(path),
      onError: onError,
    );

    if (res == null) return [];

    return res['body'] ?? [];
  }


  static Future<void> lcoRespond({
    required String ticketId,
    required String message,
    String status = 'in_progress',
  }) async {
    await ApiConfig.post(
      '/api/support/lco/tickets/$ticketId/respond',
      {
        'message': message,
        'status': status,
      },
    );
  }
}
