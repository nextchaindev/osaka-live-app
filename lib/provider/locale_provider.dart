import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:osaka_app/config/env_config.dart';
import 'package:osaka_app/services/cookies/cookies_services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider extends ChangeNotifier with WidgetsBindingObserver {
  LocaleProvider._(
      this._preferences, this._selectedLocale, this._effectiveLocale);

  static const _selectedLocaleKey = 'selectedLocale';
  static const _supported = {'ko', 'en', 'ja'};

  final SharedPreferences _preferences;
  String? _selectedLocale;
  String _effectiveLocale;

  String? get selectedLocale => _selectedLocale;
  String get effectiveLocale => _effectiveLocale;
  String get localeSource => _selectedLocale == null ? 'device' : 'user';
  Locale get locale => Locale(_effectiveLocale);

  static String normalize(String? rawLocale) {
    final language = rawLocale?.split(RegExp('[-_]')).first.toLowerCase();
    return language != null && _supported.contains(language) ? language : 'en';
  }

  static String resolveEffectiveLocale({
    required String? selectedLocale,
    required String deviceLocale,
  }) {
    if (selectedLocale != null && _supported.contains(selectedLocale)) {
      return selectedLocale;
    }
    return normalize(deviceLocale);
  }

  static Future<LocaleProvider> initialize() async {
    return _initialize(writeCookies: true);
  }

  static Future<LocaleProvider> initializeFallback() async {
    return _initialize(writeCookies: false);
  }

  static Future<LocaleProvider> _initialize(
      {required bool writeCookies}) async {
    final preferences = await SharedPreferences.getInstance();
    String? selected = preferences.getString(_selectedLocaleKey);
    if (selected != null && !_supported.contains(selected)) {
      selected = null;
      await preferences.remove(_selectedLocaleKey);
    }

    // Migrate a locale cookie written by an older app as an explicit choice.
    if (selected == null) {
      try {
        final cookieManager = CookieManager.instance();
        final url = WebUri.uri(Uri.parse(EnvConfig.instance.webviewUrl));
        final localeCookie = await cookieManager.getCookie(
          url: url,
          name: 'locale',
        );
        final sourceCookie = await cookieManager.getCookie(
          url: url,
          name: 'locale_source',
        );
        final legacyLocale = localeCookie?.value?.toString();
        final localeSource = sourceCookie?.value?.toString();
        final isExplicitSelection =
            localeSource == null || localeSource == 'user';
        if (isExplicitSelection &&
            legacyLocale != null &&
            _supported.contains(legacyLocale)) {
          selected = legacyLocale;
          await preferences.setString(_selectedLocaleKey, selected);
        }
      } catch (_) {
        // A missing cookie store is expected on a fresh install.
      }
    }

    final deviceLocale = normalize(
        WidgetsBinding.instance.platformDispatcher.locale.toLanguageTag());
    final provider = LocaleProvider._(
      preferences,
      selected,
      resolveEffectiveLocale(
        selectedLocale: selected,
        deviceLocale: deviceLocale,
      ),
    );
    if (writeCookies) {
      await writeLocaleCookies(
        webViewUrl: EnvConfig.instance.webviewUrl,
        locale: provider.effectiveLocale,
        source: provider.localeSource,
      );
    }
    WidgetsBinding.instance.addObserver(provider);
    return provider;
  }

  Future<void> setUserLocale(String locale) async {
    if (!_supported.contains(locale)) return;
    await _preferences.setString(_selectedLocaleKey, locale);
    _selectedLocale = locale;
    _effectiveLocale = locale;
    await writeLocaleCookies(
      webViewUrl: EnvConfig.instance.webviewUrl,
      locale: locale,
      source: 'user',
    );
    notifyListeners();
  }

  Future<void> applyDeviceLocale(String locale) async {
    if (_selectedLocale != null) return;
    final normalized = normalize(locale);
    if (_effectiveLocale == normalized) return;
    _effectiveLocale = normalized;
    await writeLocaleCookies(
      webViewUrl: EnvConfig.instance.webviewUrl,
      locale: normalized,
      source: 'device',
    );
    notifyListeners();
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    if (_selectedLocale == null && locales != null && locales.isNotEmpty) {
      unawaited(applyDeviceLocale(locales.first.toLanguageTag()));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
