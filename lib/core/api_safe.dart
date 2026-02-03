// lib/core/api_safe.dart
import 'api_error.dart';

class ApiSafe {
  static Future<T?> run<T>(
      Future<T> Function() call, {
        void Function(ApiError e)? onError,
      }) async {
    try {
      return await call();
    } on ApiError catch (e) {
      onError?.call(e);
      return null;
    } catch (_) {
      return null;
    }
  }
}

