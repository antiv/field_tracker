"""Shared brand pieces for the Play Store assets.

The artwork is lifted straight out of launcher_icon/app_icon.png rather than
redrawn: the icon is pure white on the flat brand plate (#8BBC53), so keying
the white back out of the green recovers the lizard and the "HERP TRACKER"
wordmark as a clean alpha mask, in the exact shapes that ship on the device.
"""
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ICON = '/Users/ivanantonijevic/development/reptiles_amphibians/launcher_icon/app_icon.png'
PLATE = (139, 188, 83)          # #8BBC53 - adaptive icon background
APPBAR = (15, 157, 88)          # #0F9D58 - the app bar green

FONT = '/System/Library/Fonts/Avenir Next.ttc'
F_BOLD, F_DEMI, F_MED, F_REG = 0, 2, 5, 7

_LIZARD = (157, 214, 867, 544)
_WORDMARK = (128, 598, 898, 849)


def font(size, index=F_DEMI):
    return ImageFont.truetype(FONT, size, index=index)


def _mask():
    a = np.asarray(Image.open(ICON).convert('RGB')).astype(np.float32)
    bg = np.array(PLATE, dtype=np.float32)
    d = np.array([255., 255., 255.]) - bg
    t = np.clip(((a - bg) @ d) / (d @ d), 0, 1)
    return Image.fromarray((t * 255).astype(np.uint8), 'L')


_FULL = None


def art(which, width, color=(255, 255, 255)):
    """White (or tinted) lizard / wordmark as an RGBA image of the given width."""
    global _FULL
    if _FULL is None:
        _FULL = _mask()
    box = _LIZARD if which == 'lizard' else _WORDMARK
    m = _FULL.crop(box)
    h = round(width * m.height / m.width)
    m = m.resize((width, h), Image.LANCZOS)
    out = Image.new('RGBA', (width, h), color + (0,))
    out.putalpha(m)
    return out


def gradient(size, top_left, bottom_right):
    w, h = size
    x = np.linspace(0, 1, w)[None, :]
    y = np.linspace(0, 1, h)[:, None]
    t = np.clip((x * 0.62 + y * 0.38), 0, 1)[..., None]
    a = np.array(top_left, dtype=np.float32)
    b = np.array(bottom_right, dtype=np.float32)
    return Image.fromarray((a + (b - a) * t).astype(np.uint8), 'RGB')


def glow(size, center, radius, strength=0.16):
    """Soft white radial light, returned as an L mask to paste white through."""
    w, h = size
    yy, xx = np.mgrid[0:h, 0:w]
    r = np.sqrt((xx - center[0]) ** 2 + (yy - center[1]) ** 2) / radius
    v = np.clip(1 - r, 0, 1) ** 2
    return Image.fromarray((v * 255 * strength).astype(np.uint8), 'L')


def text_center(draw, xy, s, f, fill=(255, 255, 255), spacing=0):
    if spacing:
        widths = [draw.textlength(c, font=f) for c in s]
        total = sum(widths) + spacing * (len(s) - 1)
        x = xy[0] - total / 2
        for c, cw in zip(s, widths):
            draw.text((x, xy[1]), c, font=f, fill=fill, anchor='lm')
            x += cw + spacing
        return
    draw.text(xy, s, font=f, fill=fill, anchor='mm')
