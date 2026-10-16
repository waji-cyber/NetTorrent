/// Pure helper functions: URL validation, filename sanitising, formatting.
///
/// These are intentionally dependency-free so they can be unit tested with
/// `flutter test` on any machine.
library;

/// Returns true when [input] is a plausible direct-download URL.
///
/// Accepts http/https URLs that parse and carry a host. Magnet links and
/// local file paths are intentionally rejected here; they have their own
/// validators.
bool isValidDownloadUrl(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return false;
  final uri = Uri.tryParse(trimmed);
  if (uri == null) return false;
  if (uri.scheme != 'http' && uri.scheme != 'https') return false;
  if (uri.host.isEmpty) return false;
  return true;
}

/// Returns true when [input] looks like a magnet link with an info hash.
bool isValidMagnetUri(String input) {
  final trimmed = input.trim().toLowerCase();
  if (!trimmed.startsWith('magnet:?')) return false;
  // BEP-9 magnet links carry xt=urn:btih:<infohash>.
  return trimmed.contains('xt=urn:btih:');
}

/// Sanitises a file name so it is safe to join onto the download directory.
///
/// - Strips directory components (defeats `../` path traversal).
/// - Replaces characters illegal on Windows (`<>:"/\|?*` and control chars).
/// - Trims trailing dots/spaces (illegal on Windows).
/// - Falls back to [fallback] when nothing usable remains.
String sanitizeFileName(String raw, {String fallback = 'download'}) {
  // Drop any directory components first: "a/../b" -> "b".
  var name = raw.split(RegExp(r'[\\/]')).last;
  // Replace illegal characters and control chars.
  name = name.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_');
  // Windows dislikes trailing dots and spaces.
  name = name.replaceAll(RegExp(r'[.\s]+$'), '');
  name = name.trim();
  if (name.isEmpty) return fallback;
  // Keep file names within a sane length.
  if (name.length > 200) {
    final dot = name.lastIndexOf('.');
    if (dot > 0 && name.length - dot < 20) {
      name = '${name.substring(0, 200 - (name.length - dot))}${name.substring(dot)}';
    } else {
      name = name.substring(0, 200);
    }
  }
  return name;
}

/// Guesses a file name from a URL's path, e.g. ".../file.zip?x=1" -> "file.zip".
String fileNameFromUrl(String url, {String fallback = 'download'}) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return fallback;
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments.isEmpty) return fallback;
  return sanitizeFileName(Uri.decodeComponent(segments.last), fallback: fallback);
}

/// Formats a byte count, e.g. 1536 -> "1.5 KB".
String formatBytes(int bytes) {
  if (bytes < 0) return '—';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  double value = bytes.toDouble();
  int unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final text = value >= 100 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  return '$text ${units[unit]}';
}

/// Formats a throughput, e.g. 1536 -> "1.5 KB/s".
String formatSpeed(double bytesPerSecond) {
  if (bytesPerSecond <= 0) return '0 B/s';
  return '${formatBytes(bytesPerSecond.round())}/s';
}

/// Formats an ETA in seconds, e.g. 90 -> "1m 30s". Returns "—" when unknown.
String formatEta(double? seconds) {
  if (seconds == null || !seconds.isFinite || seconds < 0) return '—';
  final total = seconds.round();
  if (total < 60) return '${total}s';
  final minutes = total ~/ 60;
  if (minutes < 60) return '${minutes}m ${total % 60}s';
  final hours = minutes ~/ 60;
  return '${hours}h ${minutes % 60}m';
}

/// ETA in seconds given remaining bytes and current speed, or null if unknown.
double? etaSeconds(int remainingBytes, double speedBps) {
  if (remainingBytes <= 0) return 0;
  if (speedBps <= 0) return null;
  return remainingBytes / speedBps;
}
