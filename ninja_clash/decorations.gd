# Procedural decoration renderer. Given a list of draw-commands (Dictionary),
# renders backgrounds, props, and atmospheric layers via _draw().
# main.gd instantiates one or more of these per map and passes the command list.

extends Node2D

var commands: Array = []

func set_commands(cmds: Array) -> void:
	commands = cmds
	queue_redraw()

func _draw() -> void:
	for cmd in commands:
		match cmd.get("type", ""):
			"mountain": _draw_mountain(cmd)
			"moon": _draw_moon(cmd)
			"sun_disc": _draw_sun_disc(cmd)
			"pagoda": _draw_pagoda(cmd)
			"fog_band": _draw_fog_band(cmd)
			"lantern": _draw_lantern(cmd)
			"torii": _draw_torii(cmd)
			"pine": _draw_pine(cmd)
			"petals": _draw_petals(cmd)
			"banner": _draw_banner(cmd)
			"sky_glow": _draw_sky_glow(cmd)
			"star_field": _draw_star_field(cmd)

# === Mountain silhouette range ===
func _draw_mountain(cmd: Dictionary) -> void:
	var origin_y: float = cmd.get("y", 250.0)
	var width: float = cmd.get("width", 800.0)
	var peak_count: int = cmd.get("peaks", 6)
	var min_h: float = cmd.get("min_h", 60.0)
	var max_h: float = cmd.get("max_h", 140.0)
	var color: Color = cmd.get("color", Color("1e2040"))
	var seed_v: int = cmd.get("seed", 42)

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v

	var points := PackedVector2Array()
	points.append(Vector2(-10, origin_y + 30))
	var step: float = width / peak_count
	for i in peak_count:
		var base_x: float = i * step + step * 0.5
		var h: float = rng.randf_range(min_h, max_h)
		points.append(Vector2(base_x - step * 0.45, origin_y - h * 0.35))
		points.append(Vector2(base_x - step * 0.15, origin_y - h))
		points.append(Vector2(base_x + step * 0.18, origin_y - h * 0.55))
		points.append(Vector2(base_x + step * 0.45, origin_y - h * 0.2))
	points.append(Vector2(width + 10, origin_y + 30))
	points.append(Vector2(width + 10, 460))
	points.append(Vector2(-10, 460))

	var pc := PackedColorArray()
	for _i in points.size():
		pc.append(color)
	draw_polygon(points, pc)

# === Moon with soft glow rings ===
func _draw_moon(cmd: Dictionary) -> void:
	var pos: Vector2 = cmd.get("position", Vector2(620, 90))
	var radius: float = cmd.get("radius", 30.0)
	var color: Color = cmd.get("color", Color("f0eee8"))

	# Glow rings (outer → inner, increasing alpha)
	for i in range(5, 0, -1):
		var g: Color = color
		g.a = 0.06 * (6 - i)
		draw_circle(pos, radius * (1.0 + 0.18 * i), g)

	# Moon disc
	draw_circle(pos, radius, color)

	# Crater shading (subtle)
	var crater: Color = Color(color).darkened(0.35)
	crater.a = 0.55
	draw_circle(pos + Vector2(-radius * 0.3, -radius * 0.15), radius * 0.16, crater)
	draw_circle(pos + Vector2(radius * 0.25, radius * 0.3), radius * 0.12, crater)
	draw_circle(pos + Vector2(0, -radius * 0.4), radius * 0.08, crater)

# === Sun disc (warm sky orb, no crater shading) ===
func _draw_sun_disc(cmd: Dictionary) -> void:
	var pos: Vector2 = cmd.get("position", Vector2(600, 200))
	var radius: float = cmd.get("radius", 50.0)
	var color: Color = cmd.get("color", Color("f0a040"))
	# Big diffuse outer glow
	for i in range(7, 0, -1):
		var g: Color = color
		g.a = 0.04 * (8 - i)
		draw_circle(pos, radius * (1.0 + 0.22 * i), g)
	# Solid disc
	draw_circle(pos, radius, color)
	# Hot core
	draw_circle(pos, radius * 0.55, Color(color).lightened(0.35))

