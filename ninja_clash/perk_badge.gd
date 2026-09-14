extends Node2D
const Rules := preload("res://perk_rules.gd")

func _ready() -> void:
	z_index = 110

func _process(_delta: float) -> void:
	visible = get_parent().alive
	queue_redraw()

func _draw() -> void:
	var p = get_parent()
	if p.perk_kind != Rules.Kind.NONE:
		draw_rect(Rect2(16,-27,30,20),Color("101525e8"))
		Rules.draw_icon(self,p.perk_kind,Vector2(26,-17),9)
		draw_string(Rules.FONT,Vector2(36,-12),str(p.perk_charges),HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color.WHITE)
	if p.reverse_left > 0:
		draw_rect(Rect2(-32,20,64,18),Color("101525ee"))
		Rules.draw_icon(self,Rules.Kind.MISDIRECTION,Vector2(-20,28),8)
		draw_string(Rules.FONT,Vector2(-8,32),"%.1fs" % p.reverse_left,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Rules.COLORS[1])
		draw_line(Vector2(-30,38),Vector2(-30+60*p.reverse_left/Rules.REVERSE_SECONDS,38),Rules.COLORS[1],2)
