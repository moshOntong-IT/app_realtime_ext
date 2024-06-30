import 'package:app_realtime_ext/src/models/models.dart';
import 'package:appwrite/appwrite.dart';

// ignore: always_use_package_imports
import 'realtime_ext_stub.dart'
    if (dart.library.io) 'realtime_io_ext.dart'
    if (dart.library.html) 'realtime_browser_ext.dart';

/// {@template realtime_ext}
/// A Realtime Clone from Appwrite Flutter sdk.
///  The purpose of this is to extend the capability and separate
///  from sdk-generator
///  {@endtemplate}
sealed class RealtimeExt {
  /// {@macro realtime_ext}
  factory RealtimeExt() => createRealtime();

  /// Initializes the Realtime instance.
  ///
  /// This method sets up a Realtime connection with the server, allowing for
  ///  real-time data exchange.
  ///
  /// - `[client]` is the Appwrite client used for the connection.
  /// - `[retryAttempts]` specifies the number of attempts to reconnect to the
  ///  server. Defaults to 3.
  /// - `[staleTimeout]` defines the duration (in seconds) after which the
  ///  connection is considered stale and is closed. This ensures the freshness
  ///  of the connection.
  /// - `[autoReconnect]` is a boolean flag that, when set to `true`, will
  ///  automatically attempt to reconnect if the connection is closed due
  ///  to [`staleTimeout`] or other reasons.
  ///
  /// Example:
  /// ```dart
  /// Realtime realtime = Realtime(
  ///   client: appwriteClient,
  ///   retryAttempts: 5,
  ///   staleTimeout: 30000,
  ///   autoReconnect: true,
  /// );
  /// ```
  ///
  /// Note: Ensure that the `client` is properly configured and
  ///  authenticated before initializing the Realtime instance.
  Future<void> initialize({
    required Client client,
    int retryAttempts = 3,
    int pingInterval = 30,
    bool autoReconnect = true,
  });

  /// Reconnect the Realtime instance
  Future<void> reconnect();

  /// Disposing the Realtime resources
  Future<void> dispose();

  /// Getting the state of the Realtime
  Stream<RealtimeState> get state;

  /// Subscribe to a list of channels
  Future<RealtimeSubscriptionExt> subscribe({required List<String> channels});
}

/// Realtime allows you to listen to any events on the server-side in realtime
///  using the subscribe method.
abstract class RealtimeBaseExt implements RealtimeExt {
  @override
  Future<void> initialize({
    required Client client,
    int retryAttempts = 3,
    int pingInterval = 30,
    bool autoReconnect = true,
  });

  @override
  Future<void> reconnect();

  @override
  Future<void> dispose();

  @override
  Stream<RealtimeState> get state;
  @override
  Future<RealtimeSubscriptionExt> subscribe({required List<String> channels});

  /// Create a Realtime instance for the browser
  late final Client client;

  /// The code of the close
  int? get closeCode => null;
}
