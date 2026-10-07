import http.server
import socketserver
import urllib.parse
import os
import subprocess
import shutil
import hashlib
import tempfile

PORT = 8888
DEFAULT_MUSIC_DIR = os.environ.get(
    'SPECTRAFLOW_MUSIC_DIR',
    os.path.join(os.path.expanduser('~'), 'Music', 'SpectraFlow')
)
DIRECTORY = os.path.abspath(DEFAULT_MUSIC_DIR)
CACHE_DIR = os.path.join(tempfile.gettempdir(), 'spectraflow_cache')
os.makedirs(CACHE_DIR, exist_ok=True)

class AudioStreamHandler(http.server.BaseHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Range, Content-Type')
        self.send_header('Accept-Ranges', 'bytes')
        super().end_headers()

    def do_OPTIONS(self):
        self.send_response(200, "ok")
        self.end_headers()

    def do_HEAD(self):
        file_path, is_mp3_request = self._resolve_target_file()
        if not file_path or not os.path.exists(file_path):
            self.send_error(404, "File Not Found")
            return
        
        if is_mp3_request:
            mp3_path = self._ensure_cached_mp3(file_path)
            size = os.path.getsize(mp3_path)
            self.send_response(200)
            self.send_header('Content-Type', 'audio/mpeg')
            self.send_header('Content-Length', str(size))
            self.end_headers()
        else:
            size = os.path.getsize(file_path)
            self.send_response(200)
            self.send_header('Content-Type', 'audio/flac')
            self.send_header('Content-Length', str(size))
            self.end_headers()

    def do_GET(self):
        file_path, is_mp3_request = self._resolve_target_file()
        if not file_path or not os.path.exists(file_path):
            self.send_error(404, f"File Not Found: {self.path}")
            return

        target_file = self._ensure_cached_mp3(file_path) if is_mp3_request else file_path
        content_type = 'audio/mpeg' if is_mp3_request else 'audio/flac'

        # Range-aware streaming with exact Content-Length
        try:
            file_size = os.path.getsize(target_file)
            range_header = self.headers.get('Range')

            if range_header and range_header.startswith('bytes='):
                byte_ranges = range_header[6:].split('-')
                try:
                    start = int(byte_ranges[0]) if byte_ranges[0] else 0
                    end = int(byte_ranges[1]) if len(byte_ranges) > 1 and byte_ranges[1] else file_size - 1
                except (ValueError, IndexError):
                    self.send_error(416, "Requested Range Not Satisfiable")
                    return

                if start < 0 or start >= file_size or end < start:
                    self.send_error(416, "Requested Range Not Satisfiable")
                    return

                end = min(end, file_size - 1)
                length = end - start + 1

                self.send_response(206, "Partial Content")
                self.send_header('Content-Type', content_type)
                self.send_header('Content-Range', f'bytes {start}-{end}/{file_size}')
                self.send_header('Content-Length', str(length))
                self.end_headers()

                with open(target_file, 'rb') as f:
                    f.seek(start)
                    self.wfile.write(f.read(length))
            else:
                self.send_response(200)
                self.send_header('Content-Type', content_type)
                self.send_header('Content-Length', str(file_size))
                self.end_headers()

                with open(target_file, 'rb') as f:
                    shutil.copyfileobj(f, self.wfile)
        except (ConnectionResetError, ConnectionAbortedError, BrokenPipeError):
            pass

    def _ensure_cached_mp3(self, flac_path):
        """Transcodes FLAC to MP3 once and caches it to disk for instant seeking and full browser compatibility."""
        mtime = os.path.getmtime(flac_path)
        cache_key = hashlib.md5(f"{flac_path}_{mtime}".encode('utf-8')).hexdigest()
        cached_mp3 = os.path.join(CACHE_DIR, f"{cache_key}.mp3")

        if not os.path.exists(cached_mp3) or os.path.getsize(cached_mp3) == 0:
            cmd = [
                'ffmpeg', '-y', '-i', flac_path,
                '-vn', '-c:a', 'libmp3lame', '-b:a', '192k',
                cached_mp3
            ]
            subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

        return cached_mp3

    def _resolve_target_file(self):
        parsed = urllib.parse.urlparse(self.path)
        raw_path = parsed.path.lstrip('/')
        # Decode iteratively in case it was double-encoded (%2520 -> %20 -> space)
        decoded_path = raw_path
        while '%' in decoded_path:
            unquoted = urllib.parse.unquote(decoded_path)
            if unquoted == decoded_path:
                break
            decoded_path = unquoted

        # Normalize and reject path traversal or absolute path attempts
        normalized = os.path.normpath(decoded_path)
        if normalized.startswith('..') or os.path.isabs(normalized):
            return None, False

        full_path = os.path.abspath(os.path.join(DIRECTORY, normalized))
        # Ensure path stays strictly inside DIRECTORY
        if not full_path.startswith(DIRECTORY):
            return None, False

        is_mp3 = normalized.endswith('.mp3') or 'format=mp3' in self.path

        if normalized.endswith('.mp3'):
            candidate_flac = normalized[:-4] + '.flac'
            flac_full = os.path.abspath(os.path.join(DIRECTORY, candidate_flac))
            if flac_full.startswith(DIRECTORY) and os.path.exists(flac_full):
                return flac_full, True

        return full_path, is_mp3

class ThreadedHTTPServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True

print(f'Starting High-Performance Lossless & Universal MP3 Streaming Server on http://127.0.0.1:{PORT}')
with ThreadedHTTPServer(('127.0.0.1', PORT), AudioStreamHandler) as httpd:
    httpd.serve_forever()
