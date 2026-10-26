<?php
 declare(strict_types=1);

header('Cache-Control: no-store');
header('X-Content-Type-Options: nosniff');
header('Referrer-Policy: same-origin');
header("Content-Security-Policy: default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data: https:; frame-ancestors 'none'; base-uri 'none'; form-action 'self'");
session_name('homelab');
session_start(['cookie_httponly' => true, 'cookie_samesite' => 'Strict', 'cookie_secure' => !empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off', 'use_strict_mode' => true]);
$_SESSION['csrf'] ??= bin2hex(random_bytes(32));
$csrf = $_SESSION['csrf'];
$inventoryPath = getenv('HOMELAB_CONFIG') ?: '/etc/service-inventory.json';
// Tests can supply an isolated inventory; commands are resolved through PATH.
$services = json_decode(file_get_contents($inventoryPath), true, 512, JSON_THROW_ON_ERROR);
uasort($services, fn($a, $b) => ($a['order'] ?? 100) <=> ($b['order'] ?? 100));

function respond(array $body, int $status = 200): never {
    http_response_code($status);
    header('Content-Type: application/json');
    echo json_encode($body, JSON_INVALID_UTF8_SUBSTITUTE | JSON_THROW_ON_ERROR);
    exit;
}

function plainLogText(string $output): string {
    // Strip OSC sequences (including hyperlinks), CSI sequences (colours/cursor
    // controls), and remaining two-byte terminal escapes before displaying text.
    $output = preg_replace('/\x1B\][^\x07\x1B]*(?:\x07|\x1B\\\\)/', '', $output);
    $output = preg_replace('/\x1B\[[0-?]*[ -\/]*[@-~]/', '', $output);
    $output = preg_replace('/\x1B[@-Z\\\\-_]/', '', $output);
    return preg_replace('/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/', '', $output);
}

// Array arguments bypass the shell. Binaries and units come from config, never the request.
function runCommand(array $args): array {
    $process = proc_open(array_merge(['timeout', '--signal=TERM', '--kill-after=1s', '5s'], $args), [0 => ['file', '/dev/null', 'r'], 1 => ['pipe', 'w'], 2 => ['pipe', 'w']], $pipes);
    if (!is_resource($process)) {
        return [1, '', 'Could not start command.'];
    }
    // Outputs are bounded by the commands below; consume both streams to avoid pipe deadlocks.
    stream_set_blocking($pipes[1], false);
    stream_set_blocking($pipes[2], false);
    $out = $err = '';
    while (!feof($pipes[1]) || !feof($pipes[2])) {
        $read = array_values(array_filter([$pipes[1], $pipes[2]], fn($pipe) => !feof($pipe)));
        $write = $except = null;
        if ($read && stream_select($read, $write, $except, 1) > 0) {
            foreach ($read as $pipe) {
                $chunk = stream_get_contents($pipe);
                if ($pipe === $pipes[1]) { $out .= $chunk; } else { $err .= $chunk; }
            }
        }
    }
    fclose($pipes[1]);
    fclose($pipes[2]);
    return [proc_close($process), $out, $err];
}

require __DIR__ . '/events.php';

if (isset($_GET['action'])) {
    $action = $_GET['action'];
    if (!in_array($action, ['status', 'logs', 'restart', 'events', 'reboot'], true)) { respond(['error' => 'Unknown action.'], 404); }
    $mutation = in_array($action, ['restart', 'reboot'], true);
    if ($_SERVER['REQUEST_METHOD'] !== ($mutation ? 'POST' : 'GET')) {
        header('Allow: ' . ($mutation ? 'POST' : 'GET'));
        respond(['error' => 'Method not allowed.'], 405);
    }
    if ($mutation && !hash_equals($csrf, $_SERVER['HTTP_X_CSRF_TOKEN'] ?? '')) {
        respond(['error' => 'Session expired. Reload the page and try again.'], 403);
    }
    $id = $_GET['service'] ?? '';
    $serverJournal = $id === 'server' && in_array($action, ['events', 'logs'], true);
    if (!is_string($id) || ($action === 'reboot' ? $id !== '' : ($action !== 'status' && !($action === 'events' && $id === '') && !$serverJournal && !isset($services[$id])))) {
        respond(['error' => 'Unknown service.'], 404);
    }
    if ($action === 'restart') {
        $last = $_SESSION['restart'][$id] ?? 0;
        if (time() - $last < 10) { respond(['error' => 'Please wait before restarting again.'], 429); }
        $_SESSION['restart'][$id] = time();
    }
    if ($action === 'reboot') {
        if (time() - ($_SESSION['reboot'] ?? 0) < 60) { respond(['error' => 'A reboot was recently requested. Please wait.'], 429); }
        $_SESSION['reboot'] = time();
    }
    session_write_close();
    if ($action === 'reboot') {
        [$code] = runCommand(['sudo', '-n', 'systemctl', '--no-block', 'reboot']);
        if ($code !== 0) { respond(['error' => 'Reboot could not be queued. Check the dashboard permissions.'], 503); }
        respond(['message' => 'Rebooting… Waiting for the server to return.']);
    }
    if ($action === 'events') {
        $cursor = $_SERVER['HTTP_LAST_EVENT_ID'] ?? ($_GET['cursor'] ?? '');
        if (!is_string($cursor) || strlen($cursor) > 4096 || preg_match('/[\x00-\x20\x7f]/', $cursor)) {
            respond(['error' => 'Invalid journal cursor.'], 400);
        }
        streamEvents($id, $cursor);
    }
    if ($action === 'status') {
        $state = serviceStates();
        respond($state, isset($state['error']) ? 503 : 200);
    }
    if ($action === 'logs') {
        $args = ['journalctl', '--lines=120', '--no-pager', '--output=short-iso', '--quiet', '--all'];
        if (!$serverJournal) { $args[] = '--unit=' . $services[$id]['serviceName']; }
        [$code, $output] = runCommand($args);
        if ($code !== 0) { respond(['error' => 'Could not read the journal.'], 503); }
        respond(['logs' => substr(plainLogText($output), -131072) ?: 'No journal entries for this service.']);
    }
    [$code] = runCommand(['sudo', '-n', 'systemctl', 'restart', $services[$id]['serviceName']]);
    if ($code !== 0) { respond(['error' => 'Restart could not be queued. Check the dashboard permissions.'], 503); }
    respond(['message' => 'Waiting for service…', 'completedAt' => microtime(true)]);
}
session_write_close();
function webUrl(string $url): string {
    // Inventory hostnames are also used by Caddy, so they need no scheme there.
    if (str_starts_with($url, '/') || preg_match('~^(?:https?://|data:)~i', $url)) { return $url; }
    return 'https://' . $url;
}
function esc(string $text): string { return htmlspecialchars($text, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8'); }
?>
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="color-scheme" content="dark">
  <meta name="csrf-token" content="<?= esc($csrf) ?>">
  <title>Home / Nixie</title>
  <link rel="stylesheet" href="/style.css?v=<?= filemtime(__DIR__ . '/style.css') ?>">
  <script src="/app.js?v=<?= filemtime(__DIR__ . '/app.js') ?>" defer></script>
</head>
<body>
  <div class="shell">
    <main>
      <noscript><p class="notice">Enable JavaScript to see live status, restart services, and view logs.</p></noscript>
      <section class="cards" aria-label="Homelab services">
      <?php foreach ($services as $id => $service): ?>
        <article class="card" data-service="<?= esc($id) ?>">
          <a class="service-link" href="<?= esc(webUrl($service['url'])) ?>">
            <span class="service-icon"><?php if (isset($service['icon']['url'])): ?><img src="<?= esc(webUrl($service['icon']['url'])) ?>" alt="" width="32" height="32"><?php else: ?><?= $service['icon']['html'] ?><?php endif; ?></span>
            <span class="service-name"><?= esc($service['name']) ?></span>
          </a>
          <div class="card-footer">
            <span class="service-state"><span class="status unknown" role="img" aria-label="Status unknown" title="Checking status"></span><span class="status-text">Checking</span></span>
            <div class="button-row">
              <button class="logs-button icon-button" type="button" aria-label="View <?= esc($service['name']) ?> logs" title="View logs"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="m5 7 4 5-4 5M13 17h6"/></svg></button>
              <button class="restart-button icon-button" type="button" aria-label="Restart <?= esc($service['name']) ?>" title="Restart service"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M19 10a7 7 0 1 0-1 7M19 4v6h-6"/></svg></button>
            </div>
          </div>
          <p class="action-message" role="status"></p>
        </article>
      <?php endforeach; ?>
      </section>
      <section class="server-controls" aria-label="Server controls">
        <span class="server-label">Server</span>
        <div class="button-row">
          <button id="server-journal" type="button"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="m5 7 4 5-4 5M13 17h6"/></svg>Journal</button>
          <button id="server-reboot" disabled class="restart-button" type="button"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M19 10a7 7 0 1 0-1 7M19 4v6h-6"/></svg>Reboot</button>
        </div>
        <p id="server-message" class="action-message" role="status"></p>
      </section>
    </main>
  </div>
  <dialog id="logs-modal" aria-labelledby="logs-title">
    <div class="modal-header">
      <h2 id="logs-title">Logs</h2>
      <div class="log-controls">
        <label><input type="checkbox" id="logs-follow" checked> Follow</label>
        <button id="refresh-logs" class="icon-button" type="button" aria-label="Refresh logs" title="Refresh logs"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M19 10a7 7 0 1 0-1 7M19 4v6h-6"/></svg></button>
        <button id="close-logs" class="icon-button" type="button" aria-label="Close logs" title="Close logs"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="m6 6 12 12M6 18 18 6"/></svg></button>
      </div>
    </div>
    <pre id="log-output" tabindex="0" aria-label="Recent journal entries"></pre>
    <div class="modal-footer"><span id="logs-state" role="status">Connecting…</span><span>Last 120 entries</span></div>
  </dialog>
</body>
</html>
