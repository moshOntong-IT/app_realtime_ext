import 'package:app_realtime_ext/app_realtime_ext.dart';

/// Implemented in `realtime_browser.dart` and `realtime_io.dart`.
RealtimeBaseExt createRealtime() => throw UnsupportedError(
      'Cannot create a client without dart:html or dart:io.',
    );
