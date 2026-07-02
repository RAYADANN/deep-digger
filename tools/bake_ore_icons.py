"""Bake assets/ui/ores/*.png → src/shared/data/ore_pixels/*.lua (base64 RGBA)."""
from __future__ import annotations

import base64
import io
import re
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC_PNG = ROOT / "assets" / "ui" / "ores"
OUT = ROOT / "src" / "shared" / "data" / "OreIconPixels"
SIZE = 64


def parse_ore_ids() -> list[str]:
	db = ROOT / "src" / "shared" / "data" / "OreDatabase.lua"
	text = db.read_text(encoding="utf-8")
	ids: list[str] = []
	for m in re.finditer(r'id\s*=\s*"([^"]+)"', text):
		oid = m.group(1)
		if "test" not in oid:
			ids.append(oid)
	return sorted(set(ids))


def bake_one(ore_id: str) -> None:
	png = SRC_PNG / f"{ore_id}.png"
	if not png.exists():
		raise FileNotFoundError(png)
	img = Image.open(png).convert("RGBA").resize((SIZE, SIZE), Image.Resampling.LANCZOS)
	raw = img.tobytes()
	b64 = base64.standard_b64encode(raw).decode("ascii")
	OUT.mkdir(parents=True, exist_ok=True)
	path = OUT / f"{ore_id}.lua"
	path.write_text(
		f"--!strict\n-- {SIZE}x{SIZE} RGBA — tools/bake_ore_icons.py\n"
		f'return "{b64}"\n',
		encoding="utf-8",
	)


def main() -> None:
	ids = parse_ore_ids()
	for ore_id in ids:
		bake_one(ore_id)
		print(ore_id)
	print(f"Baked {len(ids)} icons to {OUT}")


if __name__ == "__main__":
	main()