# === Multi-tier pagoda silhouette ===
func _draw_pagoda(cmd: Dictionary) -> void:
	var pos: Vector2 = cmd.get("position", Vector2(120, 320))
	var height: float = cmd.get("height", 140.0)
	var color: Color = cmd.get("color", Color("161628"))
	var tiers: int = cmd.get("tiers", 4)
	var max_w: float = cmd.get("base_width", 80.0)

	var tier_h: float = height / tiers
	for i in tiers:
		var t_w: float = max_w * (1.0 - i * 0.16)
		var y_bot: float = pos.y - i * tier_h
		var y_roof_top: float = y_bot - tier_h * 0.45
		var roof_extra: float = 7.0
		# Roof (trapezoid with overhang)
		var roof_pts := PackedVector2Array([
			Vector2(pos.x - t_w * 0.5 - roof_extra, y_bot - tier_h * 0.35),
			Vector2(pos.x - t_w * 0.5, y_roof_top),
			Vector2(pos.x + t_w * 0.5, y_roof_top),
			Vector2(pos.x + t_w * 0.5 + roof_extra, y_bot - tier_h * 0.35),
		])
		var rc := PackedColorArray()
		for _j in roof_pts.size():
			rc.append(color)
		draw_polygon(roof_pts, rc)
		# Body
		var body_w: float = t_w * 0.75
		draw_rect(Rect2(
			pos.x - body_w * 0.5,
			y_bot - tier_h,
			body_w,
			tier_h * 0.55,
		), color)

	# Top spire
	var spire_top := Vector2(pos.x, pos.y - height - 16.0)
	draw_line(spire_top, Vector2(pos.x, pos.y - height), color, 2.0)
	draw_circle(spire_top, 3.0, color)

# === Horizontal fog band (semi-transparent stripes) ===
func _draw_fog_band(cmd: Dictionary) -> void:
	var y: float = cmd.get("y", 280.0)
	var h: float = cmd.get("h", 50.0)
	var color: Color = cmd.get("color", Color(1.0, 1.0, 1.0, 0.08))
	var bands: int = cmd.get("bands", 4)
	for i in bands:
		var alpha_col: Color = color
		var fade: float = 1.0 - abs(i - bands * 0.5) / float(bands)
		alpha_col.a *= max(0.2, fade)
		draw_rect(Rect2(0, y + i * (h / float(bands)), 800, h / float(bands) + 1.0), alpha_col)

# === Lantern with glow halo ===
func _draw_lantern(cmd: Dictionary) -> void:
	var pos: Vector2 = cmd.get("position", Vector2(0, 0))
	var color: Color = cmd.get("color", Color("e8a848"))
	var rope_top: float = cmd.get("rope_top", pos.y - 22.0)
	var dark: Color = Color("1a1a24")
	# Glow halo behind body
	var glow_pos: Vector2 = pos + Vector2(0, -6)
	for i in range(4, 0, -1):
		var g: Color = color
		g.a = 0.09 * (5 - i)
		draw_circle(glow_pos, 6.0 + i * 4.5, g)
	# Rope
	draw_line(Vector2(pos.x, rope_top), Vector2(pos.x, pos.y - 14), dark, 1.2)
	# Cap
	draw_rect(Rect2(pos.x - 6.5, pos.y - 14, 13, 2.5), dark)
	# Body
	draw_rect(Rect2(pos.x - 5, pos.y - 11.5, 10, 12), color)
	# Horizontal band on body
	draw_rect(Rect2(pos.x - 5, pos.y - 5.5, 10, 1.2), dark)
	# Base
	draw_rect(Rect2(pos.x - 6.5, pos.y + 0.5, 13, 2.5), dark)

# === Torii gate (Japanese red gate) ===
func _draw_torii(cmd: Dictionary) -> void:
	var pos: Vector2 = cmd.get("position", Vector2(400, 280))
	var color: Color = cmd.get("color", Color("c03030"))
	var w: float = cmd.get("width", 100.0)
	var h: float = cmd.get("height", 130.0)

	# Pillars (slight outward lean at base)
	var left_pillar := PackedVector2Array([
		Vector2(pos.x - w * 0.5 - 1, pos.y),
		Vector2(pos.x - w * 0.5 + 4, pos.y - h),
		Vector2(pos.x - w * 0.5 + 11, pos.y - h),
		Vector2(pos.x - w * 0.5 + 6, pos.y),
	])
	var right_pillar := PackedVector2Array([
		Vector2(pos.x + w * 0.5 - 6, pos.y),
		Vector2(pos.x + w * 0.5 - 11, pos.y - h),
		Vector2(pos.x + w * 0.5 - 4, pos.y - h),
		Vector2(pos.x + w * 0.5 + 1, pos.y),
	])
	var pc := PackedColorArray()
	for _i in 4: pc.append(color)
	draw_polygon(left_pillar, pc)
	draw_polygon(right_pillar, pc)

	# Kasagi (top lintel, with upward-swooping ends)
	var lintel_pts := PackedVector2Array([
		Vector2(pos.x - w * 0.62, pos.y - h + 12),
		Vector2(pos.x - w * 0.55, pos.y - h - 4),
		Vector2(pos.x + w * 0.55, pos.y - h - 4),
		Vector2(pos.x + w * 0.62, pos.y - h + 12),
		Vector2(pos.x + w * 0.55, pos.y - h + 16),
		Vector2(pos.x - w * 0.55, pos.y - h + 16),
	])
	var lc := PackedColorArray()
	for _i in lintel_pts.size():
		lc.append(color)
	draw_polygon(lintel_pts, lc)

	# Nuki (second crossbar)
	draw_rect(Rect2(pos.x - w * 0.45, pos.y - h + 24, w * 0.9, 6), color)

	# Center plaque (small dark square)
	draw_rect(Rect2(pos.x - 8, pos.y - h + 6, 16, 8), Color(color).darkened(0.4))

