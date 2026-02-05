import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart'; // kIsWeb
import 'package:http/http.dart' as http;
import 'dart:async';
import 'api_error.dart';


/// Simple, predictable ApiConfig modeled after your small example.
/// - Web: http://localhost:<port>
/// - Android emulator: http://10.0.2.2:<port>
/// - Physical device / other: http://192.168.0.6:<port>
class ApiConfig {
  // ---------- Settings ----------
  static int port = 3000; // change as needed
  static String lanIp = '192.168.0.6'; // your physical device / laptop IP

  // optional manual overrides (useful when auto-detect fails)
  static String? _overrideHost;    // e.g. '10.0.2.2:5000' or 'localhost:5000'
  static String? _overrideProtocol; // 'http' or 'https'

  // session token (nullable)
  static String? sessionKey;

  // Optional manual switch if emulator detection is unreliable
  // If null, the code will try a best-effort auto-detect.
  static bool? forceIsEmulator;

  // ---------- Public helpers ----------
  static void setSessionKey(String? key) => sessionKey = key;

  static void setHost(String host, {int? hostPort, String protocol = 'http'}) {
    _overrideHost = hostPort != null ? '$host:$hostPort' : host;
    _overrideProtocol = protocol;
  }

  static void clearHostOverride() {
    _overrideHost = null;
    _overrideProtocol = null;
  }

  static void setPort(int p) => port = p;
  static void setLanIp(String ip) => lanIp = ip;

  // ---------- Base URLs ----------
  static String get baseUrl {
    // manual override wins
    if (_overrideHost != null) {
      final proto = _overrideProtocol ?? 'http';
      return '$proto://$_overrideHost';
    }

    if (kReleaseMode) {
      return 'https://cablepay-backend-44811766138.asia-south1.run.app';
    }

    final backend = port;

    if (kIsWeb) {
      return 'http://localhost:$backend';
    }

    if (Platform.isAndroid) {
      final isEmu = _isAndroidEmulator();
      return isEmu
          ? 'http://10.0.2.2:$backend'
          : 'http://$lanIp:$backend';
    }

    // iOS simulator and other non-Android platforms
    // iOS simulator can usually use localhost, physical iOS device needs LAN IP.
    try {
      if (!kIsWeb && Platform.isIOS) {
        // There's no reliable built-in emulator check for iOS from Dart;
        // assume simulator uses localhost, physical device uses LAN IP.
        // If you run on a physical iOS device and localhost fails, set setHost or setLanIp.
        return 'http://localhost:$backend';
      }
    } catch (_) {}

    // default fallback
    return 'http://$lanIp:$backend';
  }

  static String get baseImage {
    final base = baseUrl;
    // remove trailing / if any
    return base.replaceFirst(RegExp(r'/$'), '');
  }

  static String get socketUrl => baseImage;

  static String getFullImagePath(String path) {
    if (path.startsWith('http')) return path;
    return '$baseImage$path';
  }

  // ---------- Simple HTTP wrappers ----------
  // static Future<Map<String, dynamic>> get(String path) async {
  //   final uri = Uri.parse('${baseUrl}$path');
  //   final res = await http.get(uri, headers: _headers());
  //   return _decode(res);
  // }

  // static Future<Map<String, dynamic>> get(String path) async {
  //   final uri = Uri.parse('${baseUrl}$path');
  //   try {
  //     final res = await http
  //         .get(uri, headers: _headers())
  //         .timeout(const Duration(seconds: 12));
  //     return _decode(res);
  //   } on SocketException {
  //     throw ApiError(
  //       type: 'network',
  //       message: 'No internet connection',
  //     );
  //   } on TimeoutException {
  //     throw ApiError(
  //       type: 'timeout',
  //       message: 'Server is taking too long to respond',
  //     );
  //   } catch (_) {
  //     throw ApiError(
  //       type: 'unknown',
  //       message: 'Unexpected error',
  //     );
  //   }
  // }

  static Future<Map<String, dynamic>> get(String path) async {
    final uri = Uri.parse('${baseUrl}$path');

    try {
      final res = await http
          .get(uri, headers: _headers())
          .timeout(const Duration(seconds: 12));

      return _decode(res);
    } on SocketException catch (e) {
      throw _mapSocketError(e);
    } on TimeoutException {
      throw ApiError(
        type: 'timeout',
        message: 'Server is slow to respond',
      );
    }
  }



