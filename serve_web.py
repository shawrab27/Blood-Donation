import http.server
import socketserver
import os
import sys

PORT = 3000
DIRECTORY = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'blood_pulse', 'build', 'web')

class SPAHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

    def do_GET(self):
        # Resolve file path
        path = self.translate_path(self.path)
        if not os.path.exists(path) or os.path.isdir(path):
            index_path = os.path.join(DIRECTORY, 'index.html')
            if os.path.exists(index_path):
                self.path = '/index.html'
        return super().do_GET()

    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
        super().end_headers()

if __name__ == '__main__':
    print(f"Serving Flutter Web SPA from {DIRECTORY} on http://localhost:{PORT}")
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(('0.0.0.0', PORT), SPAHandler) as httpd:
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nShutting down server.")
