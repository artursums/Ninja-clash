extends RefCounted

const PALETTE := preload("res://portrait_palette.gdshader")
const HUES := [0.89, 0.52, 0.30, 0.075]
const CLASSIC := [
	preload("res://sprites/portraits/classic-shadow.webp"),
	preload("res://sprites/portraits/classic-storm.webp"),
	preload("res://sprites/portraits/classic-frost.webp"),
	preload("res://sprites/portraits/classic-fire.webp"),
]
const ELEMENTAL := [
	preload("res://sprites/portraits/elemental-wraith.webp"),
	preload("res://sprites/portraits/elemental-tempest.webp"),
	preload("res://sprites/portraits/elemental-glacier.webp"),
	preload("res://sprites/portraits/elemental-inferno.webp"),
]
const COSTUMES := {
	"ronin": [preload("res://sprites/portraits/ronin-shadow.webp"), 0],
	"chef": [preload("res://sprites/portraits/chef-fire.webp"), 3],
	"cyber": [preload("res://sprites/portraits/cyber-storm.webp"), 1],
	"edo": [preload("res://sprites/portraits/edo-frost.webp"), 2],
	"office": [preload("res://sprites/portraits/office-storm.webp"), 1],
	"pirate": [preload("res://sprites/portraits/pirate-shadow.webp"), 0],
	"vacation": [preload("res://sprites/portraits/vacation-frost.webp"), 2],
	"pig": [preload("res://sprites/portraits/piggy-fire.webp"), 3],
	"endobot": [preload("res://sprites/portraits/endobot-storm.webp"), 1],
	"neko": [preload("res://sprites/portraits/neko-frost.webp"), 2],
	"stalker": [preload("res://sprites/portraits/stalker-shadow.webp"), 0],
	"ironclad": [preload("res://sprites/portraits/ironclad-fire.webp"), 3],
	"bakeneko": [preload("res://sprites/portraits/bakeneko-shadow.webp"), 0],
}

static func texture(clan: int, style: String) -> Texture2D:
	if style == "elemental":
		return ELEMENTAL[clan]
	if COSTUMES.has(style):
		return COSTUMES[style][0]
	return CLASSIC[clan]

static func apply(portrait: TextureRect, clan: int, style: String) -> void:
	portrait.texture = texture(clan, style)
	if not COSTUMES.has(style) or COSTUMES[style][1] == clan:
		portrait.material = null
		return
	var palette := portrait.material as ShaderMaterial
	if palette == null:
		palette = ShaderMaterial.new()
		palette.shader = PALETTE
		portrait.material = palette
	palette.set_shader_parameter("source_hue", HUES[COSTUMES[style][1]])
	palette.set_shader_parameter("target_hue", HUES[clan])
