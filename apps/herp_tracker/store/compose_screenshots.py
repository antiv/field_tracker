"""Play Store phone screenshots, 1080x1920 (9:16), one set per listing language.

The raw device captures are 1220x2712 (1:2.223), narrower than the 9:16 Play
accepts, so each one is trimmed of its status bar and gesture pill, then seated
on a brand-green card under a headline. That fixes the ratio and gives the
listing a consistent frame instead of a dozen bare captures.

Source files are the captures dropped in store/: `screen.png`, `screen1..5.png`
for English and `screen_sr.png`, `screen_sr1..5.png` for Serbian. Output is
numbered in the order the shots should be uploaded, strongest first.
"""
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
import brand

SRC = '/Users/ivanantonijevic/development/reptiles_amphibians/store'
OUT = f'{SRC}/play'

W, H = 1080, 1920
STATUS_BAR = 96          # carrier / battery strip, cropped away
GESTURE_FALLBACK = 40    # used only if the home pill can't be located
BOX = (742, 1520)        # the device image is fitted inside this
REGION = (300, 1880)     # it is centred in the band below the headline
TEXT_MAX = 960           # a headline line wider than this gets stepped down

# (source suffix, english headline, serbian headline), in listing order
SHOTS = [
    ('5', 'Every transect,\npoint by point', 'Svaki transekt,\ntačku po tačku'),
    ('3', 'One record\nper finding', 'Jedan zapis\npo nalazu'),
    ('4', 'The full survey\ndata dictionary', 'Kompletan\nterenski upitnik'),
    ('2', 'Export as CSV,\nKML or KMZ', 'Izvoz u CSV,\nKML ili KMZ'),
    ('1', 'Tracks, backup\nand KML import', 'Staze, rezervne kopije\ni uvoz KML-a'),
    ('',  'Drop a point\nwherever you find one', 'Ubacite tačku\ngde god nađete nalaz'),
]

NAMES = ['transect_info', 'record', 'record_advanced', 'export', 'menu', 'map']


def source(suffix, lang):
    return f'{SRC}/screen{"_sr" if lang == "sr" else ""}{suffix}.png'


def pill_top(a):
    """Row where the home pill starts.

    A fixed bottom crop is not safe: the pill sits anywhere from y=2652 to
    y=2683 depending on the screen, and cutting at the deepest of those shaves
    the record form's Cancel/Save buttons off. The pill is the one horizontally
    centred band down there that contrasts with the row around it, in either
    direction — dark on the white forms, light on the map.
    """
    h, w = a.shape[:2]
    lum = a.mean(axis=2)
    for y in range(h - 60, h):
        centre = lum[y, w // 2 - 200:w // 2 + 200].mean()
        outer = np.concatenate([lum[y, :150], lum[y, -150:]]).mean()
        if abs(centre - outer) > 40:
            return y
    return h - GESTURE_FALLBACK


def trim(im):
    """Drop the status bar, the gesture pill, and any dead white tail."""
    w, h = im.size
    bottom = pill_top(np.asarray(im.convert('RGB')).astype(float)) - 8
    im = im.crop((0, STATUS_BAR, w, bottom))
    a = np.asarray(im.convert('RGB'))
    rows = np.where((a < 245).any(axis=(1, 2)))[0]
    if len(rows) and im.height - rows[-1] > 120:
        im = im.crop((0, 0, im.width, rows[-1] + 60))
    return im


def rounded(im, radius):
    mask = Image.new('L', im.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, im.width - 1, im.height - 1],
                                           radius, fill=255)
    im = im.convert('RGBA')
    im.putalpha(mask)
    return im


def fitted_font(draw, lines):
    """Serbian runs longer than English; step the headline down rather than
    letting a line run into the edge of the frame."""
    for size in (62, 58, 54, 50, 46):
        f = brand.font(size, brand.F_DEMI)
        if max(draw.textlength(line, font=f) for line in lines) <= TEXT_MAX:
            return f, size
    return f, size


def build(suffix, headline, lang, index, name):
    img = brand.gradient((W, H), (150, 197, 96), (52, 112, 36)).convert('RGB')
    img.paste((255, 255, 255), (0, 0), brand.glow((W, H), (540, 210), 720, 0.18))

    shot = trim(Image.open(source(suffix, lang)))
    scale = min(BOX[0] / shot.width, BOX[1] / shot.height)
    shot = shot.resize((round(shot.width * scale), round(shot.height * scale)),
                       Image.LANCZOS)
    shot = rounded(shot, 26)
    x = (W - shot.width) // 2

    # a trimmed capture (the record form loses its blank tail) is shorter than
    # the band, so centre it rather than pinning it under the headline
    top = REGION[0] + (REGION[1] - REGION[0] - shot.height) // 2

    # drop shadow, so the white forms don't float on the green
    shadow = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [x, top + 12, x + shot.width, top + shot.height + 12], 26, fill=(0, 40, 10, 110))
    img.paste(Image.alpha_composite(img.convert('RGBA'),
                                    shadow.filter(ImageFilter.GaussianBlur(22))).convert('RGB'),
              (0, 0))
    img.paste(shot, (x, top), shot)

    d = ImageDraw.Draw(img)
    lines = headline.split('\n')
    f, size = fitted_font(d, lines)
    step = round(size * 1.26)
    y = 150 - (len(lines) - 1) * step // 2
    for line in lines:
        brand.text_center(d, (W // 2, y), line, f)
        y += step

    path = f'{OUT}/{index:02d}_{name}_{lang}.png'
    img.save(path)
    return path


for lang in ('en', 'sr'):
    for i, ((suffix, en, sr), name) in enumerate(zip(SHOTS, NAMES), start=1):
        print(build(suffix, en if lang == 'en' else sr, lang, i, name))
