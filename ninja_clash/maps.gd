# PROTOTYPE - NOT FOR PRODUCTION
# Question: Does the throw-dodge-retrieve loop with 1-hit-kill feel fun in 2P local?
# Date: 2026-05-18
#
# TowerFall-style floating platforms + visible side walls. Wall collision extends past the
# viewport so a wall-slide stays continuous across the screen-wrap. Platforms placed with
# 50+ px clearance from wall x-ranges (0-86 and 714-800).
#
# Per-level art convention — each level keeps its own files flat in its folder (no sub-folders):
#   res://sprites/levels/<slug>/background.png   (full-screen backdrop; "background" field)
#   res://sprites/levels/<slug>/walls.png        (side-wall sheet; per-wall "sprite" field)
# Missing background → gradient sky (sky_top → sky_bot) fallback. Platforms share the generic
# sprites/platform.png for now.

extends Node

const P := "res://sprites/platform.png"

# Sakura Temple wall sheet + the tight left/right regions measured inside it.
const SAKURA_WALLS := "res://sprites/levels/sakura_temple/walls.png"
const SAKURA_WALL_REGION_LEFT  := Rect2(172, 60, 260, 1358)
const SAKURA_WALL_REGION_RIGHT := Rect2(593, 61, 261, 1360)

# Neo Tokyo wall sheet + left/right regions (measured from the sheet's opaque columns).
const NEO_TOKYO_WALLS := "res://sprites/levels/neo_tokyo/walls.png"
const NEO_TOKYO_WALL_REGION_LEFT  := Rect2(22, 0, 329, 1392)
const NEO_TOKYO_WALL_REGION_RIGHT := Rect2(672, 0, 329, 1392)

# Neo Tokyo component sheet — neon platforms (gameplay) + vertical landmarks (decoration).
# Regions measured by connected-component scan; deck rows measured per platform.
const NEO_TOKYO_PARTS := "res://sprites/levels/neo_tokyo/level-components.png"
const NT_BEAM   := Rect2(49, 420, 683, 142)   # long neon catwalk; walkable deck at row 22
const NT_PAD    := Rect2(472, 279, 283, 100)  # medium neon pad; walkable deck at row 1
const NT_LADDER := Rect2(786, 47, 228, 575)   # vertical ladder tower — decoration only
const NT_GATE_L := Rect2(35, 672, 418, 696)   # torii gate pillar — decoration only
const NT_GATE_R := Rect2(579, 672, 428, 699)  # torii gate pillar — decoration only

