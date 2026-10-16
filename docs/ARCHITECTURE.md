# NetTorrent — Architecture & Technology Plan (Phase 1)

**Version:** 0.1.0 · **Date:** 2026-10-16 · **Status:** Phase 1 approved, implementation in progress

## 1. Technology stack

| Concern | Choice | Why |
|---|---|---|
| UI framework | **Flutter 3.x / Dart 3** | One codebase compiles to Windows desktop and Android; Material 3 widgets give the required modern dark/light themes and responsive layouts. |
| State management | **flutter_riverpod 2.x** | Compile-safe providers, no BuildContext plumbing in services, easy to test. |
| HTTP(S) downloads | **dio 5.x** (`ResponseType.stream`) | Streaming bodies + `Range` headers give pause/resume; interceptors/timeouts built in. |
| BitTorrent engine | **dtorrent_task_v2 0.5.4** (pure Dart) | Real engine: BEP 3/5/6, tracker + DHT + uTP/TCP, `.torrent` parse, magnet metadata fetch, queue. Pure Dart = zero native binaries to ship per platform — critical for a student build. Verified API: `TorrentModel.parse`, `TorrentTask.newTask/start/pause/resume/stop`, `createListener`, `MagnetParser.parse`, `MetadataDownloader.fromMagnet`. |
| Magnet metadata assembly | **b_encode_decode** | Re-wraps fetched info-dict bytes into a `TorrentModel` via `TorrentParser.parseFromMap`. |
| Settings persistence | **shared_preferences** | Simple key/value, works on Windows + Android. |
| Task persistence | JSON file in app support dir | No codegen, human-inspectable, survives restarts. |
| Charts (monitor) | **fl_chart** | Throughput graphs on the Network Monitor page. |
| Notifications | **flutter_local_notifications 17.x** | Completion/failure alerts on both platforms. |
| File picking | **file_picker 8.x** | `.torrent` selection on Windows/Android. |
| Share intents (Android) | **receive_sharing_intent 1.8.x** | "Share → NetTorrent" from browsers. |
| Permissions (Android) | **permission_handler 11.x** | Storage/notification permission flows. |
| Network info | **network_info_plus 6.x** | Interface details for the monitor page. |
| Browser bridge | **shelf + shelf_router** | Localhost HTTP server (`127.0.0.1:17846`) with a per-install bearer token; the Manifest-V3 extension POSTs URLs to it. |
| Tests | **flutter_test** + **flutter_lints** | Unit tests for pure logic; widget tests for key screens. |

### Rejected alternatives
- **libtorrent FFI bindings** (`libtorrent_dart`): more powerful, but requires shipping native libtorrent binaries per platform/ABI — too fragile for a university build on student machines.
- **Electron / Tauri / .NET MAUI**: larger installers, weaker Android story (Electron/Maui) or smaller hiring pool for help; Flutter covers both targets from one codebase.

## 2. System architecture

```
┌────────────────────────────── UI (Flutter / Riverpod) ──────────────────────────────┐
│ Dashboard · All/Active/Completed · Torrents · Add · Network Monitor · Settings · About │
│                        widgets: TaskTile · SpeedGraph · StatCard · dialogs             │
└───────────────┬───────────────────────────────┬───────────────────────┬───────────────┘
                │                               │                       │
   ┌────────────▼────────────┐     ┌────────────▼────────────┐  ┌───────▼────────┐
   │    DownloadManager      │     │   NetworkStatsNotifier  │  │ SettingsService│
   │ (queue · priorities ·   │────▶│ (EMA speeds · history   │  │ (shared_prefs) │
   │  retry · persistence)   │     │  ring buffer)           │  └────────────────┘
   └──────┬──────────┬───────┘     └─────────────────────────┘
          │          │
 ┌────────▼────┐ ┌───▼────────────────────────┐   ┌─────────────────────────┐
 │HttpDownload │ │ TorrentService              │   │ BridgeServer (shelf)    │
 │Engine (dio) │ │ ManagedTorrent wraps        │   │ 127.0.0.1:17846       │
 │Range resume │ │ dtorrent_task_v2.TorrentTask│   │ POST /add (token auth)  │
 │token-bucket │ │ tracker/DHT/uTP samplers    │   │ GET /status             │
 └─────────────┘ └─────────────────────────────┘   └───────────┬─────────────┘
                                                              │
                                              ┌───────────────▼───────────────┐
                                              │ Browser extension (MV3)      │
                                              │ popup + context menu → bridge │
                                              └───────────────────────────────┘
```

