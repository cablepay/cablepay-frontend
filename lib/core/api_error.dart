class ApiError implements Exception {
  final String type;
  // network | timeout | server | auth | unknown
  final String message;
  final int? statusCode;

  ApiError({
    required this.type,
    required this.message,
    this.statusCode,
  });

  @override
  String toString() {
    return 'ApiError(type=$type, status=$statusCode, message=$message)';
  }
}
