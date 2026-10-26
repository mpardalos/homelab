'use strict';
const cards = [...document.querySelectorAll('[data-service]')];
const modal = document.querySelector('#logs-modal');
const logOutput = document.querySelector('#log-output');
const logState = document.querySelector('#logs-state');
const csrf = document.querySelector('[name="csrf-token"]').content;
const restarts = new Map();
let activeLogService = null;
let stream = null;
let logCursor = '';
let logEntries = [];
let bootId = null;
let rebooting = false;

async function api(action, service, options = {}) {
  const params = new URLSearchParams({ action });
  if (service) params.set('service', service);
  const response = await fetch(`/?${params}`, { cache: 'no-store', ...options });
  const data = await response.json();
  if (!response.ok) throw new Error(data.error || 'Request failed.');
  return data;
}

function paintStatus(card, state, text) {
  const badge = card.querySelector('.status');
  badge.className = `status ${!state || state.state === 'unknown' ? 'unknown' : (state.running ? 'up' : 'down')}`;
  const label = state ? `${state.state} · ${state.detail}` : text;
  badge.title = label;
  badge.setAttribute('aria-label', label);
  card.querySelector('.status-text').textContent = text || (state.running ? 'Running' : state.state);
}

function updateStatus(data) {
  bootId = data.bootId;
  if (!rebooting) document.querySelector('#server-reboot').disabled = !bootId;
  cards.forEach(card => {
    const id = card.dataset.service;
    const state = data.services[id];
    const restart = restarts.get(id);
    // Only a sample taken AFTER the restart command completed can confirm recovery.
    if (restart && (!restart.completedAt || data.sampledAt < restart.completedAt)) return;
    paintStatus(card, state, !state || state.state === 'unknown' ? 'Unknown' : '');
    if (restart && state) {
      const message = card.querySelector('.action-message');
      if (state.running) {
        message.textContent = '';
        restarts.delete(id);
      } else if (state.state === 'failed') {
        message.textContent = 'Service failed to start. Check the logs.';
        message.classList.add('error');
        restarts.delete(id);
      }
    }
  });
}

function unavailable() {
  cards.forEach(card => paintStatus(card, null, 'Reconnecting'));
}

function appendLog(text) {
  const scroll = logOutput.scrollTop;
  const oldHeight = logOutput.scrollHeight;
  logEntries.push(text);
  let size = logEntries.reduce((total, entry) => total + entry.length, 0);
  let trimmed = false;
  while (logEntries.length > 120 || (size > 131072 && logEntries.length > 1)) {
    size -= logEntries.shift().length;
    trimmed = true;
  }
  if (trimmed || logEntries.length === 1) logOutput.textContent = logEntries.join('');
  else logOutput.append(document.createTextNode(text));
  if (document.querySelector('#logs-follow').checked) logOutput.scrollTop = logOutput.scrollHeight;
  else {
    // Account for entries removed above the viewport when the buffer rolls over.
    const lineHeight = parseFloat(getComputedStyle(logOutput).lineHeight);
    const removedHeight = trimmed ? oldHeight + text.split('\n').length * lineHeight - lineHeight - logOutput.scrollHeight : 0;
    logOutput.scrollTop = Math.max(0, scroll - Math.max(0, removedHeight));
  }
}

function connectStream() {
  stream?.close();
  if (rebooting) return;
  const params = new URLSearchParams({ action: 'events' });
  if (activeLogService) {
    params.set('service', activeLogService);
    if (logCursor) params.set('cursor', logCursor);
    logState.textContent = 'Connecting…';
  }
  const source = new EventSource(`/?${params}`);
  stream = source;
  const listen = (type, handler) => source.addEventListener(type, event => {
    if (stream === source) handler(event);
  });
  listen('status', event => updateStatus(JSON.parse(event.data)));
  listen('status-error', unavailable);
  listen('ready', () => { logState.textContent = 'Live'; });
  listen('log', event => {
    if (event.lastEventId && event.lastEventId === logCursor) return;
    logCursor = event.lastEventId;
    appendLog(JSON.parse(event.data).text);
    logState.textContent = 'Live';
  });
  listen('log-error', event => { logState.textContent = JSON.parse(event.data).error; });
  listen('error', () => {
    unavailable();
    if (activeLogService) logState.textContent = 'Reconnecting…';
  });
}

