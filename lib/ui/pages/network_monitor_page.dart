import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_info_plus/network_info_plus.dart';

import '../../core/utils.dart';
import '../../services/bridge_server.dart';
import '../../services/download_manager.dart';
import '../widgets/speed_graph.dart';
import '../widgets/stat_card.dart';

/// Live transfer statistics plus short Computer Networks explainers.
///
/// Only connections belonging to this app (its downloads, its bridge
/// server) are inspected — no packet capture, no other apps' traffic.
class NetworkMonitorPage extends ConsumerWidget {
  const NetworkMonitorPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(networkStatsProvider);
    final theme = Theme.of(context);
    final bridge = ref.read(bridgeServerProvider);

    final sessionDuration = DateTime.now().difference(stats.sessionStart);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ------------------------------------------------ connection card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.router, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Connection status',
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _statusRow(
                    context,
                    'Transfer engine',
                    'Monitoring active',
                    Icons.check_circle,
                    theme.colorScheme.primary,
                  ),
                  _statusRow(
                    context,
                    'Extension bridge',
                    bridge.running
                        ? 'Running on 127.0.0.1:${bridge.port}'
                        : 'Not running',
                    Icons.link,
                    bridge.running
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                  ),
                  FutureBuilder<String?>(
                    future: _wifiIp(),
                    builder: (context, snapshot) {
                      final ip = snapshot.data;
                      return _statusRow(
                        context,
                        'Local IP address',
                        ip ?? 'Not available on this platform',
                        Icons.wifi,
                        theme.colorScheme.primary,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // ------------------------------------------------ throughput card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Live throughput',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  SpeedGraph(samples: stats.history),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // ---------------------------------------------------- stats grid
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth > 700 ? 3 : 2;
              return GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.6,
                children: [
                  StatCard(
                    title: 'Download',
                    value: formatSpeed(stats.downloadBps),
                    icon: Icons.arrow_downward,
                  ),
                  StatCard(
                    title: 'Upload',
                    value: formatSpeed(stats.uploadBps),
                    icon: Icons.arrow_upward,
                  ),
                  StatCard(
                    title: 'Downloaded',
                    value: formatBytes(stats.totalDownloadedBytes),
                    icon: Icons.save_alt,
                    subtitle: 'this session',
                  ),
                  StatCard(
                    title: 'Uploaded',
                    value: formatBytes(stats.totalUploadedBytes),
                    icon: Icons.upload,
                    subtitle: 'this session',
                  ),
                  StatCard(
                    title: 'Connected peers',
                    value: '${stats.connectedPeers}',
                    icon: Icons.people,
                  ),
                  StatCard(
                    title: 'Session',
                    value: _formatDuration(sessionDuration),
                    icon: Icons.timer,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Text('How it works', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          ..._explainers.map(
            (e) => Card(
              child: ExpansionTile(
                title: Text(e.$1),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text(e.$2, style: theme.textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusRow(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color iconColor,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
          Flexible(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Best-effort local IP lookup; null when the platform cannot provide it.
  Future<String?> _wifiIp() async {
    try {
      return await NetworkInfo().getWifiIP();
    } catch (_) {
      return null;
    }
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }
}

/// (title, 2–4 sentence explanation) pairs for the "How it works" section.
const List<(String, String)> _explainers = [
  (
    'Client–server vs peer-to-peer',
    'In a client–server model one central server holds the file and every '
        'downloader connects to it — simple, but the server\'s bandwidth is the '
        'bottleneck. In peer-to-peer, downloaders exchange pieces of the file '
        'directly with each other, so total capacity grows as more peers join. '
        'NetTorrent uses client–server for direct HTTP downloads and '
        'peer-to-peer for torrents.',
  ),
  (
    'The BitTorrent protocol',
    'A torrent describes a file as many fixed-size pieces, each verified by a '
        'hash stored in the .torrent metadata. Peers download pieces from each '
        'other — rarest pieces first — and re-upload the pieces they already '
        'have, so the swarm shares the load. Because every piece is '
        'individually checksummed, downloads can pause and resume safely.',
  ),
  (
    'Trackers & peer discovery',
    'A tracker is a lightweight server that introduces peers: your client '
        'announces the info-hash it wants, and the tracker replies with a list '
        'of peer addresses. Magnet links carry no file list, so the client '
        'first finds peers through trackers or the DHT distributed hash table, '
        'then fetches the metadata from them. If trackers fail, DHT and peer '
        'exchange keep discovery working.',
  ),
  (
    'Seeders & leechers',
    'A seeder holds the complete file and only uploads; a leecher is still '
        'downloading, while usually uploading the pieces it already has. A '
        'torrent\'s health depends on the seeder-to-leecher ratio — with no '
        'seeders and an incomplete swarm, some pieces may be unavailable. '
        'NetTorrent can keep seeding finished torrents to give back to the swarm.',
  ),
  (
    'TCP vs UDP',
    'TCP is a reliable, ordered, connection-oriented byte stream that '
        'retransmits lost packets — which is why HTTP downloads and most '
        'BitTorrent peer connections use it. UDP is a lightweight, '
        'connectionless datagram service with no delivery guarantees, used by '
        'UDP trackers, the DHT, and BitTorrent\'s uTP transport for lower '
        'overhead.',
  ),
  (
    'IP addresses & ports',
    'Every device on a network has an IP address, and ports (0–65535) identify '
        'the specific application on that device. A peer endpoint such as '
        '203.0.113.7:6881 means "talk BitTorrent to the app on port 6881 at '
        'that address". Trackers, the localhost extension bridge, and every '
        'peer connection are all just IP + port pairs.',
  ),
  (
    'HTTP & HTTPS',
    'HTTP is the client–server protocol of the web: the client sends a request '
        'and the server responds with the file bytes. HTTPS is HTTP over TLS, '
        'adding encryption and server authentication. NetTorrent resumes '
        'interrupted HTTP downloads with Range requests, asking the server for '
        'only the missing byte range.',
  ),
  (
    'Bandwidth, throughput & latency',
    'Bandwidth is the maximum capacity of a link; throughput is the actual '
        'transfer rate measured right now — shown live on this page. Latency '
        'is the round-trip delay, which matters most for small, chatty '
        'exchanges like tracker announces. The speed limits in Settings cap '
        'throughput so downloads don\'t starve your other apps.',
  ),
  (
    'Pieces, integrity & hashing',
    'BitTorrent splits files into pieces (typically 256 KB – 4 MB); each '
        'piece\'s SHA-1 hash is listed in the torrent metadata. After '
        'downloading a piece, the client hashes it and discards it on mismatch, '
        'so corrupt or malicious data never reaches your disk. HTTP downloads '
        'rely on the server instead — NetTorrent can only verify what the '
        'protocol itself provides.',
  ),
];
