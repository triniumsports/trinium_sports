#!/usr/bin/env bash
set -e

cd /workspaces/trinium_sports
/workspaces/flutter/bin/flutter pub get
/workspaces/flutter/bin/flutter build web
cd /workspaces/trinium_sports/build/web

cat > serve_spa.py <<'PY'
import http.server
import socketserver
import os
from urllib.parse import urlparse

PORT = 8081

class Handler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path
        full = os.path.join(os.getcwd(), path.lstrip('/'))

        if path == '/' or os.path.exists(full):
            return http.server.SimpleHTTPRequestHandler.do_GET(self)

        self.path = '/index.html'
        return http.server.SimpleHTTPRequestHandler.do_GET(self)

with socketserver.TCPServer(("0.0.0.0", PORT), Handler) as httpd:
    print(f"Serving SPA at http://0.0.0.0:{PORT}")
    httpd.serve_forever()
PY

python3 serve_spa.py