  // static Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
  //   final uri = Uri.parse('${baseUrl}$path');
  //   final res = await http.post(uri, headers: _headers(contentJson: true), body: jsonEncode(body));
  //   return _decode(res);
  // }

  static Future<Map<String, dynamic>> post(
      String path,
      Map<String, dynamic> body,
      ) async {
    final uri = Uri.parse('${baseUrl}$path');

    try {
      final res = await http
          .post(
        uri,
        headers: _headers(contentJson: true),
        body: jsonEncode(body),
      )
          .timeout(const Duration(seconds: 12));

      return _decode(res);
    } on SocketException catch (e) {
      throw _mapSocketError(e);
    } on TimeoutException {
      throw ApiError(
        type: 'timeout',
        message: 'Server is slow to respond',
      );
    }
  }


  static Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('${baseUrl}$path');
    final res = await http.put(uri, headers: _headers(contentJson: true), body: jsonEncode(body));
    return _decode(res);
  }

  static Future<Map<String, dynamic>> patch(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('${baseUrl}$path');
    final res = await http.patch(uri, headers: _headers(contentJson: true), body: jsonEncode(body));
    return _decode(res);
  }

  static Future<Map<String, dynamic>> delete(String path) async {
    final uri = Uri.parse('${baseUrl}$path');
    final res = await http.delete(uri, headers: _headers());
    return _decode(res);
  }

  // ---------- Internals ----------
  static Map<String, String> _headers({bool contentJson = false}) {
    final headers = <String, String>{};
    if (contentJson) headers['Content-Type'] = 'application/json';
    headers['Accept'] = 'application/json';
    if (sessionKey != null && sessionKey!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $sessionKey';
    }
    return headers;
  }

  // static Map<String, dynamic> _decode(http.Response res) {
  //   final code = res.statusCode;
  //   if (res.body.isEmpty) return {'statusCode': code, 'body': null};
  //
  //   try {
  //     final jsonBody = jsonDecode(res.body);
  //     return {'statusCode': code, 'body': jsonBody};
  //   } catch (_) {
  //     return {'statusCode': code, 'body': res.body};
  //   }
  // }

  static Map<String, dynamic> _decode(http.Response res) {
    final code = res.statusCode;

    // 5xx – backend is down or crashed
    if (code >= 500) {
      throw ApiError(
        type: 'server',
        message: 'Service temporarily unavailable',
        statusCode: code,
      );
    }

    // Try to parse response body once
    dynamic body;
    if (res.body.isNotEmpty) {
      try {
        body = jsonDecode(res.body);
      } catch (_) {
        body = res.body;
      }
    }

    // 401 / 403 – auth OR identity validation
    if (code == 401 || code == 403) {
      final backendMessage =
      body is Map && body['error'] is String
          ? body['error']
          : 'Authentication failed';

      throw ApiError(
        type: 'auth',
        message: backendMessage,
        statusCode: code,
      );
    }

    return {
      'statusCode': code,
      'body': body,
    };
  }



  // Best-effort Android emulator detection.
  // Not 100% reliable — exposes forceIsEmulator to let you override.
  static bool _isAndroidEmulator() {
    if (forceIsEmulator != null) return forceIsEmulator!;

    // Heuristics (may not work on all devices):
    // 1) Check common Android emulator environment keys (works in many dev setups).
    // 2) Fall back to checking some well-known Android hostnames.
    try {
      final env = Platform.environment;
      if (env.containsKey('ANDROID_EMULATOR_AVD') || env.containsKey('EMULATOR_DEVICE')) {
        return true;
      }
    } catch (_) {
      // Platform.environment can be restricted; ignore
    }

    // Another heuristic: when running on an Android emulator, the host IP is typically 10.0.2.2.
    // We can't reliably probe network here without async work, so we conservatively return false.
    // If you know you're on an emulator, call: ApiConfig.forceIsEmulator = true;
    return false;
  }
}

// ApiError _mapSocketError(SocketException e) {
//   final msg = e.message.toLowerCase();
//
//   if (msg.contains('refused') ||
//       msg.contains('failed host lookup') ||
//       msg.contains('no route to host')) {
//     return ApiError(
//       type: 'server',
//       message: 'Backend service is not running',
//     );
//   }
//
//   return ApiError(
//     type: 'network',
//     message: 'No internet connection',
//   );
// }

ApiError _mapSocketError(SocketException _) {
  // SocketException ALWAYS means network layer failed
  // NOT backend logic
  return ApiError(
    type: 'network',
    message: 'No internet connection',
  );
}

