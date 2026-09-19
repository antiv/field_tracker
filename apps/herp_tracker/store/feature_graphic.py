"""Play Store feature graphic, 1024x500, one per listing language."""
import sys
from PIL import Image, ImageDraw
import brand

OUT = '/Users/ivanantonijevic/development/reptiles_amphibians/store/play'

TAGLINE = {
    'en': 'Field surveys for reptiles and amphibians',
    'sr': 'Terenski popis gmizavaca i vodozemaca',
}

W, H = 1024, 500


def build(lang):
    img = brand.gradient((W, H), (154, 200, 100), (58, 118, 40)).convert('RGB')

    # soft light behind the lockup so the white artwork sits on the brightest
    # part of the gradient rather than fighting the dark corner
    img.paste((255, 255, 255), (0, 0), brand.glow((W, H), (430, 200), 560, 0.20))

    lizard = brand.art('lizard', 296)
    word = brand.art('wordmark', 322)

    gap = 44
    total = lizard.width + gap + word.width
    x0 = (W - total) // 2
    cy = 196
    img.paste(lizard, (x0, cy - lizard.height // 2), lizard)
    img.paste(word, (x0 + lizard.width + gap, cy - word.height // 2), word)

    d = ImageDraw.Draw(img)

    # hairline rule to tie the lockup to the tagline
    d.line([(W // 2 - 150, 330), (W // 2 + 150, 330)], fill=(255, 255, 255, 90), width=2)

    brand.text_center(d, (W // 2, 392), TAGLINE[lang], brand.font(37, brand.F_DEMI))

    path = f'{OUT}/feature_graphic_{lang}.png'
    img.save(path)
    print(path, img.size)


for lang in ('en', 'sr'):
    build(lang)
