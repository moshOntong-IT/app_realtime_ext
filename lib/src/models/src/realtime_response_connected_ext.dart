import 'dart:convert';
import 'package:flutter/foundation.dart';

/// {@template realtime_response_connected}
/// The response of the connected event
/// {@endtemplate}
@immutable
class RealtimeResponseConnectedExt {
  /// {@macro realtime_response_connected}
  const RealtimeResponseConnectedExt({
    required this.channels,
    this.user = const {},
  });

  /// Create a RealtimeResponseConnected from a map
  factory RealtimeResponseConnectedExt.fromMap(Map<String, dynamic> map) {
    return RealtimeResponseConnectedExt(
      channels: List<String>.from(map['channels'] as List<String>),
      user: Map<String, dynamic>.from(
        (map['user'] as Map<String, dynamic>?) ?? {},
      ),
    );
  }

  /// Create a RealtimeResponseConnected from a json
  factory RealtimeResponseConnectedExt.fromJson(String source) =>
      RealtimeResponseConnectedExt.fromMap(
        json.decode(source) as Map<String, dynamic>,
      );

  /// Create a copy of the RealtimeResponseConnected
  RealtimeResponseConnectedExt copyWith({
    List<String>? channels,
    Map<String, dynamic>? user,
  }) {
    return RealtimeResponseConnectedExt(
      channels: channels ?? this.channels,
      user: user ?? this.user,
    );
  }

  /// Convert the RealtimeResponseConnected to a map
  Map<String, dynamic> toMap() {
    return {
      'channels': channels,
      'user': user,
    };
  }

  /// Convert the RealtimeResponseConnected to a json
  String toJson() => json.encode(toMap());

  @override
  String toString() =>
      'RealtimeResponseConnected(channels: $channels, user: $user)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is RealtimeResponseConnectedExt &&
        listEquals(other.channels, channels) &&
        mapEquals(other.user, user);
  }

  @override
  int get hashCode => channels.hashCode ^ user.hashCode;

  /// The channels
  final List<String> channels;

  /// The user
  final Map<String, dynamic> user;
}
