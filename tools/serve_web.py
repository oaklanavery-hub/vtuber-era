"""Serve build/web at /vtuber-era/ with ordinary HTTP headers."""
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import unquote, urlsplit
import argparse

ROOT = Path(__file__).resolve().parents[1] / 'build/web'


class Handler(SimpleHTTPRequestHandler):
    def translate_path(self, path):
        relative = unquote(urlsplit(path).path)
        if not relative.startswith('/vtuber-era/'):
            return str(ROOT / '__not_found__')
        target = (ROOT / relative[len('/vtuber-era/'):]).resolve()
        if not target.is_relative_to(ROOT.resolve()):
            return str(ROOT / '__not_found__')
        return str(target)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--port', type=int, default=8000)
    args = parser.parse_args()
    print(f'Play at http://localhost:{args.port}/vtuber-era/')
    ThreadingHTTPServer(('127.0.0.1', args.port), Handler).serve_forever()
