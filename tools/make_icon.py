"""
iHunyuan app icon — minimal, clean composition.

The Tencent Hunyuan brand swirl on a single radial gradient. No drop
shadows or specular tricks (those were causing visual clipping of the
swirl's edges in earlier iterations). iOS 26 applies its own Liquid
Glass squircle + lighting at runtime; we just provide a clean square
1024×1024 PNG with the swirl centered inside the safe zone.

Generates the legacy `.appiconset` single-PNG format. iOS 26 still
accepts this for marketing icons.
"""
from __future__ import annotations
import math
import urllib.request
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "iHunyuan/Resources/Assets.xcassets"
LEGACY_PNG = ASSETS / "AppIcon.appiconset/AppIcon.png"

LOGO_URL = "https://github.com/Tencent-Hunyuan/HY-MT/raw/main/imgs/hunyuanlogo.png"
LOGO_CACHE = ROOT / "tools/.cache/hunyuanlogo.png"

# Render at 4x then downsample for crisp anti-aliasing.
SIZE_FINAL = 1024
SS = 4
SIZE = SIZE_FINAL * SS

# Tuned to harmonize with the Tencent brand-mark blue.
DEEP = (16, 18, 60)
ACCENT = (50, 80, 220)
PURPLE = (130, 90, 220)
PINK = (210, 110, 200)
GLOW = (240, 240, 255)


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def smoothstep(t: float) -> float:
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def fetch_swirl() -> Image.Image:
    LOGO_CACHE.parent.mkdir(parents=True, exist_ok=True)
    if not LOGO_CACHE.exists():
        urllib.request.urlretrieve(LOGO_URL, LOGO_CACHE)
    full = Image.open(LOGO_CACHE).convert("RGBA")
    sq = full.crop((0, 0, full.size[1], full.size[1]))
    bbox = sq.getbbox()
    if bbox:
        sq = sq.crop(bbox)
    return sq


def gradient(size: int) -> Image.Image:
    """Radial gradient with upper-left light source: glow → indigo → purple → pink → deep."""
    cx, cy = size * 0.40, size * 0.32
    max_r = size * 1.05
    img = Image.new("RGB", (size, size))
    px = img.load()
    for y in range(size):
        for x in range(size):
            dx, dy = x - cx, y - cy
            r = math.sqrt(dx * dx + dy * dy) / max_r
            r = max(0.0, min(1.4, r))
            if r < 0.30:
                t = smoothstep(r / 0.30)
                c = lerp(GLOW, ACCENT, t)
            elif r < 0.62:
                t = smoothstep((r - 0.30) / 0.32)
                c = lerp(ACCENT, PURPLE, t)
            elif r < 0.95:
                t = smoothstep((r - 0.62) / 0.33)
                c = lerp(PURPLE, PINK, t)
            else:
                t = min(1.0, (r - 0.95) / 0.45)
                c = lerp(PINK, DEEP, t)
            px[x, y] = c
    return img


def composite() -> Image.Image:
    bg = gradient(SIZE).convert("RGBA")

    # The Tencent swirl. Keep it well within iOS 26's Liquid Glass safe
    # zone — Apple's HIG recommends important content stay inside the
    # inner ~70% of the canvas. We use 56% so the round mark sits with
    # comfortable padding on every side.
    swirl = fetch_swirl()
    target = int(SIZE * 0.56)
    sw, sh = swirl.size
    new_size = (target, int(sh * target / sw))
    swirl = swirl.resize(new_size, Image.LANCZOS)

    # Soft halo around the swirl: a blurred white version of its alpha,
    # composited *under* the swirl. Drawn on a canvas with breathing room
    # so the blur doesn't get cropped.
    pad = int(SIZE * 0.05)
    halo_canvas = Image.new("RGBA", (new_size[0] + pad * 2, new_size[1] + pad * 2),
                            (0, 0, 0, 0))
    alpha = swirl.split()[3]
    halo_mask = Image.new("L", halo_canvas.size, 0)
    halo_mask.paste(alpha, (pad, pad))
    halo_mask = halo_mask.filter(ImageFilter.GaussianBlur(radius=SIZE * 0.025))
    halo = Image.new("RGBA", halo_canvas.size, (255, 255, 255, 0))
    halo.putalpha(halo_mask.point(lambda v: int(v * 0.45)))

    cx_halo = (SIZE - halo_canvas.size[0]) // 2
    cy_halo = (SIZE - halo_canvas.size[1]) // 2
    bg.alpha_composite(halo, (cx_halo, cy_halo))

    cx = (SIZE - new_size[0]) // 2
    cy = (SIZE - new_size[1]) // 2
    bg.alpha_composite(swirl, (cx, cy))

    return bg.resize((SIZE_FINAL, SIZE_FINAL), Image.LANCZOS)


def main():
    LEGACY_PNG.parent.mkdir(parents=True, exist_ok=True)
    icon = composite().convert("RGB")
    icon.save(LEGACY_PNG, "PNG", optimize=True)
    print(f"wrote {LEGACY_PNG.relative_to(ROOT)} ({LEGACY_PNG.stat().st_size / 1024:.0f} KB)")

    # Mirror to the AppIconArtwork imageset so the About sheet can show
    # the icon at runtime — keeps both assets in sync.
    artwork = ASSETS / "AppIconArtwork.imageset/AppIconArtwork.png"
    artwork.parent.mkdir(parents=True, exist_ok=True)
    icon.save(artwork, "PNG", optimize=True)
    print(f"wrote {artwork.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
