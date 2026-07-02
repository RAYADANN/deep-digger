"""Process raw Studio captures into HUD-ready ore icons."""
from __future__ import annotations

import io
import json
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).parent
RAW = ROOT / "_raw"
TARGET = 256
PADDING = 0.08

sys.path.insert(0, str(ROOT.parent))
from prepare_icons import alpha_bbox, crop_and_square, defringe, strip_matte  # noqa: E402

try:
	from rembg import remove
except ImportError:
	remove = None


def prepare(path: Path, out: Path) -> None:
	raw_bytes = path.read_bytes()
	if remove is not None:
		cutout = Image.open(io.BytesIO(remove(raw_bytes))).convert("RGBA")
	else:
		cutout = Image.open(io.BytesIO(raw_bytes)).convert("RGBA")
	cutout = strip_matte(cutout)
	cutout = defringe(cutout)
	final = crop_and_square(cutout)
	final.save(out)
	print(f"{out.name}: {final.size}")


def write_meta(ore_id: str) -> None:
	meta = ROOT / f"{ore_id}.meta.json"
	if not meta.exists():
		meta.write_text('{"className":"Image"}\n', encoding="utf-8")


def main() -> None:
	RAW.mkdir(parents=True, exist_ok=True)
	if not any(RAW.glob("*.png")):
		print("No files in _raw/. Add Studio captures first.")
		return
	for path in sorted(RAW.glob("*.png")):
		if path.name.startswith("_"):
			continue
		ore_id = path.stem
		out = ROOT / f"{ore_id}.png"
		prepare(path, out)
		write_meta(ore_id)
	print("Done.")


if __name__ == "__main__":
	main()
