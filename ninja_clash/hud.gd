# PROTOTYPE - NOT FOR PRODUCTION
# Date: 2026-05-18
#
# Minimal HUD: map name banner (mid-screen, fades after 2s).
# Per-player stash count is shown above each ninja's head (built in main.gd, owned by player).
# (The kill feed — "<clan> eliminated <clan>" — was removed; not wanted.)

extends Control

var map_banner_label: Label
var _map_banner_clear_at: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_right = 1.0
	anchor_bottom = 1.0
	_build_map_banner()

func _process(_delta: float) -> void:
	var t: float = Time.get_ticks_msec() / 1000.0
	if map_banner_label and _map_banner_clear_at > 0.0 and t > _map_banner_clear_at:
		map_banner_label.modulate.a = max(0.0, 1.0 - (t - _map_banner_clear_at) * 1.5)
		if map_banner_label.modulate.a <= 0.0:
			map_banner_label.text = ""
			_map_banner_clear_at = 0.0

func _build_map_banner() -> void:
	map_banner_label = Label.new()
	map_banner_label.position = Vector2(400 - 200, 235)
	map_banner_label.custom_minimum_size = Vector2(400, 0)
	map_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_banner_label.add_theme_font_size_override("font_size", 22)
	map_banner_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.85))
	map_banner_label.text = ""
	add_child(map_banner_label)

func show_map_banner(map_name: String) -> void:
	map_banner_label.text = map_name
	map_banner_label.modulate.a = 1.0
	_map_banner_clear_at = Time.get_ticks_msec() / 1000.0 + 2.0
