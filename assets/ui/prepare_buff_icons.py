"""Procedural buff icons — bold cartoon style (256×256 RGBA, matches upg_*)."""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).parent
SIZE = 256
C = SIZE // 2


def canvas() -> tuple[Image.Image, ImageDraw.ImageDraw]:
	img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
	return img, ImageDraw.Draw(img)


def glow(img: Image.Image, rgb: tuple, r: int = 100, a: int = 70) -> Image.Image:
	layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
	d = ImageDraw.Draw(layer)
	d.ellipse((C - r, C - r, C + r, C + r), fill=(*rgb, a))
	return Image.alpha_composite(layer, img)


def disk(d: ImageDraw.ImageDraw, box: tuple, fill: tuple, outline: tuple | None = None, w: int = 0):
	d.ellipse(box, fill=fill, outline=outline, width=w)


def rrect(d: ImageDraw.ImageDraw, box: tuple, radius: int, fill: tuple, outline: tuple | None = None, w: int = 0):
	d.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=w)


def draw_damage() -> Image.Image:
	img, d = canvas()
	img = glow(img, (255, 80, 60), 108, 80)
	d = ImageDraw.Draw(img)
	# Рукоять
	rrect(d, (112, 142, 144, 218), 12, (96, 58, 34), (36, 20, 10), 6)
	rrect(d, (118, 148, 138, 212), 8, (140, 92, 52))
	# Лезвие
	d.polygon([(64, 126), (196, 72), (210, 102), (78, 156)], fill=(235, 240, 255), outline=(50, 58, 78), width=6)
	d.polygon([(64, 126), (40, 150), (78, 156)], fill=(175, 182, 205), outline=(50, 58, 78), width=5)
	# Искра
	d.polygon([(200, 64), (232, 46), (220, 82)], fill=(255, 230, 90), outline=(210, 140, 10), width=5)
	disk(d, (206, 58, 234, 86), (255, 252, 200), (255, 200, 40), 4)
	return img


def draw_luck() -> Image.Image:
	img, d = canvas()
	img = glow(img, (50, 220, 110), 108, 80)
	d = ImageDraw.Draw(img)
	leaves = [
		(78, 54, 134, 110),
		(122, 54, 178, 110),
		(54, 108, 110, 164),
		(146, 108, 202, 164),
	]
	for box in leaves:
		disk(d, box, (45, 205, 105), (12, 110, 50), 6)
	rrect(d, (118, 118, 138, 188), 8, (28, 130, 58), (12, 70, 30), 5)
	# Звезда
	pts = []
	for i in range(10):
		ang = math.radians(-90 + i * 36)
		rad = 34 if i % 2 == 0 else 14
		pts.append((C + math.cos(ang) * rad, 88 + math.sin(ang) * rad))
	d.polygon(pts, fill=(255, 240, 110), outline=(210, 150, 20), width=5)
	return img


def draw_coin() -> Image.Image:
	img, d = canvas()
	img = glow(img, (255, 195, 40), 108, 85)
	d = ImageDraw.Draw(img)
	stacks = [
		(70, 124, 146, 200, (255, 200, 45)),
		(100, 96, 176, 172, (255, 220, 75)),
		(82, 68, 158, 144, (255, 238, 120)),
	]
	for x0, y0, x1, y1, fill in stacks:
		disk(d, (x0, y0, x1, y1), fill, (150, 95, 5), 7)
		cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
		disk(d, (cx - 18, cy - 18, cx + 18, cy + 18), (255, 250, 180), (190, 120, 0), 4)
	# Блик
	disk(d, (116, 78, 150, 112), (255, 255, 240, 180))
	return img


def draw_multimine() -> Image.Image:
	img, d = canvas()
	img = glow(img, (90, 170, 255), 108, 80)
	d = ImageDraw.Draw(img)
	blocks = [
		(52, 112, 128, 188, (110, 185, 255)),
		(128, 88, 204, 164, (75, 150, 235)),
	]
	for x0, y0, x1, y1, fill in blocks:
		rrect(d, (x0, y0, x1, y1), 16, fill, (20, 50, 110), 6)
		rrect(d, (x0 + 12, y0 + 12, x1 - 12, y0 + 30), 8, (200, 230, 255, 140))
	# x2 бейдж
	rrect(d, (142, 142, 220, 210), 20, (255, 108, 72), (150, 35, 15), 6)
	d.rectangle((158, 158, 204, 194), fill=(255, 255, 255))
	# Рисуем «x2» пиксельно (без шрифта)
	for px, py in [(162, 164), (170, 164), (178, 172), (170, 180), (162, 180)]:
		d.rectangle((px, py, px + 6, py + 6), fill=(180, 40, 20))
	for px, py in [(188, 164), (196, 164), (204, 164), (188, 172), (196, 172), (204, 172), (188, 180), (204, 180)]:
		d.rectangle((px, py, px + 6, py + 6), fill=(180, 40, 20))
	return img


def main():
	for name, fn in {
		"buff_damage": draw_damage,
		"buff_luck": draw_luck,
		"buff_coin": draw_coin,
		"buff_multimine": draw_multimine,
	}.items():
		out = ROOT / f"{name}.png"
		fn().save(out)
		(ROOT / f"{name}.meta.json").write_text('{"className":"Image"}\n', encoding="utf-8")
		print("wrote", out.name)


if __name__ == "__main__":
	main()
