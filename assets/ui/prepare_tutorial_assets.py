"""Procedural tutorial UI / world-guide textures for Roblox."""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).parent


def lerp(a: float, b: float, t: float) -> float:
	return a + (b - a) * t


def lerp_color(c1: tuple[int, int, int], c2: tuple[int, int, int], t: float) -> tuple[int, int, int]:
	return (
		int(lerp(c1[0], c2[0], t)),
		int(lerp(c1[1], c2[1], t)),
		int(lerp(c1[2], c2[2], t)),
	)


def draw_objective_bg() -> Image.Image:
	w, h = 512, 112
	img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
	px = img.load()

	for y in range(h):
		for x in range(w):
			t = y / (h - 1)
			base = lerp_color((8, 12, 26), (16, 22, 42), t)
			edge = min(x, w - 1 - x, y, h - 1 - y) / 28.0
			edge = max(0.0, min(1.0, edge))
			vignette = 0.88 + 0.12 * edge
			cx = (x - w / 2) / (w * 0.5)
			top_glow = max(0.0, 1.0 - abs(cx) * 0.85) * max(0.0, 1.0 - y / (h * 0.65)) * 0.28
			r = min(255, int((base[0] * vignette) + 48 * top_glow))
			g = min(255, int((base[1] * vignette) + 62 * top_glow))
			b = min(255, int((base[2] * vignette) + 98 * top_glow))
			px[x, y] = (r, g, b, 255)

	mask = Image.new("L", (w, h), 0)
	md = ImageDraw.Draw(mask)
	md.rounded_rectangle((0, 0, w - 1, h - 1), radius=20, fill=255)
	img.putalpha(mask)

	draw = ImageDraw.Draw(img)
	draw.rounded_rectangle((0, 0, w - 1, h - 1), radius=20, outline=(255, 208, 96, 210), width=2)
	draw.rounded_rectangle((3, 3, w - 4, h - 4), radius=17, outline=(72, 168, 255, 55), width=1)
	draw.line((20, 66, w - 20, 66), fill=(255, 220, 130, 35), width=1)

	shine = Image.new("RGBA", (w, h), (0, 0, 0, 0))
	sd = ImageDraw.Draw(shine)
	sd.rounded_rectangle((18, 6, w - 18, 30), radius=12, fill=(255, 255, 255, 18))
	img = Image.alpha_composite(img, shine)
	return img.filter(ImageFilter.GaussianBlur(0.25))


def draw_path_marker() -> Image.Image:
	size = 256
	img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
	draw = ImageDraw.Draw(img)
	cx, cy = size // 2, size // 2 + 8

	shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
	sd = ImageDraw.Draw(shadow)
	sd.ellipse((cx - 70, cy + 34, cx + 70, cy + 58), fill=(0, 0, 0, 90))
	img = Image.alpha_composite(img, shadow.filter(ImageFilter.GaussianBlur(4)))

	for r in range(86, 0, -2):
		t = r / 86
		alpha = int(28 * (1 - t) ** 2.2)
		col = lerp_color((255, 214, 110), (70, 175, 255), t * 0.6)
		draw.ellipse((cx - r, cy - r + 20, cx + r, cy + r + 20), fill=(*col, alpha))

	outer = [
		(cx, cy - 72),
		(cx - 52, cy + 6),
		(cx - 20, cy + 6),
		(cx - 20, cy + 56),
		(cx + 20, cy + 56),
		(cx + 20, cy + 6),
		(cx + 52, cy + 6),
	]
	draw.polygon(outer, fill=(255, 236, 158, 245))
	inner = [
		(cx, cy - 50),
		(cx - 32, cy + 2),
		(cx - 12, cy + 2),
		(cx - 12, cy + 40),
		(cx + 12, cy + 40),
		(cx + 12, cy + 2),
		(cx + 32, cy + 2),
	]
	draw.polygon(inner, fill=(118, 214, 255, 230))
	draw.ellipse((cx - 8, cy - 22, cx + 8, cy - 6), fill=(255, 255, 255, 110))

	return img.filter(ImageFilter.GaussianBlur(0.3))


def draw_goal_pin() -> Image.Image:
	size = 256
	img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
	draw = ImageDraw.Draw(img)
	cx = size // 2

	for r in range(96, 48, -2):
		t = (r - 48) / 48
		alpha = int(22 + 55 * (1 - abs(t - 0.55) * 1.8))
		draw.ellipse((cx - r, size - 70 - r // 2, cx + r, size - 70 + r // 2), fill=(255, 200, 80, alpha))

	outer = [(cx, 22), (cx + 38, 84), (cx, 158), (cx - 38, 84)]
	draw.polygon(outer, fill=(255, 228, 138, 250))
	inner = [(cx, 40), (cx + 22, 84), (cx, 128), (cx - 22, 84)]
	draw.polygon(inner, fill=(105, 205, 255, 235))
	draw.rounded_rectangle((cx - 5, 152, cx + 5, size - 58), radius=3, fill=(255, 230, 150, 220))

	beam = Image.new("RGBA", (size, size), (0, 0, 0, 0))
	bd = ImageDraw.Draw(beam)
	bd.polygon([(cx, 22), (cx + 10, 84), (cx, 158), (cx - 10, 84)], fill=(255, 255, 255, 45))
	img = Image.alpha_composite(img, beam)
	return img.filter(ImageFilter.GaussianBlur(0.2))


def draw_tutorial_arrow() -> Image.Image:
	size = 128
	img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
	draw = ImageDraw.Draw(img)
	cx, cy = size // 2, size // 2

	draw.ellipse((cx - 44, cy - 44, cx + 44, cy + 44), fill=(255, 210, 90, 55))
	pts = [(cx, cy - 34), (cx - 28, cy + 18), (cx - 10, cy + 18), (cx - 10, cy + 34), (cx + 10, cy + 34), (cx + 10, cy + 18), (cx + 28, cy + 18)]
	draw.polygon(pts, fill=(255, 236, 160, 250))
	draw.polygon([(cx, cy - 22), (cx - 16, cy + 14), (cx + 16, cy + 14)], fill=(120, 210, 255, 230))
	return img.filter(ImageFilter.GaussianBlur(0.15))


def main() -> None:
	assets = {
		"tutorial_objective_bg.png": draw_objective_bg(),
		"tutorial_path_marker.png": draw_path_marker(),
		"tutorial_goal_pin.png": draw_goal_pin(),
		"icon_tutorial_arrow.png": draw_tutorial_arrow(),
	}
	for name, image in assets.items():
		path = ROOT / name
		image.save(path)
		meta = ROOT / name.replace(".png", ".meta.json")
		meta.write_text('{"className":"Image"}\n', encoding="utf-8")
		print("wrote", path.name, image.size)


if __name__ == "__main__":
	main()
