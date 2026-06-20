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
        f.write(bytes.fromhex("ffd8ffe000104a46494600010101006000600000ffdb004300080606070605080707070909080a0c140d0c0b0b0c1912130f141d1a1f1e1d1a1c1c20242e2720222c231c1c2837292c30313434341f27393d38323c2e333432ffdb0043010909090c0b0c180d0d1832211c213232323232323232323232323232323232323232323232323232323232323232323232323232323232323232323232323232ffc00011080001000103012200021101031101ffc4001f0000010501010101010100000000000000000102030405060708090a0bffc400b5100002010303020403050504040000017d01020300041105122131410613516107227114328191a1082342b1c11552d1f02433627282090a161718191a25262728292a3435363738393a434445464748494a535455565758595a636465666768696a737475767778797a838485868788898a92939495969798999aa2a3a4a5a6a7a8a9aab2b3b4b5b6b7b8b9bac2c3c4c5c6c7c8c9cad2d3d4d5d6d7d8d9dae1e2e3e4e5e6e7e8e9eaf1f2f3f4f5f6f7f8f9faffc4001f0100030101010101010101010000000000000102030405060708090a0bffc400b51100020102040403040705040400010277000102031104052131061241510761711322328108144291a1b1c109233352f0156272d10a162434e125f11718191a262728292a35363738393a434445464748494a535455565758595a636465666768696a737475767778797a82838485868788898a92939495969798999aa2a3a4a5a6a7a8a9aab2b3b4b5b6b7b8b9bac2c3c4c5c6c7c8c9cad2d3d4d5d6d7d8d9dae2e3e4e5e6e7e8e9eaf2f3f4f5f6f7f8f9faffda000c03010002110311003f00f928a28afcff003f00f928a28afcff003ffd9"))
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
