"""Process AI-generated buff icons into HUD-ready PNGs (assets/ui/buff_*.png)."""
from __future__ import annotations

import io
import shutil
from pathlib import Path

from PIL import Image
from rembg import remove

import sys
sys.path.insert(0, str(Path(__file__).parent.parent / "assets" / "ui"))
from prepare_icons import strip_matte, defringe, crop_and_square  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
RAW = Path(r"C:\Users\59045\.cursor\projects\c-Projects-Roblox-Mining\assets")
OUT = ROOT / "assets" / "ui"

PAIRS = {
	"buff_damage_raw.png": "buff_damage.png",
	"buff_luck_raw.png": "buff_luck.png",
	"buff_coin_raw.png": "buff_coin.png",
	"buff_multimine_raw.png": "buff_multimine.png",
}


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
		src = RAW / raw_name
		if not src.exists():
			raise FileNotFoundError(src)
		prepare_one(src, OUT / out_name)


if __name__ == "__main__":
	main()
