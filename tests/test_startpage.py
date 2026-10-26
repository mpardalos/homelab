"""Exercise the PHP API with fake system commands; never touches real services."""
import http.cookiejar
import json
import os
from pathlib import Path
import re
import shutil
import signal
import socket
import subprocess
import tempfile
import time
import unittest
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parents[1]


class DashboardTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory()
        cls.work = Path(cls.temp.name)
        cls.calls = cls.work / "calls"
        cls.mode = cls.work / "mode"
        cls.mode.write_text("")
        fake = cls.work / "command"
        fake.write_text(f'''#!{os.sys.executable}
import json, pathlib, sys, time, os
args = sys.argv[1:]
with open({str(cls.calls)!r}, 'a') as f: f.write(json.dumps(args) + '\\n')
mode = pathlib.Path({str(cls.mode)!r}).read_text()
if mode == 'failure': sys.exit(1)
if '--follow' in args:
    pathlib.Path({str(cls.work / 'journal.pid')!r}).write_text(str(os.getpid()))
    resumed = any(arg.startswith('--after-cursor=') for arg in args)
    for number in ([2] if resumed else [1, 2]):
        print(json.dumps({{'__CURSOR': f'cursor-{{number}}', '__REALTIME_TIMESTAMP': '1793016000000000', '_HOSTNAME': 'nixie', 'SYSLOG_IDENTIFIER': 'test', 'MESSAGE': chr(27) + '[32m<script>entry ' + str(number) + '</script>' + chr(27) + '[0m'}}), flush=True)
        time.sleep(0.15)
    while True: time.sleep(0.1)
if 'show' in args:
    if mode == 'stopped':
        print('Id=jellyfin.service\\nActiveState=inactive\\nSubState=dead\\nLoadState=loaded\\n')
        sys.exit(0)
    print('Id=jellyfin.service\\nActiveState=active\\nSubState=running\\nLoadState=loaded\\n')
    print('Id=stopped.service\\nActiveState=failed\\nSubState=failed\\nLoadState=loaded\\n')
elif '--output=short-iso' in args:
    if mode == 'ansi':
        esc = chr(27)
        print(esc + '[34mINFO' + esc + '[0m message [literal] 日本語')
        print(esc + ']8;;https://example.com' + chr(7) + 'link' + esc + ']8;;' + esc + chr(92))
        print('column' + chr(9) + 'value' + esc + '[2K')
        sys.exit(0)
    print('2026-10-26T12:00:00+00:00 nixie <script>alert("test")</script>')
''')
        fake.chmod(0o755)
        for command in ('systemctl', 'journalctl', 'sudo'):
            (cls.work / command).symlink_to(fake)
        timeout = shutil.which('timeout')
        assert timeout, 'timeout must be in PATH'
        (cls.work / 'timeout').symlink_to(timeout)
        config = {
            "jellyfin": {"name": "Jellyfin", "serviceName": "jellyfin.service", "icon": {"url": "jellyfin.home.mpardalos.com/favicon.ico"}, "order": 20, "url": "jellyfin.home.mpardalos.com", "port": 8096},
            "stopped": {"name": "Stopped", "serviceName": "stopped.service", "icon": {"html": '<svg aria-hidden="true"><path d="M0 0"/></svg>'}, "order": 10, "url": "https://example.com", "port": 8080},
        }
        config_path = cls.work / "config.json"
        config_path.write_text(json.dumps(config))
        with socket.socket() as sock:
            sock.bind(("127.0.0.1", 0))
            port = sock.getsockname()[1]
        cls.base = f"http://127.0.0.1:{port}"
        cls.log = (cls.work / "php.log").open("w+")
        cls.server = subprocess.Popen(
            [os.environ.get("PHP_BINARY", "php"), "-d", f"session.save_path={cls.work}", "-S", f"127.0.0.1:{port}", "-t", str(ROOT / "startpage")],
            env={**os.environ, "HOMELAB_CONFIG": str(config_path), "PHP_CLI_SERVER_WORKERS": "2", "PATH": str(cls.work)}, stdout=cls.log, stderr=cls.log, start_new_session=True,
        )
        for _ in range(100):
            try:
                urllib.request.urlopen(cls.base, timeout=1).close()
                break
            except OSError:
                if cls.server.poll() is not None:
                    cls.log.seek(0)
                    raise RuntimeError(cls.log.read())
                time.sleep(0.05)
        else:
            raise RuntimeError("PHP server did not start")

    @classmethod
    def tearDownClass(cls):
        os.killpg(cls.server.pid, signal.SIGTERM)
        cls.server.wait(timeout=5)
        cls.log.close()
        cls.temp.cleanup()

    def setUp(self):
        self.mode.write_text("")
        self.opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
        self.page = self.opener.open(self.base).read().decode()
        self.token = re.search(r'name="csrf-token" content="([a-f0-9]+)"', self.page)[1]

    def request(self, query, method="GET", token=None):
        headers = {"X-CSRF-Token": token} if token else {}
        req = urllib.request.Request(self.base + "/?" + query, method=method, headers=headers)
        try:
            response = self.opener.open(req)
        except urllib.error.HTTPError as error:
            response = error
        return response.status, json.loads(response.read())

    def test_page_and_headers(self):
        self.assertIn('src="https://jellyfin.home.mpardalos.com/favicon.ico"', self.page)
        self.assertIn('href="https://jellyfin.home.mpardalos.com"', self.page)
        self.assertIn('aria-label="View Jellyfin logs"', self.page)
        self.assertIn('aria-label="Restart Jellyfin"', self.page)
        self.assertIn('<dialog', self.page)
        response = self.opener.open(self.base)
        self.assertIn('no-store', response.headers['Cache-Control'])
        self.assertIn("frame-ancestors 'none'", response.headers['Content-Security-Policy'])

    def test_generated_inventory_controls_labels_icons_and_order(self):
        self.assertLess(self.page.index('data-service="stopped"'), self.page.index('data-service="jellyfin"'))
        self.assertIn('<svg aria-hidden="true"><path d="M0 0"/></svg>', self.page)
        self.assertIn('href="https://example.com"', self.page)
        self.assertIn('>Stopped</span>', self.page)

    def test_status(self):
        status, body = self.request("action=status")
        self.assertEqual(status, 200)
        self.assertTrue(body['services']['jellyfin']['running'])
        self.assertFalse(body['services']['stopped']['running'])

    def test_restart_requires_post(self):
        self.assertEqual(self.request("action=restart&service=jellyfin")[0], 405)

    def test_restart_requires_csrf(self):
        for token in (None, "invalid"):
            self.assertEqual(self.request("action=restart&service=jellyfin", "POST", token)[0], 403)

    def test_restart_and_cooldown(self):
        self.assertEqual(self.request("action=restart&service=jellyfin", "POST", self.token)[0], 200)
        self.assertEqual(self.request("action=restart&service=jellyfin", "POST", self.token)[0], 429)
        args = json.loads(self.calls.read_text().splitlines()[-1])
        self.assertEqual(args[-2:], ['restart', 'jellyfin.service'])

    def test_unknown_and_injected_units(self):
        for service in ("other", "jellyfin.service", "jellyfin%3Btouch%20%2Ftmp%2Foops", "../jellyfin"):
            self.assertEqual(self.request(f"action=logs&service={service}")[0], 404)
            self.assertEqual(self.request(f"action=restart&service={service}", "POST", self.token)[0], 404)

    def test_logs_preserve_text(self):
        status, body = self.request("action=logs&service=jellyfin")
        self.assertEqual(status, 200)
        self.assertIn('<script>', body['logs'])


    def test_command_failures(self):
        self.mode.write_text('failure')
        self.assertEqual(self.request('action=status')[0], 503)
        self.assertEqual(self.request('action=logs&service=jellyfin')[0], 503)
        self.assertEqual(self.request('action=restart&service=jellyfin', 'POST', self.token)[0], 503)

    def test_logs_strip_terminal_controls(self):
        self.mode.write_text('ansi')
        status, body = self.request('action=logs&service=jellyfin')
        self.assertEqual(status, 200)
        self.assertEqual(body['logs'], 'INFO message [literal] 日本語\nlink\ncolumn\tvalue\n')

    def stream_event(self, response, kind):
        event = None
        cursor = None
        for _ in range(100):
            line = response.readline().decode().rstrip('\n')
            if line.startswith('event: '): event = line[7:]
            if line.startswith('id: '): cursor = line[4:]
            if line.startswith('data: ') and event == kind:
                return json.loads(line[6:]), cursor
        self.fail(f'Missing {kind} event')

    def test_status_stream_changes_and_releases_session(self):
        with self.opener.open(self.base + '/?action=events', timeout=8) as response:
            self.assertEqual(response.headers['Content-Type'], 'text/event-stream;charset=UTF-8')
            first, _ = self.stream_event(response, 'status')
            self.assertTrue(first['services']['jellyfin']['running'])
            # The same session can issue a restart while its event stream is open.
            status, restart = self.request('action=restart&service=jellyfin', 'POST', self.token)
            self.assertEqual(status, 200)
            self.assertGreater(restart['completedAt'], first['sampledAt'])
            self.mode.write_text('stopped')
            stopped, _ = self.stream_event(response, 'status')
            self.assertFalse(stopped['services']['jellyfin']['running'])
            self.mode.write_text('')
            recovered, _ = self.stream_event(response, 'status')
            self.assertTrue(recovered['services']['jellyfin']['running'])
            self.assertGreater(recovered['sampledAt'], restart['completedAt'])

    def test_journal_follow_resume_and_cleanup(self):
        before = len(self.calls.read_text().splitlines()) if self.calls.exists() else 0
        with self.opener.open(self.base + '/?action=events&service=jellyfin', timeout=8) as response:
            first, cursor = self.stream_event(response, 'log')
            self.assertEqual(cursor, 'cursor-1')
            self.assertIn('<script>entry 1</script>', first['text'])
            self.assertNotIn(chr(27), first['text'])
            second, cursor = self.stream_event(response, 'log')
            self.assertEqual(cursor, 'cursor-2')
            self.assertIn('entry 2', second['text'])
        pid = int((self.work / 'journal.pid').read_text())
        for _ in range(60):
            try: os.kill(pid, 0)
            except ProcessLookupError: break
            time.sleep(0.1)
        else: self.fail('Journal process survived client disconnect')
        calls = [json.loads(line) for line in self.calls.read_text().splitlines()[before:]]
        self.assertEqual(sum('--follow' in args for args in calls), 1)
        req = urllib.request.Request(self.base + '/?action=events&service=jellyfin', headers={'Last-Event-ID': 'cursor-1'})
        with self.opener.open(req, timeout=8) as response:
            entry, cursor = self.stream_event(response, 'log')
            self.assertEqual(cursor, 'cursor-2')
        calls = [json.loads(line) for line in self.calls.read_text().splitlines()]
        self.assertTrue(any('--after-cursor=cursor-1' in args for args in calls))

    def test_stream_validation_and_failures(self):
        self.assertEqual(self.request('action=events&service=other')[0], 404)
        self.assertEqual(self.request('action=events&cursor[]=bad')[0], 400)
        self.assertEqual(self.request('action=events&cursor=bad%0Acursor')[0], 400)
        self.assertEqual(self.request('action=events', 'POST')[0], 405)
        self.mode.write_text('failure')
        with self.opener.open(self.base + '/?action=events&service=jellyfin', timeout=8) as response:
            event, _ = self.stream_event(response, 'status-error')
            self.assertIn('error', event)
            event, _ = self.stream_event(response, 'log-error')
            self.assertIn('error', event)

    def test_reboot_requires_post_csrf_and_no_service(self):
        self.assertEqual(self.request('action=reboot')[0], 405)
        self.assertEqual(self.request('action=reboot', 'POST')[0], 403)
        self.assertEqual(self.request('action=reboot', 'POST', 'invalid')[0], 403)
        self.assertEqual(self.request('action=reboot&service=jellyfin', 'POST', self.token)[0], 404)
        self.assertEqual(self.request('action=restart&service=server', 'POST', self.token)[0], 404)

    def test_reboot_queues_only_fixed_command_and_has_cooldown(self):
        status, body = self.request('action=reboot', 'POST', self.token)
        self.assertEqual(status, 200)
        self.assertIn('Rebooting', body['message'])
        args = json.loads(self.calls.read_text().splitlines()[-1])
        self.assertEqual(args, ['-n', 'systemctl', '--no-block', 'reboot'])
        self.assertEqual(self.request('action=reboot', 'POST', self.token)[0], 429)

    def test_reboot_failure(self):
        self.mode.write_text('failure')
        self.assertEqual(self.request('action=reboot', 'POST', self.token)[0], 503)

    def test_server_journal_has_no_unit_filter(self):
        before = len(self.calls.read_text().splitlines()) if self.calls.exists() else 0
        with self.opener.open(self.base + '/?action=events&service=server', timeout=8) as response:
            data, cursor = self.stream_event(response, 'log')
            self.assertIn('entry 1', data['text'])
        calls = [json.loads(line) for line in self.calls.read_text().splitlines()[before:]]
        journals = [args for args in calls if '--follow' in args]
        self.assertEqual(len(journals), 1)
        self.assertFalse(any(arg.startswith('--unit=') for arg in journals[0]))
        self.assertEqual(self.request('action=logs&service=server')[0], 200)
        self.assertIn('bootId', self.request('action=status')[1])

    def test_invalid_routes_and_methods(self):
        self.assertEqual(self.request('action=arbitrary')[0], 404)
        self.assertEqual(self.request('action=status', 'POST')[0], 405)
        self.assertEqual(self.request('action=logs&service[]=jellyfin')[0], 404)


if __name__ == '__main__':
    unittest.main(verbosity=2)
