extends RefCounted

const FRAME_SIZE := Vector2(48, 48)
const COLUMNS := 12
const ANIMATIONS := ["idle", "run", "rise", "fall", "wall", "swing", "throw", "dodge"]
const COUNTS := [8, 12, 6, 6, 6, 10, 8, 8]
const STYLES := ["base", "elemental", "ronin", "chef", "cyber", "edo", "office", "pirate", "vacation", "pig", "endobot", "neko", "stalker", "ironclad", "bakeneko"]
const SWORD_ANGLES := [-110.0, -85.0, 5.0, 50.0, 70.0, 55.0, 35.0, 20.0, 5.0, 0.0]
const PALETTE := preload("res://fighter_palette.gdshader")
static var _materials: Dictionary = {}

static func path(style: int, color: String = "cyan") -> String:
	return "res://sprites/fighters/" + STYLES[posmod(style, STYLES.size())] + "/" + color + ".png"

static func portrait(style: int, color: String = "cyan") -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = load(path(style,color))
	atlas.region = Rect2(Vector2.ZERO, FRAME_SIZE)
	return atlas

static func material_for(color: Color) -> ShaderMaterial:
	var key := color.to_html()
	if not _materials.has(key):
		var material := ShaderMaterial.new()
		material.shader = PALETTE
		material.set_shader_parameter("clan_color", color)
		_materials[key] = material
	return _materials[key]

static func frame_for(animation: String, phase: float) -> int:
	var row := ANIMATIONS.find(animation)
	if row < 0:
		row = 0
	return row * COLUMNS + clampi(int(phase * COUNTS[row]), 0, COUNTS[row] - 1)

static func sword_angle(phase: float) -> float:
	var f := clampf(phase, 0, 1) * (SWORD_ANGLES.size() - 1)
	var i := mini(int(f), SWORD_ANGLES.size() - 2)
	return deg_to_rad(lerpf(SWORD_ANGLES[i], SWORD_ANGLES[i + 1], f - i))

static func sword_hand(phase: float) -> Vector2:
	return Vector2(9 + sin(phase * PI) * 2, 2 + sin(phase * PI) * 3).round()
