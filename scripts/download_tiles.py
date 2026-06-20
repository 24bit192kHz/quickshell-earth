import os
import urllib.request
import time
from concurrent.futures import ThreadPoolExecutor, as_completed

BASE_URL = "https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}"

# Web Mercator has 2^z tiles in both dimensions
LEVELS = [
    (0, 1, 1),
    (1, 2, 2),
    (2, 4, 4),
    (3, 8, 8),
    (4, 16, 16),
    (5, 32, 32),
    (6, 64, 64),
    (7, 128, 128),
    (8, 256, 256),
    (9, 512, 512)
]

def download_tile(z, x, y):
    path = f"tiles_esri/{z}/{x}/{y}.jpeg"
    if os.path.exists(path):
        return True, path # Already downloaded

    url = BASE_URL.format(z=z, x=x, y=y)
    
    # Ensure directory exists
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
    except FileExistsError:
        pass
    
    retries = 3
    while retries > 0:
        try:
            req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
            with urllib.request.urlopen(req, timeout=5) as response:
                with open(path, 'wb') as f:
                    f.write(response.read())
            return True, path
        except Exception as e:
            retries -= 1
            time.sleep(0.5)
            
    # Write a 1x1 black pixel on absolute failure so we don't try again
    with open(path, 'wb') as f:
        # minimal valid 1x1 black JPEG
        f.write(bytes.fromhex("ffd8ffe000104a46494600010100000100010000ffdb004300030202020202030202020303030304060404040404080606050609080a0a090809090a0c0f0c0a0b0e0b09090d110d0e0f101011100a0c12131210130f101010ffc0000b080001000101011100ffc40014000100000000000000000000000000000009ffc40014100100000000000000000000000000000000ffda0008010100003f002a9fffd9"))
    return False, path

def main():
    print("WARNING: This will download ESRI World Imagery up to Level 9 (approx 6-8 GB).")
    TARGET_LEVEL = 9 # Modify this to limit zoom
    
    for z, max_x, max_y in LEVELS:
        if z > TARGET_LEVEL:
            continue
            
        print(f"Downloading Level {z} ({max_x * max_y} tiles)...")
        tasks = []
        with ThreadPoolExecutor(max_workers=200) as executor:
            for y in range(max_y):
                for x in range(max_x):
                    tasks.append(executor.submit(download_tile, z, x, y))
            
            completed = 0
            for future in as_completed(tasks):
                success, path = future.result()
                completed += 1
                if completed % 1000 == 0:
                    print(f"  ... {completed} / {len(tasks)} tiles complete.")
                    
if __name__ == "__main__":
    main()
