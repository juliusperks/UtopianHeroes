#!/usr/bin/env python3
"""Generate a thematic game background with PixelLab.

Writes a single image you can assign to the Main scene background.
"""

from __future__ import annotations

import argparse
import os
from pathlib import Path

from dotenv import load_dotenv
import pixellab
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT_DEFAULT = ROOT / "assets" / "art" / "backgrounds" / "main_bg.png"
MAX_DIM = 400


THEMES = {
    "utopia_fantasy": (
        "pixel-art fantasy battlefield backdrop, twilight sky, ancient ruins, distant forests, "
        "subtle atmosphere for strategy game UI readability, no characters, no text, no watermark"
    ),
    "enchanted_forest": (
        "pixel-art enchanted forest clearing, mystical runes, moonlit fog, layered depth, "
        "dark readable center area for gameplay overlays, no characters, no text, no watermark"
    ),
    "war_camp": (
        "pixel-art medieval war camp background, banners, distant fires, "
        "moody blue night lighting, "
        "clean composition for tactical UI overlays, no characters, no text, no watermark"
    ),
    "battlefield_topdown": (
        "top-down pixel-art battlefield, small central arena of grass and worn dirt, "
        "stone border enclosing the field, subtle fantasy atmosphere, clean readable play surface, "
        "no characters, no text, no watermark"
    ),
}


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser()
    p.add_argument("--theme", choices=sorted(THEMES.keys()), default="utopia_fantasy")
    p.add_argument("--prompt", default="", help="Optional custom prompt override")
    p.add_argument("--model", choices=["pixflux", "bitforge"], default="pixflux")
    p.add_argument("--width", type=int, default=400, help="Generation width (API max 400)")
    p.add_argument("--height", type=int, default=225, help="Generation height (API max 400)")
    p.add_argument(
        "--target-width", type=int, default=1280, help="Final output width after upscale"
    )
    p.add_argument(
        "--target-height", type=int, default=720, help="Final output height after upscale"
    )
    p.add_argument("--out", default=str(OUT_DEFAULT))
    p.add_argument("--seed", type=int, default=0)
    return p.parse_args()


def main() -> int:
    args = parse_args()
    load_dotenv(ROOT / ".env")
    api_key = os.getenv("PIXELLAB_API_KEY", "").strip()
    if not api_key:
        print("ERROR: PIXELLAB_API_KEY missing")
        return 1

    prompt = args.prompt.strip() or THEMES[args.theme]
    if args.width > MAX_DIM or args.height > MAX_DIM:
        print(f"ERROR: --width/--height must be <= {MAX_DIM} for PixelLab")
        return 2

    client = pixellab.Client(secret=api_key)
    kwargs = {
        "description": prompt,
        "image_size": {"width": args.width, "height": args.height},
        "negative_description": "text, letters, logo, watermark, blurry",
        "no_background": False,
        "seed": args.seed,
    }
    if args.model == "bitforge":
        resp = client.generate_image_bitforge(**kwargs)
    else:
        resp = client.generate_image_pixflux(**kwargs)

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    img: Image.Image = resp.image.pil_image().convert("RGBA")

    # Upscale/crop to target viewport while preserving aspect ratio.
    src_w, src_h = img.size
    scale = max(args.target_width / float(src_w), args.target_height / float(src_h))
    up_w = max(1, int(round(src_w * scale)))
    up_h = max(1, int(round(src_h * scale)))
    upscaled = img.resize((up_w, up_h), resample=Image.NEAREST)
    left = max(0, (up_w - args.target_width) // 2)
    top = max(0, (up_h - args.target_height) // 2)
    cropped = upscaled.crop((left, top, left + args.target_width, top + args.target_height))

    cropped.save(out)
    print(f"saved: {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
