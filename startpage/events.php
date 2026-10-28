<?php
declare(strict_types=1);

function dataDiskUsage(): ?array {
    // Each SSE connection reuses its sample for 30 seconds.
    static $checkedAt = 0;
    static $usage = null;
    if (microtime(true) - $checkedAt < 30) { return $usage; }
    $checkedAt = microtime(true);
    $total = @disk_total_space('/data');
    $free = @disk_free_space('/data');
    $usage = $total !== false && $total > 0 && $free !== false
        ? ['total' => $total, 'used' => max(0, $total - $free)] : null;
    return $usage;
}

function serviceStates(): array {
    global $services;
    $sampledAt = microtime(true);
    [$code, $output] = runCommand(array_merge(['systemctl', 'show', '--no-pager', '--property=Id,ActiveState,SubState,LoadState'], array_column($services, 'serviceName')));
    if ($code !== 0) { return ['error' => 'Could not read service states.']; }
    $states = [];
    foreach (preg_split('/\n\s*\n/', trim($output)) as $block) {
        $properties = [];
        foreach (explode("\n", $block) as $line) {
            if (str_contains($line, '=')) { [$key, $value] = explode('=', $line, 2); $properties[$key] = $value; }
        }
        if (isset($properties['Id'])) { $states[$properties['Id']] = $properties; }
    }
    $result = [];
    foreach ($services as $key => $service) {
        $state = $states[$service['serviceName']] ?? [];
        $result[$key] = ['running' => ($state['ActiveState'] ?? '') === 'active', 'state' => $state['ActiveState'] ?? 'unknown', 'detail' => ($state['LoadState'] ?? '') === 'not-found' ? 'Unit not found' : ($state['SubState'] ?? 'Unknown')];
    }
    return ['services' => $result, 'disk' => dataDiskUsage(), 'bootId' => trim(file_get_contents('/proc/sys/kernel/random/boot_id')), 'sampledAt' => $sampledAt, 'updated' => gmdate('c')];
}

function sendEvent(string $event, array $data, ?string $cursor = null): void {
    if ($cursor !== null) { echo 'id: ' . $cursor . "\n"; }
    echo 'event: ' . $event . "\ndata: " . json_encode($data, JSON_INVALID_UTF8_SUBSTITUTE | JSON_THROW_ON_ERROR) . "\n\n";
    flush();
}

function journalText(mixed $value): string {
    if (is_string($value)) { return $value; }
    // journalctl encodes binary values as byte arrays, repeated fields as arrays.
    if (is_array($value)) {
        if (count(array_filter($value, 'is_int')) === count($value)) { return implode('', array_map('chr', $value)); }
        return implode("\n", array_map('journalText', $value));
    }
    return '';
}

function streamEvents(string $id, string $cursor): never {
    global $services;
    header('Content-Type: text/event-stream');
    header('Cache-Control: no-store, no-transform');
    ini_set('zlib.output_compression', '0');
    while (ob_get_level() > 0) { ob_end_flush(); }
    set_time_limit(0);
    ignore_user_abort(true);
    echo "retry: 2000\n\n";
    flush();
    $process = null;
    $pipes = [];
    $cleanup = static function () use (&$process, &$pipes): void {
        if (!is_resource($process)) { return; }
        proc_terminate($process);
        foreach ($pipes as $pipe) { if (is_resource($pipe)) { fclose($pipe); } }
        // journalctl normally exits on SIGTERM; bound cleanup even for a stuck child.
        $until = microtime(true) + 1.2;
        while (proc_get_status($process)['running'] && microtime(true) < $until) { usleep(10000); }
        if (proc_get_status($process)['running']) { proc_terminate($process, 9); }
        proc_close($process);
        $process = null;
    };
    register_shutdown_function($cleanup);
    try {
        if ($id !== '') {
            $args = ['journalctl', '--follow', '--no-pager', '--output=json', '--output-fields=MESSAGE,_HOSTNAME,SYSLOG_IDENTIFIER,_COMM,_PID', '--quiet', '--all'];
            if ($id !== 'server') { $args[] = '--unit=' . $services[$id]['serviceName']; }
            $args[] = $cursor === '' ? '--lines=120' : '--lines=all';
            if ($cursor !== '') { $args[] = '--after-cursor=' . $cursor; }
            // An independent watchdog also bounds the child's lifetime if PHP is killed.
            $args = array_merge(['timeout', '--signal=TERM', '--kill-after=1s', '300s'], $args);
            $process = proc_open($args, [0 => ['file', '/dev/null', 'r'], 1 => ['pipe', 'w'], 2 => ['pipe', 'w']], $pipes);
            if (!is_resource($process)) { sendEvent('log-error', ['error' => 'Could not start the journal.']); exit; }
            foreach ($pipes as $pipe) { stream_set_blocking($pipe, false); }
            sendEvent('ready', []);
        }
        $nextStatus = 0;
        $buffer = '';
        // Rotate connections periodically so FPM workers are not held indefinitely.
        // EventSource resumes the journal from its last delivered cursor.
        $deadline = microtime(true) + 300;
        while (!connection_aborted() && microtime(true) < $deadline) {
            if (microtime(true) >= $nextStatus) {
                $state = serviceStates();
                sendEvent(isset($state['error']) ? 'status-error' : 'status', $state);
                $nextStatus = microtime(true) + 1;
                if (connection_aborted()) { break; }
            }
            if ($id === '') { usleep(100000); continue; }
            $read = array_values(array_filter($pipes, fn($pipe) => !feof($pipe)));
            $write = $except = null;
            if ($read && stream_select($read, $write, $except, 0, 100000) > 0) {
                foreach ($read as $pipe) {
                    $chunk = fread($pipe, 65536);
                    if ($pipe !== $pipes[1]) { continue; } // Drain stderr without leaking command details.
                    $buffer .= $chunk;
                    while (($end = strpos($buffer, "\n")) !== false) {
                        $line = substr($buffer, 0, $end);
                        $buffer = substr($buffer, $end + 1);
                        $entry = json_decode($line, true);
                        if (!is_array($entry) || !is_string($entry['__CURSOR'] ?? null)) { continue; }
                        $stamp = gmdate('Y-m-d\TH:i:s\Z', (int) ((int) ($entry['__REALTIME_TIMESTAMP'] ?? 0) / 1000000));
                        $source = journalText($entry['SYSLOG_IDENTIFIER'] ?? $entry['_COMM'] ?? '');
                        $pid = journalText($entry['_PID'] ?? '');
                        if ($pid !== '') { $source .= '[' . $pid . ']'; }
                        $text = $stamp . ' ' . journalText($entry['_HOSTNAME'] ?? '') . ' ' . $source . ': ' . journalText($entry['MESSAGE'] ?? '');
                        sendEvent('log', ['text' => substr(plainLogText($text), -131072) . "\n"], str_replace(["\r", "\n", "\0"], '', $entry['__CURSOR']));
                    }
                    if (strlen($buffer) > 1048576) { sendEvent('log-error', ['error' => 'Journal entry exceeds the display limit.']); break 2; }
                }
            }
            if (feof($pipes[1]) && feof($pipes[2])) {
                sendEvent('log-error', ['error' => 'Journal stream ended. Reconnecting…']);
                break;
            }
        }
    } finally {
        $cleanup();
    }
    exit;
}
