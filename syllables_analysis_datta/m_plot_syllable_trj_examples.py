"""
Tile syllable trajectory example images in a grid, ordered by frequency.
"""

from PIL import Image, ImageDraw, ImageFont
from pathlib import Path

# Parameters
png_dir = Path("/Users/stefan/Downloads/berkeley_collab/kpms/trajectory_plots/pngs")
output_path = png_dir.parent / "syllable_grid.png"
grid_rows = 5
grid_cols = 4
strip_height = 18
tile_padding = 10

# Most common motifs (in order of frequency)
most_common_motifs = [0, 2, 1, 3, 4, 16, 18, 14, 23, 13, 7, 11, 22, 12, 15, 20, 26, 32, 29, 19]

sorted_syllables = [29, 22, 14, 16, 32, 23, 13, 20, 26, 18, 12, 4, 19, 15, 11, 7, 3, 1, 2, 0, 8, 52, 47, 28, 40]
cmap25 = [
    (0.8667, 0.6275, 0.8667),
    (0.0000, 0.9804, 0.6039),
    (1.0000, 0.6471, 0.0000),
    (0.5020, 0.5020, 0.0000),
    (0.9412, 0.9020, 0.5490),
    (1.0000, 0.0000, 0.0000),
    (0.0000, 0.0000, 0.8039),
    (0.0000, 0.7490, 1.0000),
    (1.0000, 0.0000, 1.0000),
    (0.6980, 0.1333, 0.1333),
    (0.9137, 0.5882, 0.4784),
    (1.0000, 1.0000, 0.0000),
    (1.0000, 0.0784, 0.5765),
    (0.0000, 1.0000, 1.0000),
    (0.7294, 0.3333, 0.8275),
    (0.0000, 1.0000, 0.0000),
    (0.0980, 0.0980, 0.4392),
    (0.1804, 0.5451, 0.3412),
    (0.1843, 0.3098, 0.3098),
    (0.8275, 0.8275, 0.8275),
    (0.3647, 0.2510, 0.2157),
    (0.4745, 0.5255, 0.7961),
    (0.0000, 0.3765, 0.3922),
    (0.7490, 0.2118, 0.0471),
    (0.2902, 0.0784, 0.5490),
]

# Load images in order
images = []
for motif in most_common_motifs[:grid_rows * grid_cols]:
    img_path = png_dir / f"Syllable{motif}.png"
    if img_path.exists():
        img = Image.open(img_path)
        images.append((motif, img))
        print(f"Loaded Syllable{motif}.png: {img.size}")
    else:
        print(f"Warning: {img_path} not found")
        images.append((motif, None))

# Get target size (use first valid image or specify manually)
target_size = None
for motif, img in images:
    if img is not None:
        target_size = img.size  # (width, height)
        break

if target_size is None:
    raise ValueError("No valid images found")

print(f"\nTarget size: {target_size}")

try:
    font = ImageFont.truetype("Arial.ttf", 16)
except OSError:
    font = ImageFont.load_default()


def get_syllable_color(motif):
    try:
        idx = sorted_syllables.index(motif)
        rgb = cmap25[idx]
    except ValueError:
        rgb = (0.5, 0.5, 0.5)
    return tuple(int(round(channel * 255)) for channel in rgb)


def make_labeled_tile(motif, img):
    tile_w, tile_h = img.size
    header_h = strip_height + tile_padding
    tile = Image.new("RGB", (tile_w, tile_h + header_h), color=(255, 255, 255))
    tile.paste(img, (0, header_h))

    draw = ImageDraw.Draw(tile)
    strip_margin = 8
    strip_y = 0
    draw.rectangle(
        [(strip_margin, strip_y), (tile_w - strip_margin, strip_y + strip_height)],
        fill=get_syllable_color(motif),
    )
    return tile

# Resize all images to target size
resized = []
for motif, img in images:
    if img is not None:
        if img.size != target_size:
            img = img.resize(target_size, Image.Resampling.LANCZOS)
        resized.append((motif, make_labeled_tile(motif, img)))
    else:
        # Create blank placeholder
        blank = Image.new('RGB', target_size, color=(255, 255, 255))
        resized.append((motif, make_labeled_tile(motif, blank)))

# Create grid
tile_w, tile_h = target_size
tile_h = tile_h + strip_height + tile_padding
grid_w = grid_cols * tile_w
grid_h = grid_rows * tile_h
grid_img = Image.new('RGB', (grid_w, grid_h), color=(255, 255, 255))

for idx, (motif, img) in enumerate(resized):
    row = idx // grid_cols
    col = idx % grid_cols
    x = col * tile_w
    y = row * tile_h
    grid_img.paste(img, (x, y))

# Save
grid_img.save(output_path, dpi=(300, 300))
print(f"\nSaved grid to: {output_path}")
print(f"Grid size: {grid_w} x {grid_h} px")
