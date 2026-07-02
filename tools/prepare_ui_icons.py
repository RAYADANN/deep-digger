"""Process AI-generated HUD icons into assets/ui/icon_*.png."""
from __future__ import annotations

import io
import sys
from pathlib import Path

from PIL import Image
from rembg import remove

sys.path.insert(0, str(Path(__file__).parent.parent / "assets" / "ui"))
from prepare_icons import strip_matte, defringe, crop_and_square  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
RAW_DIRS = [
    Path(r"C:\Users\59045\.cursor\projects\c-Projects-Roblox-Mining\assets"),
    ROOT / "assets" / "_raw_icons",
]
OUT = ROOT / "assets" / "ui"

PAIRS = {
    "icon_gift_raw.png": "icon_gift.png",
    "icon_streak_raw.png": "icon_streak.png",
    "icon_crown_raw.png": "icon_crown.png",
    "icon_gem_raw.png": "icon_gem.png",
    "icon_egg_raw.png": "icon_egg.png",
    "icon_warning_raw.png": "icon_warning.png",
    "icon_check_raw.png": "icon_check.png",
    "icon_close_raw.png": "icon_close.png",
    "icon_medal_raw.png": "icon_medal.png",
    "icon_sparkle_raw.png": "icon_sparkle.png",
    "icon_empty_raw.png": "icon_empty.png",
    "icon_boss_raw.png": "icon_boss.png",
    "icon_robux_raw.png": "icon_robux.png",
    "pack_starter_raw.png": "pack_starter.png",
    "pack_miner_raw.png": "pack_miner.png",
    "pack_mega_raw.png": "pack_mega.png",
}


def find_raw(name: str) -> Path | None:
    for folder in RAW_DIRS:
        path = folder / name
        if path.exists():
            return path
    return None


def prepare_one(src: Path, dst: Path) -> None:
    raw = src.read_bytes()
    cutout = Image.open(io.BytesIO(remove(raw))).convert("RGBA")
    cutout = strip_matte(cutout)
    cutout = defringe(cutout)
    final = crop_and_square(cutout)
    final.save(dst)
    meta = dst.with_suffix(".meta.json")
    meta.write_text('{"className":"Image"}\n', encoding="utf-8")
    print(f"wrote {dst.name} {final.size}")


def main() -> None:
    for raw_name, out_name in PAIRS.items():
        src = find_raw(raw_name)
        if not src:
            print(f"skip missing {raw_name}")
            continue
        prepare_one(src, OUT / out_name)


if __name__ == "__main__":
    main()
