/// The State of the Realtime
sealed class RealtimeState {
  const RealtimeState();
}

/// {@template ConnectedState}
/// A state indicating that the Realtime is connected
/// {@endtemplate}
class ConnectedState implements RealtimeState {
  /// {@macro ConnectedState}
  const ConnectedState();
}

/// {@template DisconnectedState}
/// A state indicating that the Realtime is disconnected
/// {@endtemplate}
class DisconnectedState implements RealtimeState {
  /// {@macro DisconnectedState}
  const DisconnectedState();
}

/// {@template ConnectingState}
/// A state indicating that the Realtime is connecting
/// {@endtemplate}
class ConnectingState implements RealtimeState {
  /// {@macro ConnectingState}
  const ConnectingState();
}

/// A state indicating that the Realtime is going to subscribe with channels
class SubscribingState implements RealtimeState {
  /// Create a SubscribingState
  const SubscribingState({required this.id, required this.channels});

  /// The id of the subscription
  final String id;

  /// The channels that are going to be subscribed
  final List<String> channels;
}

/// A state indicating that the Realtime is going to close a specific
/// subscription
class UnSubscribingState implements RealtimeState {
  /// Create a ClosingState
  const UnSubscribingState({required this.id});

  /// The id of the subscription
  final String id;
}

/// {@template DisposingState}
/// A state indicating that the Realtime is disposing
/// {@endtemplate}
class DisposingState implements RealtimeState {
  ///  {@macro DisposingState}
  const DisposingState();
}

/// {@template ReconnectingState}
/// A state indicating that the Realtime is reconnecting
/// {@endtemplate}
class ReconnectingState implements RealtimeState {
  /// {@macro ReconnectingState}
  const ReconnectingState();
}

/// {@template ErrorState}
/// A state indicating that the Realtime has encountered an error
/// {@endtemplate}
class ErrorState implements RealtimeState {
  /// {@macro ErrorState}
  const ErrorState({
    required this.error,
    this.stackTrace,
  });

  /// The error that was encountered
  final Object error;

  /// The stack trace of the error
  final StackTrace? stackTrace;
}

/// {@template PingState}
/// A state indicating that the Realtime is pinging
/// {@endtemplate}
class PingState implements RealtimeState {
  /// {@macro PingState}
  const PingState();
}
