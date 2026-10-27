import 'package:firebase_remote_config/firebase_remote_config.dart';

class RemoteConfigManager {
  static final RemoteConfigManager _instance = RemoteConfigManager._internal();
  late final FirebaseRemoteConfig _remoteConfig;
  bool _initialized = false;

  factory RemoteConfigManager() => _instance;

  RemoteConfigManager._internal();

  Future<void> initialize() async {
    if (_initialized) return;

    _remoteConfig = FirebaseRemoteConfig.instance;

    await _remoteConfig.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: Duration(seconds: 10),
      minimumFetchInterval: Duration.zero, // Adjust as needed
    ));

    await _remoteConfig.fetchAndActivate();
    _initialized = true;
  }

  String getString(String key) {
    return _remoteConfig.getString(key);
  }
}
