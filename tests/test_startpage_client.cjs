// Exercise real client code with controlled events, requests, and a tiny DOM.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

function page(confirmResult = true) {
  class Element {
    constructor() { this.listeners = {}; this.textContent = ''; this.scrollTop = 0; this.scrollHeight = 100; this.checked = true; this.classes = new Set(); this.classList = { add: name => this.classes.add(name), remove: name => this.classes.delete(name) }; }
    addEventListener(type, fn) { this.listeners[type] = fn; }
    emit(type) { return this.listeners[type]?.({ currentTarget: this, target: this }); }
    setAttribute(name, value) { this[name] = value; }
    append(node) { this.textContent += node.textContent; }
    showModal() { this.open = true; }
    close() { this.open = false; this.emit('close'); }
  }
  const selectors = ['.status', '.status-text', '.action-message', '.restart-button', '.logs-button', '.service-name'];
  const parts = Object.fromEntries(selectors.map(name => [name, new Element()]));
  parts['.service-name'].textContent = 'Jellyfin';
  const card = { dataset: { service: 'jellyfin' }, querySelector: name => parts[name] };
  const ids = Object.fromEntries(['#logs-modal', '#log-output', '#logs-state', '#logs-title', '#logs-follow', '#refresh-logs', '#close-logs', '#server-journal', '#server-reboot', '#server-message'].map(name => [name, new Element()]));
  const sources = [];
  class Source {
    constructor(url) { this.url = url; this.listeners = {}; sources.push(this); }
    addEventListener(type, fn) { this.listeners[type] = fn; }
    emit(type, data = {}, lastEventId = '') { this.listeners[type]?.({ data: JSON.stringify(data), lastEventId }); }
    close() { this.closed = true; }
  }
  let resolveRestart;
  const requests = [];
  const window = new Element();
  let reloads = 0;
  window.location = { reload: () => { reloads++; } };
  const timers = [];
  vm.runInNewContext(fs.readFileSync('startpage/app.js', 'utf8'), {
    document: { querySelectorAll: () => [card], querySelector: name => name.includes('csrf-token') ? { content: 'token' } : ids[name], createTextNode: textContent => ({ textContent }) },
    window, EventSource: Source, URLSearchParams, AbortSignal, confirm: () => confirmResult,
    setTimeout: (fn, delay) => { timers.push({ fn, delay }); return timers.length; }, getComputedStyle: () => ({ lineHeight: '20' }),
    fetch: (url, options) => { requests.push({ url, options }); return new Promise(resolve => { resolveRestart = body => resolve({ ok: true, json: async () => body }); }); },
  });
  const status = (state, sampledAt) => ({ bootId: 'boot-before', sampledAt, services: { jellyfin: { state, running: state === 'active', detail: state } } });
  return { parts, ids, sources, window, requests, status, timers, reloads: () => reloads, resolve: body => resolveRestart(body) };
}

test('restart ignores stale active events and clears message on streamed recovery', async () => {
  const p = page();
  const stream = p.sources[0];
  stream.emit('status', p.status('active', 1));
  assert.equal(p.parts['.status-text'].textContent, 'Running');
  const restart = p.parts['.restart-button'].emit('click');
  assert.equal(p.parts['.status-text'].textContent, 'Restarting');
  stream.emit('status', p.status('active', 2));
  assert.equal(p.parts['.action-message'].textContent, 'Restarting…');
  p.resolve({ completedAt: 3, message: 'Waiting for service…' });
  await restart;
  stream.emit('status', p.status('active', 2.5));
  assert.equal(p.parts['.action-message'].textContent, 'Waiting for service…');
  stream.emit('status', p.status('activating', 4));
  assert.equal(p.parts['.status-text'].textContent, 'activating');
  stream.emit('status', p.status('active', 5));
  assert.equal(p.parts['.status-text'].textContent, 'Running');
  assert.equal(p.parts['.action-message'].textContent, '');
  assert.equal(p.requests.length, 1);
  assert.equal(p.requests[0].options.method, 'POST');
});

