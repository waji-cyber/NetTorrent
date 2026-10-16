# NetTorrent — Architecture Diagrams (Phase 8)

Mermaid source diagrams for the academic report (chapters 12–20) and the
teacher presentation. Every box below maps to a real file in this repo —
`lib/` has 31 Dart files; the key ones are named in the notes under each diagram.

Render these with any Mermaid renderer (mermaid.live, the Mermaid VS Code
extension, or GitHub markdown preview).

---

## 1. System architecture (report chapter 12)

```mermaid
flowchart TB
    subgraph UI["Presentation layer — lib/ui (flutter_riverpod)"]
        Pages["9 pages:<br/>Dashboard · All / Active / Completed Downloads<br/>Torrents · Add Download<br/>Network Monitor · Settings · About"]
        Widgets["Widgets:<br/>DownloadTaskTile · SpeedGraph (fl_chart)<br/>StatCard · Dialogs · EmptyState"]
        Shell["App shell:<br/>NavigationRail on desktop<br/>Drawer + bottom nav on mobile"]
    end

    subgraph State["State layer — lib/core/app_providers.dart"]
        DLProv["DownloadManager<br/>StateNotifier of List&lt;DownloadTask&gt;"]
        TorProv["TorrentService"]
        StatProv["NetworkStatsNotifier"]
        SetProv["SettingsService"]
    end

    subgraph Engines["Engine layer — lib/services"]
        HTTP["HttpDownloadEngine<br/>(dio streaming,<br/>Range resume, _TokenBucket)"]
        BRIDGE["BridgeServer<br/>(shelf + shelf_router,<br/>localhost, Bearer token)"]
        NOTIF["NotificationsService"]
    end

    subgraph Models["Models — lib/models"]
        Task["DownloadTask"]
        Settings["AppSettings"]
    end

    subgraph Data["Data & platform"]
        Prefs[("shared_preferences<br/>(settings + task list)")]
        Files["path_provider · file_picker<br/>(download folder)"]
        Android["receive_sharing_intent<br/>permission_handler<br/>flutter_local_notifications"]
        NetInfo["network_info_plus"]
    end

    subgraph External["External world"]
        HTTPServers["HTTP/HTTPS servers"]
        Swarm["BitTorrent swarm<br/>trackers · DHT · peers (TCP/uTP)<br/>via dtorrent_task_v2"]
        Ext["Browser extension (Manifest V3)<br/>popup.js / background.js"]
        ShareSrc["Android share sheet"]
    end

    Shell --> Pages
    Pages --> Widgets
    Pages --> DLProv & TorProv & StatProv & SetProv
    DLProv --> HTTP
    DLProv --> Task
    TorProv --> Swarm
    HTTP --> HTTPServers
    SetProv --> Settings
    SetProv --> Prefs
    DLProv --> Prefs
    DLProv --> NOTIF
    NOTIF --> Android
    StatProv --> NetInfo
    Pages --> Files
    Ext -->|"POST /add<br/>Authorization: Bearer <token>"| BRIDGE
    BRIDGE --> DLProv
    ShareSrc -->|"shared URL intent"| Android
    Android --> DLProv
```

**Notes.** `DownloadManager` owns the queue, priorities, retry-with-backoff
and persistence. `HttpDownloadEngine` never fabricates progress: every speed
and percentage comes from the `HttpProgress` stream sampler. `TorrentService`
wraps the pure-Dart `dtorrent_task_v2` engine (tracker + DHT + uTP/TCP);
magnet metadata is decoded with `b_encode_decode`.

---

## 2. Use-case diagram (report chapter 13)

```mermaid
flowchart LR
    User((User))
    UC1([Add download by URL])
    UC2([Add torrent — .torrent file or magnet link])
    UC3([Pause / resume / cancel / retry download])
    UC4([Set queue order and priorities])
    UC5([Set bandwidth and peer limits])
    UC6([Change settings — folder, theme, seeding, notifications])
    UC7([Monitor network — throughput graph, peers, trackers])
    UC8([Receive completion / failure notifications])
    UC9([Send URL from desktop browser])
    UC10([Share link from Android browser])

    User --> UC1 & UC2 & UC3 & UC4 & UC5 & UC6 & UC7 & UC8
    UC9 -.->|via extension + localhost bridge| UC1
    UC10 -.->|via Android share intent| UC1
```

---

## 3. Data-flow diagram (report chapter 14)

