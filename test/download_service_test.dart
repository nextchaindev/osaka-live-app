import 'package:flutter_test/flutter_test.dart';
import 'package:osaka_app/services/rest_api/download_service.dart';

void main() {
  group('sanitizeDownloadFileName', () {
    test('keeps a normal filename', () {
      expect(sanitizeDownloadFileName('statement.pdf'), 'statement.pdf');
    });

    test('removes directory components from an untrusted filename', () {
      expect(
        sanitizeDownloadFileName('../../private/statement.pdf'),
        'statement.pdf',
      );
    });

    test('replaces forbidden filename characters', () {
      expect(
        sanitizeDownloadFileName('report<>:"|?*.pdf'),
        'report_______.pdf',
      );
    });

    test('uses the fallback for an empty or dot filename', () {
      expect(sanitizeDownloadFileName('..'), 'download');
      expect(sanitizeDownloadFileName('  '), 'download');
    });
  });
}
