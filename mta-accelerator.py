#!/usr/bin/env python3

import argparse
import ipaddress
import mimetypes
import os
import re
import shutil
import tempfile
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import quote, unquote, urlsplit


ROOT = Path(os.getenv("MTA_CONTAINER_DIR", "/home/container")).resolve()
MODS = ROOT / "mods"
NO_CLIENT_CACHE = os.getenv("HTTPCLIENTNOCLIENTCACHE", "true").strip().lower() in {
    "1",
    "true",
    "yes",
    "on",
}
CHUNK_SIZE = 256 * 1024


def _validated_public_host(value, require_public_ip=True):
    host = value.strip()
    if not host or any(character in host for character in "/\\:@?#"):
        raise ValueError("host must be a hostname or IP address without a scheme or port")

    try:
        address = ipaddress.ip_address(host)
    except ValueError:
        if require_public_ip:
            raise ValueError("discovered address is not a valid IP address")
        if len(host) > 253 or not re.fullmatch(
            r"(?=.{1,253}\Z)(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)(?:\.(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?))*",
            host,
        ):
            raise ValueError("host is not a valid DNS name")
        return host.lower()

    if require_public_ip and not address.is_global:
        raise ValueError(f"address is not public: {address}")
    return f"[{address}]" if address.version == 6 else str(address)


def _download_host():
    configured_host = os.getenv("MTA_DOWNLOAD_HOST", "").strip()
    if configured_host:
        return _validated_public_host(configured_host, require_public_ip=False)

    server_ip = os.getenv("SERVER_IP", "").strip()
    if server_ip:
        try:
            return _validated_public_host(server_ip)
        except ValueError:
            pass

    with urllib.request.urlopen("https://ifconfig.me/ip", timeout=10) as response:
        if response.status != 200:
            raise RuntimeError(f"Public IP lookup returned HTTP {response.status}")
        return _validated_public_host(response.read().decode("ascii").strip())


def configure_download_url(port, host=None):
    config = MODS / "deathmatch" / "mtaserver.conf"
    if not config.is_file():
        raise RuntimeError(f"MTA config not found: {config}")

    url_host = host or _download_host()
    if host is not None:
        try:
            url_host = _validated_public_host(host, require_public_ip=False)
        except ValueError as error:
            raise RuntimeError(f"Invalid download host: {error}") from error

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

    file_mode = config.stat().st_mode & 0o777
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{config.name}.", dir=config.parent
    )
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as temporary_file:
            temporary_file.write(updated)
            temporary_file.flush()
            os.fsync(temporary_file.fileno())
        os.chmod(temporary_name, file_mode)
        os.replace(temporary_name, config)
    except BaseException:
        try:
            os.unlink(temporary_name)
        except FileNotFoundError:
            pass
        raise


def _cache_directories():
    try:
        mod_directories = sorted(path for path in MODS.iterdir() if path.is_dir())
    except OSError:
        return []

    cache_names = ["http-client-files"]
    if NO_CLIENT_CACHE:
        cache_names.append("http-client-files-no-client-cache")

    directories = []
    for mod_directory in mod_directories:
        for cache_name in cache_names:
            cache_directory = mod_directory / "resource-cache" / cache_name
            try:
                resolved_cache = cache_directory.resolve(strict=True)
            except OSError:
                continue
            if resolved_cache.is_dir() and resolved_cache.is_relative_to(ROOT):
                directories.append(resolved_cache)
    return directories


def find_resource(request_path):
    if "\x00" in request_path or "\\" in request_path:
        return None

    relative_path = Path(request_path.lstrip("/"))
    if (
        not relative_path.parts
        or relative_path.is_absolute()
        or any(part in ("", ".", "..") for part in relative_path.parts)
    ):
        return None

    for cache_directory in _cache_directories():
        candidate = cache_directory / relative_path
        try:
            resolved_candidate = candidate.resolve(strict=True)
        except OSError:
            continue
        if (
            resolved_candidate.is_relative_to(cache_directory)
            and resolved_candidate.is_relative_to(ROOT)
            and resolved_candidate.is_file()
        ):
            return resolved_candidate
    return None


class AcceleratorHandler(BaseHTTPRequestHandler):
    server_version = "MTA-Accelerator"
    protocol_version = "HTTP/1.1"

    def do_GET(self):
        self._serve(head_only=False)

    def do_HEAD(self):
        self._serve(head_only=True)

    def _serve(self, head_only):
        try:
            request_path = unquote(urlsplit(self.path).path, errors="strict")
        except (UnicodeDecodeError, ValueError):
            self.send_error(400, "Invalid URL")
            return

        if request_path == "/":
            self.send_error(403, "Forbidden")
            return

        resource = find_resource(request_path)
        if resource is None:
            self.send_error(404, "Resource not found")
            return

        try:
            source = resource.open("rb")
        except OSError:
            self.send_error(500, "Unable to read resource")
            return

        with source:
            resource_size = os.fstat(source.fileno()).st_size
            safe_filename = re.sub(r"[^A-Za-z0-9._-]", "_", resource.name)
            self.send_response(200)
            self.send_header(
                "Content-Type",
                mimetypes.guess_type(resource.name)[0] or "application/octet-stream",
            )
            self.send_header("Content-Length", str(resource_size))
            self.send_header("Cache-Control", "no-transform")
            self.send_header(
                "Content-Disposition",
                f'attachment; filename="{safe_filename}"; '
                f"filename*=UTF-8''{quote(resource.name, safe='')}",
            )
            self.send_header("X-Content-Type-Options", "nosniff")
            self.end_headers()
            if not head_only:
                try:
                    shutil.copyfileobj(source, self.wfile, length=CHUNK_SIZE)
                except (BrokenPipeError, ConnectionResetError):
                    pass

    def log_message(self, format_string, *args):
        print(
            f"[ACCELERATOR] {self.address_string()} - {format_string % args}",
            flush=True,
        )


class AcceleratorServer(ThreadingHTTPServer):
    allow_reuse_address = True
    daemon_threads = True


def main():
    parser = argparse.ArgumentParser(
        description="Binary-safe MTA HTTP download accelerator"
    )
    parser.add_argument(
        "--express", "-e", type=int, required=True, help="HTTP listening port"
    )
    parser.add_argument(
        "--host",
        help="Public IP or DNS name used in mtaserver.conf; defaults to MTA_DOWNLOAD_HOST, SERVER_IP, then public-IP discovery",
    )
    args = parser.parse_args()
    if not 1 <= args.express <= 65535:
        parser.error("--express must be between 1 and 65535")

    server = AcceleratorServer(("0.0.0.0", args.express), AcceleratorHandler)
    try:
        configure_download_url(args.express, args.host)
    except BaseException:
        server.server_close()
        raise

    print(f"[ACCELERATOR] Listening on 0.0.0.0:{args.express}", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
