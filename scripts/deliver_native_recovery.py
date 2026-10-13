#!/usr/bin/env python3
"""Deliver a real local Mailpit PKCE callback through Android ACTION_VIEW.

No URI/code/token is printed. Reads only this run's random test email marker.
"""
import argparse
import html
import json
from pathlib import Path
import re
import subprocess
import time
from urllib.parse import urlparse, parse_qs
from urllib.request import Request, urlopen, build_opener, HTTPRedirectHandler
from urllib.error import HTTPError

ROOT = Path(__file__).resolve().parent.parent
class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None
def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--log', required=True)
    parser.add_argument('--adb', required=True)
    parser.add_argument('--device', default='emulator-5554')
    args = parser.parse_args()
    log = Path(args.log).resolve()
    if not log.is_relative_to(ROOT / '.tooling'):
        raise RuntimeError('Only ignored local test logs are accepted')
    limit = time.monotonic() + 150
    email = None
    while time.monotonic() < limit:
        text = log.read_text('utf-8', errors='replace') if log.exists() else ''
        match = re.search(r'MIXTICK_RECOVERY_READY:(mixtick-native-[0-9a-f]{1,8}@example\.test)', text)
        if match:
            email = match.group(1)
            break
        time.sleep(0.25)
    if email is None:
        raise RuntimeError('Native recovery marker not received')
    with urlopen('http://127.0.0.1:54324/api/v1/messages', timeout=10) as response:
        messages = json.load(response)['messages']
    message = next(m for m in messages if email in json.dumps(m['To']))
    identifier = message['ID']
    with urlopen(f'http://127.0.0.1:54324/api/v1/message/{identifier}', timeout=10) as response:
        detail = json.load(response)
    match = re.search(r'''href=["']([^"']+/auth/v1/verify[^"']+)["']''', html.unescape(detail['HTML']))
    if match is None:
        raise RuntimeError('Local recovery action missing')
    action = urlparse(match.group(1))
    if action.hostname not in ('127.0.0.1', 'localhost') or action.port != 54321 or action.path != '/auth/v1/verify':
        raise RuntimeError('Invalid action destination')
    opener = build_opener(NoRedirect())
    try:
        response = opener.open(match.group(1), timeout=10)
        callback = response.headers.get('Location', '')
    except HTTPError as error:
        callback = error.headers.get('Location', '')
    parsed = urlparse(callback)
    params = parse_qs(parsed.query)
    if parsed.scheme != 'es.sergiotech.mixtick' or parsed.netloc != 'auth' or parsed.path != '/callback' or parsed.fragment or set(params) != {'code'}:
        raise RuntimeError('Invalid PKCE callback')
    result = subprocess.run([args.adb, '-s', args.device, 'shell', 'am', 'start', '-a',
                             'android.intent.action.VIEW', '-d', callback,
                             'es.sergiotech.mixtick/.MainActivity'], capture_output=True, text=True)
    # am can echo its URI, so neither stdout nor stderr is included in evidence.
    if result.returncode != 0:
        raise RuntimeError('Android ACTION_VIEW delivery failed')
    print('PASS: real local PKCE callback delivered by Android ACTION_VIEW; code not logged')
    return 0
if __name__ == '__main__':
    raise SystemExit(main())
