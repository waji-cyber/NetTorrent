import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_providers.dart';
import '../../models/app_settings.dart';
import '../../services/bridge_server.dart';
import '../../services/download_manager.dart';
import '../../services/settings_service.dart';
import '../widgets/dialogs.dart';

/// Editable [AppSettings]. Changes persist via [SettingsService.update].
///
/// The service is a plain Provider (not a notifier), so this page rebuilds
/// itself with setState after each update.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _downSpeedCtrl = TextEditingController();
  final _upSpeedCtrl = TextEditingController();
  bool _speedFieldsInit = false;

  @override
  void dispose() {
    _downSpeedCtrl.dispose();
    _upSpeedCtrl.dispose();
    super.dispose();
  }

  SettingsService get _service => ref.read(settingsServiceProvider);

  Future<void> _update(AppSettings next) async {
    await _service.update(next);
    if (mounted) setState(() {});
  }

  /// Seed the KB/s fields once from the persisted byte values.
  void _initSpeedFields(AppSettings s) {
    if (_speedFieldsInit) return;
    _speedFieldsInit = true;
    _downSpeedCtrl.text = (s.maxDownloadSpeed ~/ 1024).toString();
    _upSpeedCtrl.text = (s.maxUploadSpeed ~/ 1024).toString();
  }

  @override
  Widget build(BuildContext context) {
    final settings = _service.settings;
    _initSpeedFields(settings);
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _section('General'),
        _downloadDirTile(settings),
        _sliderTile(
          title: 'Max simultaneous downloads',
          value: settings.maxSimultaneous.toDouble(),
          min: 1,
          max: 10,
          divisions: 9,
          label: '${settings.maxSimultaneous}',
          onChanged: (v) =>
              _update(settings.copyWith(maxSimultaneous: v.round())),
        ),
        _speedField(
          label: 'Max download speed (KB/s)',
          hint: '0 = unlimited',
          controller: _downSpeedCtrl,
          onApply: (kb) =>
              _update(settings.copyWith(maxDownloadSpeed: kb * 1024)),
        ),
        _speedField(
          label: 'Max upload speed (KB/s)',
          hint: '0 = unlimited',
          controller: _upSpeedCtrl,
          onApply: (kb) =>
              _update(settings.copyWith(maxUploadSpeed: kb * 1024)),
        ),
        _themeTile(settings),
        SwitchListTile(
          title: const Text('Notifications'),
          subtitle:
              const Text('Notify when downloads complete or fail'),
          value: settings.notificationsEnabled,
          onChanged: (v) =>
              _update(settings.copyWith(notificationsEnabled: v)),
        ),
        SwitchListTile(
          title: const Text('Launch on startup'),
          subtitle:
              const Text('Start NetTorrent with Windows (where supported)'),
          value: settings.launchOnStartup,
          onChanged: (v) =>
              _update(settings.copyWith(launchOnStartup: v)),
        ),
        _section('Torrents'),
        SwitchListTile(
          title: const Text('Seed after complete'),
          subtitle: const Text('Keep uploading finished torrents to peers'),
          value: settings.seedAfterComplete,
          onChanged: (v) =>
              _update(settings.copyWith(seedAfterComplete: v)),
        ),
        _sliderTile(
          title: 'Seed ratio limit',
          value: settings.seedRatioLimit,
          min: 0,
          max: 3,
          divisions: 6,
          label: '${settings.seedRatioLimit.toStringAsFixed(1)}×',
          onChanged: (v) => _update(settings.copyWith(
            seedRatioLimit: double.parse(v.toStringAsFixed(1)),
          ),),
        ),
        _sliderTile(
          title: 'Max peer connections',
          value: settings.maxPeerConnections.toDouble(),
          min: 10,
          max: 200,
          divisions: 19,
          label: '${settings.maxPeerConnections}',
          onChanged: (v) => _update(
              settings.copyWith(maxPeerConnections: v.round()),),
        ),
        _section('Retries & deletion'),
        SwitchListTile(
          title: const Text('Auto-retry failed downloads'),
          subtitle: const Text('Retry with increasing delays'),
          value: settings.autoRetry,
          onChanged: (v) => _update(settings.copyWith(autoRetry: v)),
        ),
        _sliderTile(
          title: 'Max retry attempts',
          value: settings.maxRetryAttempts.toDouble(),
          min: 0,
          max: 10,
          divisions: 10,
          label: '${settings.maxRetryAttempts}',
          onChanged: (v) =>
              _update(settings.copyWith(maxRetryAttempts: v.round())),
        ),
        SwitchListTile(
          title: const Text('Confirm before deleting'),
          subtitle: const Text('Ask before removing downloads'),
          value: settings.confirmBeforeDelete,
          onChanged: (v) =>
              _update(settings.copyWith(confirmBeforeDelete: v)),
        ),
        _section('Browser extension bridge'),
        _bridgeTile(theme),
        _section('Danger zone'),
        Card(
          child: ListTile(
            leading: Icon(Icons.restart_alt, color: theme.colorScheme.error),
            title: const Text('Reset to defaults'),
            subtitle: const Text('Restore all settings to factory values'),
            onTap: _reset,
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------ sections

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _sliderTile({
    required String title,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String label,
    required ValueChanged<double> onChanged,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            Slider(
              value: value.clamp(min, max).toDouble(),
              min: min,
              max: max,
              divisions: divisions,
              label: label,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget _speedField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required void Function(int kb) onApply,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (raw) {
          final kb = int.tryParse(raw.trim());
          if (kb == null || kb < 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Enter a non-negative number (KB/s).'),
              ),
            );
            return;
          }
          onApply(kb);
        },
      ),
    );
  }

  // ---------------------------------------------------------- download dir

  Widget _downloadDirTile(AppSettings settings) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.folder),
        title: const Text('Download folder'),
        subtitle: Text(
          settings.downloadDir ?? 'Default (system download folder)',
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Wrap(
          spacing: 8,
          children: [
            if (settings.downloadDir != null)
              TextButton(
                onPressed: () =>
                    _update(settings.copyWith(clearDownloadDir: true)),
                child: const Text('Default'),
              ),
            FilledButton.tonal(
              onPressed: _pickDir,
              child: const Text('Choose'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDir() async {
    final path = await FilePicker.platform.getDirectoryPath();
    if (path == null) return; // user cancelled
    await _update(_service.settings.copyWith(downloadDir: path));
  }

  // ----------------------------------------------------------------- theme

  Widget _themeTile(AppSettings settings) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Theme', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            SegmentedButton<AppThemeMode>(
              segments: const [
                ButtonSegment(
                  value: AppThemeMode.system,
                  icon: Icon(Icons.settings_suggest),
                  label: Text('System'),
                ),
                ButtonSegment(
                  value: AppThemeMode.dark,
                  icon: Icon(Icons.dark_mode),
                  label: Text('Dark'),
                ),
                ButtonSegment(
                  value: AppThemeMode.light,
                  icon: Icon(Icons.light_mode),
                  label: Text('Light'),
                ),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (sel) => _setTheme(sel.first),
            ),
          ],
        ),
      ),
    );
  }

  /// Persists the theme choice and flips the app-wide [ThemeMode] so the
  /// change applies immediately.
  Future<void> _setTheme(AppThemeMode mode) async {
    await _update(_service.settings.copyWith(themeMode: mode));
    ref.read(appThemeModeProvider.notifier).state = switch (mode) {
      AppThemeMode.dark => ThemeMode.dark,
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.system => ThemeMode.system,
    };
  }

  // ---------------------------------------------------------------- bridge

  Widget _bridgeTile(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Extension pairing token',
                style: theme.textTheme.titleSmall,),
            const SizedBox(height: 4),
            Text(
              'Paste this token into the NetTorrent browser extension once '
              'to pair it. The bridge only listens on this device.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            FutureBuilder<String>(
              future: ref.read(bridgeServerProvider).getToken(),
              builder: (context, snapshot) {
                final token = snapshot.data;
                if (token == null) {
                  return const LinearProgressIndicator();
                }
                return Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        token,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copy token',
                      icon: const Icon(Icons.copy),
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: token),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Bridge token copied to clipboard'),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------------- reset

  Future<void> _reset() async {
    final ok = await confirmDialog(
      context,
      title: 'Reset settings?',
      message: 'All settings will return to their default values.',
      confirmLabel: 'Reset',
      destructive: true,
    );
    if (!ok) return;
    await _service.reset();
    _speedFieldsInit = false; // re-seed the KB/s fields from defaults
    // The default themeMode is dark — keep the app theme in sync.
    ref.read(appThemeModeProvider.notifier).state = ThemeMode.dark;
    if (mounted) setState(() {});
  }
}
