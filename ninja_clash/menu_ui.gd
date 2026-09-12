extends RefCounted

const FONT = preload("res://fonts/PixelifySans.ttf")
const BACKGROUND = preload("res://sprites/menu/sanctuary.webp")
const GOLD := Color("efc878")
const IVORY := Color("fff1cf")
const MUTED := Color("acabc4")
const INK := Color("101326")
const EDGE := Color("41415e")

static func label(parent: Node, text: String, rect: Rect2, font_size: int = 18, color: Color = IVORY, centered: bool = false) -> Label:
	var node := Label.new()
	node.text = text
	node.position = rect.position
	node.size = rect.size
	node.add_theme_font_override("font", FONT)
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

static func image(parent: Node, texture: Texture2D, rect: Rect2) -> TextureRect:
	var node := TextureRect.new()
	node.texture = texture
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.position = rect.position
	node.size = rect.size
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

static func fill(parent: Node, rect: Rect2, color: Color) -> ColorRect:
	var node := ColorRect.new()
	node.position = rect.position
	node.size = rect.size
	node.color = color
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

static func style(selected: bool = false, accent: Color = GOLD) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("292439") if selected else Color("14182c")
	box.border_color = accent if selected else EDGE
	box.set_border_width_all(2 if selected else 1)
	box.shadow_color = Color(0.02, 0.02, 0.06, 0.6)
	box.shadow_size = 3
	box.shadow_offset = Vector2(0, 3)
	box.content_margin_left = 14
	box.content_margin_right = 14
	return box

static func panel(parent: Node, rect: Rect2, accent: Color = EDGE) -> Panel:
	var node := Panel.new()
	node.position = rect.position
	node.size = rect.size
	node.add_theme_stylebox_override("panel", style(true, accent))
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

static func button(parent: Node, text: String, rect: Rect2, pressed: Callable, font_size: int = 20) -> Button:
	var node := Button.new()
	node.text = text
	node.position = rect.position
	node.size = rect.size
	node.focus_mode = Control.FOCUS_NONE
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.add_theme_font_override("font", FONT)
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", IVORY)
	node.add_theme_color_override("font_hover_color", GOLD)
	node.add_theme_color_override("font_pressed_color", INK)
	var normal := style()
	var hover := style(true)
	var down := style(true)
	down.bg_color = GOLD
	if rect.size.x < 50:
		for box in [normal, hover, down]:
			box.content_margin_left = 0
			box.content_margin_right = 0
	node.add_theme_stylebox_override("normal", normal)
	node.add_theme_stylebox_override("hover", hover)
	node.add_theme_stylebox_override("pressed", down)
	node.size = rect.size
	node.pressed.connect(pressed)
	parent.add_child(node)
	return node

static func select(button_node: Button, selected: bool, accent: Color = GOLD) -> void:
	button_node.add_theme_stylebox_override("normal", style(selected, accent))
	button_node.add_theme_color_override("font_color", accent if selected else IVORY)

static func backdrop(parent: Control, dim: float = 0.72, rules: bool = true) -> void:
	var bg := image(parent, BACKGROUND, Rect2(0, 0, 800, 450))
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	fill(parent, Rect2(0, 0, 800, 450), Color(0.025, 0.03, 0.08, dim))
	if rules:
		fill(parent, Rect2(24, 20, 752, 1), Color("646075"))
		fill(parent, Rect2(24, 409, 752, 1), EDGE)

static func header(parent: Control, title: String, step: int) -> void:
	label(parent, "FOUR CLANS", Rect2(32, 28, 180, 18), 14, GOLD)
	label(parent, title, Rect2(32, 50, 620, 40), 32)
	var names := ["01  MODE", "02  CLAN", "03  ARENA"]
	for i in 3:
		label(parent, names[i], Rect2(466 + i * 104, 28, 102, 20), 14, GOLD if step == i else MUTED)

static func footer(parent: Node, text: String) -> Label:
	return label(parent, text, Rect2(32, 416, 736, 24), 14, MUTED, true)

static func nav(suffix: String) -> bool:
	return Input.is_action_just_pressed("p1_" + suffix) or Input.is_action_just_pressed("p2_" + suffix)

static func confirm() -> bool:
	return nav("jump") or nav("confirm")
