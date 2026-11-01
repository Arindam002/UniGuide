import 'package:flutter/foundation.dart';

class AppConfig {
  static const String _apiHost = String.fromEnvironment(
    'API_HOST',
    defaultValue: '',
  );

  static String get resolvedApiHost {
    if (_apiHost.isNotEmpty) {
      return _apiHost;
    }

    if (kIsWeb) {
      return '127.0.0.1:5000';
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return '10.0.2.2:5000';
    }

    return '127.0.0.1:5000';
  }

  static String get baseUrl => 'http://$resolvedApiHost';
}
