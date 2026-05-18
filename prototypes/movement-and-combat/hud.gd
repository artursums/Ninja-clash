# PROTOTYPE - NOT FOR PRODUCTION
# Date: 2026-05-18
#
# HUD: per-slot panels using selected clans from GameState, round counter,
# kill feed, map name banner. Visibility controlled by main.gd.

extends Control

const SHURIKEN_TEX_PATH := "res://sprites/shuriken.svg"

var round_label: Label
var kill_feed_label: Label
var map_banner_label: Label
var p1_stash_icons: Array = []
var p2_stash_icons: Array = []
var p1_score_label: Label
var p2_score_label: Label
var p1_name_label: Label
var p2_name_label: Label
var p1_tile: ColorRect
var p2_tile: ColorRect
var _kill_feed_clear_at: float = 0.0
var _map_banner_clear_at: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_right = 1.0
	anchor_bottom = 1.0
	_build_panels()
	_build_round_counter()
	_build_kill_feed()
	_build_map_banner()
	_refresh_clans()
	Combat.score_changed.connect(_on_score_changed)
	Combat.kill_logged.connect(_on_kill_logged)
	GameState.state_changed.connect(_on_state_changed)

func _on_state_changed(s: int) -> void:
	# Rebuild on match start to pick up clan changes from select screen
	if s == GameState.State.MATCH_INTRO:
		_refresh_clans()
		_on_score_changed()
		_update_round_label()

func _process(_delta: float) -> void:
	var t: float = Time.get_ticks_msec() / 1000.0
	if kill_feed_label and _kill_feed_clear_at > 0.0 and t > _kill_feed_clear_at:
		kill_feed_label.text = ""
		_kill_feed_clear_at = 0.0
	if map_banner_label and _map_banner_clear_at > 0.0 and t > _map_banner_clear_at:
		map_banner_label.modulate.a = max(0.0, 1.0 - (t - _map_banner_clear_at) * 1.5)
		if map_banner_label.modulate.a <= 0.0:
			map_banner_label.text = ""
			_map_banner_clear_at = 0.0
	_refresh_stash_icons(1, p1_stash_icons)
	_refresh_stash_icons(2, p2_stash_icons)

func _build_panels() -> void:
	var p1 = _make_panel(1, Vector2(10, 8), false)
	add_child(p1)
	var p2 = _make_panel(2, Vector2(800 - 10 - 220, 8), true)
	add_child(p2)

func _make_panel(slot: int, position_v: Vector2, mirrored: bool) -> Control:
	var panel = HBoxContainer.new()
	panel.position = position_v
	panel.add_theme_constant_override("separation", 8)

	var tile = ColorRect.new()
	tile.size = Vector2(22, 22)
	tile.custom_minimum_size = Vector2(22, 22)
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if slot == 1:
		p1_tile = tile
	else:
		p2_tile = tile

	var name_lbl = Label.new()
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	name_lbl.custom_minimum_size = Vector2(64, 0)
	if slot == 1:
		p1_name_label = name_lbl
	else:
		p2_name_label = name_lbl

	var stash_box = HBoxContainer.new()
	stash_box.add_theme_constant_override("separation", 2)
	var icons: Array = []
	for i in 3:
		var icon = TextureRect.new()
		icon.texture = load(SHURIKEN_TEX_PATH)
		icon.custom_minimum_size = Vector2(14, 14)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stash_box.add_child(icon)
		icons.append(icon)
	if slot == 1:
		p1_stash_icons = icons
	else:
		p2_stash_icons = icons

	var score_lbl = Label.new()
	score_lbl.text = "0"
	score_lbl.add_theme_font_size_override("font_size", 22)
	score_lbl.add_theme_color_override("font_color", Color.WHITE)
	score_lbl.custom_minimum_size = Vector2(28, 0)
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if slot == 1:
		p1_score_label = score_lbl
	else:
		p2_score_label = score_lbl

	if mirrored:
		panel.add_child(score_lbl)
		panel.add_child(stash_box)
		panel.add_child(name_lbl)
		panel.add_child(tile)
	else:
		panel.add_child(tile)
		panel.add_child(name_lbl)
		panel.add_child(stash_box)
		panel.add_child(score_lbl)
	return panel

func _refresh_clans() -> void:
	var c1: Dictionary = GameState.get_clan(1)
	var c2: Dictionary = GameState.get_clan(2)
	if p1_tile:
		p1_tile.color = c1.color
	if p2_tile:
		p2_tile.color = c2.color
	if p1_name_label:
		p1_name_label.text = c1.name
		p1_name_label.add_theme_color_override("font_color", c1.color)
	if p2_name_label:
		p2_name_label.text = c2.name
		p2_name_label.add_theme_color_override("font_color", c2.color)
	for icon in p1_stash_icons:
		icon.modulate = c1.color
	for icon in p2_stash_icons:
		icon.modulate = c2.color

func _build_round_counter() -> void:
	round_label = Label.new()
	round_label.position = Vector2(400 - 80, 10)
	round_label.custom_minimum_size = Vector2(160, 0)
	round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	round_label.add_theme_font_size_override("font_size", 16)
	round_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	round_label.text = "ROUND 1 / 5"
	add_child(round_label)

func _update_round_label() -> void:
	round_label.text = "ROUND %d / %d" % [GameState.current_round, GameState.target_score]

func _build_kill_feed() -> void:
	kill_feed_label = Label.new()
	kill_feed_label.position = Vector2(400 - 200, 50)
	kill_feed_label.custom_minimum_size = Vector2(400, 0)
	kill_feed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kill_feed_label.add_theme_font_size_override("font_size", 16)
	kill_feed_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	kill_feed_label.text = ""
	add_child(kill_feed_label)

func _build_map_banner() -> void:
	map_banner_label = Label.new()
	map_banner_label.position = Vector2(400 - 200, 235)
	map_banner_label.custom_minimum_size = Vector2(400, 0)
	map_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_banner_label.add_theme_font_size_override("font_size", 22)
	map_banner_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.85))
	map_banner_label.text = ""
	add_child(map_banner_label)

func _refresh_stash_icons(slot: int, icons: Array) -> void:
	for p in get_tree().get_nodes_in_group("players"):
		if p.slot == slot:
			for i in 3:
				if i < icons.size():
					icons[i].modulate.a = 1.0 if (i < p.stash) else 0.2
			return

func _on_score_changed(_unused = null) -> void:
	if p1_score_label != null:
		p1_score_label.text = str(Combat.scores.get(1, 0))
	if p2_score_label != null:
		p2_score_label.text = str(Combat.scores.get(2, 0))

func _on_kill_logged(killer_slot: int, victim_slot: int) -> void:
	var killer_name: String = GameState.get_clan(killer_slot).name
	var victim_name: String = GameState.get_clan(victim_slot).name
	kill_feed_label.text = "%s eliminated %s" % [killer_name, victim_name]
	_kill_feed_clear_at = Time.get_ticks_msec() / 1000.0 + 3.0

func show_map_banner(map_name: String) -> void:
	map_banner_label.text = map_name
	map_banner_label.modulate.a = 1.0
	_map_banner_clear_at = Time.get_ticks_msec() / 1000.0 + 2.0
