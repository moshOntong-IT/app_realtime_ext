/// {@template app_realtime_exception}
/// An exception class for AppRealtime
/// {@endtemplate}
class AppRealtimeException implements Exception {
  /// {@macro app_realtime_exception}
  const AppRealtimeException({
    required this.message,
    required this.error,
    this.stackTrace,
  });

  /// The error message
  final String message;

  /// The error object
  final Object error;

  /// The stack trace
  final StackTrace? stackTrace;

  @override
  String toString() {
    return 'AppRealtimeException: $message';
  }
}
