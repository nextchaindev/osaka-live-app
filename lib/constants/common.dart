import 'package:osaka_app/config/env_config.dart';

const appName = "Osaka Live";

// Get localized app name based on locale
String getLocalizedAppName(String? languageCode) {
  final env = EnvConfig.instance;
  if (languageCode == 'ko') {
    return "Osaka Live ${env.env != "PROD" ? "(${env.env})" : ""}";
  }
  return "$appName ${env.env != "PROD" ? "(${env.env})" : ""}";
}

const bool testEnviroment = false;

const bool hideHeader = false;
const bool hideFooter = false;

const String iconPath = 'assets/icons/';

const bool isStoragePermissionEnabled = false;

const String androidForceUpdateVerion = 'android_force_update_version';
const String iOSForceUpdateVerion = 'ios_force_update_version';
const String androidLastestLiveVersion = 'android_latest_live_version';
const String iOSLastestLiveVersion = 'ios_latest_live_version';

const List<String> routeNoSafeArea = ['/sessions/', '/introduce'];
const List<String> routeNoBottomSafeArea = ['/introduce'];
