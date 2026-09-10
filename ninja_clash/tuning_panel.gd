# Live tuning panel for the five combat levers on the Combat autoload — dodge i-frames,
# throw velocity, pickup radius, self-hit immunity and wall-grab fall speed. Visible
# during the ROUND state only; a development aid for tuning feel without a rebuild.

extends VBoxContainer

func _ready() -> void:
	_add_header("LIVE TUNING (changes apply immediately)")
	_add_slider("Dodge i-frame (s)", 0.05, 0.40, Combat.dodge_iframe_duration_s,
		func(v: float) -> void: Combat.dodge_iframe_duration_s = v, "%.3f")
	_add_slider("Throw velocity (px/s)", 100.0, 1500.0, Combat.shuriken_throw_velocity,
		func(v: float) -> void: Combat.shuriken_throw_velocity = v, "%.0f")
	_add_slider("Pickup radius (px)", 4.0, 40.0, Combat.pickup_radius_px,
		func(v: float) -> void: Combat.pickup_radius_px = v, "%.0f")
	_add_slider("Self-hit immunity (s)", 0.0, 0.30, Combat.self_hit_immunity_s,
		func(v: float) -> void: Combat.self_hit_immunity_s = v, "%.3f")
	_add_slider("Wall-grab fall speed (0=hang)", 0.0, 200.0, Combat.wall_grab_fall_speed,
		func(v: float) -> void: Combat.wall_grab_fall_speed = v, "%.0f")

func _add_header(text: String) -> void:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	add_child(lbl)

func _add_slider(label_text: String, min_v: float, max_v: float, default_v: float,
		on_change: Callable, fmt: String) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	add_child(row)
	var lbl: Label = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(200.0, 0.0)
	lbl.add_theme_font_size_override("font_size", 11)
	row.add_child(lbl)
	var slider: HSlider = HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.value = default_v
	slider.step = (max_v - min_v) / 200.0
	slider.custom_minimum_size = Vector2(220.0, 0.0)
	row.add_child(slider)
	var value_lbl: Label = Label.new()
	value_lbl.text = fmt % default_v
	value_lbl.custom_minimum_size = Vector2(60.0, 0.0)
	value_lbl.add_theme_font_size_override("font_size", 11)
	row.add_child(value_lbl)
	slider.value_changed.connect(func(v: float) -> void:
		on_change.call(v)
		value_lbl.text = fmt % v
	)
