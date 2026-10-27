import 'package:flutter_test/flutter_test.dart';
import 'package:osaka_app/provider/locale_provider.dart';

void main() {
  group('LocaleProvider.normalize', () {
    test('normalizes supported language tags', () {
      expect(LocaleProvider.normalize('ko-KR'), 'ko');
      expect(LocaleProvider.normalize('ja-JP'), 'ja');
      expect(LocaleProvider.normalize('en-US'), 'en');
    });

    test('uses English for unsupported device locales', () {
      expect(LocaleProvider.normalize('fr-FR'), 'en');
      expect(LocaleProvider.normalize(null), 'en');
    });
  });

  test('a saved selection takes precedence over the device locale', () {
    expect(
      LocaleProvider.resolveEffectiveLocale(
        selectedLocale: 'ja',
        deviceLocale: 'ko-KR',
      ),
      'ja',
    );
    expect(
      LocaleProvider.resolveEffectiveLocale(
        selectedLocale: null,
        deviceLocale: 'ko-KR',
      ),
      'ko',
    );
  });
}
