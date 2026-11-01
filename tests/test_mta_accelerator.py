import gzip
import http.client
import importlib.util
import os
import tempfile
import threading
import unittest
from pathlib import Path
from http.server import ThreadingHTTPServer
from unittest.mock import patch


MODULE_PATH = Path(__file__).resolve().parents[1] / "mta-accelerator.py"
SPEC = importlib.util.spec_from_file_location("mta_accelerator", MODULE_PATH)
accelerator = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(accelerator)


class AcceleratorTests(unittest.TestCase):
    def setUp(self):
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary_directory.cleanup)
        self.root = Path(self.temporary_directory.name)
        self.mods = self.root / "mods"
        self.cache = (
            self.mods
            / "deathmatch"
            / "resource-cache"
            / "http-client-files"
        )
        self.cache.mkdir(parents=True)
        self.config = self.mods / "deathmatch" / "mtaserver.conf"
        self.config.write_text(
            "<httpdownloadurl></httpdownloadurl>\n", encoding="utf-8"
        )
        self.original_root = accelerator.ROOT
        self.original_mods = accelerator.MODS
        self.original_no_client_cache = accelerator.NO_CLIENT_CACHE
        accelerator.ROOT = self.root
        accelerator.MODS = self.mods
        accelerator.NO_CLIENT_CACHE = True
        self.addCleanup(self._restore_module_state)

    def _restore_module_state(self):
        accelerator.ROOT = self.original_root
        accelerator.MODS = self.original_mods
        accelerator.NO_CLIENT_CACHE = self.original_no_client_cache

    def _start_server(self):
        server = ThreadingHTTPServer(
            ("127.0.0.1", 0), accelerator.AcceleratorHandler
        )
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        self.addCleanup(self._stop_server, server, thread)
        return server

    @staticmethod
    def _stop_server(server, thread):
        server.shutdown()
        thread.join(timeout=2)
        server.server_close()

    def test_configures_download_url_and_preserves_permissions(self):
        self.config.chmod(0o640)

        accelerator.configure_download_url(23527, "fastdl.example.com")

        self.assertIn(
            "<httpdownloadurl>http://fastdl.example.com:23527</httpdownloadurl>",
            self.config.read_text(encoding="utf-8"),
        )
        self.assertEqual(self.config.stat().st_mode & 0o777, 0o640)

    def test_rejects_invalid_host_without_changing_config(self):
        original = self.config.read_text(encoding="utf-8")

        with self.assertRaises(RuntimeError):
            accelerator.configure_download_url(23527, "https://example.com/path")

        self.assertEqual(self.config.read_text(encoding="utf-8"), original)

    def test_discovers_public_ip_when_no_host_is_configured(self):
        response = type("Response", (), {
            "status": 200,
            "read": lambda self: b"8.8.8.8\n",
            "__enter__": lambda self: self,
            "__exit__": lambda self, *_: None,
        })()
        with patch.dict(os.environ, {"MTA_DOWNLOAD_HOST": "", "SERVER_IP": ""}), patch.object(
            accelerator.urllib.request, "urlopen", return_value=response
        ) as urlopen:
            self.assertEqual(accelerator._download_host(), "8.8.8.8")
        urlopen.assert_called_once_with("https://ifconfig.me/ip", timeout=10)

    def test_requires_existing_download_url_tag(self):
        self.config.write_text("<config></config>\n", encoding="utf-8")

        with self.assertRaisesRegex(RuntimeError, "tag not found"):
            accelerator.configure_download_url(23527, "fastdl.example.com")

    def test_finds_files_only_inside_mta_cache(self):
        resource = self.cache / "ip2c/client/images/flags/iq.png"
        resource.parent.mkdir(parents=True)
        resource.write_bytes(b"\x89PNG\r\n\x1a\n")

        self.assertEqual(
            accelerator.find_resource("/ip2c/client/images/flags/iq.png"),
            resource,
        )
        self.assertIsNone(accelerator.find_resource("/../../mtaserver.conf"))
        self.assertIsNone(accelerator.find_resource("/..%2fmtaserver.conf"))
        self.assertIsNone(accelerator.find_resource("/etc/passwd"))

    def test_rejects_symlink_outside_cache(self):
        outside = self.root / "not-a-resource.png"
        outside.write_bytes(b"private")
        link = self.cache / "linked.png"
        link.symlink_to(outside)

        self.assertIsNone(accelerator.find_resource("/linked.png"))

    def test_http_serves_binary_gzip_and_correct_headers(self):
        payload = b"\x89PNG\r\n\x1a\n" + os.urandom(2 * 1024 * 1024)
        resource = self.cache / "ip2c/client/images/flags/iq.png"
        resource.parent.mkdir(parents=True)
        resource.write_bytes(payload)

        server = self._start_server()

        connection = http.client.HTTPConnection(
            "127.0.0.1", server.server_port, timeout=5
        )
        self.addCleanup(connection.close)
        connection.request("GET", "/ip2c/client/images/flags/iq.png")
        response = connection.getresponse()
        compressed = response.read()

        self.assertEqual(response.status, 200)
        self.assertEqual(response.getheader("Content-Type"), "image/png")
        self.assertEqual(response.getheader("Content-Encoding"), "gzip")
        self.assertEqual(response.getheader("Content-Length"), str(len(compressed)))
        self.assertEqual(gzip.decompress(compressed), payload)

    def test_http_head_and_missing_resources(self):
        payload = b"resource payload"
        (self.cache / "test.dat").write_bytes(payload)

        server = self._start_server()
        connection = http.client.HTTPConnection(
            "127.0.0.1", server.server_port, timeout=5
        )
        self.addCleanup(connection.close)

        connection.request("HEAD", "/test.dat")
        head_response = connection.getresponse()
        head_length = head_response.getheader("Content-Length")
        self.assertEqual(head_response.status, 200)
        self.assertEqual(head_response.read(), b"")

        connection.request("GET", "/missing.dat")
        missing_response = connection.getresponse()
        self.assertEqual(missing_response.status, 404)
        missing_response.read()

        connection.request("GET", "/%2e%2e/mtaserver.conf")
        traversal_response = connection.getresponse()
        self.assertEqual(traversal_response.status, 404)
        traversal_response.read()

        connection.request("GET", "/")
        root_response = connection.getresponse()
        self.assertEqual(root_response.status, 403)
        root_response.read()

        connection.request("GET", "/test.dat")
        get_response = connection.getresponse()
        body = get_response.read()
        self.assertEqual(head_length, str(len(body)))
        self.assertEqual(gzip.decompress(body), payload)


if __name__ == "__main__":
    unittest.main()
