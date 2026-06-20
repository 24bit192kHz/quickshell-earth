import os
import sqlite3
import socket
import threading
import subprocess
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler

DB_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "tiles.db")
PORT = 49152 # Start checking for open ports in the dynamic range

def find_open_port(start_port):
    for port in range(start_port, 65535):
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            s.bind(('', port))
            s.close()
            return port
        except OSError:
            continue
    return None

class TileHandler(BaseHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        # We need a per-thread or per-request connection if threading is used,
        # but for simple BaseHTTPRequestHandler, it handles sequentially.
        self.conn = None
        if os.path.exists(DB_FILE):
            self.conn = sqlite3.connect(DB_FILE)
            self.conn.execute("PRAGMA cache_size = 10000") # Cache 10MB
            self.conn.execute("PRAGMA synchronous = OFF")
            self.conn.execute("PRAGMA temp_store = MEMORY")
            
        super().__init__(*args, **kwargs)

    def do_GET(self):
        # Expected path: /tiles/z/x/y
        parts = self.path.strip('/').split('/')
        if len(parts) != 4 or parts[0] != "tiles":
            self.send_response(404)
            self.end_headers()
            return
            
        try:
            z, x, y = int(parts[1]), int(parts[2]), int(parts[3])
        except ValueError:
            self.send_response(400)
            self.end_headers()
            return

        if self.conn is None:
            self.send_response(404)
            self.end_headers()
            return

        c = self.conn.cursor()
        c.execute('SELECT tile_data FROM tiles WHERE zoom_level=? AND tile_column=? AND tile_row=?', (z, x, y))
        row = c.fetchone()
        
        if row and row[0] and len(row[0]) > 0:
            data = row[0]
        else:
            # Auto-heal 0-byte corrupt tiles or missing tiles with a valid 1x1 black JPEG
            # This prevents QML from flooding the console with 404s or "Unsupported image format" errors
            data = bytes.fromhex("ffd8ffe000104a46494600010100000100010000ffdb004300030202020202030202020303030304060404040404080606050609080a0a090809090a0c0f0c0a0b0e0b09090d110d0e0f101011100a0c12131210130f101010ffc0000b080001000101011100ffc40014000100000000000000000000000000000009ffc40014100100000000000000000000000000000000ffda0008010100003f002a9fffd9")
            
        self.send_response(200)
        self.send_header('Content-type', 'image/jpeg')
        self.send_header('Cache-Control', 'max-age=86400')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(data)
            
    def log_message(self, format, *args):
        # Suppress logging to keep terminal clean
        pass

def background_setup(port):
    # Self-heal legacy corrupted databases (a full DB is >2GB, anything under 100MB is broken)
    if os.path.exists(DB_FILE) and os.path.getsize(DB_FILE) < 100 * 1024 * 1024:
        print("Notice: Detected incomplete/corrupted tiles.db. Self-healing by deleting it...")
        os.remove(DB_FILE)

    if not os.path.exists(DB_FILE):
        if not os.path.exists("tiles_esri") or not os.path.exists(".download_complete"):
            print("Notice: High-res tiles not complete. Launching background download (this may take a while to resume/finish).")
            try:
                subprocess.run(["python3", "scripts/download_tiles.py"], cwd=os.path.dirname(os.path.abspath(__file__)), check=True)
                # Mark download complete
                with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".download_complete"), "w") as f:
                    f.write("done")
            except subprocess.CalledProcessError:
                print("Error: Background download failed or was interrupted. Will resume next time.")
                return
        
        import shutil
        print("Packing downloaded tiles into SQLite database...")
        try:
            subprocess.run(["python3", "scripts/pack_tiles.py"], cwd=os.path.dirname(os.path.abspath(__file__)), check=True)
        except subprocess.CalledProcessError:
            print("Error: Packing failed.")
            return
        
        print("Cleaning up raw tile directory to save space...")
        try:
            shutil.rmtree(os.path.join(os.path.dirname(os.path.abspath(__file__)), "tiles_esri"))
            os.remove(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".download_complete"))
        except: pass
        
        print("Setup complete! High-res chunks are now active.")
    
    # Broadcast URL to QML only when the database is absolutely ready
    print(f"http://127.0.0.1:{port}/tiles", flush=True)

def run():
    port = find_open_port(PORT)
    if not port:
        print("ERROR: No open ports found!")
        return
        
    threading.Thread(target=background_setup, args=(port,), daemon=True).start()
        
    server = ThreadingHTTPServer(('127.0.0.1', port), TileHandler)
    server.serve_forever()

if __name__ == '__main__':
    run()
