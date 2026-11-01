#!/usr/bin/env python3

import argparse
import gzip
import ipaddress
import json
import os
import re
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import unquote, urlsplit


ROOT = Path(os.getenv("MTA_CONTAINER_DIR", "/home/container")).resolve()
MODS = ROOT / "mods"
NO_CLIENT_CACHE = os.getenv("HTTPCLIENTNOCLIENTCACHE", "true").lower() == "true"


def configure_download_url(port):
    config = MODS / "deathmatch" / "mtaserver.conf"
    if not config.is_file():
        raise RuntimeError(f"MTA config not found: {config}")

    host = os.getenv("SERVER_IP", "").strip()
    try:
        address = ipaddress.ip_address(host)
        if not address.is_global:
            host = ""
    except ValueError:
        host = ""
    if not host:
        with urllib.request.urlopen("https://ifconfig.me/ip", timeout=10) as response:
            host = response.read().decode("ascii").strip()

    address = ipaddress.ip_address(host)
    if not address.is_global:
        raise RuntimeError(f"Download URL address is not public: {address}")
    url_host = f"[{address}]" if address.version == 6 else str(address)
    content = config.read_text(encoding="utf-8")
    updated, count = re.subn(
        r"<httpdownloadurl>.*?</httpdownloadurl>",
        f"<httpdownloadurl>http://{url_host}:{port}</httpdownloadurl>",
        content,
        count=1,
        flags=re.DOTALL,
    )
    if count != 1:
        raise RuntimeError(f"<httpdownloadurl> tag not found in {config}")
    config.write_text(updated, encoding="utf-8")


def find_resource(request_path):
    relative_path = Path(request_path.lstrip("/"))
    if not relative_path.parts or any(part in ("", ".", "..") for part in relative_path.parts):
        return None

    try:
        mod_directories = sorted(path for path in MODS.iterdir() if path.is_dir())
    except OSError:
        return None

    cache_names = ["http-client-files"]
    if NO_CLIENT_CACHE:
        cache_names.append("http-client-files-no-client-cache")

    for mod_directory in mod_directories:
        for cache_name in cache_names:
            candidate = (mod_directory / "resource-cache" / cache_name / relative_path).resolve()
            if not candidate.is_relative_to(ROOT):
                continue
            if candidate.is_file():
                return candidate
    return None


class AcceleratorHandler(BaseHTTPRequestHandler):
    server_version = "MTA-Accelerator"

    def do_GET(self):
        self._serve(head_only=False)

    def do_HEAD(self):
        self._serve(head_only=True)

    def _serve(self, head_only):
        request_path = unquote(urlsplit(self.path).path)
        if request_path == "/":
            self.send_error(403, "Forbidden")
            return

        resource = find_resource(request_path)
        if resource is None:
            body = json.dumps({"error": "Not Found"}).encode("utf-8")
            self.send_response(404)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            if not head_only:
                self.wfile.write(body)
            return

        try:
            compressed = gzip.compress(resource.read_bytes(), mtime=0)
        except OSError:
            self.send_error(500, "Internal Server Error")
            return

        self.send_response(200)
        self.send_header("Content-Type", "application/octet-stream")
        self.send_header("Content-Encoding", "gzip")
        self.send_header(
            "Content-Disposition",
            f'attachment; filename="{resource.name.replace(chr(34), "")}"',
        )
        self.send_header("Content-Length", str(len(compressed)))
        self.end_headers()
        if not head_only:
            self.wfile.write(compressed)

    def log_message(self, format_string, *args):
        print(f"[ACCELERATOR] {self.address_string()} - {format_string % args}", flush=True)


def main():
    parser = argparse.ArgumentParser(description="Binary-safe MTA HTTP download accelerator")
    parser.add_argument("--express", "-e", type=int, required=True, help="HTTP listening port")
    port = parser.parse_args().express
    if not 1 <= port <= 65535:
        parser.error("--express must be between 1 and 65535")

    configure_download_url(port)
    server = ThreadingHTTPServer(("0.0.0.0", port), AcceleratorHandler)
    server.daemon_threads = True
    print(f"[ACCELERATOR] Listening on 0.0.0.0:{port}", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
