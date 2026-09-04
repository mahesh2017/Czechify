#!/usr/bin/env python3
"""Re-encode bundled illustration PNGs as WebP.

The art is watercolour-style illustration that was being stored losslessly,
which is the worst possible format for it: `assets/images` was 42 MB of a
75.6 MB app. WebP q95 takes that to about 11.3 MB. q90 was tried first and is smaller
still, at 7.7 MB, but at 4x magnification it visibly flattens the paper grain
the watercolour style depends on — worst-case SSIM 0.938 against 0.953 for
q95. Three and a half megabytes is not worth losing the texture over. Going
further has no more to give: q98 costs another 3 MB for 0.005 of SSIM, because
the ceiling is lossy WebP's 4:2:0 chroma subsampling, which no quality setting
changes.

Images with an alpha channel are left alone. There are eight, they total half
a megabyte, and they are the ones where re-encoding would actually cost
something: the two launcher-icon sources that `flutter_launcher_icons` reads
from `pubspec.yaml`, the four Google sign-in buttons (brand assets that must
not be re-encoded), and the two teacher portraits.

Run after adding new art:

    python3 tool/compress_images.py

It is idempotent — converted files leave no PNG behind — and it only writes
inside assets/images. It does NOT rewrite the paths that reference the files;
`test/asset_paths_test.dart` fails if a reference is left pointing at a file
that no longer exists.
"""

from __future__ import annotations

import pathlib
import sys

try:
    from PIL import Image
except ImportError:  # pragma: no cover - developer tooling
    sys.exit("Pillow is required: python3 -m pip install Pillow")

QUALITY = 95
ROOT = pathlib.Path(__file__).resolve().parent.parent / "assets" / "images"


def has_alpha(image: Image.Image) -> bool:
    return image.mode in ("RGBA", "LA") or (
        image.mode == "P" and "transparency" in image.info
    )


def main() -> int:
    if not ROOT.is_dir():
        sys.exit(f"not found: {ROOT}")

    converted = kept = 0
    before = after = 0

    for png in sorted(ROOT.rglob("*.png")):
        with Image.open(png) as image:
            image.load()
            if has_alpha(image):
                kept += 1
                continue
            source = image.convert("RGB")
            webp = png.with_suffix(".webp")
            source.save(webp, "WEBP", quality=QUALITY, method=6)

        before += png.stat().st_size
        after += webp.stat().st_size
        png.unlink()
        converted += 1

    if converted:
        print(
            f"{converted} converted: {before / 1e6:.1f} MB -> {after / 1e6:.1f} MB "
            f"({100 * (1 - after / before):.0f}% smaller)"
        )
    print(f"{kept} left as PNG (alpha channel)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