### Key flows
- **HTTP download:** UI → `DownloadManager.addHttpDownload` → validate → probe size → queue → `HttpDownloadEngine.download` (HEAD probe, `Range` resume, token-bucket throttle, `CancelToken` for pause) → progress callbacks → completion notification → queue pump.
- **Torrent (.torrent):** file picker → `TorrentService.addTorrentFile` (`TorrentModel.parse` validates first) → queue → `ManagedTorrent.start()` → 1s sampler polls `progress/connectedPeersNumber/uploadSpeed` → completion → optional seeding.
- **Magnet:** `MagnetParser.parse` validates → `MetadataDownloader.fromMagnet` → `startDownload()` → `MetaDataDownloadComplete.data` → bdecode → `TorrentParser.parseFromMap` → same as above. Metadata fetch can take minutes on dead hashes — surfaced as progress + timeout error.
- **Browser → app:** extension POSTs `{url}` + bearer token to the bridge → `addHttpDownload`. Token pairing is a one-time paste shown in Settings.

## 3. Folder structure

```
nettorrent/
├── pubspec.yaml
├── analysis_options.yaml
├── README.md                      # setup + build commands
├── lib/
│   ├── main.dart                  # bootstrap, providers, theme wiring
│   ├── core/
│   │   ├── constants.dart         # ports, timeouts, defaults
│   │   ├── theme.dart             # dark/light Material 3 themes
│   │   └── utils.dart             # URL validation, filename sanitising, formatters
│   ├── models/
│   │   ├── download_task.dart     # DownloadTask (immutable, JSON)
│   │   └── app_settings.dart      # AppSettings (persisted)
│   ├── services/
│   │   ├── settings_service.dart
│   │   ├── http_download_engine.dart
│   │   ├── torrent_service.dart
│   │   ├── download_manager.dart  # queue, stats, persistence, providers
│   │   ├── network_stats.dart
│   │   ├── bridge_server.dart
│   │   └── notifications_service.dart
│   └── ui/
│       ├── app.dart               # responsive shell + navigation
│       ├── pages/                 # 9 pages
│       └── widgets/               # TaskTile, SpeedGraph, StatCard, dialogs
├── browser-extension/             # Manifest V3 extension
│   ├── manifest.json
│   ├── popup.html / popup.js
│   ├── background.js
│   └── README.md
├── android/                       # generated by `flutter create` (intent filters documented)
├── windows/                       # generated by `flutter create`
├── test/                          # unit + widget tests
└── docs/
    ├── ARCHITECTURE.md            # this file
    ├── BUILD.md                   # Windows + Android build commands
    ├── PLATFORM_INTEGRATION.md    # intents, protocol handlers, startup
    ├── BROWSER_EXTENSION.md       # pairing + limits
    ├── TEST_PLAN.md
    └── TROUBLESHOOTING.md
```

## 4. What is real vs. stubbed (honesty ledger)

| Feature | State |
|---|---|
| HTTP/HTTPS download, pause/resume (Range), retry, queue, priorities, speed cap | Real (`HttpDownloadEngine`, token bucket) |
| .torrent add/parse/download/pause/resume, peers, speeds | Real (`dtorrent_task_v2` wrapper) |
| Magnet links (metadata fetch → download) | Real, metadata fetch may be slow on dead hashes |
| Settings persistence, task list persistence across restarts | Real |
| Dashboard stats, throughput graph, network monitor | Real (sampled from engines) |
| Completion/failure notifications | Real via `flutter_local_notifications` |
| Browser extension → app handoff | Real via localhost bridge + token |
| Android share-intent, `.torrent`/magnet association | Documented integration; verified at build time |
| Seeding ratio limits, UPnP port forwarding, proxy support | Engine supports; UI exposes basic toggles, advanced config deferred |
| Upload speed cap for torrents | Engine-level; wired in Phase 4 hardening |

## 5. Risks & mitigations
- **No Flutter SDK in this build environment** → code is written to compile; `flutter analyze`/`flutter test` must run on the student's machine (commands in README).
- **Tracker/DHT reachability** on university networks → test torrents include a locally-hosted option (Phase 7 test plan).
- **Android scoped storage** → downloads default to app external dir; SAF folder picker documented.
- **Simulated data** → forbidden by project rules; every number on screen comes from an engine sampler or is labelled "unavailable".

## 6. Phase plan
1. ✅ Architecture, stack, structure, plan (this doc)
2. UI shell + 9 pages navigation (functional, wired to providers)
3. HTTP engine + manager + queue + persistence (done in core; UI wiring in 2)
4. Torrent integration hardening (engine wrapper done; UI torrent page in 2)
5. Network stats + monitor page (service done; page in 2)
6. Platform integrations + browser extension
7. Tests + fixes + limitations
8. Academic report (32 chapters), diagrams, presentation
