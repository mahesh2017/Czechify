#!/usr/bin/env python3
"""
Prepare the teacher character art for the teaching-card intro.

Takes the full-body source renders, cuts the white background to transparency,
crops to a head-and-torso framing (keeps the welcoming hand gesture), and writes
retina-sized PNGs into assets/images/.

The background cut uses an edge flood-fill rather than a global white threshold,
so the characters' light/cream clothing is not punched through.

Source images are not in the repo (they are large originals); pass their folder
with --src if regenerating.

Usage:
    python3 tool/prepare_teacher_art.py [--src ~/Downloads]
"""

import argparse
import os

from PIL import Image, ImageDraw, ImageFilter
import numpy as np

HERE = os.path.dirname(__file__)
OUT_DIR = os.path.join(HERE, '..', 'assets', 'images')

SOURCES = {
    'female': 'animated Female teacher.png',
    'male': 'animated Male teacher.png',
}

# Vertical crop window in source pixels: just above the hair down to below the
# gesturing hands. The sources are the same 1408x3054 framing for both.
CROP_TOP = 330
CROP_BOTTOM = 1780

# Exported width (≈3x the ~112pt slot the card renders it in).
TARGET_W = 400

SENTINEL = (255, 0, 255)


def cut_background(path):
    """White background -> transparent, via flood fill from the borders."""
    im = Image.open(path).convert('RGB')
    w, h = im.size
    work = im.copy()
    seeds = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1),
             (w // 2, 0), (w // 2, h - 1), (0, h // 2), (w - 1, h // 2)]
    for pt in seeds:
        ImageDraw.floodfill(work, pt, SENTINEL, thresh=42)

    arr = np.asarray(work)
    bg = ((arr[:, :, 0] == SENTINEL[0]) &
          (arr[:, :, 1] == SENTINEL[1]) &
          (arr[:, :, 2] == SENTINEL[2]))

    alpha = Image.fromarray(np.where(bg, 0, 255).astype(np.uint8))
    # A hair of blur keeps the cut edge from looking jagged.
    alpha = alpha.filter(ImageFilter.GaussianBlur(0.8))

    out = im.convert('RGBA')
    out.putalpha(alpha)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--src', default=os.path.expanduser('~/Downloads'))
    args = ap.parse_args()

    os.makedirs(OUT_DIR, exist_ok=True)
    for gender, filename in SOURCES.items():
        src = os.path.join(args.src, filename)
        if not os.path.exists(src):
            print(f'!! missing source: {src}')
            continue

        full = cut_background(src)
        crop = full.crop((0, CROP_TOP, full.width, CROP_BOTTOM))
        # Trim to the character's actual bounds.
        bbox = crop.split()[3].getbbox()
        if bbox:
            crop = crop.crop(bbox)

        ratio = TARGET_W / crop.width
        crop = crop.resize(
            (TARGET_W, max(1, round(crop.height * ratio))), Image.LANCZOS
        )

        dest = os.path.join(OUT_DIR, f'teacher_{gender}.png')
        crop.save(dest, optimize=True)
        kb = os.path.getsize(dest) / 1024
        print(f'wrote {os.path.basename(dest)}  {crop.width}x{crop.height}  {kb:.0f} KB')


if __name__ == '__main__':
    main()
