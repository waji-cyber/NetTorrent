// NetTorrent Companion — popup logic.
// Talks only to the NetTorrent bridge on this machine (127.0.0.1:17846).
// No external network calls, no history/cookie access.

const BRIDGE = 'http://127.0.0.1:17846';

const statusEl = document.getElementById('status');
const tokenEl = document.getElementById('token');
const urlEl = document.getElementById('url');
const msgEl = document.getElementById('msg');

function setMsg(text, kind) {
  msgEl.textContent = text;
  msgEl.className = kind || '';
}

document.addEventListener('DOMContentLoaded', () => {
  // Load the saved pairing token, if any.
  chrome.storage.local.get(['bridgeToken'], (r) => {
    if (r.bridgeToken) tokenEl.value = r.bridgeToken;
  });

  // Save the token as soon as the user finishes editing it.
  tokenEl.addEventListener('change', () => {
    const token = tokenEl.value.trim();
    chrome.storage.local.set({ bridgeToken: token }, () => {
      setMsg(token ? 'Token saved on this browser only.' : 'Token cleared.', 'ok');
    });
  });

  document.getElementById('send').addEventListener('click', sendUrl);
  document.getElementById('refresh').addEventListener('click', refreshStatus);
  urlEl.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') sendUrl();
  });

  refreshStatus();
});

async function refreshStatus() {
  statusEl.textContent = 'Checking…';
  statusEl.className = 'status';
  try {
    const res = await fetch(`${BRIDGE}/status`);
    if (!res.ok) throw new Error('HTTP ' + res.status);
    const s = await res.json();
    statusEl.textContent =
      `Connected to ${s.name} v${s.version} · ${s.tasks} task(s), ${s.active} active`;
    statusEl.className = 'status ok';
  } catch (e) {
    statusEl.textContent = 'Not running — start NetTorrent first.';
    statusEl.className = 'status bad';
  }
}

async function sendUrl() {
  const url = urlEl.value.trim();
  const token = tokenEl.value.trim();
  if (!url) return setMsg('Paste a URL first.', 'err');
  if (!token) {
    return setMsg('Paste your bridge token first (NetTorrent → Settings).', 'err');
  }
  setMsg('Sending…', '');
  try {
    const res = await fetch(`${BRIDGE}/add`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ' + token,
      },
      body: JSON.stringify({ url }),
    });
    const data = await res.json().catch(() => ({}));
    if (res.status === 202) {
      setMsg(`Added: ${data.name || url}`, 'ok');
      urlEl.value = '';
      refreshStatus();
    } else if (res.status === 403) {
      setMsg('Token rejected — copy the current token from NetTorrent → Settings.', 'err');
    } else {
      setMsg(`Error: ${data.error || 'HTTP ' + res.status}`, 'err');
    }
  } catch (e) {
    setMsg('Could not reach NetTorrent — is it running?', 'err');
  }
}
