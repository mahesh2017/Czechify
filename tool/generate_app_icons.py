#!/usr/bin/env python3
"""Derive the Android adaptive-icon layers from the iOS app icon.

`assets/images/app_icon.png` is the master: a full-bleed square with a vertical
blue gradient behind a cream speech bubble. iOS uses it directly. Android
cannot — an adaptive icon is two layers, and the launcher masks them to a
circle, squircle or whatever shape the device uses, showing only the central
72dp of a 108dp canvas.

The previous foreground was a miniature of the whole icon: its own opaque blue
plate with the bubble on it, sitting on the flat `#415AE8` background layer.
The plate's gradient matched that flat colour at the top and drifted away from
it toward the bottom, so a hard square edge appeared across the lower half of
every Android icon. It was also padded twice — once in the art, once by the
16% inset flutter_launcher_icons writes into ic_launcher.xml — which left the
bubble small and adrift.

So the foreground here is the bubble alone on a transparent canvas, and the
background is the gradient rather than a flat colour, which is what makes
Android read like iOS.

    python3 tool/generate_app_icons.py && dart run flutter_launcher_icons
"""

from __future__ import annotations

import pathlib
import sys

try:
    import numpy as np
    from PIL import Image
except ImportError:  # pragma: no cover - developer tooling
    sys.exit("Pillow and numpy are required: python3 -m pip install Pillow numpy")

ROOT = pathlib.Path(__file__).resolve().parent.parent
MASTER = ROOT / "assets" / "images" / "app_icon.png"
FOREGROUND = ROOT / "assets" / "images" / "app_icon_foreground.png"
BACKGROUND = ROOT / "assets" / "images" / "app_icon_background.png"

CANVAS = 1024

# Height of the bubble as a fraction of the foreground canvas.
#
# The canvas is 108dp; flutter_launcher_icons insets the foreground 16%, so it
# spans 68% of that; the launcher's mask shows the central 72dp. 63% puts the
# bubble at the same proportion of the visible circle that it occupies of the
# iOS square. Larger starts clipping the bubble's tail on a circular mask.
GLYPH_HEIGHT = 0.63

# The bubble's fill, needed to solve for coverage along its anti-aliased edge.
CREAM = np.array([246.0, 244.0, 239.0])


def cut_out_bubble(master: Image.Image) -> Image.Image:
    """Lift the bubble off its gradient, keeping soft edges.

    Every edge pixel is `a*F + (1-a)*B` for background `B` and bubble `F`. `B`
    is known exactly — the gradient is purely vertical, so column 0 is the
    background at every row — which makes both `a` and `F` recoverable. Keying
    on colour distance alone would leave a blue fringe around the bubble.
    """
    rgb = np.asarray(master.convert("RGB"), dtype=np.float64)
    height = rgb.shape[0]
    background = rgb[:, 0, :][:, None, :]

    reach = np.maximum(np.abs(CREAM[None, None, :] - background).max(axis=2), 1e-6)
    alpha = np.clip(np.abs(rgb - background).max(axis=2) / reach, 0, 1)
    safe = np.clip(alpha, 1e-6, 1)[:, :, None]
    front = np.clip((rgb - (1 - safe) * background) / safe, 0, 255)

    glyph = Image.fromarray(
        np.dstack([front, alpha * 255]).astype(np.uint8), "RGBA"
    )
    rows, cols = np.where(alpha > 0.02)
    if rows.size == 0:
        sys.exit(f"{MASTER} looks like a flat image — nothing to cut out")
    assert height == rgb.shape[0]
    return glyph.crop((cols.min(), rows.min(), cols.max() + 1, rows.max() + 1))


def main() -> int:
    if not MASTER.exists():
        sys.exit(f"not found: {MASTER}")

    with Image.open(MASTER) as master:
        master.load()
        bubble = cut_out_bubble(master)
        gradient_source = np.asarray(master.convert("RGB"))[:, 0, :]

    scale = CANVAS * GLYPH_HEIGHT / max(bubble.size)
    sized = bubble.resize(
        (round(bubble.width * scale), round(bubble.height * scale)), Image.LANCZOS
    )
    foreground = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    foreground.paste(
        sized, ((CANVAS - sized.width) // 2, (CANVAS - sized.height) // 2), sized
    )
    foreground.save(FOREGROUND)

    rows = len(gradient_source)
    gradient = np.zeros((CANVAS, CANVAS, 3), dtype=np.uint8)
    for y in range(CANVAS):
        gradient[y, :, :] = gradient_source[round(y * (rows - 1) / (CANVAS - 1))]
    Image.fromarray(gradient, "RGB").save(BACKGROUND)

    print(f"foreground: {FOREGROUND.relative_to(ROOT)}  bubble {sized.size}")
    print(f"background: {BACKGROUND.relative_to(ROOT)}  {CANVAS}x{CANVAS} gradient")
    print("now run: dart run flutter_launcher_icons")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
