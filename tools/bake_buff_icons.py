"""Bake assets/ui/buff_*.png → src/shared/data/BuffIconPixels/*.lua (base64 RGBA)."""
from __future__ import annotations

import base64
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "assets" / "ui"
OUT = ROOT / "src" / "shared" / "data" / "BuffIconPixels"
SIZE = 64

NAMES = ("buff_damage", "buff_luck", "buff_coin", "buff_multimine")


def bake_one(name: str) -> None:
	png = SRC / f"{name}.png"
	if not png.exists():
		raise FileNotFoundError(png)
	img = Image.open(png).convert("RGBA").resize((SIZE, SIZE), Image.Resampling.LANCZOS)
	raw = img.tobytes()
	b64 = base64.standard_b64encode(raw).decode("ascii")
	OUT.mkdir(parents=True, exist_ok=True)
	path = OUT / f"{name}.lua"
	path.write_text(
		f"--!strict\n-- {SIZE}x{SIZE} RGBA — tools/bake_buff_icons.py\n"
		f'return "{b64}"\n',
		encoding="utf-8",
	)


def main() -> None:
	for name in NAMES:
		bake_one(name)
		print(name)
	print(f"Baked {len(NAMES)} buff icons to {OUT}")


if __name__ == "__main__":
	main()
