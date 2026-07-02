"""Procedural ore icons — 3/4 изометрия (поворот ~45°), цвета из OreDatabase."""
from __future__ import annotations

import math
import re
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).parent
DB = Path(__file__).resolve().parents[3] / "src" / "shared" / "data" / "OreDatabase.lua"
TARGET = 256
FILLER_WEIGHT = 300

# «Пол-оборота» от фронтального вида → угол угла куба к камере (классическая 3D-иконка).
YAW = math.pi / 4
PITCH = math.radians(32)


def parse_ores() -> list[dict]:
	text = DB.read_text(encoding="utf-8")
	ores: list[dict] = []
	pattern = re.compile(
		r'\{\s*id\s*=\s*"([^"]+)"[^}]*?'
		r'weight\s*=\s*(\d+)[^}]*?'
		r'color\s*=\s*Color3\.fromRGB\((\d+),\s*(\d+),\s*(\d+)\)'
		r'(?:[^}]*?protrusion\s*=\s*"([^"]+)")?',
		re.DOTALL,
	)
	for m in pattern.finditer(text):
		ore_id = m.group(1)
		if "test" in ore_id:
			continue
		ores.append({
			"id": ore_id,
			"weight": int(m.group(2)),
			"rgb": (int(m.group(3)), int(m.group(4)), int(m.group(5))),
			"crystal": m.group(6) == "crystal",
		})
	return ores


def darken(rgb: tuple[int, int, int], amt: float) -> tuple[int, int, int]:
	return tuple(max(0, min(255, int(c * (1 - amt)))) for c in rgb)


def brighten(rgb: tuple[int, int, int], amt: float) -> tuple[int, int, int]:
	return tuple(max(0, min(255, int(c + (255 - c) * amt))) for c in rgb)


def rotate_project(x: float, y: float, z: float, cx: float, cy: float, scale: float) -> tuple[float, float, float]:
	cos_y, sin_y = math.cos(YAW), math.sin(YAW)
	x1 = x * cos_y + z * sin_y
	z1 = -x * sin_y + z * cos_y
	cos_x, sin_x = math.cos(PITCH), math.sin(PITCH)
	y1 = y * cos_x - z1 * sin_x
	z2 = y * sin_x + z1 * cos_x
	return (cx + x1 * scale, cy - y1 * scale, z2)


def project_poly(
	verts_3d: list[tuple[float, float, float]],
	cx: float,
	cy: float,
	scale: float,
) -> list[tuple[float, float]]:
	out: list[tuple[float, float]] = []
	for x, y, z in verts_3d:
		px, py, _ = rotate_project(x, y, z, cx, cy, scale)
		out.append((px, py))
	return out


def face_depth(verts_3d: list[tuple[float, float, float]]) -> float:
	return sum(rotate_project(x, y, z, 0, 0, 1)[2] for x, y, z in verts_3d) / len(verts_3d)


def cube_faces(half: float = 1.0) -> list[tuple[str, list[tuple[float, float, float]]]]:
	h = half
	return [
		("top", [(-h, h, -h), (h, h, -h), (h, h, h), (-h, h, h)]),
		("bottom", [(-h, -h, h), (h, -h, h), (h, -h, -h), (-h, -h, -h)]),
		("right", [(h, -h, -h), (h, -h, h), (h, h, h), (h, h, -h)]),
		("left", [(-h, -h, h), (-h, -h, -h), (-h, h, -h), (-h, h, h)]),
		("front", [(-h, -h, h), (h, -h, h), (h, h, h), (-h, h, h)]),
		("back", [(h, -h, -h), (-h, -h, -h), (-h, h, -h), (h, h, -h)]),
	]


def face_colors(rgb: tuple[int, int, int], *, filler: bool) -> dict[str, tuple[int, int, int]]:
	if filler:
		return {
			"top": brighten(rgb, 0.22),
			"left": darken(rgb, 0.06),
			"right": darken(rgb, 0.14),
			"front": brighten(rgb, 0.06),
			"back": darken(rgb, 0.22),
			"bottom": darken(rgb, 0.28),
		}
	base = darken(rgb, 0.36)
	return {
		"top": brighten(base, 0.18),
		"left": darken(base, 0.04),
		"right": darken(base, 0.12),
		"front": brighten(base, 0.04),
		"back": darken(base, 0.2),
		"bottom": darken(base, 0.26),
	}


