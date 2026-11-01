import 'package:flutter/foundation.dart';

const int kMaxStoredChats = 10;

class AppConfig {
  static const String _configuredHost =
      String.fromEnvironment('API_HOST', defaultValue: '');

  static String get apiHost {
    if (_configuredHost.isNotEmpty) {
      return _configuredHost;
    }

    if (kIsWeb) {
      return '127.0.0.1:5000';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return '10.0.2.2:5000';
      default:
        return '127.0.0.1:5000';
    }
  }

  static String get baseUrl => 'http://$apiHost';
}
