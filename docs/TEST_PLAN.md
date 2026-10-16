# NetTorrent — Test Plan

**Version:** 0.1.0 · **Date:** 2026-10-16

How to read this plan: each requirement maps to **automated** (`flutter test`) and/or **manual** verification. Status **PENDING** means not yet executed — this build environment has no Flutter SDK, so every row below must be run on a development machine before results may be cited. Nothing here is a fabricated result.

Run automated tests with:

```bash
flutter test                 # whole suite
flutter test test/utils_test.dart   # single file
```

## Test matrix

| ID | Requirement | Automated (`flutter test`) | Manual | Steps | Expected result | Status |
|---|---|---|---|---|---|---|
| TP-01 | URL validation | ✅ `test/utils_test.dart` — `isValidDownloadUrl` group | — | Run `flutter test test/utils_test.dart` | Accepts `http/https` with host; rejects empty, `ftp:`, `magnet:`, host-less URLs | PENDING — no Flutter SDK here |
| TP-02 | Small HTTP/HTTPS download | — | ✅ | Add `https://example.com/` (or any small lawful file) via Add Download; watch progress | File completes, size matches, progress reaches 100% | PENDING |
| TP-03 | Pause / resume (HTTP) | — | ✅ | Start a large download, pause mid-way, resume | Resume continues from stored bytes (no restart from 0) when the server honours `Range`; progress preserved | PENDING |
| TP-04 | Interrupted connection | — | ✅ | Start a download, disable network mid-transfer, re-enable | Task enters failed/retrying state; auto-retry resumes it without data corruption | PENDING |
| TP-05 | Cancel download | — | ✅ | Start a download, cancel it | Task marked cancelled; partial file removed or clearly marked; slot freed for the queue | PENDING |
| TP-06 | Retry failed download | — | ✅ | Force a failure (bad URL / drop network), then retry from the task menu | Retry re-attempts the download; `retries` counter increments | PENDING |
| TP-07 | Queue limits (max simultaneous) | — | ✅ | Set max simultaneous = 2 in Settings; add 5 downloads | Only 2 active at once; the rest stay queued and start as slots free | PENDING |
| TP-08 | Priority order | — | ✅ | Queue several downloads with mixed low/normal/high priorities | High-priority tasks start before low-priority ones when slots free | PENDING |
| TP-09 | Storage permission failure (Android) | — | ✅ | Deny storage permission, then add a download | Clear, non-technical error shown; no crash; task not stuck in "downloading" | PENDING |
| TP-10 | Torrent metadata parse (valid + corrupt) | — | ✅ | Add a valid `.torrent`; then add a deliberately corrupted `.torrent` file | Valid: name/size shown, task starts. Corrupt: rejected with a readable error before any network activity | PENDING |
| TP-11 | Lawful test torrent download | — | ✅ | See "Lawful torrent testing" below | Full download completes; piece hashes verify; completion notification fires | PENDING |
| TP-12 | Magnet metadata timeout | — | ✅ | Add a magnet link with a dead/random info hash | UI shows "fetching metadata" progress, then a clear timeout error (no silent hang) | PENDING |
| TP-13 | Speed cap enforcement | — | ✅ | Set max download speed = 100 KB/s; download a fast file; watch Network Monitor | Sustained throughput stays at/below the cap | PENDING |
| TP-14 | Settings persistence | — | ✅ | Change theme, limits, download folder; kill and restart the app | All settings restored exactly | PENDING |
| TP-15 | Restart recovery (tasks) | — | ✅ | Start downloads, kill the app mid-transfer, restart | Task list restored from JSON; interrupted tasks resume or re-queue cleanly | PENDING |
| TP-16 | Bridge `/add` auth | — | ✅ | `curl -X POST http://127.0.0.1:17846/add -H "Authorization: Bearer WRONG" -d '{"url":"https://example.com/f.zip"}'`; then with the real token from Settings | Wrong token → `403 {"error":"invalid or missing token"}`; correct token → `202 {"id":"<taskId>"}` and the task appears in the app | PENDING |
| TP-17 | UI responsiveness | — | ✅ | Resize the Windows window to narrow widths; rotate an Android phone | Layout adapts (sidebar → bottom nav / drawer); no clipped text or overflow errors | PENDING |
| TP-18 | Model/unit logic | ✅ `test/models_test.dart` + `test/utils_test.dart` | — | `flutter test` | `DownloadTask` JSON round-trip, `copyWith`, progress maths; `AppSettings` defaults/round-trip; formatters and validators | PENDING — no Flutter SDK here |

## Lawful torrent testing

Do **not** use copyrighted material. Two lawful options:

1. **Linux distro ISO torrent** — e.g. an official Ubuntu release torrent. Lawful, well-seeded, exercises tracker + DHT + piece verification end-to-end.
2. **Local seed** — create a `.torrent` of a local file with the engine's `TorrentCreator`, then seed it from one NetTorrent instance (or the engine's example) and download it from another on the same machine/network. This needs no internet at all and is the recommended option on restricted campus networks. (Note: `python -m http.server` is **not** BitTorrent — it serves HTTP only and cannot test the torrent engine.)

## Manual test checklist (per release)

- [ ] Fresh install: app launches, Dashboard shows zero-state correctly.
- [ ] Add HTTP download → completes; notification appears.
- [ ] Pause → resume; cancel; retry-after-failure.
- [ ] Queue: 5 tasks with max simultaneous = 2; priorities respected.
- [ ] `.torrent` add (valid + corrupt file handling).
- [ ] Magnet add; dead-hash magnet shows a timeout error, not a hang.
- [ ] Lawful torrent completes; peers/seeders/speeds shown; optional seeding works.
- [ ] Speed caps hold under Network Monitor.
- [ ] Kill app mid-download → restart → tasks recovered.
- [ ] Settings changed → restart → settings kept.
- [ ] Bridge: wrong token 403, right token 202, task appears.
- [ ] Android: share a link from Chrome → NetTorrent opens with the URL prefilled.
- [ ] Android: deny storage permission → clear error, no crash.
- [ ] Windows resize + Android rotation: no layout overflow.

## What is not covered yet

- Widget/golden tests for the UI pages (Phase 2 will add key-screen widget tests).
- Automated engine tests (HTTP engine and torrent service need network/fixtures; covered manually in Phase 7).
- Performance benchmarks — any numbers quoted in the report must come from a real run on the student's machine.
