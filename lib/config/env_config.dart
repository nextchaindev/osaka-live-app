import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  EnvConfig._internal();
  static final EnvConfig instance = EnvConfig._internal();

  bool _initialized = false;

  factory EnvConfig() {
    return instance;
  }

  static Future<void> initialize(String environment) async {
    if (instance._initialized) return;
    print('environment 2 => $environment');
    await dotenv.load(fileName: 'lib/config/.env.$environment');
    instance._initialized = true;
  }

  String get env => dotenv.env['ENVIRONMENT'] ?? '';
  String get webviewUrl => dotenv.env['WEBVIEW_URL'] ?? '';
  String get baseUrl => dotenv.env['BASE_URL'] ?? '';
  String get apiKey => dotenv.env['API_KEY'] ?? '';
  String get appScheme => dotenv.env['APP_SCHEME'] ?? '';
  String get googleServerClientId =>
      dotenv.env['GOOGLE_SERVER_CLIENT_ID'] ?? '';
  String get googleIosClientId => dotenv.env['GOOGLE_IOS_CLIENT_ID'] ?? '';

  /// Get config value by key
  String getValue(String key, {String defaultValue = ''}) {
    return dotenv.env[key] ?? defaultValue;
  }
}
