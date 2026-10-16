import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import '../core/constants.dart';

/// Why an HTTP download failed.
enum HttpFailure {
  network,
  httpError,
  fileSystem,
  cancelled,
  unknown,
}

/// Typed failure for HTTP downloads with a human-readable message.
class HttpDownloadException implements Exception {
  final HttpFailure kind;
  final String message;
  final int? statusCode;

  const HttpDownloadException(this.kind, this.message, [this.statusCode]);

  @override
  String toString() => 'HttpDownloadException($kind): $message';
}

/// Progress snapshot emitted while streaming.
class HttpProgress {
  /// Bytes written so far in this session (includes resumed bytes).
  final int receivedBytes;

  /// Total file size, or -1 when the server did not advertise it.
  final int totalBytes;

  const HttpProgress(this.receivedBytes, this.totalBytes);
}

/// Performs real HTTP/HTTPS downloads with resume support.
///
/// Strategy:
/// 1. `HEAD` (falling back to a ranged `GET`) to learn the total size and
///    whether the server honours `Range` requests.
/// 2. Stream the body with `dio` (`ResponseType.stream`) and append to the
///    destination file, so pause/resume is a matter of re-issuing the
///    request with `Range: bytes=<already-have>-`.
/// 3. An optional token-bucket limiter caps throughput when the user sets a
///    maximum download speed.
class HttpDownloadEngine {
  final Dio _dio;

  HttpDownloadEngine({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: kHttpConnectTimeout,
                receiveTimeout: kHttpReceiveTimeout,
                followRedirects: true,
                maxRedirects: 5,
                headers: {
                  'User-Agent': 'NetTorrent/$kAppVersion (Computer Networks project)',
                },
              ),
            );

  /// Returns the advertised content length, or null when unknown.
  Future<int?> probeContentLength(String url) async {
    try {
      final head = await _dio.head(url);
      final length = head.headers.value(HttpHeaders.contentLengthHeader);
      final parsed = int.tryParse(length ?? '');
      if (parsed != null) return parsed;
    } on DioException {
      // Some servers reject HEAD; fall through to a ranged GET probe.
    }
    try {
      final res = await _dio.get(
        url,
        options: Options(
          responseType: ResponseType.stream,
          headers: {'Range': 'bytes=0-0'},
        ),
      );
      final body = res.data as ResponseBody;
      await body.stream.drain();
      final range = res.headers.value(HttpHeaders.contentRangeHeader);
      // "bytes 0-0/12345" -> 12345
      final total = range?.split('/').last;
      return int.tryParse(total ?? '');
    } on DioException {
      return null;
    }
  }

  /// Downloads [url] to [savePath], resuming from [startByte] when possible.
  ///
  /// Calls [onProgress] as bytes arrive. Throws [HttpDownloadException].
  /// Pass a [CancelToken] to support pause/cancel.
  Future<void> download({
    required String url,
    required String savePath,
    int startByte = 0,
    int maxBytesPerSecond = 0,
    required void Function(HttpProgress progress) onProgress,
    CancelToken? cancelToken,
  }) async {
    final file = File(savePath);
    await file.parent.create(recursive: true);

    int written = startByte;
    int total = -1;
    bool resumeSupported = startByte > 0;

    Response<ResponseBody> res;
    try {
      res = await _dio.get<ResponseBody>(
        url,
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.stream,
          headers: startByte > 0 ? {'Range': 'bytes=$startByte-'} : null,
        ),
      );
    } on DioException catch (e) {
      throw _mapDioError(e);
    }

    if (res.statusCode == 206) {
      // Server honoured our Range request: parse "bytes 100-199/1000".
      final range = res.headers.value(HttpHeaders.contentRangeHeader);
      final totalPart = range?.split('/').last;
      final parsed = int.tryParse(totalPart ?? '');
      if (parsed != null) total = parsed;
    } else if (res.statusCode == 200) {
      // Server ignored Range: restart from scratch to avoid corruption.
      resumeSupported = false;
      written = 0;
      final length = res.headers.value(HttpHeaders.contentLengthHeader);
      total = int.tryParse(length ?? '') ?? -1;
    } else {
      throw HttpDownloadException(
        HttpFailure.httpError,
        'Server returned HTTP ${res.statusCode}',
        res.statusCode,
      );
    }

    final sink = await file.open(
      mode: resumeSupported ? FileMode.append : FileMode.write,
    );
    final limiter = maxBytesPerSecond > 0
        ? _TokenBucket(maxBytesPerSecond.toDouble())
        : null;

    try {
      await for (final chunk in res.data!.stream) {
        if (cancelToken?.isCancelled ?? false) {
          throw const HttpDownloadException(
            HttpFailure.cancelled,
            'Download cancelled',
          );
        }
        if (limiter != null) await limiter.consume(chunk.length);
        await sink.writeFrom(chunk);
        written += chunk.length;
        onProgress(HttpProgress(written, total));
      }
      await sink.flush();
    } on HttpDownloadException {
      rethrow;
    } catch (e) {
      if (e is DioException) throw _mapDioError(e);
      throw HttpDownloadException(
        HttpFailure.fileSystem,
        'Failed writing to disk: $e',
      );
    } finally {
      await sink.close();
    }
  }

  HttpDownloadException _mapDioError(DioException e) {
    if (e.type == DioExceptionType.cancel) {
      return const HttpDownloadException(
        HttpFailure.cancelled,
        'Download cancelled',
      );
    }
    final code = e.response?.statusCode;
    if (code != null) {
      return HttpDownloadException(
        HttpFailure.httpError,
        'Server returned HTTP $code',
        code,
      );
    }
    if (e.error is SocketException || e.error is HttpException) {
      return HttpDownloadException(
        HttpFailure.network,
        'Network error: ${e.message}',
      );
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return const HttpDownloadException(
        HttpFailure.network,
        'Connection timed out. Check your network and retry.',
      );
    }
    return HttpDownloadException(
      HttpFailure.unknown,
      'Download failed: ${e.message}',
    );
  }
}

/// Simple token-bucket rate limiter used for the download speed cap.
class _TokenBucket {
  final double ratePerSecond;
  double _tokens;
  DateTime _lastRefill;

  _TokenBucket(this.ratePerSecond)
      : _tokens = ratePerSecond,
        _lastRefill = DateTime.now();

  Future<void> consume(int bytes) async {
    var remaining = bytes.toDouble();
    while (remaining > 0) {
      final now = DateTime.now();
      final elapsed = now.difference(_lastRefill).inMicroseconds / 1e6;
      _lastRefill = now;
      _tokens = (_tokens + elapsed * ratePerSecond)
          .clamp(0, ratePerSecond)
          .toDouble();
      if (_tokens >= remaining) {
        _tokens -= remaining;
        return;
      }
      remaining -= _tokens;
      _tokens = 0;
      final waitMs = (remaining / ratePerSecond * 1000).ceil().clamp(1, 1000);
      await Future.delayed(Duration(milliseconds: waitMs));
    }
  }
}