function refreshLogs() {
  if (!activeLogService) return;
  logCursor = '';
  logEntries = [];
  logOutput.textContent = '';
  connectStream();
}

function openJournal(id, title) {
  activeLogService = id;
  document.querySelector('#logs-title').textContent = title;
  document.querySelector('#logs-follow').checked = true;
  modal.showModal();
  refreshLogs();
}

async function waitForReboot(previousBoot) {
  // Keep this document alive while the host is offline; reload only after a new boot.
  try {
    const data = await api('status', null, { signal: AbortSignal.timeout(4000) });
    if (data.bootId && data.bootId !== previousBoot) { window.location.reload(); return; }
  } catch { /* The connection is expected to fail while the host reboots. */ }
  setTimeout(() => waitForReboot(previousBoot), 5000);
}

document.querySelector('#server-journal').addEventListener('click', () => openJournal('server', 'System journal'));
document.querySelector('#server-reboot').addEventListener('click', async event => {
  if (!bootId || rebooting || !confirm('Reboot the entire server? All services and active connections will be interrupted.')) return;
  const button = event.currentTarget;
  const message = document.querySelector('#server-message');
  const previousBoot = bootId;
  button.disabled = true;
  rebooting = true;
  message.classList.remove('error');
  message.textContent = 'Rebooting… Waiting for the server to return.';
  try {
    await api('reboot', null, { method: 'POST', headers: { 'X-CSRF-Token': csrf }, signal: AbortSignal.timeout(10000) });
  } catch (error) {
    // A reboot may sever the request before its acknowledgement reaches the browser.
    if (!(error instanceof TypeError) && error.name !== 'TimeoutError' && error.name !== 'SyntaxError') {
      rebooting = false;
      button.disabled = false;
      message.textContent = error.message;
      message.classList.add('error');
      return;
    }
    message.textContent = 'Connection lost. Waiting for the server to return…';
  }
  stream?.close();
  stream = null;
  setTimeout(() => waitForReboot(previousBoot), 5000);
});

cards.forEach(card => {
  card.querySelector('.restart-button').addEventListener('click', async event => {
    const button = event.currentTarget;
    const id = card.dataset.service;
    const name = card.querySelector('.service-name').textContent;
    if (!confirm(`Restart ${name}? Active connections may be interrupted.`)) return;
    const message = card.querySelector('.action-message');
    button.disabled = true;
    restarts.set(id, { completedAt: null });
    message.classList.remove('error');
    message.textContent = 'Restarting…';
    paintStatus(card, null, 'Restarting');
    try {
      const result = await api('restart', id, { method: 'POST', headers: { 'X-CSRF-Token': csrf }, signal: AbortSignal.timeout(10000) });
      restarts.set(id, { completedAt: result.completedAt });
      message.textContent = result.message;
    } catch (error) {
      restarts.delete(id);
      message.textContent = error.message;
      message.classList.add('error');
    } finally {
      setTimeout(() => { button.disabled = false; }, 10000);
    }
  });
  card.querySelector('.logs-button').addEventListener('click', () => {
    openJournal(card.dataset.service, `${card.querySelector('.service-name').textContent} logs`);
  });
});
document.querySelector('#close-logs').addEventListener('click', () => modal.close());
modal.addEventListener('click', event => {
  if (event.target === modal) {
    const rect = modal.getBoundingClientRect();
    if (event.clientX < rect.left || event.clientX > rect.right || event.clientY < rect.top || event.clientY > rect.bottom) modal.close();
  }
});
modal.addEventListener('close', () => {
  activeLogService = null;
  logCursor = '';
  logEntries = [];
  if (!rebooting) connectStream();
});
document.querySelector('#refresh-logs').addEventListener('click', refreshLogs);
document.querySelector('#logs-follow').addEventListener('change', event => {
  if (event.currentTarget.checked) logOutput.scrollTop = logOutput.scrollHeight;
});
window.addEventListener('pagehide', () => { stream?.close(); stream = null; });
window.addEventListener('pageshow', () => { if (!stream && !rebooting) connectStream(); });
connectStream();
