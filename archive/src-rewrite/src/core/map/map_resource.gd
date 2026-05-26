class_name MapResource
extends Resource
## Structured metadata for one arena, paired with a MapScene (.tscn) via `scene_path`.
## See design/gdd/map.md — Core Rules 1, 7, 10. Authored as .tres; consumed by MatchSetup,
## Round Flow (spawn points), Movement/Projectile (wrap config), and UI Flow (name/thumbnail).

@export var id: StringName = &""                       ## unique, addressable map id
@export var display_name: String = ""
@export var thumbnail: Texture2D = null                ## map-select preview (UI Flow)
@export var scene_path: String = ""                    ## res:// path to the MapScene .tscn

@export var spawn_points: Array[Vector2] = []          ## exactly 4 — one per slot, pixel coords

@export var horizontal_wrap: bool = true               ## TowerFall-style side wrap (default on)
@export var vertical_wrap: bool = false                ## off by default (avoids perpetual fall)
@export var playfield_width: float = 480.0             ## v1 locked to INTERNAL_WIDTH
@export var playfield_height: float = 270.0            ## v1 locked to INTERNAL_HEIGHT

@export var recommended_player_count: Vector2i = Vector2i(2, 4)
@export var recoverability_validated: bool = false     ## designer assertion; must be true to ship
