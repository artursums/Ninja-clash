extends Node2D
const Rules := preload("res://perk_rules.gd")

func _ready() -> void:
	z_index = 110
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _process(_delta: float) -> void:
	visible = get_parent().alive
	queue_redraw()

func _draw() -> void:
	var p = get_parent()
	if p.perk_kind != Rules.Kind.NONE:
		Rules.draw_icon(self, p.perk_kind, p.perk_icon_anchor, 8)
	if p.reverse_left > 0:
		var at := Vector2(0, 24)
		Rules.draw_icon(self, Rules.Kind.MISDIRECTION, at, 7)
		draw_arc(at, 10, -PI/2, -PI/2+TAU*p.reverse_left/Rules.REVERSE_SECONDS, 20, Rules.COLORS[1], 1)
