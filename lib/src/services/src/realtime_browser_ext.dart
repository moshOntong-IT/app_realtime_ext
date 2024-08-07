import 'dart:async';
import 'dart:convert';

import 'package:app_realtime_ext/app_realtime_ext.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/client_browser.dart';
import 'package:universal_html/html.dart' as html;
import 'package:web_socket_channel/html.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Create a Realtime instance for the browser
RealtimeBaseExt createRealtime() => RealtimeBrowserExt();

/// Realtime for the browser
class RealtimeBrowserExt extends RealtimeBaseExt with RealtimeMixinExt {
  @override
  Future<void> initialize({
    required Client client,
    int retryAttempts = 3,
    int pingInterval = 30,
    bool pingEnabled = true,
    bool autoReconnect = true,
  }) async {
    this.client = client;
    getWebSocket = _getWebSocketBrowserPlatform;
    getFallbackCookie = _getFallbackCookie;

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

  Future<WebSocketChannel> _getWebSocketBrowserPlatform(Uri uri) async {
    await (client as ClientBrowser).init();
    return HtmlWebSocketChannel.connect(uri);
  }

  String? _getFallbackCookie() {
    final fallbackCookie = html.window.localStorage['cookieFallback'];
    if (fallbackCookie != null) {
      final cookie =
          Map<String, dynamic>.from(jsonDecode(fallbackCookie) as Map);
      return cookie.values.first! as String;
    }
    return null;
  }

  @override
  Completer<void> get getConnectionCompleter => connectionCompleter;

  @override
  RealtimeState get getState => state;
}
