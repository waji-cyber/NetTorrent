// Unit tests for lib/models/download_task.dart and lib/models/app_settings.dart.
import 'package:flutter_test/flutter_test.dart';
import 'package:nettorrent/models/app_settings.dart';
import 'package:nettorrent/models/download_task.dart';

DownloadTask _sampleTask() => DownloadTask(
      id: 'task-1',
      type: TaskType.torrent,
      name: 'Example Linux ISO',
      source: 'magnet:?xt=urn:btih:abc123',
      saveDir: '/downloads',
      fileName: 'example.iso',
      status: TaskStatus.downloading,
      totalBytes: 1000,
      receivedBytes: 500,
      speedBps: 123.4, // transient: not persisted to JSON
      avgSpeedBps: 100.0,
      priority: TaskPriority.high,
      error: 'boom',
      retries: 2,
      createdAt: DateTime.utc(2026, 1, 1, 12),
      completedAt: null,
      infoHash: 'abc123',
      peers: 12, // transient: not persisted to JSON
      seeders: 3, // transient: not persisted to JSON
      uploadSpeedBps: 45.6, // transient: not persisted to JSON
    );

void main() {
  group('DownloadTask JSON round-trip', () {
    test('toJson -> fromJson preserves all persisted fields', () {
      final task = _sampleTask();
      final restored = DownloadTask.fromJson(task.toJson());

      expect(restored.id, task.id);
      expect(restored.type, task.type);
      expect(restored.name, task.name);
      expect(restored.source, task.source);
      expect(restored.saveDir, task.saveDir);
      expect(restored.fileName, task.fileName);
      expect(restored.status, task.status);
      expect(restored.totalBytes, task.totalBytes);
      expect(restored.receivedBytes, task.receivedBytes);
      expect(restored.avgSpeedBps, task.avgSpeedBps);
      expect(restored.priority, task.priority);
      expect(restored.error, task.error);
      expect(restored.retries, task.retries);
      expect(restored.createdAt, task.createdAt);
      expect(restored.completedAt, task.completedAt);
      expect(restored.infoHash, task.infoHash);
    });

    test('transient sampler fields reset after a round-trip', () {
      final restored = DownloadTask.fromJson(_sampleTask().toJson());
      expect(restored.speedBps, 0);
      expect(restored.peers, isNull);
      expect(restored.seeders, isNull);
      expect(restored.uploadSpeedBps, isNull);
    });
  });

  group('DownloadTask.copyWith', () {
    test('changes only the given fields', () {
      final task = _sampleTask();
      final updated = task.copyWith(
        status: TaskStatus.paused,
        receivedBytes: 750,
      );

      expect(updated.status, TaskStatus.paused);
      expect(updated.receivedBytes, 750);
      // Everything else is untouched.
      expect(updated.id, task.id);
      expect(updated.type, task.type);
      expect(updated.name, task.name);
      expect(updated.source, task.source);
      expect(updated.saveDir, task.saveDir);
      expect(updated.totalBytes, task.totalBytes);
      expect(updated.error, task.error);
      expect(updated.createdAt, task.createdAt);
    });

    test('clearError resets the error to null', () {
      final task = _sampleTask();
      expect(task.error, isNotNull);
      expect(task.copyWith(clearError: true).error, isNull);
    });
  });

  group('DownloadTask.progress', () {
    test('is null when the total size is unknown (totalBytes = -1)', () {
      final task = _sampleTask().copyWith(totalBytes: -1, receivedBytes: 500);
      expect(task.progress, isNull);
    });

    test('is 0.5 at half download', () {
      expect(_sampleTask().progress, 0.5);
    });

    test('is clamped to 0.0 - 1.0', () {
      final over = _sampleTask().copyWith(receivedBytes: 1500);
      expect(over.progress, 1.0);
    });
  });

  group('DownloadTask.isActive', () {
    test('true for queued and downloading', () {
      expect(
        _sampleTask().copyWith(status: TaskStatus.queued).isActive,
        isTrue,
      );
      expect(
        _sampleTask().copyWith(status: TaskStatus.downloading).isActive,
        isTrue,
      );
    });

    test('false for paused, completed and failed', () {
      expect(
        _sampleTask().copyWith(status: TaskStatus.paused).isActive,
        isFalse,
      );
      expect(
        _sampleTask().copyWith(status: TaskStatus.completed).isActive,
        isFalse,
      );
      expect(
        _sampleTask().copyWith(status: TaskStatus.failed).isActive,
        isFalse,
      );
    });
  });

  group('AppSettings.fromJson', () {
    test('empty map yields the documented defaults', () {
      final s = AppSettings.fromJson({});

      expect(s.downloadDir, isNull);
      expect(s.maxSimultaneous, 3);
      expect(s.maxDownloadSpeed, 0);
      expect(s.maxUploadSpeed, 0);
      expect(s.themeMode, AppThemeMode.dark);
      expect(s.notificationsEnabled, isTrue);
      expect(s.launchOnStartup, isFalse);
      expect(s.seedAfterComplete, isTrue);
      expect(s.seedRatioLimit, 1.5);
      expect(s.maxPeerConnections, 60);
      expect(s.autoRetry, isTrue);
      expect(s.maxRetryAttempts, 3);
      expect(s.confirmBeforeDelete, isTrue);
    });
  });

  group('AppSettings JSON round-trip', () {
    test('preserves custom values', () {
      const custom = AppSettings(
        downloadDir: '/tmp/dl',
        maxSimultaneous: 5,
        maxDownloadSpeed: 1024,
        maxUploadSpeed: 512,
        themeMode: AppThemeMode.light,
        notificationsEnabled: false,
        launchOnStartup: true,
        seedAfterComplete: false,
        seedRatioLimit: 2.0,
        maxPeerConnections: 100,
        autoRetry: false,
        maxRetryAttempts: 5,
        confirmBeforeDelete: false,
      );
      final restored = AppSettings.fromJson(custom.toJson());

      expect(restored.downloadDir, '/tmp/dl');
      expect(restored.maxSimultaneous, 5);
      expect(restored.maxDownloadSpeed, 1024);
      expect(restored.maxUploadSpeed, 512);
      expect(restored.themeMode, AppThemeMode.light);
      expect(restored.notificationsEnabled, isFalse);
      expect(restored.launchOnStartup, isTrue);
      expect(restored.seedAfterComplete, isFalse);
      expect(restored.seedRatioLimit, 2.0);
      expect(restored.maxPeerConnections, 100);
      expect(restored.autoRetry, isFalse);
      expect(restored.maxRetryAttempts, 5);
      expect(restored.confirmBeforeDelete, isFalse);
    });
  });

  group('AppSettings.copyWith', () {
    test('clearDownloadDir resets the download folder to null', () {
      const custom = AppSettings(downloadDir: '/tmp/dl', maxSimultaneous: 5);
      final cleared = custom.copyWith(clearDownloadDir: true);

      expect(cleared.downloadDir, isNull);
      // Other fields are preserved.
      expect(cleared.maxSimultaneous, 5);
    });

    test('sets a new download directory', () {
      const s = AppSettings();
      expect(s.copyWith(downloadDir: '/x').downloadDir, '/x');
    });
  });
}
