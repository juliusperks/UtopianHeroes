#!/usr/bin/env python3
"""Generate unit icons with PixelLab and wire sprite paths in data/units.json.

Usage examples:
  python scripts/pixellab_generate_unit_icons.py --limit 5
  python scripts/pixellab_generate_unit_icons.py --model bitforge --overwrite
  python scripts/pixellab_generate_unit_icons.py --dry-run
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
import time
from pathlib import Path
from typing import Dict, List

from dotenv import load_dotenv
import pixellab

ROOT = Path(__file__).resolve().parents[1]
UNITS_JSON = ROOT / "data" / "units.json"
OUT_DIR = ROOT / "assets" / "art" / "units"

STYLE = (
    "pixel-art fantasy unit portrait icon, clean silhouette, centered subject, "
    "high contrast, transparent background, no text, no letters, no watermark"
)

RACE_CUES: Dict[str, str] = {
    "avian": "winged sky warrior motif, feathered armor, agile",
    "dwarf": "stout armored engineer motif, metalwork and runes",
    "elf": "graceful arcane forest motif, elegant armor",
    "dark_elf": "shadow-arcane motif, sinister elegant armor",
    "orc": "brutal war motif, tusks and tribal armor",
    "undead": "necromantic motif, bone and plague energy",
    "halfling": "small stealthy trickster motif, nimble",
    "faerie": "fey magic motif, luminous and whimsical",
    "human": "noble disciplined kingdom motif, heraldic",
    "gnome": "tinker mage motif, gadgets and clever design",
    "dryad": "nature spirit motif, wood and vine elements",
}

CLASS_CUES: Dict[str, str] = {
    "paladin": "holy defender with shield",
    "rogue": "stealth assassin with daggers",
    "general": "battle commander with banner",
    "sage": "scholar mage with tome",
    "mystic": "spellcaster with arcane focus",
    "heretic": "forbidden caster with dark sigils",
    "shepherd": "supportive warden with staff",
    "merchant": "trader archetype with coin and utility gear",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", choices=["pixflux", "bitforge"], default="pixflux")
    parser.add_argument("--size", type=int, default=256)
    parser.add_argument("--limit", type=int, default=0, help="Generate only first N units")
    parser.add_argument("--overwrite", action="store_true")
    parser.add_argument("--no-wire", action="store_true", help="Do not update data/units.json")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--sleep", type=float, default=0.2, help="Delay between requests")
    return parser.parse_args()


def load_units() -> List[dict]:
    with UNITS_JSON.open("r", encoding="utf-8") as f:
        return json.load(f)


def save_units(units: List[dict]) -> None:
    with UNITS_JSON.open("w", encoding="utf-8") as f:
        json.dump(units, f, indent=2)
        f.write("\n")


def stable_seed(unit_id: str) -> int:
    h = hashlib.sha1(unit_id.encode("utf-8")).hexdigest()
    return int(h[:8], 16)


def prompt_for(unit: dict) -> str:
    origin = unit.get("origin", "")
    unit_class = unit.get("class", "")
    race_desc = RACE_CUES.get(origin, "fantasy faction motif")
    class_desc = CLASS_CUES.get(unit_class, "combat role motif")
    return (
        f"{unit.get('name', unit.get('id', 'unit'))}, "
        f"{race_desc}, {class_desc}, {STYLE}"
    )


def generate_one(client: pixellab.Client, unit: dict, model: str, size: int, out_path: Path) -> None:
    desc = prompt_for(unit)
    seed = stable_seed(unit.get("id", "unit"))

    kwargs = {
        "description": desc,
        "image_size": {"width": size, "height": size},
        "no_background": True,
        "seed": seed,
        "negative_description": "text, letters, watermark, blurry, low contrast",
    }

    if model == "bitforge":
        resp = client.generate_image_bitforge(**kwargs)
    else:
        resp = client.generate_image_pixflux(**kwargs)

    image = resp.image.pil_image()
    image.save(out_path)


def main() -> int:
    args = parse_args()

    load_dotenv(ROOT / ".env")
    api_key = os.getenv("PIXELLAB_API_KEY", "").strip()
    if not api_key:
        print("ERROR: PIXELLAB_API_KEY is not set (env or .env)", file=sys.stderr)
        return 1

    units = load_units()
    if args.limit > 0:
        units = units[: args.limit]

    OUT_DIR.mkdir(parents=True, exist_ok=True)

    if args.dry_run:
        for u in units:
            rel = f"res://assets/art/units/{u['id']}.png"
            print(f"[DRY RUN] {u['id']} -> {rel}")
            print(f"          prompt: {prompt_for(u)}")
        return 0

    client = pixellab.Client(secret=api_key)

    ok = 0
    failed: List[str] = []

    for unit in units:
        uid = unit["id"]
        out_path = OUT_DIR / f"{uid}.png"
        rel_path = f"res://assets/art/units/{uid}.png"

        if out_path.exists() and not args.overwrite:
            print(f"[SKIP] {uid} already exists")
            if not args.no_wire:
                unit["sprite"] = rel_path
            continue

        try:
            print(f"[GEN ] {uid}")
            generate_one(client, unit, args.model, args.size, out_path)
            ok += 1
            if not args.no_wire:
                unit["sprite"] = rel_path
        except Exception as exc:  # noqa: BLE001
            failed.append(uid)
            print(f"[FAIL] {uid}: {exc}", file=sys.stderr)

        if args.sleep > 0:
            time.sleep(args.sleep)

    if not args.no_wire:
        # Update all generated/kept units in full JSON while preserving untouched entries.
        all_units = load_units()
        by_id = {u["id"]: u for u in units}
        for entry in all_units:
            if entry["id"] in by_id and "sprite" in by_id[entry["id"]]:
                entry["sprite"] = by_id[entry["id"]]["sprite"]
        save_units(all_units)
        print("[DONE] Updated data/units.json sprite paths")

    print(f"[DONE] generated={ok} failed={len(failed)}")
    if failed:
        print("[DONE] failed ids: " + ", ".join(failed), file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
