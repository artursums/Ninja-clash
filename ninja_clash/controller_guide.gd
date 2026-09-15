extends Control
## Controller callouts use the same Kenney artwork and palette for both layouts.

const UI := preload("res://menu_ui.gd")
const ROOT := "res://sprites/input/"
var playstation := true
var _texture: Texture2D
var _anchors: Array[Vector2] = []
var _ends: Array[Vector2] = []
const BODY := Rect2(246, 112, 308, 228)

func configure(use_playstation: bool) -> void:
	playstation = use_playstation
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texture = load(ROOT + ("controller_playstation5.svg" if playstation else "controller_xboxseries.svg"))
	var rows := [
		["GUARD", "Hold to block from the front", ["playstation_trigger_l2", "xbox_lt"], Vector2(14, 17)],
		["DASH", "Burst, dodge and catch blades", ["playstation_trigger_l1", "xbox_lb"], Vector2(17, 19)],
		["MOVE + AIM", "Left stick or directional pad", ["playstation_stick_l", "xbox_stick_l"], Vector2(25, 32) if playstation else Vector2(20.5, 23.5)],
		["MATCH SETUP", "Adjust the rules before a fight", ["playstation5_button_create_outline", "xbox_button_view"], Vector2(22, 23) if playstation else Vector2(28, 25)],
		["PAUSE", "Take a breath, then resume", ["playstation5_button_options_outline", "xbox_button_menu"], Vector2(42, 23) if playstation else Vector2(35, 25)],
		["KATANA", "Strike nearby opponents", ["playstation_button_triangle_outline", "xbox_button_y"], Vector2(46.5, 23.5) if playstation else Vector2(43, 21)],
		["SHURIKEN", "Hold to aim, release to throw", ["playstation_button_square_outline", "xbox_button_x"], Vector2(43.5, 26.5) if playstation else Vector2(39, 25)],
		["JUMP", "Jump again against a wall", ["playstation_button_cross_outline", "xbox_button_a"], Vector2(46.5, 29.5) if playstation else Vector2(43, 29)],
	]
	for i in rows.size():
		var right := i >= 4
		var x := 578.0 if right else 42.0
		var y := 124.0 + (i % 4) * 54
		var row: Array = rows[i]
		var icon := UI.image(self, load(ROOT + row[2][0 if playstation else 1] + ".svg"), Rect2(x, y, 30, 30))
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		icon.modulate = UI.GOLD if i in [0, 1] else UI.IVORY
		UI.label(self, row[0], Rect2(x + 36, y, 162, 22), 17)
		var caption := UI.label(self, row[1], Rect2(x, y + 28, 190, 20), 12, UI.MUTED)
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var point: Vector2 = row[3]
		_anchors.append(BODY.position + (point - Vector2(5, 12)) * BODY.size / Vector2(54, 40))
		_ends.append(Vector2(571 if right else 232, y + 14))
	var alternate := ["playstation_button_circle_outline", "playstation_trigger_r1", "playstation_trigger_r2"] if playstation else ["xbox_button_b", "xbox_rb", "xbox_rt"]
	UI.label(self, "ALSO DASH", Rect2(280, 333, 106, 26), 13, UI.MUTED)
	for i in alternate.size():
		var icon := UI.image(self, load(ROOT + alternate[i] + ".svg"), Rect2(384 + i * 36, 331, 28, 28))
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		icon.modulate = UI.GOLD
	queue_redraw()

func _draw() -> void:
	if _texture == null:
		return
	draw_texture_rect(_texture, BODY, false)
	for i in _anchors.size():
		var endpoint := _ends[i]
		var elbow := Vector2(240 if i < 4 else 560, endpoint.y)
		draw_polyline(PackedVector2Array([endpoint, elbow, _anchors[i]]), Color(0.75, 0.67, 0.5, 0.55), 1.0, true)
		draw_circle(_anchors[i], 2.5, UI.GOLD, true, -1, true)
