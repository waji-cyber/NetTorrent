import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils.dart';
import '../../services/download_manager.dart';

/// Add a new download: direct URL, .torrent file, or magnet link.
///
/// After a successful add the user is taken to the All Downloads page
/// (navigation index 1).
class AddDownloadPage extends ConsumerStatefulWidget {
  const AddDownloadPage({super.key});

  @override
  ConsumerState<AddDownloadPage> createState() => _AddDownloadPageState();
}

class _AddDownloadPageState extends ConsumerState<AddDownloadPage> {
  int _tab = 0; // 0 = URL, 1 = .torrent file, 2 = magnet
  final _urlCtrl = TextEditingController();
  final _magnetCtrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _urlCtrl.dispose();
    _magnetCtrl.dispose();
    super.dispose();
  }

  bool get _urlValid => isValidDownloadUrl(_urlCtrl.text);
  bool get _magnetValid => isValidMagnetUri(_magnetCtrl.text);

  void _goToAll() {
    // Clear any stale search text so the newly added download is visible.
    ref.read(searchQueryProvider.notifier).state = '';
    ref.read(navIndexProvider.notifier).state = 1;
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _addUrl() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(downloadManagerProvider.notifier)
          .addHttpDownload(_urlCtrl.text.trim());
      if (!mounted) return;
      _urlCtrl.clear();
      _goToAll();
    } catch (e) {
      if (!mounted) return;
      _snack('Could not add download: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addTorrentFile() async {
    setState(() => _busy = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['torrent'],
      );
      final path = result?.files.single.path;
      if (path == null) return; // user cancelled the picker
      await ref
          .read(downloadManagerProvider.notifier)
          .addTorrentFile(path);
      if (!mounted) return;
      _goToAll();
    } catch (e) {
      if (!mounted) return;
      _snack('Could not add torrent: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addMagnet() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(downloadManagerProvider.notifier)
          .addMagnet(_magnetCtrl.text.trim());
      if (!mounted) return;
      _magnetCtrl.clear();
      _goToAll();
    } catch (e) {
      if (!mounted) return;
      _snack('Could not add magnet link: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                value: 0,
                icon: Icon(Icons.link),
                label: Text('URL'),
              ),
              ButtonSegment(
                value: 1,
                icon: Icon(Icons.file_open),
                label: Text('Torrent file'),
              ),
              ButtonSegment(
                value: 2,
                icon: Icon(Icons.link),
                label: Text('Magnet'),
              ),
            ],
            selected: {_tab},
            onSelectionChanged: (s) => setState(() => _tab = s.first),
          ),
          const SizedBox(height: 24),
          if (_tab == 0) _urlForm(theme),
          if (_tab == 1) _torrentFileForm(theme),
          if (_tab == 2) _magnetForm(theme),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- URL form

  Widget _urlForm(ThemeData theme) {
    final showError = _urlCtrl.text.isNotEmpty && !_urlValid;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _urlCtrl,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) {
            if (_urlValid && !_busy) _addUrl();
          },
          decoration: InputDecoration(
            labelText: 'Download URL',
            hintText: 'https://example.com/file.zip',
            prefixIcon: const Icon(Icons.link),
            border: const OutlineInputBorder(),
            errorText: showError ? 'Enter a valid http(s) URL' : null,
            suffixIcon: _urlCtrl.text.isEmpty
                ? null
                : Icon(
                    _urlValid ? Icons.check_circle : Icons.error,
                    color: _urlValid
                        ? theme.colorScheme.primary
                        : theme.colorScheme.error,
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Direct http/https links only. Downloads resume automatically '
          'when the server supports Range requests.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add),
          label: const Text('Add download'),
          onPressed: (_urlValid && !_busy) ? _addUrl : null,
        ),
      ],
    );
  }

  // ------------------------------------------------------ torrent file form

  Widget _torrentFileForm(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Pick a .torrent file from your device. Its metadata is validated '
          'before the download is queued.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.file_open),
          label: const Text('Choose .torrent file'),
          onPressed: _busy ? null : _addTorrentFile,
        ),
      ],
    );
  }

  // ----------------------------------------------------------- magnet form

  Widget _magnetForm(ThemeData theme) {
    final showError = _magnetCtrl.text.isNotEmpty && !_magnetValid;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _magnetCtrl,
          maxLines: 3,
          minLines: 2,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'Magnet link',
            hintText: 'magnet:?xt=urn:btih:…',
            prefixIcon: const Icon(Icons.link),
            border: const OutlineInputBorder(),
            errorText:
                showError ? 'Enter a valid magnet link (xt=urn:btih:…)' : null,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Magnet links fetch metadata from the swarm first — this can take '
          'a while. The task appears as “Fetching metadata…” until then.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add),
          label: const Text('Add magnet link'),
          onPressed: (_magnetValid && !_busy) ? _addMagnet : null,
        ),
      ],
    );
  }
}
