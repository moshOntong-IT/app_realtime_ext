import 'dart:async';
import 'dart:convert';

import 'package:app_realtime_ext/app_realtime_ext.dart';
import 'package:appwrite/appwrite.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:web_socket_channel/web_socket_channel.dart';

/// Typed function to create a WebSocketChannel
typedef WebSocketFactory = Future<WebSocketChannel> Function(Uri uri);

/// Typed function to get a fallback cookie
typedef GetFallbackCookie = String? Function();

/// Mixin for Realtime
mixin RealtimeMixinExt {
  /// The client
  late Client client;
  final Set<String> _channels = {};
  WebSocketChannel? _websok;
  String? _lastUrl;

  /// Function to get a WebSocket
  late WebSocketFactory getWebSocket;

  /// Function to get a fallback cookie
  GetFallbackCookie? getFallbackCookie;

  /// The code of the close
  int? get closeCode => _websok?.closeCode;

  /// The subscriptions
  final Map<String, RealtimeSubscriptionExt> _subscriptions = {};

  /// The Stream controller of knowing the state of the realtime
  final StreamController<RealtimeState> stateController =
      StreamController.broadcast();

  StreamSubscription<dynamic>? _websocketSubscription;

  Timer? _staleTimer;

  /// The number of retry attempts
  late final int retryAttempts;

  /// The stale timeout
  late final int staleTimeout;

  /// Indicates if the realtime should auto reconnect
  late final bool autoReconnect;

  /// Indicates if the realtime is initialized
  bool isInitialized = false;

  /// Indicated if the realtime is going to reconnect
  bool isReconnecting = false;

  /// Indicate if the realtime is disposed
  bool isDisposed = false;

  /// Indicates if the realtime is connected
  bool isConnected = false;
  bool _creatingSocket = false;

  /// Indicate the remeaning attempts
  int attemptsCount = 0;

  Future<dynamic> _closeConnection() async {
    _staleTimer?.cancel();
    unawaited(_websocketSubscription?.cancel());
    unawaited(_websok?.sink.close(status.normalClosure, 'Ending session'));
    _lastUrl = null;
    isConnected = false;
  }

  Future<void> _createSocket() async {
    if (_creatingSocket || _channels.isEmpty) return;
    stateController.add(const ConnectingState());
    _creatingSocket = true;
    isConnected = false;
    _staleTimer?.cancel();

    final uri = _prepareUri();
    try {
      if (_websok == null) {
        _websok = await getWebSocket(uri);
        _lastUrl = uri.toString();
      } else {
        if (_lastUrl == uri.toString() && _websok?.closeCode == null) {
          _creatingSocket = false;
          return;
        }

        await _closeConnection();
        _lastUrl = uri.toString();
        _websok = await getWebSocket(uri);
      }
      debugPrint('subscription: $_lastUrl');

      isConnected = true;

      _websocketSubscription = _websok?.stream.listen(
        (response) {
          final data = RealtimeResponseExt.fromJson(response as String);
          switch (data.type) {
            case RealtimeResponseType.error:
              isConnected = false;
              handleError(data);

            case RealtimeResponseType.connected:
              attemptsCount = 0;

              // channels, user?
              final message = RealtimeResponseConnectedExt.fromMap(data.data);
              if (message.user.isEmpty) {
                // send fallback cookie if exists
                final cookie = getFallbackCookie?.call();
                if (cookie != null) {
                  _websok?.sink.add(
                    jsonEncode(
                      {
                        'type': 'authentication',
                        'data': {
                          'session': cookie,
                        },
                      },
                    ),
                  );
                }
              }

              _resetStaleTimer();

            case RealtimeResponseType.event:
              isConnected = true;
              _resetStaleTimer();
              attemptsCount = 0;
              final message = RealtimeMessage.fromMap(data.data);
              for (final subscription in _subscriptions.values) {
                for (final channel in message.channels) {
                  if (subscription.channels.contains(channel)) {
                    subscription.controller.add(message);
                  }
                }
              }
          }
        },
        onDone: () {
          attemptsCount = 0;
          final subscriptions =
              List<RealtimeSubscriptionExt>.from(_subscriptions.values);
          for (final subscription in subscriptions) {
            subscription.close();
          }
          _channels.clear();
          _closeConnection();
          stateController.add(const DisconnectedState());
        },
        onError: (Object err, StackTrace stack) {
          isConnected = false;
          stateController.add(
            ErrorState(
              error: err,
              stackTrace: stack,
            ),
          );
          for (final subscription in _subscriptions.values) {
            subscription.controller.addError(err, stack);
          }
          if (_websok?.closeCode != null && _websok?.closeCode != 1008) {
            toReconnect();
          }
        },
      );
    } catch (e, stackTrace) {
      stateController.add(
        ErrorState(
          error: e,
          stackTrace: stackTrace,
        ),
      );
      // if (e is AppwriteException) {
      //   rethrow;
      // }
      // if (e is WebSocketChannelException) {
      //   throw AppwriteException(e.message);
      // }
      // throw AppwriteException(e.toString());
    } finally {
      _creatingSocket = false;
      if (!isConnected) {
        await _closeConnection();
      }

      if (isConnected) {
        stateController.add(const ConnectedState());
        attemptsCount = 0;
      } else {
        if (autoReconnect) {
          await toReconnect();
        }
      }

      isReconnecting = false;
    }
  }

  Uri _prepareUri() {
    if (client.endPointRealtime == null) {
      throw AppwriteException(
        'Please set endPointRealtime to connect to realtime server',
      );
    }
    final uri = Uri.parse(client.endPointRealtime!);
    return Uri(
      host: uri.host,
      scheme: uri.scheme,
      port: uri.port,
      queryParameters: {
        'project': client.config['project'],
        'channels[]': _channels.toList(),
      },
      path: '${uri.path}/realtime',
    );
  }

  /// A function to subscribe to a channel
  Future<RealtimeSubscriptionExt> subscribeTo({
    required List<String> channels,
  }) async {
    isReconnecting = false;
    final id = ID.unique();
    attemptsCount = 0;
    stateController.add(
      SubscribingState(
        id: id,
        channels: channels,
      ),
    );
    final controller = StreamController<RealtimeMessage>.broadcast();
    _channels.addAll(channels);
    await toReconnect();

    final subscription = RealtimeSubscriptionExt(
      controller: controller,
      channels: channels,
      close: () async {
        stateController.add(
          UnSubscribingState(
            id: id,
          ),
        );
        _subscriptions.remove(id);
        unawaited(controller.close());
        _cleanup(channels);

        if (_channels.isNotEmpty) {
          await toReconnect();
        } else {
          await _closeConnection();
        }
      },
    );
    _subscriptions[id] = subscription;
    return subscription;
  }

  void _cleanup(List<String> channels) {
    for (final channel in channels) {
      final found = _subscriptions.values
          .any((subscription) => subscription.channels.contains(channel));
      if (!found) {
        _channels.remove(channel);
      }
    }
  }

  /// Handling the error
  void handleError(RealtimeResponseExt response) {
    if (response.data['code'] == 1008) {
      final exception = AppwriteException(
        response.data['message'] as String,
        response.data['code'] as int,
      );

      stateController.add(
        ErrorState(
          error: exception,
          stackTrace: StackTrace.current,
        ),
      );
    } else {
      debugPrint('Reconnecting');
      toReconnect();
    }
  }

  /// A function to reconnect the realtime
  Future<void> toReconnect() async {
    if (!isInitialized) {
      throw AppwriteException('Realtime is not initialized');
    }
    if (isDisposed) {
      throw AppwriteException('Realtime is disposed');
    }

    if (isReconnecting) {
      return;
    }

    if (attemptsCount >= retryAttempts) {
      stateController.add(
        ErrorState(
          error: AppwriteException('Max retry attempts reached'),
          stackTrace: StackTrace.current,
        ),
      );
      return;
    }

    isReconnecting = true;
    attemptsCount++;
    stateController.add(const ReconnectingState());
    await _createSocket();
  }

  /// To dispose the resources of realtime
  Future<void> toDispose() async {
    if (!isInitialized) {
      throw AppwriteException('Realtime is not initialized');
    }
    if (isDisposed) {
      throw AppwriteException('Realtime is already disposed');
    }
    stateController.add(const DisposingState());
    isDisposed = true;
    unawaited(_closeConnection());
    unawaited(stateController.close());
  }

  void _resetStaleTimer() {
    _staleTimer?.cancel();
    _staleTimer = Timer(Duration(seconds: staleTimeout), () {
      stateController.add(const StaleTimeoutState());
      if (isConnected && autoReconnect && !isDisposed && !isReconnecting) {
        unawaited(toReconnect());
      } else {
        unawaited(_closeConnection());
      }
    });
  }
}
