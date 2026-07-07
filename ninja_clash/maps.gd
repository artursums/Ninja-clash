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

const VC_PARTS := "res://sprites/levels/verdant_cistern/components.png"
const VC_FLOOR := Rect2(0, 0, 800, 56)
const VC_CEILING := Rect2(0, 64, 800, 34)
const VC_SIDE_TOP := Rect2(0, 112, 86, 116)
const VC_SIDE_MID := Rect2(96, 112, 86, 112)
const VC_SIDE_LOW := Rect2(192, 112, 86, 54)
const VC_BRIDGE := Rect2(0, 240, 228, 32)
const VC_PAD_WIDE := Rect2(240, 240, 168, 30)
const VC_PAD_MED := Rect2(420, 240, 128, 28)

# Sky Temple component atlas (Higgsfield z_image, chroma-keyed to alpha). Pieces measured
# from the built atlas; "walkable" = the source-pixel row of the grassy deck top within each
# region (aligns to the collision top for WYSIWYG). Towers render in "fill" mode.
const ST_PARTS := "res://sprites/levels/sky_temple/components.png"
const ST_FLOOR := Rect2(0, 0, 800, 52)      # full floor strip; deck row 2
const ST_TOWER := Rect2(804, 0, 86, 450)    # full-height side tower (fill mode)
const ST_CAP   := Rect2(0, 100, 210, 46)    # corner ceiling-cap block; deck row 2
const ST_APEX  := Rect2(0, 60, 200, 34)     # wide central platform; deck row 9
const ST_LEDGE := Rect2(210, 60, 160, 34)   # side ledge; deck row 0
const ST_PAD   := Rect2(380, 60, 170, 34)   # spawn pad; deck row 0

