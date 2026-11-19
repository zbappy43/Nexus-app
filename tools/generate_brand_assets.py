#!/usr/bin/env python3
"""Generates the Nexus Consumers brand images used by the app.

Outputs (all PNG):
  assets/images/logo.png                    in-app logo (transparent, 1024px)
  assets/images/splash_logo.png             native splash image (pre Android 12)
  assets/images/splash_logo_android12.png   Android 12+ splash icon (1152px canvas)
  assets/icons/app_icon.png                 legacy launcher icon (1024px)
  assets/icons/app_icon_foreground.png      adaptive icon foreground (1024px, safe zone)
  assets/icons/app_icon_monochrome.png      Android 13 themed icon (white on transparent)
  android/app/src/main/res/mipmap-*/ic_launcher_round.png  round launcher icons
  android/app/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml

Replace the generated logo with the official company artwork by overwriting
assets/icons/app_icon*.png and assets/images/*.png, then run:
  dart run flutter_launcher_icons
  dart run flutter_native_splash:create
  python3 tools/generate_brand_assets.py --round-only

Requires Pillow (pip install pillow).
"""
import argparse
import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GREEN = (10, 124, 62, 255)
GREEN_DARK = (6, 90, 44, 255)
GOLD = (255, 215, 0, 255)
WHITE = (255, 255, 255, 255)
SS = 4  # supersampling factor for smooth edges


def _n_polygon(cx, cy, size):
    """Bold geometric 'N' centred on (cx, cy) with total height `size`."""
    h = size
    w = size * 0.82
    s = size * 0.24  # stroke width
    x0, y0 = cx - w / 2, cy - h / 2
    x1, y1 = cx + w / 2, cy + h / 2
    return [
        (x0, y1), (x0, y0), (x0 + s, y0),
        (x1 - s, y1 - h * 0.42), (x1 - s, y0), (x1, y0),
        (x1, y1), (x1 - s, y1),
        (x0 + s, y0 + h * 0.42), (x0 + s, y1),
    ]


def draw_mark(size, *, background=None, ring=True, mark_scale=1.0, mono=False):
    """Circle badge with gold ring and white N. Returns an RGBA image."""
    big = size * SS
    img = Image.new('RGBA', (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    if background is not None:
        d.rectangle([0, 0, big, big], fill=background)
    c = big / 2
    r = big / 2 * mark_scale
    fg = WHITE
    if mono:
        d.ellipse([c - r, c - r, c + r, c + r], outline=WHITE, width=int(r * 0.09))
    else:
        d.ellipse([c - r, c - r, c + r, c + r], fill=GREEN)
        if ring:
            d.ellipse([c - r, c - r, c + r, c + r], outline=GOLD, width=int(r * 0.075))
        # Subtle inner shade for depth.
        ri = r * 0.82
        d.ellipse([c - ri, c - ri, c + ri, c + ri], outline=GREEN_DARK, width=int(r * 0.02))
    d.polygon(_n_polygon(c, c - r * 0.04, r * 0.95), fill=fg)
    # Gold swoosh under the N.
    sw = r * 0.62
    d.arc([c - sw, c + r * 0.18, c + sw, c + r * 0.78], start=20, end=160,
          fill=WHITE if mono else GOLD, width=int(r * 0.07))
    return img.resize((size, size), Image.LANCZOS)


def save(img, rel):
    path = os.path.join(ROOT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, optimize=True)
    print('wrote', rel)


def generate_main():
    save(draw_mark(1024), 'assets/images/logo.png')
    save(draw_mark(512), 'assets/images/splash_logo.png')
    # Android 12 splash: icon must fit in a 768px circle inside 1152px.
    canvas = Image.new('RGBA', (1152, 1152), (0, 0, 0, 0))
    canvas.alpha_composite(draw_mark(700), (226, 226))
    save(canvas, 'assets/images/splash_logo_android12.png')
    save(draw_mark(1024, background=GREEN, ring=True, mark_scale=0.86), 'assets/icons/app_icon.png')
    # Adaptive foreground: flutter_launcher_icons adds a 16% inset (safe zone).
    save(draw_mark(1024, mark_scale=0.92), 'assets/icons/app_icon_foreground.png')
    save(draw_mark(1024, mark_scale=0.92, mono=True), 'assets/icons/app_icon_monochrome.png')


def generate_round():
    densities = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}
    source = Image.open(os.path.join(ROOT, 'assets/icons/app_icon.png')).convert('RGBA')
    for name, px in densities.items():
        icon = source.resize((px * SS, px * SS), Image.LANCZOS)
        mask = Image.new('L', icon.size, 0)
        ImageDraw.Draw(mask).ellipse([0, 0, icon.size[0], icon.size[1]], fill=255)
        out = Image.new('RGBA', icon.size, (0, 0, 0, 0))
        out.paste(icon, (0, 0), mask)
        save(out.resize((px, px), Image.LANCZOS),
             f'android/app/src/main/res/mipmap-{name}/ic_launcher_round.png')
    xml_path = 'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml'
    if os.path.exists(os.path.join(ROOT, xml_path)):
        with open(os.path.join(ROOT, xml_path)) as f:
            xml = f.read()
        round_path = os.path.join(ROOT, 'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml')
        with open(round_path, 'w') as f:
            f.write(xml)
        print('wrote', 'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--round-only', action='store_true', help='only regenerate round launcher icons')
    args = parser.parse_args()
    if not args.round_only:
        generate_main()
    generate_round()
