"""Prepare UI icons: remove matte, crop, square resize for Roblox HUD."""
from __future__ import annotations

import io
from pathlib import Path

from PIL import Image
from rembg import remove

ROOT = Path(__file__).parent
TARGET = 256
PADDING = 0.06


def alpha_bbox(image: Image.Image, threshold: int = 8) -> tuple[int, int, int, int] | None:
	pixels = image.load()
	width, height = image.size
	min_x, min_y = width, height
	max_x, max_y = 0, 0
	found = False
	for y in range(height):
		for x in range(width):
			if pixels[x, y][3] > threshold:
				found = True
				min_x = min(min_x, x)
				max_x = max(max_x, x)
				min_y = min(min_y, y)
				max_y = max(max_y, y)
	if not found:
		return None
	return min_x, min_y, max_x, max_y


def strip_matte(image: Image.Image) -> Image.Image:
	pixels = image.load()
	width, height = image.size
	for y in range(height):
		for x in range(width):
			r, g, b, a = pixels[x, y]
			if a == 0:
				continue
			if r < 10 and g < 10 and b < 10:
				pixels[x, y] = (r, g, b, 0)
	return image


def defringe(image: Image.Image) -> Image.Image:
	pixels = image.load()
	width, height = image.size
	for y in range(height):
		for x in range(width):
			r, g, b, a = pixels[x, y]
			if a == 0:
				continue
			if a < 24 or (r + g + b < 48 and a < 200):
				pixels[x, y] = (0, 0, 0, 0)
				continue
			alpha = a / 255
			if alpha < 0.98:
				r = min(255, int(r / alpha))
				g = min(255, int(g / alpha))
				b = min(255, int(b / alpha))
			pixels[x, y] = (r, g, b, 255)
	return image


def crop_and_square(image: Image.Image) -> Image.Image:
	bounds = alpha_bbox(image)
	if not bounds:
		return image
	min_x, min_y, max_x, max_y = bounds
	width = max_x - min_x + 1
	height = max_y - min_y + 1
	pad_x = int(width * PADDING)
	pad_y = int(height * PADDING)
	min_x = max(0, min_x - pad_x)
	min_y = max(0, min_y - pad_y)
	max_x = min(image.width - 1, max_x + pad_x)
	max_y = min(image.height - 1, max_y + pad_y)
	cropped = image.crop((min_x, min_y, max_x + 1, max_y + 1))

	side = max(cropped.width, cropped.height)
	square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
	offset_x = (side - cropped.width) // 2
	offset_y = (side - cropped.height) // 2
	square.paste(cropped, (offset_x, offset_y))
	return square.resize((TARGET, TARGET), Image.Resampling.LANCZOS)


def prepare(path: Path) -> None:
	raw = path.read_bytes()
	cutout = Image.open(io.BytesIO(remove(raw))).convert("RGBA")
	cutout = strip_matte(cutout)
	cutout = defringe(cutout)
	final = crop_and_square(cutout)
	final.save(path)
	bounds = alpha_bbox(final)
	print(f"{path.name}: {final.size}, alpha bbox {bounds}")


def main() -> None:
	for path in sorted(ROOT.glob("*.png")):
		if path.name.startswith("_"):
			continue
		prepare(path)


if __name__ == "__main__":
	main()