```mermaid
flowchart LR
    U([User / extension / share intent])
    V["1. Validate input<br/>(URL + magnet validators,<br/>safe filename sanitizer)"]
    M["2. DownloadManager<br/>(queue, priority, retry)"]
    HE["3a. HttpDownloadEngine<br/>(dio stream → .part file)"]
    TE["3b. TorrentService<br/>(dtorrent_task_v2 swarm)"]
    D[("4. Disk<br/>(download folder)")]
    S["5. NetworkStats sampler<br/>(live throughput)"]
    UI["6. UI<br/>(tiles, graphs, dashboard)"]
    N["7. NotificationsService"]
    P[("8. shared_preferences<br/>(task + settings persistence)")]

    U --> V --> M
    M --> HE & TE
    HE & TE --> D
    HE & TE -->|HttpProgress / TorrentSnapshot| S --> UI
    M -->|state changes| UI
    M -->|completed / failed| N
    M <--> P
```

---

## 4. HTTP/HTTPS download process (report chapter 18)

```mermaid
sequenceDiagram
    participant UI as Add Download page
    participant DM as DownloadManager
    participant ENG as HttpDownloadEngine
    participant SRV as HTTP server
    participant FS as Disk (.part file)

    UI->>DM: add(url)
    DM->>DM: validate URL, sanitize filename
    DM->>ENG: start(task)
    ENG->>SRV: GET url (stream)
    SRV-->>ENG: 200 OK + body stream
    loop chunks
        ENG->>FS: append bytes
        ENG->>DM: HttpProgress(downloaded, speed)
        DM->>UI: update tile / graph
    end
    Note over ENG: pause → cancel stream, keep .part
    ENG->>SRV: GET url, Range: bytes=N-
    SRV-->>ENG: 206 Partial Content
    Note over ENG: resume continues appending
    ENG->>FS: rename .part → final name
    ENG->>DM: completed
    DM->>UI: notification via NotificationsService
```

---

## 5. BitTorrent protocol workflow (report chapter 19)

```mermaid
flowchart TD
    A([User adds .torrent file or magnet link]) --> B["Parse metadata<br/>(b_encode_decode for magnet)"]
    B --> C["TorrentService creates task<br/>(dtorrent_task_v2)"]
    C --> D["Peer discovery:<br/>tracker announce (HTTP/UDP)<br/>+ DHT"]
    D --> E["Peer handshake<br/>(TCP / uTP)"]
    E --> F["Request pieces<br/>(rarest-first by engine)"]
    F --> G{"SHA-1 piece hash<br/>valid?"}
    G -->|yes| H["Write piece to disk"]
    G -->|no| F
    H --> I{"All pieces<br/>done?"}
    I -->|no| F
    I -->|yes| J["Assemble files,<br/>mark completed"]
    J --> K{"Seeding enabled<br/>in settings?"}
    K -->|yes| L["Seed to swarm<br/>(upload, respecting cap)"]
    K -->|no| M["Stop task"]
    C --> N["TorrentSnapshot stream:<br/>peers, seeders, up/down speed,<br/>tracker status → UI"]
```

---

## 6. UI navigation map (report chapter 20)

```mermaid
flowchart TD
    Shell["App shell<br/>(theme: dark default, light optional)"]
    Shell --> Rail["Desktop: NavigationRail"]
    Shell --> Mob["Mobile: Drawer + bottom navigation"]
    Rail & Mob --> D["1. Dashboard<br/>(stat cards, speed graph)"]
    Rail & Mob --> A1["2. All Downloads"]
    Rail & Mob --> A2["3. Active Downloads"]
    Rail & Mob --> A3["4. Completed Downloads"]
    Rail & Mob --> T["5. Torrents<br/>(peers, seeders, tracker status)"]
    Rail & Mob --> AD["6. Add Download<br/>(URL / magnet / .torrent)"]
    Rail & Mob --> NM["7. Network Monitor<br/>(throughput graph +<br/>networking explainers)"]
    Rail & Mob --> S["8. Settings<br/>(persisted via shared_preferences)"]
    Rail & Mob --> AB["9. About"]
    A1 & A2 & A3 --> Tile["DownloadTaskTile:<br/>progress bar, speeds, ETA,<br/>pause / resume / cancel / retry"]
```

---

*Generated 2026-10-16 from the phase 1–6 codebase (`flutter analyze` clean,
34/34 unit tests passing). Pending real-device runs: screenshots for
chapter 27 and any measured benchmarks — these must come from actual builds,
never fabricated.*
