# NetTorrent — Troubleshooting Guide

Each entry is **Symptom → Likely cause → Fix**. If a fix doesn't work, note the exact error text and where it appeared (snackbar, task error field, console) before asking for help.

## Browser bridge

### Extension shows "connection refused" / "can't reach NetTorrent"

- **Cause:** the NetTorrent app isn't running, or another program already occupies port `17846`.
- **Fix:**
  1. Make sure NetTorrent is open — the bridge server only runs while the app runs.
  2. Check what's on the port: `netstat -ano | findstr 17846` (Windows). If another app holds it, close that app or change `kBridgePort` in `lib/core/constants.dart` **and** the extension's target URL, then rebuild both.

### Bridge returns `403 {"error":"invalid or missing token"}`

- **Cause:** the bearer token in the extension doesn't match the app's per-install token (token mismatch), or the `Authorization` header is missing.
- **Fix:** open NetTorrent → **Settings** → copy the bridge token shown there → paste it into the extension's options page and save. Tokens are generated per install; reinstalling the app generates a new one, so re-pair after reinstall.

## HTTP/HTTPS downloads

### Download fails with 403 or 404

- **Cause:** the server refused the request (403: hotlink protection, expired signed URL, bot filtering) or the file is gone (404). This is the *server's* decision, not an app bug.
- **Fix:** open the URL in a browser to confirm it still works there. If the site requires login or blocks non-browser clients, NetTorrent cannot and will not bypass that — use a link the site exposes publicly, or paste a fresh URL.

### Resume restarts the download from 0%

- **Cause:** the server ignores `Range` requests (no `Accept-Ranges: bytes` in its response headers). Without server cooperation, resuming mid-file is impossible — the app must re-download.
- **Fix:** none needed; this is expected behaviour for such servers. NetTorrent detects it and restarts cleanly instead of writing a corrupt file. Prefer mirrors/CDNs that advertise `Accept-Ranges`.

## BitTorrent

### Torrent stuck at "fetching metadata" (magnet links)

- **Cause:** (a) the info hash is dead — no peers in the DHT/tracker swarm carry it; or (b) the network blocks DHT (common on campus networks that filter UDP).
- **Fix:** try a known-good lawful torrent (see `docs/TEST_PLAN.md` → "Lawful torrent testing"). If *no* magnet ever resolves, the network is likely blocking DHT/UDP — test on a different network. Dead hashes eventually surface a clear timeout error; don't wait indefinitely.

### Torrent downloads very slowly despite a healthy swarm

- **Cause:** no incoming connections — the client is unreachable from the internet (NAT, no port forwarding), so it can only connect *out* to peers, missing many of them.
- **Fix:** enable UPnP/NAT-PMP on your router if available, or manually forward the client's listening port. On restricted networks (dorms, campus), speeds may stay low — that's environmental, not a bug. Seeding a local test torrent (TEST_PLAN.md) verifies the engine itself is healthy.

## Android

### "Permission denied" when writing a download

- **Cause:** Android scoped storage — the app can only write to its own directories or folders the user explicitly granted.
- **Fix:** grant storage permission when prompted, and set the download folder to the app's external directory or pick a folder through the system folder picker (Settings → download folder). Don't point the app at arbitrary paths it was never granted.

### Download completes but no notification appears

- **Cause:** notification permission denied, or the system silenced the app's notification channel.
- **Fix:** Android Settings → Apps → NetTorrent → Notifications → allow. On first run the app requests permission via `permission_handler`; if it was denied, re-enable it in system settings. On Windows, check Settings → System → Notifications.

## Build & dependencies

### `flutter pub get` reports version conflicts

- **Cause:** pinned versions in `pubspec.yaml` disagree with each other or with the installed Flutter/Dart SDK.
- **Fix:**
  1. `flutter upgrade` to the latest stable, then `flutter pub get` again.
  2. If a specific package conflicts, loosen its constraint (e.g. `^0.5.4` → `any` temporarily), run `flutter pub get`, note the resolved version, and re-pin.
  3. As a last resort, delete `pubspec.lock` and `.dart_tool/`, then `flutter pub get` for a fresh resolve.

### Windows build fails: missing MSVC / "unable to find vcvarsall"

- **Cause:** Flutter's Windows toolchain needs Visual Studio's C++ build tools, which aren't installed.
- **Fix:** install Visual Studio (Community is fine) with the **"Desktop development with C++"** workload, reboot, then run `flutter doctor` and resolve any remaining items before `flutter build windows --release`.

## Still stuck?

1. Reproduce the problem once more and copy the exact error text.
2. Check `docs/ARCHITECTURE.md` §4 (honesty ledger) — the feature may be documented as deferred.
3. For bridge issues, test with `curl` (see TEST_PLAN.md TP-16) to separate extension problems from app problems.
