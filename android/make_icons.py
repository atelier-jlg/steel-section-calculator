"""Génère les icônes du lanceur (res/mipmap-*/ic_launcher.png)."""
import os, sys
from PIL import Image, ImageDraw

SIZES = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}

def icon(px):
    s = px * 4  # sur-échantillonnage pour l'anticrénelage
    im = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([0, 0, s - 1, s - 1], radius=s * 0.22, fill=(37, 99, 235, 255))
    # Section de barre HA : cercle + nervures, avec le symbole Ø
    c, r = s / 2, s * 0.30
    d.ellipse([c - r, c - r, c + r, c + r], outline=(255, 255, 255, 255), width=int(s * 0.07))
    w = int(s * 0.07)
    d.line([c - r * 1.25, c + r * 1.25, c + r * 1.25, c - r * 1.25], fill=(255, 255, 255, 255), width=w)
    return im.resize((px, px), Image.LANCZOS)

out = sys.argv[1]
for name, px in SIZES.items():
    p = os.path.join(out, "mipmap-" + name)
    os.makedirs(p, exist_ok=True)
    icon(px).save(os.path.join(p, "ic_launcher.png"), optimize=True)