const MAPS: Array = [
	{
		"name": "Verdant Cistern",
		"subtitle": "moss-lit wrap tunnels",
		"ambience": "verdant_cistern",
		"background": "res://sprites/levels/verdant_cistern/background.png",
		"bg_color": Color("10222a"),
		"sky_top": Color("0b1a1d"),
		"sky_bot": Color("183a3f"),
		"wall_color": Color("245348"),
		"wall_edge_color": Color("a3e589"),
		"platform_overhang": 1.0,
		# Mirror-symmetric 5-tier arena (matches the proven Neo Tokyo template) but keeps the
		# cistern identity: solid top/bottom caps + segmented side walls that leave two clean
		# wrap-tunnel openings per side. Earlier revision crammed 21 thick bodies in here — pieces
		# overlapped and two 17 px gaps were narrower than the 20 px player. This layout keeps every
		# platform spaced (each tier ≤71 px below the next, within the ~82 px jump apex) with no
		# overlaps and every opening ≥44 px (player is 32 px tall). WYSIWYG: collision heights equal
		# the source-art heights so the walkable deck is exactly where it's drawn.
		"walls": [
			# Top cap + bottom floor — the cistern is fully enclosed (no chasm).
			{"center": Vector2(400, 17), "size": Vector2(800, 34), "sprite": VC_PARTS, "sprite_region": VC_CEILING, "sprite_walkable": 0.0},
			{"center": Vector2(400, 422), "size": Vector2(800, 56), "sprite": VC_PARTS, "sprite_region": VC_FLOOR, "sprite_walkable": 0.0},

			# Segmented side walls: openings at y133–184 (51 px) and y296–340 (44 px) form the
			# left/right wrap tunnels. Collision extends full segment height; no lips clutter them.
			{"center": Vector2(43, 75), "size": Vector2(86, 116), "sprite": VC_PARTS, "sprite_region": VC_SIDE_TOP, "sprite_walkable": 0.0},
			{"center": Vector2(757, 75), "size": Vector2(86, 116), "sprite": VC_PARTS, "sprite_region": VC_SIDE_TOP, "sprite_walkable": 0.0},
			{"center": Vector2(43, 240), "size": Vector2(86, 112), "sprite": VC_PARTS, "sprite_region": VC_SIDE_MID, "sprite_walkable": 0.0},
			{"center": Vector2(757, 240), "size": Vector2(86, 112), "sprite": VC_PARTS, "sprite_region": VC_SIDE_MID, "sprite_walkable": 0.0},
			{"center": Vector2(43, 367), "size": Vector2(86, 54), "sprite": VC_PARTS, "sprite_region": VC_SIDE_LOW, "sprite_walkable": 0.0},
			{"center": Vector2(757, 367), "size": Vector2(86, 54), "sprite": VC_PARTS, "sprite_region": VC_SIDE_LOW, "sprite_walkable": 0.0},

			# Tier 1 — apex bridge (high-ground perch).
			{"center": Vector2(400, 100), "size": Vector2(228, 32), "sprite": VC_PARTS, "sprite_region": VC_BRIDGE, "sprite_walkable": 0.0},
			# Tier 2 — upper ears (mirrored).
			{"center": Vector2(200, 168), "size": Vector2(128, 28), "sprite": VC_PARTS, "sprite_region": VC_PAD_MED, "sprite_walkable": 0.0},
			{"center": Vector2(600, 168), "size": Vector2(128, 28), "sprite": VC_PARTS, "sprite_region": VC_PAD_MED, "sprite_walkable": 0.0},
			# Tier 3 — central catwalk (main battle line through the middle).
			{"center": Vector2(400, 236), "size": Vector2(168, 30), "sprite": VC_PARTS, "sprite_region": VC_PAD_WIDE, "sprite_walkable": 0.0},
			# Tier 4 — outer climb pads (mirrored; bridge mid → spawn tiers).
			{"center": Vector2(195, 300), "size": Vector2(128, 28), "sprite": VC_PARTS, "sprite_region": VC_PAD_MED, "sprite_walkable": 0.0},
			{"center": Vector2(605, 300), "size": Vector2(128, 28), "sprite": VC_PARTS, "sprite_region": VC_PAD_MED, "sprite_walkable": 0.0},
			# Tier 5 — spawn pads (mirrored; players start 8 px above these decks).
			{"center": Vector2(230, 372), "size": Vector2(168, 30), "sprite": VC_PARTS, "sprite_region": VC_PAD_WIDE, "sprite_walkable": 0.0},
			{"center": Vector2(570, 372), "size": Vector2(168, 30), "sprite": VC_PARTS, "sprite_region": VC_PAD_WIDE, "sprite_walkable": 0.0},
		],
		"spawn_points": [Vector2(230, 340), Vector2(570, 340)],
		"transparent_platforms": false,
	},
	{
		"name": "Sakura Temple",
		"subtitle": "moonlit shinobi sanctum",
		"ambience": "sakura",   # layered atmosphere controller (sakura_ambience.gd): lantern glow, moon bloom, drifting birds
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
		"ambience": "neon_tokyo",   # layered atmosphere (neon_tokyo_ambience.gd): rain, sun bloom, neon flicker, lightning, mist
		"music": "res://audio/gameplay/Rain Circuit Clash.mp3",   # per-map fight track (overrides Audio.MATCH_MUSIC_PATH)
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
		# WYSIWYG platforms: the neon art is opaque edge-to-edge, so the visual must equal the hitbox
		# (overhang 1.0) — at the old 1.4 the beam was drawn 40% wider than its collision and fighters
		# fell straight through the visible-but-non-solid edges.
		"platform_overhang": 1.0,
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
			# Widths trimmed ~12% from the originals (160/130/220/110/175/150) for a slightly smaller feel.
			# Tier 1 — top apex catwalk (high-ground sniping perch)
			{"center": Vector2(400, 72),  "size": Vector2(140, 12), "sprite": NEO_TOKYO_PARTS, "sprite_region": NT_BEAM, "sprite_walkable": 22.0},
			# Tier 2 — upper ears (mirrored)
			{"center": Vector2(205, 155), "size": Vector2(114, 12), "sprite": NEO_TOKYO_PARTS, "sprite_region": NT_PAD, "sprite_walkable": 1.0},
			{"center": Vector2(595, 155), "size": Vector2(114, 12), "sprite": NEO_TOKYO_PARTS, "sprite_region": NT_PAD, "sprite_walkable": 1.0},
			# Tier 3 — central long catwalk (the main battle line through the middle)
			{"center": Vector2(400, 235), "size": Vector2(194, 12), "sprite": NEO_TOKYO_PARTS, "sprite_region": NT_BEAM, "sprite_walkable": 22.0},
			# Tier 4 — outer climb pads (mirrored, bridge mid → spawn tiers)
			{"center": Vector2(200, 300), "size": Vector2(96, 12), "sprite": NEO_TOKYO_PARTS, "sprite_region": NT_PAD, "sprite_walkable": 1.0},
			{"center": Vector2(600, 300), "size": Vector2(96, 12), "sprite": NEO_TOKYO_PARTS, "sprite_region": NT_PAD, "sprite_walkable": 1.0},
			# Tier 5 — spawn-pad catwalks (mirrored, players start 8 px above these)
			{"center": Vector2(230, 372), "size": Vector2(154, 14), "sprite": NEO_TOKYO_PARTS, "sprite_region": NT_BEAM, "sprite_walkable": 22.0},
			{"center": Vector2(570, 372), "size": Vector2(154, 14), "sprite": NEO_TOKYO_PARTS, "sprite_region": NT_BEAM, "sprite_walkable": 22.0},
			# Bottom — central landing over the chasm
			{"center": Vector2(400, 420), "size": Vector2(132, 12), "sprite": NEO_TOKYO_PARTS, "sprite_region": NT_PAD, "sprite_walkable": 1.0},
		],
		# No decorative landmarks: only the collidable platforms above are drawn, so every
		# platform the player sees is one they can land on (no jump-on-the-background confusion).
		"spawn_points": [Vector2(230, 340), Vector2(570, 340)],
		"transparent_platforms": false,
		"bg_decorations": [],
		"fg_decorations": [],
	},
	{
		"name": "Sky Temple",
		"subtitle": "open sanctuary above the clouds",
		# TODO(art): dedicated ambience later. Falls back to no atmosphere controller for now.
		"ambience": "",
		# Higgsfield art wired in (see sky_temple/ART_SPEC.md). Frame + platforms draw from the
		# component atlas; the backdrop is the full-frame 800x450 image.
		"background": "res://sprites/levels/sky_temple/background.png",
		"bg_color": Color("1a2b3a"),
		"sky_top": Color("6fb7d8"),        # open TowerFall-temple blue sky
		"sky_bot": Color("bfe3ea"),
		"wall_color": Color("2f5a4a"),     # mossy green stone
		"wall_edge_color": Color("a3e589"),
		"platform_overhang": 1.0,          # WYSIWYG: visual width == hitbox once art is in
		# OPEN, full-frame TowerFall arena. Half the platform count of Verdant Cistern: the entire
		# central column stays open sky. Frame (floor + corner ceiling caps + full-height side
		# towers) uses color-fill until art arrives; the 5 floating platforms use the generic sprite.
		# Verified: every floating platform >=50 px off the wall x-ranges (0-86, 714-800); intended
		# jump gaps <=~82 px apex (floor->spawn 71 px; other routes use wall-jumps off the towers).
		"walls": [
			# --- Frame: full floor, open-center corner ceiling caps, solid side towers ---
			{"center": Vector2(400, 432), "size": Vector2(800, 36), "sprite": ST_PARTS, "sprite_region": ST_FLOOR, "sprite_walkable": 2.0},   # floor (walkable top ~414)
			{"center": Vector2(72, 20),   "size": Vector2(210, 40), "sprite": ST_PARTS, "sprite_region": ST_CAP, "sprite_walkable": 2.0},    # ceiling cap L (corner)
			{"center": Vector2(728, 20),  "size": Vector2(210, 40), "sprite": ST_PARTS, "sprite_region": ST_CAP, "sprite_walkable": 2.0},    # ceiling cap R (corner)
			{"center": Vector2(43, 225),  "size": Vector2(86, 450), "sprite": ST_PARTS, "sprite_region": ST_TOWER, "sprite_mode": "fill"},   # side tower L (full height)
			{"center": Vector2(757, 225), "size": Vector2(86, 450), "sprite": ST_PARTS, "sprite_region": ST_TOWER, "sprite_mode": "fill"},   # side tower R (full height)
			# --- Sparse floating platforms: center-top and mid stay open sky ---
			{"center": Vector2(175, 350), "size": Vector2(150, 14), "sprite": ST_PARTS, "sprite_region": ST_PAD, "sprite_walkable": 0.0},    # spawn pad L
			{"center": Vector2(625, 350), "size": Vector2(150, 14), "sprite": ST_PARTS, "sprite_region": ST_PAD, "sprite_walkable": 0.0},    # spawn pad R
			{"center": Vector2(215, 250), "size": Vector2(130, 14), "sprite": ST_PARTS, "sprite_region": ST_LEDGE, "sprite_walkable": 0.0},  # side ledge L
			{"center": Vector2(585, 250), "size": Vector2(130, 14), "sprite": ST_PARTS, "sprite_region": ST_LEDGE, "sprite_walkable": 0.0},  # side ledge R
			{"center": Vector2(400, 165), "size": Vector2(170, 14), "sprite": ST_PARTS, "sprite_region": ST_APEX, "sprite_walkable": 9.0},   # central apex
		],
		# Players start ~30 px above the spawn-pad decks (feet on the pad).
		"spawn_points": [Vector2(175, 320), Vector2(625, 320)],
		"transparent_platforms": false,
		"bg_decorations": [],
		"fg_decorations": [],
	},
]

func get_map(index: int) -> Dictionary:
	return MAPS[index % MAPS.size()]

func count() -> int:
	return MAPS.size()
