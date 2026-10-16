// Unit tests for lib/core/utils.dart — pure helpers, no Flutter bindings needed.
import 'package:flutter_test/flutter_test.dart';
import 'package:nettorrent/core/utils.dart';

void main() {
  group('isValidDownloadUrl', () {
    test('accepts http and https URLs with a host', () {
      expect(isValidDownloadUrl('https://example.com/file.zip'), isTrue);
      expect(isValidDownloadUrl('http://example.com'), isTrue);
      expect(
        isValidDownloadUrl('  https://cdn.example.org/a/b.iso?x=1  '),
        isTrue,
      );
    });

    test('rejects empty input', () {
      expect(isValidDownloadUrl(''), isFalse);
      expect(isValidDownloadUrl('   '), isFalse);
    });

    test('rejects non-http schemes (ftp, magnet)', () {
      expect(isValidDownloadUrl('ftp://example.com/f.iso'), isFalse);
      expect(isValidDownloadUrl('magnet:?xt=urn:btih:abc123'), isFalse);
      expect(isValidDownloadUrl('file:///C:/tmp/a.zip'), isFalse);
    });

    test('rejects URLs without a host and unparsable input', () {
      expect(isValidDownloadUrl('https:///no-host-here'), isFalse);
      expect(isValidDownloadUrl('notaurl'), isFalse);
      expect(isValidDownloadUrl('https://'), isFalse);
    });
  });

  group('isValidMagnetUri', () {
    test('accepts magnet links carrying xt=urn:btih:', () {
      expect(
        isValidMagnetUri(
          'magnet:?xt=urn:btih:dd8255ecdc7ca55fb0bbf81323d87062db1f6d1c'
          '&dn=Example',
        ),
        isTrue,
      );
      // Matching is case-insensitive.
      expect(isValidMagnetUri('MAGNET:?XT=URN:BTIH:ABCDEF1234'), isTrue);
    });

    test('rejects plain URLs and magnets without an info hash', () {
      expect(isValidMagnetUri('https://example.com/file.torrent'), isFalse);
      expect(isValidMagnetUri('magnet:?dn=just-a-name'), isFalse);
      expect(isValidMagnetUri(''), isFalse);
    });
  });

  group('sanitizeFileName', () {
    test('strips directory components (defeats ../ traversal)', () {
      expect(sanitizeFileName('../../etc/passwd'), 'passwd');
      expect(sanitizeFileName(r'C:\Users\x\evil.exe'), 'evil.exe');
      expect(sanitizeFileName('a/b/c.zip'), 'c.zip');
    });

    test('replaces characters illegal on Windows', () {
      expect(sanitizeFileName('my<file>:name?.txt'), 'my_file__name_.txt');
      expect(sanitizeFileName('a|b*c"d'), 'a_b_c_d');
    });

    test('trims trailing dots and whitespace', () {
      expect(sanitizeFileName('report...'), 'report');
      expect(sanitizeFileName('notes. . '), 'notes');
    });

    test('falls back when nothing usable remains', () {
      expect(sanitizeFileName(''), 'download');
      expect(sanitizeFileName('...'), 'download');
      expect(sanitizeFileName('...', fallback: 'file'), 'file');
    });

    test('truncates names longer than 200 characters', () {
      final long = List.filled(300, 'a').join();
      expect(sanitizeFileName(long).length, 200);
    });
  });

  group('fileNameFromUrl', () {
    test('extracts the last path segment and ignores the query string', () {
      expect(
        fileNameFromUrl('https://example.com/files/archive.zip?token=abc&x=1'),
        'archive.zip',
      );
    });

    test('decodes percent-encoding', () {
      expect(
        fileNameFromUrl('https://example.com/files/my%20file.zip'),
        'my file.zip',
      );
    });

    test('falls back when the URL has no usable path', () {
      expect(fileNameFromUrl('https://example.com'), 'download');
      expect(fileNameFromUrl('https://example.com/downloads/'), 'downloads');
    });
  });

  group('formatBytes', () {
    test('formats common sizes', () {
      expect(formatBytes(0), '0.0 B');
      expect(formatBytes(1023), '1023 B');
      expect(formatBytes(1024), '1.0 KB');
      expect(formatBytes(1536), '1.5 KB');
      expect(formatBytes(1572864), '1.5 MB');
      expect(formatBytes(1073741824), '1.0 GB');
    });

    test('returns an em dash for negative input', () {
      expect(formatBytes(-5), '—');
    });
  });

  group('formatEta', () {
    test('formats seconds, minutes and hours', () {
      expect(formatEta(45), '45s');
      expect(formatEta(90), '1m 30s');
      expect(formatEta(3600), '1h 0m');
    });

    test('returns an em dash when unknown', () {
      expect(formatEta(null), '—');
      expect(formatEta(-1), '—');
    });
  });

  group('etaSeconds', () {
    test('divides remaining bytes by speed', () {
      expect(etaSeconds(1000, 100), 10.0);
    });

    test('returns null when speed is zero or negative', () {
      expect(etaSeconds(1000, 0), isNull);
      expect(etaSeconds(1000, -5), isNull);
    });

    test('returns zero when nothing remains', () {
      expect(etaSeconds(0, 100), 0);
    });
  });
}
