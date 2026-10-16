// NetTorrent Companion — service worker.
// Adds a right-click menu item on links and POSTs the link URL to the
// NetTorrent bridge on this machine. No external network calls,
// no history/cookie access.

const BRIDGE = 'http://127.0.0.1:17846';

chrome.runtime.onInstalled.addListener(() => {
  chrome.contextMenus.create({
    id: 'send-to-nettorrent',
    title: 'Send link to NetTorrent',
    contexts: ['link'],
  });
});

chrome.contextMenus.onClicked.addListener(async (info) => {
  if (info.menuItemId !== 'send-to-nettorrent' || !info.linkUrl) return;

  const { bridgeToken } = await chrome.storage.local.get(['bridgeToken']);
  if (!bridgeToken) {
    // Not paired yet: open the popup so the user can paste the token.
    try {
      await chrome.action.openPopup();
    } catch (_) {
      // openPopup() needs a user gesture context; fall back to a tab.
      chrome.tabs.create({ url: chrome.runtime.getURL('popup.html') });
    }
    return;
  }

  try {
    const res = await fetch(`${BRIDGE}/add`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ' + bridgeToken,
      },
      body: JSON.stringify({ url: info.linkUrl }),
    });
    const data = await res.json().catch(() => ({}));
    if (res.status === 202) {
      console.log('[NetTorrent] added:', data.name);
      setBadge('✓', '#4caf50');
    } else {
      console.error('[NetTorrent] rejected:', res.status, data.error);
      setBadge('!', '#f44336');
    }
  } catch (e) {
    console.error('[NetTorrent] bridge unreachable — is the app running?', e);
    setBadge('!', '#f44336');
  }
});

function setBadge(text, color) {
  chrome.action.setBadgeText({ text });
  chrome.action.setBadgeBackgroundColor({ color });
  setTimeout(() => chrome.action.setBadgeText({ text: '' }), 4000);
}
