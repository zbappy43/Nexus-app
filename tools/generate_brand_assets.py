#!/usr/bin/env python3
"""Generates every brand image used by the app from the official logo.

Source: assets/brand/logo_source.jpg (round Nexus Consumers Limited emblem
on a white background). Replace that file to rebrand, then run:

  python3 tools/generate_brand_assets.py
  dart run flutter_launcher_icons
  dart run flutter_native_splash:create
  python3 tools/generate_brand_assets.py --round-only

Outputs (all PNG):
  assets/images/logo.png                    in-app logo (transparent circle, 1024px)
  assets/images/splash_logo.png             native splash image (pre Android 12)
  assets/images/splash_logo_android12.png   Android 12+ splash icon (1152px canvas)
  assets/icons/app_icon.png                 legacy launcher icon (1024px)
  assets/icons/app_icon_foreground.png      adaptive icon foreground (1024px)
  assets/icons/app_icon_monochrome.png      Android 13 themed icon (white silhouette)
  android/app/src/main/res/mipmap-*/ic_launcher_round.png
  android/app/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml

Requires Pillow (pip install pillow).
"""
import argparse
import os

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, 'assets/brand/logo_source.jpg')
WHITE = (255, 255, 255, 255)
SS = 4  # supersampling for smooth mask edges


def load_emblem(size):
    """Returns the round emblem cut out of its background, `size` px square."""
    src = Image.open(SOURCE).convert('RGB')
    # Bounding box of everything that is not (near) white = the emblem circle.
    gray = src.convert('L').point(lambda v: 255 if v < 235 else 0)
    left, top, right, bottom = gray.getbbox()
    side = max(right - left, bottom - top)
    cx, cy = (left + right) / 2, (top + bottom) / 2
    box = (round(cx - side / 2), round(cy - side / 2), round(cx + side / 2), round(cy + side / 2))
    emblem = src.crop(box).convert('RGBA').resize((size * SS, size * SS), Image.LANCZOS)
    mask = Image.new('L', emblem.size, 0)
    inset = SS * size * 0.004  # trim the anti-aliased white fringe
    ImageDraw.Draw(mask).ellipse([inset, inset, emblem.size[0] - inset, emblem.size[1] - inset], fill=255)
    emblem.putalpha(mask)
    return emblem.resize((size, size), Image.LANCZOS)


def on_canvas(emblem, canvas_size, scale, background=None):
    """Centres the emblem at `scale` of the canvas width."""
    canvas = Image.new('RGBA', (canvas_size, canvas_size), background or (0, 0, 0, 0))
    inner = round(canvas_size * scale)
    piece = emblem.resize((inner, inner), Image.LANCZOS)
    offset = (canvas_size - inner) // 2
    canvas.alpha_composite(piece, (offset, offset))
    return canvas


def monochrome(emblem):
    """White silhouette of the coloured parts (ring, arrows, hands)."""
    rgb = emblem.convert('RGB')
    # Non-white pixels become opaque; white text / background becomes transparent.
    ink = ImageChops.invert(rgb.convert('L')).point(lambda v: 255 if v > 40 else 0)
    alpha = ImageChops.multiply(ink, emblem.getchannel('A')).filter(ImageFilter.SMOOTH)
    out = Image.new('RGBA', emblem.size, WHITE)
    out.putalpha(alpha)
    return out


def save(img, rel):
    path = os.path.join(ROOT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, optimize=True)
    print('wrote', rel)


def generate_main():
    emblem = load_emblem(1024)
    save(emblem, 'assets/images/logo.png')
    save(emblem.resize((512, 512), Image.LANCZOS), 'assets/images/splash_logo.png')
    # Android 12 splash: the icon is clipped to a circle of 2/3 of the canvas.
    save(on_canvas(emblem, 1152, 0.64), 'assets/images/splash_logo_android12.png')
    # Legacy (pre-Android 8) launcher icon: emblem on white.
    save(on_canvas(emblem, 1024, 0.96, background=WHITE), 'assets/icons/app_icon.png')
    # Adaptive foreground: flutter_launcher_icons adds a 16% inset; launchers
    # mask to circles/squircles, so keep the round emblem inside the safe zone.
    save(on_canvas(emblem, 1024, 0.98), 'assets/icons/app_icon_foreground.png')
    save(on_canvas(monochrome(emblem), 1024, 0.98), 'assets/icons/app_icon_monochrome.png')


def generate_round():
    densities = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}
    emblem = load_emblem(1024)
    for name, px in densities.items():
        save(emblem.resize((px, px), Image.LANCZOS),
             f'android/app/src/main/res/mipmap-{name}/ic_launcher_round.png')
    xml_rel = 'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml'
    xml_path = os.path.join(ROOT, xml_rel)
    if os.path.exists(xml_path):
        with open(xml_path) as f:
            xml = f.read()
        with open(xml_path.replace('ic_launcher.xml', 'ic_launcher_round.xml'), 'w') as f:
            f.write(xml)
        print('wrote', xml_rel.replace('ic_launcher.xml', 'ic_launcher_round.xml'))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--round-only', action='store_true', help='only regenerate round launcher icons')
    args = parser.parse_args()
    if not args.round_only:
        generate_main()
    generate_round()
