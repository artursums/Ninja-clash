# PROTOTYPE - NOT FOR PRODUCTION
# Date: 2026-05-18
#
# Title screen. Press any key → CLAN_SELECT.

extends Control

func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()

func _build() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.color = Color("0d0d1a")
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Decorative clan-color stripes (silent nod to the 4 clans)
	var stripe_y: float = 60.0
	var clan_w: float = 200.0
	for i in 4:
		var stripe: ColorRect = ColorRect.new()
		stripe.position = Vector2(i * clan_w, stripe_y)
		stripe.size = Vector2(clan_w, 4)
		stripe.color = GameState.CLANS[i].color
		stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(stripe)

	var title: Label = Label.new()
	title.text = "FOUR CLANS"
	title.position = Vector2(0, 120)
	title.size = Vector2(800, 80)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", Color("f0eee8"))
	add_child(title)

	var subtitle: Label = Label.new()
	subtitle.text = "shinobi arena"
	subtitle.position = Vector2(0, 215)
	subtitle.size = Vector2(800, 30)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color("a8a498"))
	add_child(subtitle)

	var prompt: Label = Label.new()
	prompt.text = "press any key to begin"
	prompt.position = Vector2(0, 320)
	prompt.size = Vector2(800, 30)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 20)
	prompt.add_theme_color_override("font_color", Color("d4a830"))
	add_child(prompt)

	var footer: Label = Label.new()
	footer.text = "v0 prototype  ·  2P keyboard local  ·  placeholder art"
	footer.position = Vector2(0, 410)
	footer.size = Vector2(800, 30)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 11)
	footer.add_theme_color_override("font_color", Color("6a6e88"))
	add_child(footer)

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		Audio.play("confirm")
		GameState.change_state(GameState.State.CLAN_SELECT)
		get_viewport().set_input_as_handled()
