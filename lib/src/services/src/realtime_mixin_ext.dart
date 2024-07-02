import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
  Timer? _pingTimer;

  /// The number of retry attempts
  late final int retryAttempts;

  /// The ping interval
  late final int pingInterval;

  /// Indicates if the realtime should auto reconnect
  late final bool autoReconnect;

  /// The state of the realtime
  RealtimeState state = const DisconnectedState();

  /// The connection completer
  Completer<void> connectionCompleter = Completer<void>();

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

  void _setState(RealtimeState newState) {
    state = newState;
    stateController.add(newState);

    if (newState is ConnectedState || newState is ErrorState) {
      if (!connectionCompleter.isCompleted) {
        connectionCompleter.complete();
      }
    } else if (newState is DisconnectedState || newState is ReconnectingState) {
      if (connectionCompleter.isCompleted) {
        connectionCompleter = Completer<void>();
      }
    }
  }

  Future<dynamic> _closeConnection() async {
    _staleTimer?.cancel();
    // Cancel the websocket subscription and wait for it to complete
    await _websocketSubscription?.cancel();
    _websocketSubscription = null;
    await _websok?.sink.close(status.normalClosure, 'Ending session');
    _websok = null;
    _lastUrl = null;
    isConnected = false;
    // stateController.add(const DisconnectedState());
    _setState(const DisconnectedState());
    _stopPingTimer();
  }

  Future<void> _createSocket() async {
    // ! I dont know if this have to be here
    // ! But what I want to do is to ensure that
    // ! the websocket subscription is closed
    // ! before creating a new one
    // ! Because according to my debug phase, I found out that
    // ! I got Bad state: Stream has already been listened to
    await _websocketSubscription?.cancel();
    _websocketSubscription = null;
    if (_creatingSocket || _channels.isEmpty) return;
    // stateController.add(const ConnectingState());

    _setState(const ConnectingState());
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
      // ! I got Bad state: Stream has already been listened to
      // ! That is why i tried to make it multiple subscription
      _websocketSubscription = _websok?.stream.asBroadcastStream().listen(
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

            // _resetStaleTimer();

            case RealtimeResponseType.event:
              isConnected = true;
              // _resetStaleTimer();
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
          debugPrint('Websocket done');
          attemptsCount = 0;
          final subscriptions =
              List<RealtimeSubscriptionExt>.from(_subscriptions.values);
          for (final subscription in subscriptions) {
            subscription.close();
          }
          _channels.clear();
          _closeConnection();
          // stateController.add(const DisconnectedState());
          _setState(const DisconnectedState());
        },
        onError: (Object err, StackTrace stack) {
          debugPrint('Websocket error: $err');
          isConnected = false;
          // stateController.add(
          //   ErrorState(
          //     error: err,
          //     stackTrace: stack,
          //   ),
          // );
          _setState(
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

      _startPingTimer();
    } on WebSocketException catch (e, _) {
      debugPrint('Websocket: $e');
      if (e.message.contains('was not upgraded to websocket')) {
        await toReconnect();
      }
    } catch (e, stackTrace) {
      debugPrint('Failed to connect to WebSocket: $e');
      // stateController.add(
      //   ErrorState(
      //     error: e,
      //     stackTrace: stackTrace,
      //   ),
      // );
      _setState(
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
        // stateController.add(const ConnectedState());
        _setState(const ConnectedState());
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
    // stateController.add(
    //   SubscribingState(
    //     id: id,
    //     channels: channels,
    //   ),
    // );
    _setState(
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
        // stateController.add(
        //   UnSubscribingState(
        //     id: id,
        //   ),
        // );
        _setState(
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

      // stateController.add(
      //   ErrorState(
      //     error: exception,
      //     stackTrace: StackTrace.current,
      //   ),
      // );
      _setState(
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
      // stateController.add(
      //   ErrorState(
      //     error: AppwriteException('Max retry attempts reached'),
      //     stackTrace: StackTrace.current,
      //   ),
      // );
      _setState(
        ErrorState(
          error: AppwriteException('Max retry attempts reached'),
          stackTrace: StackTrace.current,
        ),
      );
      return;
    }

    isReconnecting = true;
    attemptsCount++;
    // stateController.add(const ReconnectingState());
    _setState(const ReconnectingState());

    await _closeConnection();
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
    // stateController.add(const DisposingState());
    _setState(const DisposingState());
    isDisposed = true;
    _staleTimer?.cancel();
    await _closeConnection();
    await stateController.close();
  }

  // void _resetStaleTimer() {
  //   _staleTimer?.cancel();
  //   _staleTimer = Timer(Duration(seconds: staleTimeout), () {
  ////     stateController.add(const StaleTimeoutState());
  //    _setState(const StaleTimeoutState());
  //     if (isConnected && autoReconnect && !isDisposed && !isReconnecting) {
  //       unawaited(toReconnect());
  //     } else {
  //       unawaited(_closeConnection());
  //     }
  //   });
  // }

  void _startPingTimer() {
    _pingTimer?.cancel(); // Cancel any existing timer
    _pingTimer = Timer.periodic(Duration(seconds: pingInterval), (timer) {
      if (isConnected) {
        // stateController.add(const PingState());
        _setState(const PingState());
        _websok?.sink.add('{"type":"ping"}');
      } else {
        timer.cancel();
      }
    });
  }

  void _stopPingTimer() {
    _pingTimer?.cancel();
  }
}
