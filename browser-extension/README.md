# NetTorrent Companion — Browser Extension

A small Manifest V3 extension for Chromium-based browsers (Chrome, Edge, Brave, …)
that sends download links to the NetTorrent desktop app through a localhost bridge.

## How it works

The extension talks **only** to `http://127.0.0.1:17846` on your own machine —
the bridge server built into NetTorrent. It sends a one-time pairing token with
each request so only your browser can queue downloads. It never contacts any
website, never reads browsing history, and never touches cookies.

## Install (load unpacked)

1. Open `chrome://extensions` in your Chromium browser.
2. Turn on **Developer mode** (toggle, top right).
3. Click **Load unpacked** and select this `browser-extension/` folder.
4. The NetTorrent icon appears in the toolbar. Pin it for easy access.

To update after editing the files: press the reload icon on the extension card
at `chrome://extensions`.

## One-time token pairing

1. Open the NetTorrent desktop app → **Settings**.
2. Find the **Browser bridge token** field and copy the token.
   (It is generated once per install and never leaves your machine.)
3. Click the extension icon → paste the token into the **Bridge token** field.
   It is saved in the browser's local storage (`chrome.storage.local`) and used
   only for bridge requests.

The popup shows the connection status: `Connected to NetTorrent vX …` means the
app is running and reachable; `Not running` means start NetTorrent first.

## Usage

- **Right-click any link** → **Send link to NetTorrent**. The download is queued
  in the app (a ✓ badge confirms success; ! means something failed — check the
  popup or the service-worker console).
- **Popup:** paste any URL into the field and click **Send to NetTorrent**.
- **Manual fallback:** if a site blocks right-click or a link is not a direct
  file URL, copy the URL and paste it into the popup — or into NetTorrent's
  **Add Download** page.

## LIMITS — please read

- **Only direct `http://` / `https://` URLs are accepted.** The bridge rejects
  anything else (the app's URL validator runs on every request).
- **The extension cannot intercept Google Drive, Chrome, or other apps'
  downloads automatically.** Those services do not expose plain file URLs to
  extensions, and browsers deliberately sandbox their download pipelines.
  For such files: use the site's own download, or find a direct link and paste
  it manually.
- **It cannot redirect all web traffic to NetTorrent.** It only acts when you
  explicitly right-click a link or paste a URL.
- **NetTorrent must be running** for the bridge to answer; the bridge binds to
  `127.0.0.1:17846` only and refuses connections from anywhere else.

## Files

| File | Purpose |
|---|---|
| `manifest.json` | Manifest V3: name, permissions, popup, service worker |
| `popup.html` / `popup.js` | Toolbar popup: status, token pairing, manual URL send |
| `background.js` | Service worker: link context menu → bridge POST |

Full protocol details: `../docs/BROWSER_EXTENSION.md`.
