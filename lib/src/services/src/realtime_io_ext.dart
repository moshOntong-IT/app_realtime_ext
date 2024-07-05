import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:app_realtime_ext/app_realtime_ext.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/client_io.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Create a Realtime instance for the browser
RealtimeBaseExt createRealtime() => RealtimeIoExt();

/// Realtime for the non-browser platform
class RealtimeIoExt extends RealtimeBaseExt with RealtimeMixinExt {
  @override
  Future<void> initialize({
    required Client client,
    int retryAttempts = 3,
    int pingInterval = 30,
    bool pingEnabled = true,
    bool autoReconnect = true,
  }) async {
    this.client = client;
    getWebSocket = _getWebSocket;

    isInitialized = true;
    isDisposed = false;

    this.pingEnabled = pingEnabled;
    this.retryAttempts = retryAttempts;
    this.pingInterval = pingInterval;
    this.autoReconnect = autoReconnect;
  }

  @override
  Future<RealtimeSubscriptionExt> subscribe({required List<String> channels}) {
    return subscribeTo(channels: channels);
  }

  @override
  Future<void> dispose() => toDispose();

  @override
  Future<void> reconnect() => toReconnect();

  @override
  void setPingEnabled({required bool enabled}) {
    toSetPingEnabled(enabled: enabled);
  }

  @override
  Stream<RealtimeState> get stateStream => stateController.stream;

  Future<WebSocketChannel> _getWebSocket(Uri uri) async {
    Map<String, String>? headers;
    while (!(client as ClientIO).initialized &&
        (client as ClientIO).initProgress) {
      // ignore: inference_failure_on_instance_creation
      await Future.delayed(const Duration(milliseconds: 10));
    }
    if (!(client as ClientIO).initialized) {
      await (client as ClientIO).init();
    }
    final cookies = await (client as ClientIO).cookieJar.loadForRequest(uri);
    headers = {HttpHeaders.cookieHeader: CookieManagerExt.getCookies(cookies)};

    // final websok = IOWebSocketChannel(
    //   (client as ClientIO).selfSigned
    //       ? await _connectForSelfSignedCert(uri, headers)
    //       : await WebSocket.connect(uri.toString(), headers: headers),
    // );
    // return websok;

    try {
      final websok = IOWebSocketChannel(
        (client as ClientIO).selfSigned
            ? await _connectForSelfSignedCert(uri, headers)
            : await WebSocket.connect(uri.toString(), headers: headers),
      );
      return websok;
    } catch (e) {
      // Handle and log the error
      debugPrint('Failed to connect to WebSocket: $e');
      rethrow;
    }
  }

  // https://github.com/jonataslaw/getsocket/blob/f25b3a264d8cc6f82458c949b86d286cd0343792/lib/src/io.dart#L104
  // and from official dart sdk websocket_impl.dart connect method
  Future<WebSocket> _connectForSelfSignedCert(
    Uri uri,
    Map<String, dynamic> headers,
  ) async {
    try {
      final r = Random();
      final key = base64.encode(List<int>.generate(16, (_) => r.nextInt(255)));
      final client = HttpClient(context: SecurityContext())
        ..badCertificateCallback =
            (X509Certificate cert, String host, int port) {
          debugPrint('AppwriteRealtime: Allow self-signed certificate');
          return true;
        };

      final uriCopy = Uri(
        scheme: uri.scheme == 'wss' ? 'https' : 'http',
        userInfo: uri.userInfo,
        host: uri.host,
        port: uri.port,
        path: uri.path,
        query: uri.query,
        fragment: uri.fragment,
      );

      final request = await client.getUrl(uriCopy);

      headers
          .forEach((key, value) => request.headers.add(key, value as Object));

      request.headers
        ..set(HttpHeaders.connectionHeader, 'Upgrade')
        ..set(HttpHeaders.upgradeHeader, 'websocket')
        ..set('Sec-WebSocket-Key', key)
        ..set('Cache-Control', 'no-cache')
        ..set('Sec-WebSocket-Version', '13');

      final response = await request.close();

      // ignore: close_sinks
      final socket = await response.detachSocket();
      final webSocket = WebSocket.fromUpgradedSocket(socket, serverSide: false);
      return webSocket;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Completer<void> get getConnectionCompleter => connectionCompleter;

  @override
  RealtimeState get getState => state;
}
