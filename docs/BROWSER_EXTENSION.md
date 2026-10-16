# NetTorrent — Browser Extension & Bridge Protocol

Reference for the **NetTorrent Companion** extension (`browser-extension/`) and
the localhost bridge it talks to (`lib/services/bridge_server.dart`, shelf +
shelf_router). All behaviour below is taken from that implementation — nothing
here is aspirational.

## 1. Architecture

```
 ┌────────────────────────┐   right-click link / popup    ┌──────────────────────────┐
 │ Chromium-based browser │ ─────────────────────────────▶ │ NetTorrent Companion     │
 │                        │  POST http://127.0.0.1:17846  │ (Manifest V3 extension)  │
 │                        │  /add  +  Bearer token        │ popup.html/js            │
 └────────────────────────┘                               │ background.js (context   │
                                                          │ menu, service worker)    │
                                                          └────────────┬─────────────┘
                                                                       │ localhost only
                                                             ┌─────────▼──────────────┐
                                                             │ NetTorrent desktop app │
                                                             │ BridgeServer (shelf)   │
                                                             │ 127.0.0.1:17846        │
                                                             │  ├─ GET  /status       │
                                                             │  └─ POST /add (auth)   │
                                                             └────────────────────────┘
```

- The bridge binds to **`127.0.0.1` only** (`InternetAddress.loopbackIPv4`);
  no other machine on the network can reach it.
- If the port is busy or loopback is unavailable, the bridge silently does not
  start (`SocketException` is caught) — the app works normally, the extension
  just cannot connect.

## 2. Pairing flow (one-time)

1. NetTorrent generates a random **UUID v4 token** on first run and stores it
   in `SharedPreferences` (key `kBridgeTokenPrefsKey`). It never changes unless
   app data is cleared.
2. The token is displayed in the app under **Settings → Browser bridge token**.
3. The user copies it into the extension popup's **Bridge token** field.
4. The extension saves it in `chrome.storage.local` (browser-local only) and
   sends it as `Authorization: Bearer <token>` on every `/add` request.

## 3. HTTP API reference

Base URL: `http://127.0.0.1:17846`. All responses are JSON
(`Content-Type: application/json`).

### `GET /status` — no authentication

```http
GET /status HTTP/1.1
Host: 127.0.0.1:17846
```

Success — `200 OK`:

```json
{ "name": "NetTorrent", "version": "0.1.0", "tasks": 3, "active": 1 }
```

| Field | Meaning |
|---|---|
| `name` | Application name (`kAppName`) |
| `version` | Application version (`kAppVersion`) |
| `tasks` | Total tasks in the download manager |
| `active` | Tasks currently downloading/seeding |

Used by the popup's status line and the "Refresh status" button.

### `POST /add` — bearer-token authentication

```http
POST /add HTTP/1.1
Host: 127.0.0.1:17846
Content-Type: application/json
Authorization: Bearer <token>

{ "url": "https://example.com/file.zip" }
```

| Case | Status | Body |
|---|---|---|
| Queued successfully | `202 Accepted` | `{ "id": "<taskId>", "name": "<taskName>" }` |
| Missing/wrong token | `403 Forbidden` | `{ "error": "invalid or missing token" }` |
| Body is not JSON | `400 Bad Request` | `{ "error": "body must be JSON" }` |
| Not an http/https URL | `400 Bad Request` | `{ "error": "not a valid http/https URL" }` |
| Queueing failed | `500 Internal Server Error` | `{ "error": "<details>" }` |

Notes:
- The URL is validated with the app's `isValidDownloadUrl` — only `http://`
  and `https://` are accepted; `magnet:` links and anything else are rejected
  here (add those inside the app instead).
- The returned `name` is derived from the URL by `addHttpDownload`.
- `logRequests()` middleware logs each request to the app console.

## 4. Security model

- **Loopback-only bind** — packets never leave the machine.
- **Per-install bearer token** — knowing the port is not enough; the token is
  required for `/add`. `/status` is intentionally unauthenticated (it exposes
  only the app name, version, and task counts).
- **Minimal extension permissions** — `contextMenus` (right-click menu),
  `storage` (token), and `http://127.0.0.1/*` host access. The extension
  declares no `history`, `cookies`, `tabs`, or `<all_urls>` permissions and
  makes no external network calls.
- **Safe defaults** — the token is shown only in Settings, never logged; error
  responses never echo the token.

## 5. Troubleshooting

| Symptom | Check |
|---|---|
| Popup says "Not running" | Is the NetTorrent desktop app open? The bridge only lives while the app runs. |
| "Could not reach NetTorrent" on send | Same as above; also check nothing else occupies the port: `netstat -ano \| findstr 17846` (Windows). If something does, stop it and restart NetTorrent — the bridge binds at startup. |
| `403 invalid or missing token` | The token changed (app data cleared) or was pasted with extra whitespace. Re-copy from Settings → paste into the popup (the popup trims it on save). |
| `400 not a valid http/https URL` | The link is not a direct file URL (e.g. a Google Drive share page or `magnet:` link). Paste direct URLs only; add magnets/torrents inside the app. |
| Context menu does nothing, `!` badge | Open `chrome://extensions` → enable Developer mode → *Inspect views: service worker* → read the console error. Usual cause: app not running or token missing (first use opens the popup for pairing). |
| Works in Chrome but not another browser | Any Chromium browser (Edge, Brave, …) supports Manifest V3 and `chrome://extensions`-style loading; Firefox is **not** supported by this extension build. |

## 6. What the extension deliberately does NOT do

- Intercept or redirect downloads automatically — every send is an explicit
  user action (right-click or popup button).
- Read browsing history, cookies, tabs, or page contents.
- Contact any server other than `127.0.0.1:17846`.
- Work when NetTorrent is closed — there is no background daemon in this
  project; the bridge lives inside the app process.
