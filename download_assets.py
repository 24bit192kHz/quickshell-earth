import os
import urllib.request

# Define required assets and their known public URLs (e.g. Solar System Scope or NASA)
ASSETS = {
    "earth_8k_opt.jpg": "https://www.solarsystemscope.com/textures/download/8k_earth_daymap.jpg",
    "night_8k.jpg": "https://www.solarsystemscope.com/textures/download/8k_earth_nightmap.jpg",
    "8k_earth_clouds.jpg": "https://www.solarsystemscope.com/textures/download/8k_earth_clouds.jpg",
    "elev_bump_8k.jpg": "https://www.solarsystemscope.com/textures/download/8k_earth_normal_map.jpg",
    "water_8k.png": "https://www.solarsystemscope.com/textures/download/8k_earth_specular_map.tif",
    "8k_stars_milky_way.jpg": "https://www.solarsystemscope.com/textures/download/8k_stars_milky_way.jpg",
    "moon_2k.jpg": "https://www.solarsystemscope.com/textures/download/2k_moon.jpg",
    "8k_saturn_ring_alpha.png": "https://www.solarsystemscope.com/textures/download/8k_saturn_ring_alpha.png",
}

def download_file(url, filename):
    out_path = os.path.join("assets", "textures", filename)
    print(f"Downloading {out_path}...")
    try:
        os.makedirs(os.path.dirname(out_path), exist_ok=True)
        if filename == "elev_bump_8k.jpg":
            url = "https://www.solarsystemscope.com/textures/download/8k_earth_normal_map.tif"
            req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
            with urllib.request.urlopen(req) as response, open("temp.tif", 'wb') as out_file:
                out_file.write(response.read())
            os.system(f"magick temp.tif -quality 85 {out_path}")
            os.remove("temp.tif")
            print(f"Successfully downloaded and converted {filename}")
        else:
            req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
            with urllib.request.urlopen(req) as response, open(out_path, 'wb') as out_file:
                out_file.write(response.read())
            print(f"Successfully downloaded {filename}")
    except Exception as e:
        print(f"Failed to download {filename}. Error: {e}")
        print(f"Creating fallback 1x1 texture to prevent crashes.")
        os.system(f"magick -size 1x1 xc:black {out_path}")

def main():
    missing_files = []
    for filename in ASSETS:
        out_path = os.path.join("assets", "textures", filename)
        if not os.path.exists(out_path):
            missing_files.append(filename)

    
    if not missing_files:
        print("All texture assets are already present.")
        return

    print(f"Missing {len(missing_files)} texture assets. Starting downloads...")
    for filename in missing_files:
        download_file(ASSETS[filename], filename)

if __name__ == "__main__":
    main()
