"""Generates the original Cut & Run launcher icons (legacy + adaptive) with Pillow.

Run from repo root: python tool/gen_icons.py
"""
import os
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, "android", "app", "src", "main", "res")

BG_TOP = (34, 41, 92)
BG_BOTTOM = (13, 16, 36)
ORANGE = (255, 106, 61)
ORANGE_LIGHT = (255, 150, 105)
ORANGE_DARK = (201, 67, 34)
CYAN = (61, 214, 245)
WHITE = (255, 255, 255)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def gradient(size):
    img = Image.new("RGB", (size, size))
    d = ImageDraw.Draw(img)
    for y in range(size):
        d.line([(0, y), (size, y)], fill=lerp(BG_TOP, BG_BOTTOM, y / size))
    return img


def half_block(size, offset, side):
    """Draws one half of a square cut along the diagonal (bottom-left to top-right)."""
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    s = size
    x0, y0, x1, y1 = 0.26 * s, 0.26 * s, 0.74 * s, 0.74 * s
    if side == 0:  # upper-left half
        pts = [(x0, y0), (x1, y0), (x0, y1)]
        dx, dy = -offset, -offset
    else:  # lower-right half
        pts = [(x1, y0), (x1, y1), (x0, y1)]
        dx, dy = offset, offset
    pts = [(p[0] + dx, p[1] + dy) for p in pts]
    d.polygon(pts, fill=ORANGE)
    # soft inner shade on the lower-right half gives the pieces depth
    if side == 1:
        d.polygon([(x1 + dx, y0 + dy + s * 0.06), (x1 + dx, y1 + dy), (x0 + dx + s * 0.06, y1 + dy)], fill=ORANGE_DARK)
        d.polygon([(x1 + dx - s * 0.03, y0 + dy + s * 0.12), (x1 + dx - s * 0.03, y1 + dy - s * 0.03), (x0 + dx + s * 0.12, y1 + dy - s * 0.03)], fill=ORANGE)
    else:
        d.polygon([(x0 + dx, y0 + dy), (x1 + dx - s * 0.06, y0 + dy), (x0 + dx, y1 + dy - s * 0.06)], fill=ORANGE_LIGHT)
        d.polygon([(x0 + dx + s * 0.03, y0 + dy + s * 0.03), (x1 + dx - s * 0.12, y0 + dy + s * 0.03), (x0 + dx + s * 0.03, y1 + dy - s * 0.12)], fill=ORANGE)
    return layer


def emblem(size, with_bg):
    img = gradient(size).convert("RGBA") if with_bg else Image.new("RGBA", (size, size), (0, 0, 0, 0))
    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.ellipse([0.24 * size, 0.70 * size, 0.76 * size, 0.82 * size], fill=(0, 0, 0, 110))
    shadow = shadow.filter(ImageFilter.GaussianBlur(size / 40))
    img = Image.alpha_composite(img, shadow)
    off = size * 0.035
    img = Image.alpha_composite(img, half_block(size, off, 0))
    img = Image.alpha_composite(img, half_block(size, off, 1))
    # the slash: a glowing blade line across the cut
    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    a = (0.16 * size, 0.84 * size)
    b = (0.84 * size, 0.16 * size)
    gd.line([a, b], fill=CYAN + (170,), width=int(size * 0.06))
    glow = glow.filter(ImageFilter.GaussianBlur(size / 45))
    img = Image.alpha_composite(img, glow)
    ld = ImageDraw.Draw(img)
    ld.line([a, b], fill=WHITE, width=max(2, int(size * 0.022)))
    return img


def rounded(img, radius_ratio):
    size = img.size[0]
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size - 1, size - 1], radius=int(size * radius_ratio), fill=255)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    return out


def circle(img):
    size = img.size[0]
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).ellipse([0, 0, size - 1, size - 1], fill=255)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    return out


def main():
    master = emblem(1024, True)
    legacy = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
    for density, px in legacy.items():
        folder = os.path.join(RES, f"mipmap-{density}")
        os.makedirs(folder, exist_ok=True)
        rounded(master, 0.22).resize((px, px), Image.LANCZOS).save(os.path.join(folder, "ic_launcher.png"))
        circle(master).resize((px, px), Image.LANCZOS).save(os.path.join(folder, "ic_launcher_round.png"))
        # adaptive foreground: 108dp canvas with the emblem inside the 72dp safe zone
        fg_px = int(px * 108 / 48)
        fg = Image.new("RGBA", (fg_px, fg_px), (0, 0, 0, 0))
        inner = emblem(1024, False).resize((int(fg_px * 0.78), int(fg_px * 0.78)), Image.LANCZOS)
        pos = (fg_px - inner.size[0]) // 2
        fg.alpha_composite(inner, (pos, pos))
        fg.save(os.path.join(folder, "ic_launcher_foreground.png"))
    anydpi = os.path.join(RES, "mipmap-anydpi-v26")
    os.makedirs(anydpi, exist_ok=True)
    xml = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
"""
    for name in ("ic_launcher.xml", "ic_launcher_round.xml"):
        with open(os.path.join(anydpi, name), "w") as f:
            f.write(xml)
    # splash emblem (drawn on the splash background colour)
    splash = emblem(1024, False).resize((288, 288), Image.LANCZOS)
    splash_dir = os.path.join(RES, "drawable-nodpi")
    os.makedirs(splash_dir, exist_ok=True)
    splash.save(os.path.join(splash_dir, "splash_emblem.png"))
    store = os.path.join(ROOT, "assets", "branding")
    os.makedirs(store, exist_ok=True)
    master.resize((512, 512), Image.LANCZOS).save(os.path.join(store, "icon_512.png"))
    print("icons generated")


if __name__ == "__main__":
    main()
