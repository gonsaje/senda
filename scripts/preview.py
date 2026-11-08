#!/usr/bin/env python3
"""Live native SwiftUI window plus an auto-refreshing local browser review."""
from pathlib import Path
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
import os
import subprocess
import threading
import time
from urllib.parse import urlparse

root = Path(__file__).resolve().parent.parent
build = Path('/tmp/senda-live-build')
preview = Path('/tmp/senda-live-browser')
preview.mkdir(parents=True, exist_ok=True)
log = Path('/tmp/senda-live-preview-build.log')
window_log = Path('/tmp/senda-live-preview-window.log')
environment = dict(os.environ, CLANG_MODULE_CACHE_PATH='/tmp/senda-clang-cache',
                   SWIFT_MODULECACHE_PATH='/tmp/senda-swift-cache')
state = {'building': True}
process = None

(preview / 'index.html').write_text('''<!doctype html><html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>Senda live preview</title>
<style>body{margin:0;background:#e9e4db;color:#302720;font:15px -apple-system,BlinkMacSystemFont,sans-serif}
header{padding:22px 28px}h1{font:italic 32px Georgia,serif;margin:0 0 8px;color:#a94e32}
p{margin:5px 0;color:#6e655d}main{display:flex;gap:28px;justify-content:center;align-items:flex-start;flex-wrap:wrap;padding:8px 24px 40px}
figure{margin:0;width:min(100%,393px)}figcaption{margin:0 0 10px;font-size:13px}img{width:100%;height:auto;display:block;box-shadow:0 10px 35px #30272018;border-radius:12px}
small{font-size:12px}#status{float:right;font-size:12px}</style></head><body>
<header><span id="status">Updating…</span><h1>senda</h1><p>Live preview — updates as I work.</p>
<small>Actual SwiftUI screen, rendered on this Mac at phone size. For interactive controls, use the “Senda — Live preview” window.</small></header>
<main><figure><figcaption>Week</figcaption><img data-file="senda-week.png"></figure>
<figure><figcaption>Day</figcaption><img data-file="senda-day.png"></figure>
<figure><figcaption>Add exercise</figcaption><img data-file="senda-picker.png"></figure></main>
<script>let previous='';async function refresh(){try{let s=await(await fetch('/status.json',{cache:'no-store'})).json();
document.querySelector('#status').textContent=s.building?'Updating preview…':'Preview ready';
let stamp=JSON.stringify(s.files);if(stamp!==previous){previous=stamp;document.querySelectorAll('img').forEach(i=>{let f=i.dataset.file;if(s.files[f])i.src='/'+f+'?v='+s.files[f]})}}catch(e){}}
refresh();setInterval(refresh,1000);</script></body></html>''')

class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(preview), **kwargs)
    def log_message(self, *args):
        pass
    def do_GET(self):
        if urlparse(self.path).path == '/status.json':
            payload = json.dumps(dict(state, files={p.name: p.stat().st_mtime_ns for p in preview.glob('*.png')})).encode()
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Cache-Control', 'no-store')
            self.send_header('Content-Length', str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
        else:
            super().do_GET()

server = ThreadingHTTPServer(('127.0.0.1', 8765), Handler)
threading.Thread(target=server.serve_forever, daemon=True).start()
print('Browser preview: http://127.0.0.1:8765', flush=True)

def fingerprint():
    paths = [root / 'Package.swift', *sorted((root / 'Sources').rglob('*.swift'))]
    return tuple((str(p), p.stat().st_mtime_ns, p.stat().st_size) for p in paths)

try:
    previous = None
    while True:
        current = fingerprint()
        if current != previous:
            previous = current
            state['building'] = True
            print('Building live SwiftUI preview…', flush=True)
            with log.open('w') as output:
                result = subprocess.run(['swift', 'build', '--product', 'senda-preview',
                    '--scratch-path', str(build), '--cache-path', '/tmp/senda-live-package-cache',
                    '--config-path', '/tmp/senda-live-config', '--security-path', '/tmp/senda-live-security',
                    '--disable-sandbox'], cwd=root, env=environment, stdout=output, stderr=subprocess.STDOUT)
            if result.returncode == 0:
                binary = str(build / 'debug/senda-preview')
                with window_log.open('a') as output:
                    subprocess.run([binary, str(preview)], cwd=root, env=environment, stdout=output, stderr=subprocess.STDOUT)
                if process and process.poll() is None:
                    process.terminate()
                    try:
                        process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        process.kill(); process.wait()
                with window_log.open('a') as output:
                    process = subprocess.Popen([binary, '--live'], cwd=root, env=environment, stdout=output, stderr=subprocess.STDOUT)
                print('Preview updated. Watching Sources for changes.', flush=True)
            else:
                print('Build is not ready; keeping the last preview. Details: ' + str(log), flush=True)
            state['building'] = False
        time.sleep(1)
except KeyboardInterrupt:
    pass
finally:
    server.shutdown()
    if process and process.poll() is None:
        process.terminate()
