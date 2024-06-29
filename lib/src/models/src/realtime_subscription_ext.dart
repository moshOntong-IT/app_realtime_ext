import 'dart:async';

import 'package:appwrite/appwrite.dart';

/// Realtime Subscription
class RealtimeSubscriptionExt {
  /// Initializes a [RealtimeSubscriptionExt]
  RealtimeSubscriptionExt({
    required this.close,
    required this.channels,
    required this.controller,
  }) : stream = controller.stream;

  /// Stream of [RealtimeMessage]s
  final Stream<RealtimeMessage> stream;

  /// Stream controller
  final StreamController<RealtimeMessage> controller;

  /// List of channels
  List<String> channels;

  /// Closes the subscription
  final Future<void> Function() close;
}