# === Pine tree silhouette ===
func _draw_pine(cmd: Dictionary) -> void:
	var pos: Vector2 = cmd.get("position", Vector2(0, 0))
	var height: float = cmd.get("height", 50.0)
	var color: Color = cmd.get("color", Color("0d0d1a"))
	# Trunk
	draw_rect(Rect2(pos.x - 1.5, pos.y - 5.0, 3.0, 5.0), color)
	# Three stacked triangle tiers
	for i in 3:
		var w: float = 22.0 - i * 5.0
		var y_base: float = pos.y - 5.0 - i * (height * 0.28)
		var y_top: float = pos.y - 5.0 - (i + 1) * (height * 0.36)
		var pts := PackedVector2Array([
			Vector2(pos.x - w * 0.5, y_base),
			Vector2(pos.x + w * 0.5, y_base),
			Vector2(pos.x, y_top),
		])
		var pc := PackedColorArray()
		for _j in pts.size():
			pc.append(color)
		draw_polygon(pts, pc)

# === Scattered cherry petals (static decorative dots) ===
func _draw_petals(cmd: Dictionary) -> void:
	var color: Color = cmd.get("color", Color("f0a0c8"))
	var count: int = cmd.get("count", 30)
	var seed_v: int = cmd.get("seed", 17)
	var area_h: float = cmd.get("area_h", 360.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	for _i in count:
		var x: float = rng.randf_range(10, 790)
		var y: float = rng.randf_range(10, area_h)
		var r: float = rng.randf_range(1.4, 2.6)
		var c: Color = color
		c.a = rng.randf_range(0.45, 0.85)
		draw_circle(Vector2(x, y), r, c)

# === Banner (vertical fabric strip hanging from a point) ===
func _draw_banner(cmd: Dictionary) -> void:
	var pos: Vector2 = cmd.get("position", Vector2(0, 0))  # top of banner
	var color: Color = cmd.get("color", Color("c03030"))
	var w: float = cmd.get("width", 10.0)
	var h: float = cmd.get("height", 60.0)
	var pole: Color = Color("1a1a24")
	# Horizontal pole/dowel at top
	draw_rect(Rect2(pos.x - w * 0.65, pos.y - 2.0, w * 1.3, 2.0), pole)
	# Fabric body
	draw_rect(Rect2(pos.x - w * 0.5, pos.y, w, h), color)
	# Triangular bottom cutout (banner v-cut)
	var notch_pts := PackedVector2Array([
		Vector2(pos.x - w * 0.5, pos.y + h),
		Vector2(pos.x + w * 0.5, pos.y + h),
		Vector2(pos.x, pos.y + h - 5),
	])
	var nc := PackedColorArray()
	for _i in 3: nc.append(Color("0d0d1a"))
	draw_polygon(notch_pts, nc)
	# Single horizontal stripe (accent)
	var stripe: Color = Color(color).lightened(0.4)
	draw_rect(Rect2(pos.x - w * 0.5, pos.y + h * 0.4, w, 2.5), stripe)

# === Sky glow (radial-ish bright spot on horizon) ===
func _draw_sky_glow(cmd: Dictionary) -> void:
	var pos: Vector2 = cmd.get("position", Vector2(400, 250))
	var radius: float = cmd.get("radius", 120.0)
	var color: Color = cmd.get("color", Color("f0a040"))
	for i in range(8, 0, -1):
		var g: Color = color
		g.a = 0.05 * (9 - i)
		draw_circle(pos, radius * (1.0 + 0.18 * i), g)

# === Star field (tiny dots in upper portion) ===
func _draw_star_field(cmd: Dictionary) -> void:
	var count: int = cmd.get("count", 50)
	var seed_v: int = cmd.get("seed", 7)
	var area_h: float = cmd.get("area_h", 200.0)
	var color: Color = cmd.get("color", Color("f0eee8"))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	for _i in count:
		var x: float = rng.randf_range(0, 800)
		var y: float = rng.randf_range(0, area_h)
		var r: float = rng.randf_range(0.5, 1.4)
		var c: Color = color
		c.a = rng.randf_range(0.4, 1.0)
		draw_circle(Vector2(x, y), r, c)
