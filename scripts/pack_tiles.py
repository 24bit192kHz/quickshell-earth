import os
import sqlite3
import glob

DB_FILE = "tiles.db"
TILES_DIR = "tiles_esri"

def pack_tiles():
    if os.path.exists(DB_FILE):
        print(f"{DB_FILE} already exists. Skipping packing.")
        return
        
    print(f"Packing {TILES_DIR} into {DB_FILE}...")
    conn = sqlite3.connect(DB_FILE)
    c = conn.cursor()
    
    # Create the mbtiles-compatible schema
    c.execute('''CREATE TABLE IF NOT EXISTS tiles (
                    zoom_level integer,
                    tile_column integer,
                    tile_row integer,
                    tile_data blob
                 )''')
    c.execute('CREATE UNIQUE INDEX IF NOT EXISTS tile_index ON tiles (zoom_level, tile_column, tile_row)')
    
    # Walk the directory
    count = 0
    for z_dir in os.listdir(TILES_DIR):
        if not z_dir.isdigit(): continue
        z = int(z_dir)
        z_path = os.path.join(TILES_DIR, z_dir)
        
        for x_dir in os.listdir(z_path):
            if not x_dir.isdigit(): continue
            x = int(x_dir)
            x_path = os.path.join(z_path, x_dir)
            
            for file in os.listdir(x_path):
                if not file.endswith('.jpeg'): continue
                y = int(file.split('.')[0])
                file_path = os.path.join(x_path, file)
                
                with open(file_path, 'rb') as f:
                    data = f.read()
                
                c.execute('INSERT OR REPLACE INTO tiles (zoom_level, tile_column, tile_row, tile_data) VALUES (?, ?, ?, ?)', (z, x, y, data))
                count += 1
                if count % 1000 == 0:
                    print(f"Packed {count} tiles...")
                    conn.commit()
                    
    conn.commit()
    conn.close()
    print(f"Done! Packed {count} total tiles.")

if __name__ == "__main__":
    if os.path.isdir(TILES_DIR):
        pack_tiles()
    else:
        print(f"No {TILES_DIR} found. Run download_tiles.py first.")
