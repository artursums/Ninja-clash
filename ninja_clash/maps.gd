# PROTOTYPE - NOT FOR PRODUCTION
# Question: Does the throw-dodge-retrieve loop with 1-hit-kill feel fun in 2P local?
# Date: 2026-05-18
#
# TowerFall-style floating platforms over sprites/level-1.png + visible side
# walls cut from sprites/wall.png. Wall collision extends past the viewport
# so a wall-slide stays continuous across the screen-wrap.
# Platforms placed with 50+ px clearance from wall x-ranges (0-86 and 714-800).

extends Node

const P := "res://sprites/platform.png"
const W := "res://sprites/wall.png"

# Tight regions for each individual wall in the source sprite (measured)
const WALL_REGION_LEFT  := Rect2(172, 60, 260, 1358)
const WALL_REGION_RIGHT := Rect2(593, 61, 261, 1360)

const MAPS: Array = [
	{
		"name": "Sakura Temple",
		"subtitle": "moonlit shinobi sanctum",
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
				"sprite": W,
				"sprite_region": WALL_REGION_LEFT,
				"sprite_mode": "fill",
			},
			{
				"center": Vector2(757, 225),
				"size": Vector2(86, 550),
				"sprite": W,
				"sprite_region": WALL_REGION_RIGHT,
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
]

func get_map(index: int) -> Dictionary:
	return MAPS[index % MAPS.size()]

func count() -> int:
	return MAPS.size()
