# PROTOTYPE - NOT FOR PRODUCTION
# Date: 2026-05-18
#
# Match-end screen. Shows winning clan + round tally + prompts.
# W or Enter: play again (back to MAP_SELECT, same clans).
# T: title screen (reset everything).
# ESC: title screen.

extends Control

var winner_label: Label
var subline: Label
var tally_label: Label
var prompt_label: Label
var _input_lockout_until: float = 0.0

func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	visibility_changed.connect(_on_visibility_changed)

func _on_visibility_changed() -> void:
	if visible:
		_refresh()
		_input_lockout_until = Time.get_ticks_msec() / 1000.0 + 1.0
		Audio.play_win_fanfare()

func _build() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.color = Color(0.05, 0.05, 0.08, 0.95)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	winner_label = Label.new()
	winner_label.position = Vector2(0, 100)
	winner_label.size = Vector2(800, 80)
	winner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	winner_label.add_theme_font_size_override("font_size", 64)
	add_child(winner_label)

	subline = Label.new()
	subline.position = Vector2(0, 195)
	subline.size = Vector2(800, 30)
	subline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subline.add_theme_font_size_override("font_size", 20)
	subline.add_theme_color_override("font_color", Color("d4a830"))
	add_child(subline)

	tally_label = Label.new()
	tally_label.position = Vector2(0, 260)
	tally_label.size = Vector2(800, 60)
	tally_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tally_label.add_theme_font_size_override("font_size", 32)
	tally_label.add_theme_color_override("font_color", Color("f0eee8"))
	add_child(tally_label)

	prompt_label = Label.new()
	prompt_label.position = Vector2(0, 380)
	prompt_label.size = Vector2(800, 30)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 16)
	prompt_label.add_theme_color_override("font_color", Color("a8a498"))
	prompt_label.text = "✕ / Space — play again (same arena)    ◯ / Esc — title screen"
	add_child(prompt_label)

func _refresh() -> void:
	var winner_slot: int = GameState.match_winner_slot
	var clan: Dictionary = GameState.get_clan(winner_slot)
	winner_label.text = "%s WINS" % clan.name
	winner_label.add_theme_color_override("font_color", clan.color)
	subline.text = "match victory"
	var p1c: Dictionary = GameState.get_clan(1)
	var p2c: Dictionary = GameState.get_clan(2)
	tally_label.text = "%s  %d  —  %d  %s" % [
		p1c.name, Combat.scores.get(1, 0), Combat.scores.get(2, 0), p2c.name,
	]

func _process(_delta: float) -> void:
	if not visible:
		return
	var t: float = Time.get_ticks_msec() / 1000.0
	if t < _input_lockout_until:
		return
	# Back to title — any controller (Circle) or Esc.
	if Input.is_action_just_pressed("menu_cancel"):
		Audio.play("click")
		GameState.change_state(GameState.State.TITLE)
		return
	if Input.is_action_just_pressed("p1_jump") or Input.is_action_just_pressed("p2_jump"):
		Audio.play("confirm")
		GameState.start_new_match()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	var t: float = Time.get_ticks_msec() / 1000.0
	if t < _input_lockout_until:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_T:   # Esc/Circle handled by menu_cancel in _process
			Audio.play("click")
			GameState.change_state(GameState.State.TITLE)
			get_viewport().set_input_as_handled()
