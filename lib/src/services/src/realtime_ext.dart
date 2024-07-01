import 'dart:async';

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

  /// Initializes the Realtime Extension service.
  ///
  /// This method initializes the Realtime Extension service with the provided
  ///  parameters.
  ///
  /// Parameters:
  /// - `client`: The client used for communication with the Realtime Extension
  ///  service.
  /// - `retryAttempts`: The number of retry attempts to make in case of
  ///  connection failure. Default is 3.
  /// - `pingInterval`: The interval (in seconds) at which ping messages will
  ///  be sent to keep the connection alive. Default is 30. Unfornutely, the
  /// Appwrite Realtime does not support two-way communication. To handle this,
  /// when we receive an error from the WebSocket, the service will attempt to
  /// reconnect. This helps to keep our realtime connection alive.
  /// - `autoReconnect`: Whether to automatically reconnect in case of
  /// disconnection. Default is true.
  ///
  /// Returns:
  /// A `Future` that completes when the initialization is finished.
  ///
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
  Stream<RealtimeState> get stateStream;

  /// Get the connection completer
  /// This also have benefit if we try to create a new document
  /// So you can check if the connection is ready or not. However,
  /// even the connection is ready, you have to double check
  /// if the connection has error or not.
  Completer<void> get getConnectionCompleter;

  /// Get the connection state
  RealtimeState get getState;

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
  Stream<RealtimeState> get stateStream;
  @override
  Future<RealtimeSubscriptionExt> subscribe({required List<String> channels});

  /// Create a Realtime instance for the browser
  late final Client client;

  /// The code of the close
  int? get closeCode => null;
}