def draw_cube(
	draw: ImageDraw.ImageDraw,
	cx: float,
	cy: float,
	size: float,
	rgb: tuple[int, int, int],
	*,
	filler: bool,
) -> None:
	colors = face_colors(rgb, filler=filler)
	faces = cube_faces(1.0)
	# painter's algorithm: дальние грани первыми
	sorted_faces = sorted(faces, key=lambda f: face_depth(f[1]))
	for name, verts in sorted_faces:
		if name == "bottom":
			continue
		pts = project_poly(verts, cx, cy, size * 0.36)
		draw.polygon(pts, fill=colors[name])
		outline = darken(colors[name], 0.28)
		draw.line(pts + [pts[0]], fill=outline, width=2)


def draw_shard_3d(
	draw: ImageDraw.ImageDraw,
	ox: float,
	oy: float,
	oz: float,
	height: float,
	width: float,
	color: tuple[int, int, int],
	cx: float,
	cy: float,
	scale: float,
) -> None:
	# пирамида на верхней грани
	base = [
		(ox - width, oy, oz - width * 0.6),
		(ox + width, oy, oz - width * 0.6),
		(ox + width * 0.3, oy, oz + width * 0.7),
		(ox - width * 0.3, oy, oz + width * 0.7),
	]
	apex = (ox, oy + height, oz)
	base2d = project_poly(base, cx, cy, scale)
	apex2d = rotate_project(apex[0], apex[1], apex[2], cx, cy, scale)
	for i in range(len(base2d)):
		j = (i + 1) % len(base2d)
		draw.polygon([base2d[i], base2d[j], (apex2d[0], apex2d[1])], fill=color)
	draw.polygon(base2d, fill=darken(color, 0.12))


def draw_crystal_cluster(
	draw: ImageDraw.ImageDraw,
	cx: float,
	cy: float,
	scale: float,
	rgb: tuple[int, int, int],
) -> None:
	shard = brighten(rgb, 0.45)
	layout = [
		(0, 0, 0, 0.42, 0.11),
		(-0.38, 0, -0.22, 0.32, 0.09),
		(0.38, 0, -0.22, 0.32, 0.09),
		(-0.22, 0, 0.32, 0.28, 0.08),
		(0.22, 0, 0.32, 0.28, 0.08),
		(0, 0, -0.34, 0.36, 0.1),
	]
	for ox, oy, oz, h, w in layout:
		draw_shard_3d(draw, ox, oy, oz, h, w, shard, cx, cy, scale)


def draw_face_shells(
	draw: ImageDraw.ImageDraw,
	cx: float,
	cy: float,
	scale: float,
	shell: tuple[int, int, int],
) -> None:
	spots = [
		(0.55, 0.2, 0.45, 0.22, 0.07),
		(-0.5, 0.15, 0.35, 0.18, 0.06),
		(0.15, 0.25, -0.55, 0.2, 0.065),
		(-0.2, 0.1, -0.45, 0.17, 0.06),
	]
	for ox, oy, oz, h, w in spots:
		draw_shard_3d(draw, ox, oy, oz, h, w, shell, cx, cy, scale)


def render_ore(ore: dict) -> Image.Image:
	img = Image.new("RGBA", (TARGET, TARGET), (0, 0, 0, 0))
	draw = ImageDraw.Draw(img)
	rgb = ore["rgb"]
	filler = ore["weight"] >= FILLER_WEIGHT
	scale = TARGET * 0.64
	cx, cy = TARGET * 0.5, TARGET * 0.56

	draw_cube(draw, cx, cy, scale, rgb, filler=filler)

	if not filler:
		shell = brighten(rgb, 0.3)
		if ore["crystal"]:
			draw_crystal_cluster(draw, cx, cy, scale, rgb)
			draw_face_shells(draw, cx, cy, scale * 0.92, shell)
		else:
			draw_face_shells(draw, cx, cy, scale, shell)

	return img


def main() -> None:
	ores = parse_ores()
	for ore in ores:
		out = ROOT / f"{ore['id']}.png"
		render_ore(ore).save(out)
		meta = ROOT / f"{ore['id']}.meta.json"
		meta.write_text('{"className":"Image"}\n', encoding="utf-8")
		print(ore["id"])
	print(f"Rendered {len(ores)} icons (yaw={math.degrees(YAW):.0f}°).")


if __name__ == "__main__":
	main()