const MAPS: Array = [
	{
		"name": "Sakura Temple",
		"subtitle": "moonlit shinobi sanctum",
		"background": "res://sprites/levels/sakura_temple/background.png",
		"bg_color": Color("0a081a"),
		"sky_top": Color("0a081a"),
		"sky_bot": Color("3a3458"),
		"wall_color": Color("3a3344"),
		"wall_edge_color": Color("6a5e7a"),
		"walls": [
			# === Side walls: visible sprite, full screen height, collision past viewport ===
			{
				"center": Vector2(43, 225),
				"size": Vector2(86, 550),
				"sprite": SAKURA_WALLS,
				"sprite_region": SAKURA_WALL_REGION_LEFT,
				"sprite_mode": "fill",
			},
			{
				"center": Vector2(757, 225),
				"size": Vector2(86, 550),
				"sprite": SAKURA_WALLS,
				"sprite_region": SAKURA_WALL_REGION_RIGHT,
				"sprite_mode": "fill",
			},

			# === Floating platforms — ALL ≥50 px from wall x-ranges (0-86, 714-800) ===
			# Top center — apex perch
			{"center": Vector2(400, 90),  "size": Vector2(140, 12), "sprite": P},
			# Upper-left & upper-right (mid-tier, mirrored, 54 px wall clearance)
			{"center": Vector2(220, 180), "size": Vector2(160, 12), "sprite": P},
			{"center": Vector2(580, 180), "size": Vector2(160, 12), "sprite": P},
			# Mid-center single (forces dodge fights through middle)
			{"center": Vector2(400, 250), "size": Vector2(130, 12), "sprite": P},
			# Mid-left & mid-right outer climbing route (59 px wall clearance)
			{"center": Vector2(200, 290), "size": Vector2(110, 12), "sprite": P},
			{"center": Vector2(600, 290), "size": Vector2(110, 12), "sprite": P},
			# Lower-left & lower-right spawn pads (54 px wall clearance)
			{"center": Vector2(230, 370), "size": Vector2(180, 14), "sprite": P},
			{"center": Vector2(570, 370), "size": Vector2(180, 14), "sprite": P},
			# Bottom center — landing area above chasm
			{"center": Vector2(400, 420), "size": Vector2(150, 12), "sprite": P},
		],
		# Spawns 8 px above lower-left / lower-right platform tops
		"spawn_points": [Vector2(230, 340), Vector2(570, 340)],
		"transparent_platforms": false,
		"bg_decorations": [],
		"fg_decorations": [],
	},
	{
		"name": "Neo Tokyo",
		"subtitle": "neon shinobi sprawl",
		"background": "res://sprites/levels/neo_tokyo/background.png",
		"bg_color": Color("0b0a1f"),
		"sky_top": Color("0b0a1f"),
		"sky_bot": Color("2a1840"),       # neon-night fallback until the background art is dropped in
		"wall_color": Color("241d3a"),
		"wall_edge_color": Color("ff3da6"),
		# Mirror-symmetric 5-tier vertical arena (TowerFall-style): a top apex, two upper
		# ears, a long central catwalk, two outer climb pads, the spawn pads, and a bottom
		# landing over the chasm. Long neon catwalks (BEAM) anchor the main fight lines;
		# medium PADs make the climbing/dodge routes. All platforms ≥50 px off the walls.
		"walls": [
			# === Side walls: neon towers, full screen height, collision past viewport ===
			{
				"center": Vector2(43, 225),
				"size": Vector2(86, 550),
				"sprite": NEO_TOKYO_WALLS,
				"sprite_region": NEO_TOKYO_WALL_REGION_LEFT,
				"sprite_mode": "fill",
			},
			{
				"center": Vector2(757, 225),
				"size": Vector2(86, 550),
				"sprite": NEO_TOKYO_WALLS,
				"sprite_region": NEO_TOKYO_WALL_REGION_RIGHT,
				"sprite_mode": "fill",
			},

			# === Floating neon platforms (all ≥50 px from wall x-ranges 0-86, 714-800) ===
			# Tier 1 — top apex catwalk (high-ground sniping perch)
			{"center": Vector2(400, 72),  "size": Vector2(160, 12), "sprite": NEO_TOKYO_PARTS, "sprite_region": NT_BEAM, "sprite_walkable": 22.0},
			# Tier 2 — upper ears (mirrored)
			{"center": Vector2(205, 155), "size": Vector2(130, 12), "sprite": NEO_TOKYO_PARTS, "sprite_region": NT_PAD, "sprite_walkable": 1.0},
			{"center": Vector2(595, 155), "size": Vector2(130, 12), "sprite": NEO_TOKYO_PARTS, "sprite_region": NT_PAD, "sprite_walkable": 1.0},
			# Tier 3 — central long catwalk (the main battle line through the middle)
			{"center": Vector2(400, 235), "size": Vector2(220, 12), "sprite": NEO_TOKYO_PARTS, "sprite_region": NT_BEAM, "sprite_walkable": 22.0},
			# Tier 4 — outer climb pads (mirrored, bridge mid → spawn tiers)
			{"center": Vector2(200, 300), "size": Vector2(110, 12), "sprite": NEO_TOKYO_PARTS, "sprite_region": NT_PAD, "sprite_walkable": 1.0},
			{"center": Vector2(600, 300), "size": Vector2(110, 12), "sprite": NEO_TOKYO_PARTS, "sprite_region": NT_PAD, "sprite_walkable": 1.0},
			# Tier 5 — spawn-pad catwalks (mirrored, players start 8 px above these)
			{"center": Vector2(230, 372), "size": Vector2(175, 14), "sprite": NEO_TOKYO_PARTS, "sprite_region": NT_BEAM, "sprite_walkable": 22.0},
			{"center": Vector2(570, 372), "size": Vector2(175, 14), "sprite": NEO_TOKYO_PARTS, "sprite_region": NT_BEAM, "sprite_walkable": 22.0},
			# Bottom — central landing over the chasm
			{"center": Vector2(400, 420), "size": Vector2(150, 12), "sprite": NEO_TOKYO_PARTS, "sprite_region": NT_PAD, "sprite_walkable": 1.0},
		],
		# Vertical neon landmarks behind the platforms (z = -5/-6): a ladder tower spine
		# dead-center, flanked by two torii gate pillars. Pure scenery — no collision.
		"deco_sprites": [
			{"sprite": NEO_TOKYO_PARTS, "sprite_region": NT_LADDER, "center": Vector2(400, 270), "height": 380.0, "z": -5},
			{"sprite": NEO_TOKYO_PARTS, "sprite_region": NT_GATE_L, "center": Vector2(122, 300), "height": 300.0, "z": -6},
			{"sprite": NEO_TOKYO_PARTS, "sprite_region": NT_GATE_R, "center": Vector2(678, 300), "height": 300.0, "z": -6},
		],
		"spawn_points": [Vector2(230, 340), Vector2(570, 340)],
		"transparent_platforms": false,
		"bg_decorations": [],
		"fg_decorations": [],
	},
]

func get_map(index: int) -> Dictionary:
	return MAPS[index % MAPS.size()]

func count() -> int:
	return MAPS.size()