test('failed restart is reported, disconnected state recovers through SSE', async () => {
  const p = page();
  const restart = p.parts['.restart-button'].emit('click');
  p.resolve({ completedAt: 3, message: 'Waiting for service…' });
  await restart;
  p.sources[0].emit('status', p.status('failed', 4));
  assert.match(p.parts['.action-message'].textContent, /failed/);
  p.sources[0].emit('error');
  assert.equal(p.parts['.status-text'].textContent, 'Reconnecting');
  p.sources[0].emit('status', p.status('active', 5));
  assert.equal(p.parts['.status-text'].textContent, 'Running');
});

test('one stream, safe incremental logs, bounded buffer, follow and cleanup', () => {
  const p = page();
  p.parts['.logs-button'].emit('click');
  assert.equal(p.sources[0].closed, true);
  const logs = p.sources[1];
  assert.match(logs.url, /service=jellyfin/);
  logs.emit('log', { text: '<script>hello</script>\n' }, 'one');
  assert.equal(p.ids['#log-output'].textContent, '<script>hello</script>\n');
  logs.emit('log', { text: 'duplicate\n' }, 'one');
  assert.doesNotMatch(p.ids['#log-output'].textContent, /duplicate/);
  p.ids['#logs-follow'].checked = false;
  p.ids['#log-output'].scrollTop = 20;
  logs.emit('log', { text: 'second\n' }, 'two');
  assert.equal(p.ids['#log-output'].scrollTop, 20);
  for (let i = 0; i < 121; i++) logs.emit('log', { text: `entry ${i}\n` }, `cursor-${i}`);
  assert.equal(p.ids['#log-output'].textContent.split('\n').length - 1, 120);
  assert.doesNotMatch(p.ids['#log-output'].textContent, /hello/);
  p.ids['#logs-follow'].checked = true;
  p.ids['#logs-follow'].emit('change');
  assert.equal(p.ids['#log-output'].scrollTop, 100);
  p.ids['#logs-modal'].close();
  assert.equal(logs.closed, true);
  assert.doesNotMatch(p.sources[2].url, /service=/);
  logs.emit('status', p.status('failed', 100));
  assert.notEqual(p.parts['.status-text'].textContent, 'failed');
  p.window.emit('pagehide');
  assert.equal(p.sources[2].closed, true);
  p.window.emit('pageshow');
  assert.equal(p.sources.length, 4);
});


test('server journal uses the same stream without a service unit', () => {
  const p = page();
  p.ids['#server-journal'].emit('click');
  assert.equal(p.sources[0].closed, true);
  assert.match(p.sources[1].url, /service=server/);
  assert.equal(p.ids['#logs-title'].textContent, 'System journal');
  p.ids['#logs-modal'].close();
  assert.equal(p.sources[1].closed, true);
});

test('reboot requires confirmation, then checks every five seconds and reloads after a new boot', async () => {
  const cancelled = page(false);
  cancelled.sources[0].emit('status', cancelled.status('active', 1));
  await cancelled.ids['#server-reboot'].emit('click');
  assert.equal(cancelled.requests.length, 0);
  const p = page();
  p.sources[0].emit('status', p.status('active', 1));
  const reboot = p.ids['#server-reboot'].emit('click');
  assert.equal(p.requests[0].url, '/?action=reboot');
  assert.equal(p.requests[0].options.method, 'POST');
  assert.equal(p.requests[0].options.headers['X-CSRF-Token'], 'token');
  p.resolve({ message: 'Rebooting' });
  await reboot;
  assert.equal(p.sources[0].closed, true);
  assert.equal(p.timers[0].delay, 5000);
  const waiting = p.timers.shift().fn();
  p.resolve(p.status('active', 2));
  await waiting;
  assert.equal(p.reloads(), 0);
  assert.equal(p.timers[0].delay, 5000);
  const recovered = p.timers.shift().fn();
  p.resolve({ ...p.status('active', 3), bootId: 'boot-after' });
  await recovered;
  assert.equal(p.reloads(), 1);
});
