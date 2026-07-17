from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import unquote, urlparse

PORT = 8081
ROOT = Path(__file__).resolve().parents[1] / "build" / "web"


class SpaHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(
            *args,
            directory=str(ROOT),
            **kwargs,
        )

    def do_GET(self):
        parsed_path = unquote(urlparse(self.path).path)
        requested_file = ROOT / parsed_path.lstrip("/")

        if parsed_path == "/" or requested_file.exists():
            return super().do_GET()

        self.path = "/index.html"
        return super().do_GET()


class ReusableThreadingServer(ThreadingHTTPServer):
    allow_reuse_address = True


if not (ROOT / "index.html").exists():
    raise SystemExit(
        "build/web/index.html não existe. "
        "Execute primeiro: flutter build web"
    )


with ReusableThreadingServer(("0.0.0.0", PORT), SpaHandler) as server:
    print(f"Aplicação: {ROOT}")
    print(f"Porta: {PORT}")
    server.serve_forever()
