import 'dart:convert';

import 'package:flutter/foundation.dart';

/// {@template realtime_response_type}
/// The type of the realtime response
/// {@endtemplate}
enum RealtimeResponseType {
  /// Error response
  error(code: 'error'),

  /// Event response
  event(code: 'event'),

  /// Connected response
  connected(code: 'connected');

  const RealtimeResponseType({required this.code});

  /// The code of the response
  final String code;

  /// Converting the response from string/code to enum
  static RealtimeResponseType fromCode(String code) {
    switch (code) {
      case 'error':
        return RealtimeResponseType.error;
      case 'event':
        return RealtimeResponseType.event;
      case 'connected':
        return RealtimeResponseType.connected;
      default:
        throw Exception('Unknown code: $code');
    }
  }
}

/// {@template realtime_response_ext}
/// The realtime response from the server
/// {@endtemplate}
@immutable
class RealtimeResponseExt {
  /// {@macro realtime_response_ext}
  const RealtimeResponseExt({
    required this.type,
    required this.data,
  });

  /// Creates a RealtimeResponseExt from a map
  factory RealtimeResponseExt.fromMap(Map<String, dynamic> map) {
    return RealtimeResponseExt(
      type: RealtimeResponseType.fromCode(map['type'] as String),
      data: map['data'] as Map<String, dynamic>,
    );
  }

  /// Creates a RealtimeResponseExt from a json
  factory RealtimeResponseExt.fromJson(String source) =>
      RealtimeResponseExt.fromMap(json.decode(source) as Map<String, dynamic>);

  /// Creates a copy of the RealtimeResponseExt with the given fields replaced
  RealtimeResponseExt copyWith({
    RealtimeResponseType? type,
    Map<String, dynamic>? data,
  }) {
    return RealtimeResponseExt(
      type: type ?? this.type,
      data: data ?? this.data,
    );
  }

  /// Converts the RealtimeResponseExt to a map
  Map<String, dynamic> toMap() {
    return {
      'type': type.code,
      'data': data,
    };
  }

  /// To convert the RealtimeResponseExt to a json
  String toJson() => json.encode(toMap());

  @override
  String toString() => 'RealtimeResponseExt(type: $type, data: $data)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is RealtimeResponseExt &&
        other.type == type &&
        mapEquals(other.data, data);
  }

  @override
  int get hashCode => type.hashCode ^ data.hashCode;

  /// The realtime response from the server
  final RealtimeResponseType type;

  /// The data of the response
  final Map<String, dynamic> data;
}
