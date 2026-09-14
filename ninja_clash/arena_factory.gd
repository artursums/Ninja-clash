## Constructs map nodes from data. The caller owns scene placement and lifetime.

extends RefCounted

const Arena := preload("res://arena_rules.gd")
const PLATFORM_SRC_Y_WALKABLE := 395.0
const PLATFORM_VISUAL_OVERHANG := 1.4

static func make_decoration(parent: Node2D, d: Dictionary) -> Sprite2D:
	var path: String = d.get("sprite", "")
	if path == "" or not ResourceLoader.exists(path):
		return null
	var spr := Sprite2D.new()
	spr.texture = load(path)
	spr.centered = true
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var region: Rect2 = d.get("sprite_region", Rect2())
	var src_h: float = spr.texture.get_height()
	if region.size.x > 0:
		spr.region_enabled = true
		spr.region_rect = region
		src_h = region.size.y

	var screen_h: float = d.get("height", src_h)
	var s: float = screen_h / src_h
	spr.scale = Vector2(s, s)
	spr.position = d.get("center", Vector2.ZERO)
	spr.z_index = int(d.get("z", -5))
	spr.modulate = d.get("modulate", Color.WHITE)
	parent.add_child(spr)
	return spr

static func apply_sky(sky_bg_solid: ColorRect, sky_rect: TextureRect, top_color: Color, bottom_color: Color, bg_path: String) -> bool:

	if sky_bg_solid:
		sky_bg_solid.color = top_color

	if bg_path != "" and ResourceLoader.exists(bg_path):
		var img: Resource = load(bg_path)
		if img != null and img is Texture2D:
			sky_rect.texture = img
			return true

	var grad := Gradient.new()
	grad.colors = PackedColorArray([top_color, bottom_color])
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = int(Arena.WIDTH)
	tex.height = int(Arena.HEIGHT)
	sky_rect.texture = tex
	return false

static func make_solid(parent: Node2D, center: Vector2, size: Vector2, fill_color: Color, edge_color: Color, transparent: bool = false, sprite_path: String = "", sprite_region: Rect2 = Rect2(), sprite_mode: String = "platform", walkable_y: float = -1.0, overhang: float = PLATFORM_VISUAL_OVERHANG) -> StaticBody2D:
	var body: StaticBody2D = StaticBody2D.new()
	body.add_to_group("arena_solids")
	body.position = center
	var col: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = size
	col.shape = rect
	body.add_child(col)

	# Bodies straddling the screen seam must collide on both sides.
	for offset in Arena.seam_offsets(Rect2(center-size/2,size)):
		var continuation := CollisionShape2D.new()
		continuation.shape = rect
		continuation.position = offset
		body.add_child(continuation)

	if sprite_path != "" and ResourceLoader.exists(sprite_path):
		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = load(sprite_path)
		sprite.centered = true
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var src_w: float
		var src_h: float
		if sprite_region.size.x > 0:
			sprite.region_enabled = true
			sprite.region_rect = sprite_region
			src_w = sprite_region.size.x
			src_h = sprite_region.size.y
		else:
			src_w = float(sprite.texture.get_width())
			src_h = float(sprite.texture.get_height())
		if sprite_mode == "block":

			sprite.scale = size / Vector2(src_w, src_h)
		elif sprite_mode == "fill":

			var s: float = 450.0 / src_h
			sprite.scale = Vector2(s, s)
			sprite.position = Vector2.ZERO
		else:

			var s: float = (size.x * overhang) / src_w
			sprite.scale = Vector2(s, s)

			var wy: float = PLATFORM_SRC_Y_WALKABLE if walkable_y < 0.0 else walkable_y
			sprite.position = Vector2(0.0, -size.y / 2.0 + s * (src_h / 2.0 - wy))
		body.add_child(sprite)

	elif not transparent:
		var vis: ColorRect = ColorRect.new()
		vis.size = size
		vis.position = -size / 2.0
		vis.color = fill_color
		vis.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.add_child(vis)
		var edge_top: ColorRect = ColorRect.new()
		edge_top.size = Vector2(size.x, 2.0)
		edge_top.position = Vector2(-size.x / 2.0, -size.y / 2.0)
		edge_top.color = edge_color
		edge_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.add_child(edge_top)
		var edge_bot: ColorRect = ColorRect.new()
		edge_bot.size = Vector2(size.x, 1.5)
		edge_bot.position = Vector2(-size.x / 2.0, size.y / 2.0 - 1.5)
		edge_bot.color = Color(fill_color).darkened(0.4)
		edge_bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.add_child(edge_bot)

	parent.add_child(body)
	return body
