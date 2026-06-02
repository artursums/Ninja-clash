extends Control
## Fight Setup / Variants screen. Configures the GLOBAL match ruleset (the MatchConfig autoload)
## before fighters lock in — TowerFall's Variants menu is the reference. P1/P2 navigable: up/down
## moves the cursor, left/right changes the focused value, confirm flips a toggle or triggers an
## action row, back (Esc / pad Select) returns to clan select. Every change persists immediately
## via MatchConfig's setters; defaults reproduce the standard game, so an untouched setup is a no-op.

const ROW_X := 210.0
const VALUE_X := 500.0
const ROW_Y0 := 80.0
const ROW_H := 28.0
const HILITE_X := 176.0
const HILITE_W := 448.0

var rows: Array = []        # row descriptors (see _build_rows)
var row_labels: Array = []  # left-hand Label per row
var row_values: Array = []  # right-hand Label per row
var cursor: int = 0
var highlight: ColorRect
var _input_lockout_until: float = 0.0


func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	visibility_changed.connect(_on_visibility_changed)
	_refresh()


func _on_visibility_changed() -> void:
	if visible:
		cursor = 0
		_input_lockout_until = Time.get_ticks_msec() / 1000.0 + 0.2
		_refresh()


func _build() -> void:
	var bg := ColorRect.new()
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.color = Color("0d0d1a")
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var header := Label.new()
	header.position = Vector2(0, 26)
	header.size = Vector2(800, 40)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 30)
	header.add_theme_color_override("font_color", Color("d4a830"))
	header.text = "FIGHT SETUP"
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(header)

	# Selection highlight behind the active row (added before the labels so it renders under them).
	highlight = ColorRect.new()
	highlight.color = Color(1, 1, 1, 0.10)
	highlight.size = Vector2(HILITE_W, ROW_H - 4.0)
	highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(highlight)

	_build_rows()
	for i in rows.size():
		var y: float = ROW_Y0 + i * ROW_H
		var lbl := Label.new()
		lbl.position = Vector2(ROW_X, y)
		lbl.size = Vector2(VALUE_X - ROW_X - 10.0, ROW_H)
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(lbl)
		row_labels.append(lbl)
		var val := Label.new()
		val.position = Vector2(VALUE_X, y)
		val.size = Vector2(624.0 - VALUE_X, ROW_H)
		val.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		val.add_theme_font_size_override("font_size", 16)
		val.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(val)
		row_values.append(val)

	var hint := Label.new()
	hint.position = Vector2(0, 410)
	hint.size = Vector2(800, 20)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color("8a8ea8"))
	hint.text = "UP/DOWN  MOVE     LEFT/RIGHT  CHANGE     BACK: ESC / SELECT"
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)


func _build_rows() -> void:
	rows = [
		_toggle("KATANA",
			func() -> bool: return MatchConfig.katana_enabled,
			func(v: bool) -> void: MatchConfig.set_katana_enabled(v),
			"ON", "OFF", Callable()),
		_toggle("KATANA RECHARGE",
			func() -> bool: return MatchConfig.katana_recharge,
			func(v: bool) -> void: MatchConfig.set_katana_recharge(v),
			"PER-ROUND", "NEVER",
			func() -> bool: return MatchConfig.katana_enabled),
		_stepper("KATANA CHARGES",
			func() -> int: return MatchConfig.katana_charges,
			func(v: int) -> void: MatchConfig.set_katana_charges(v),
			0, MatchConfig.MAX_KATANA_CHARGES,
			func() -> bool: return MatchConfig.katana_enabled),
		_toggle("BLADE WAVE",
			func() -> bool: return MatchConfig.blade_wave_enabled,
			func(v: bool) -> void: MatchConfig.set_blade_wave_enabled(v),
			"ON", "OFF",
			func() -> bool: return MatchConfig.katana_enabled),
		_toggle("SHURIKENS",
			func() -> bool: return MatchConfig.shurikens_enabled,
			func(v: bool) -> void: MatchConfig.set_shurikens_enabled(v),
			"ON", "OFF", Callable()),
		_stepper("START SHURIKENS",
			func() -> int: return MatchConfig.start_shurikens,
			func(v: int) -> void: MatchConfig.set_start_shurikens(v),
			0, MatchConfig.STASH_CAP,
			func() -> bool: return MatchConfig.shurikens_enabled),
		_toggle("INFINITE SHURIKENS",
			func() -> bool: return MatchConfig.infinite_shurikens,
			func(v: bool) -> void: MatchConfig.set_infinite_shurikens(v),
			"ON", "OFF",
			func() -> bool: return MatchConfig.shurikens_enabled),
		_stepper("HITS TO KILL",
			func() -> int: return MatchConfig.max_hp,
			func(v: int) -> void: MatchConfig.set_max_hp(v),
			1, MatchConfig.MAX_HP_CAP, Callable()),
		_stepper("ROUNDS TO WIN",
			func() -> int: return MatchConfig.target_score,
			func(v: int) -> void: MatchConfig.set_target_score(v),
			MatchConfig.MIN_TARGET_SCORE, MatchConfig.MAX_TARGET_SCORE, Callable()),
		_action("RESET TO DEFAULTS", _do_reset),
		_action("DONE", _do_done),
	]


func _toggle(label: String, getter: Callable, setter: Callable, on_text: String, off_text: String, active: Callable) -> Dictionary:
	return {"kind": "toggle", "label": label, "getter": getter, "setter": setter, "on": on_text, "off": off_text, "active": active}


func _stepper(label: String, getter: Callable, setter: Callable, lo: int, hi: int, active: Callable) -> Dictionary:
	return {"kind": "stepper", "label": label, "getter": getter, "setter": setter, "lo": lo, "hi": hi, "active": active}


func _action(label: String, do: Callable) -> Dictionary:
	return {"kind": "action", "label": label, "do": do, "active": Callable()}


func _do_reset() -> void:
	MatchConfig.reset_to_defaults()
	Audio.play("confirm")
	_refresh()


func _do_done() -> void:
	Audio.play("confirm")
	GameState.change_state(GameState.State.CLAN_SELECT)


func _nav(suffix: String) -> bool:
	return Input.is_action_just_pressed("p1_" + suffix) or Input.is_action_just_pressed("p2_" + suffix)


func _process(_delta: float) -> void:
	if not visible:
		return
	if Time.get_ticks_msec() / 1000.0 < _input_lockout_until:
		return
	if Input.is_action_just_pressed("menu_cancel") or Input.is_action_just_pressed("menu_setup"):
		Audio.play("click")
		GameState.change_state(GameState.State.CLAN_SELECT)
		return
	var n: int = rows.size()
	if _nav("aim_up"):
		cursor = (cursor + n - 1) % n
		Audio.play("click")
		_refresh()
	elif _nav("aim_down"):
		cursor = (cursor + 1) % n
		Audio.play("click")
		_refresh()
	elif _nav("left"):
		_adjust(-1)
	elif _nav("right"):
		_adjust(1)
	elif _nav("jump"):
		_activate()


# Left/right on the focused row: flip a toggle, step a number (clamped), no-op on action rows.
func _adjust(dir: int) -> void:
	var row: Dictionary = rows[cursor]
	match row.kind:
		"toggle":
			row.setter.call(not bool(row.getter.call()))
			Audio.play("click")
			_refresh()
		"stepper":
			var cur: int = int(row.getter.call())
			var nv: int = clampi(cur + dir, int(row.lo), int(row.hi))
			if nv != cur:
				row.setter.call(nv)
				Audio.play("click")
				_refresh()


# Confirm on the focused row: run action rows, flip toggles, wrap-increment steppers.
func _activate() -> void:
	var row: Dictionary = rows[cursor]
	match row.kind:
		"action":
			row.do.call()
		"toggle":
			row.setter.call(not bool(row.getter.call()))
			Audio.play("click")
			_refresh()
		"stepper":
			var cur: int = int(row.getter.call())
			var nv: int = cur + 1
			if nv > int(row.hi):
				nv = int(row.lo)
			row.setter.call(nv)
			Audio.play("click")
			_refresh()


func _refresh() -> void:
	highlight.position = Vector2(HILITE_X, ROW_Y0 + cursor * ROW_H + 2.0)
	for i in rows.size():
		var row: Dictionary = rows[i]
		var sel: bool = (i == cursor)
		var active: bool = true
		var act_cb: Callable = row.active
		if not act_cb.is_null():
			active = bool(act_cb.call())
		var col: Color
		if not active:
			col = Color(0.45, 0.47, 0.55)
		elif sel:
			col = Color(1, 1, 1)
		else:
			col = Color(0.78, 0.80, 0.88)
		row_labels[i].text = String(row.label)
		row_labels[i].add_theme_color_override("font_color", col)
		row_values[i].add_theme_color_override("font_color", col)
		match row.kind:
			"toggle":
				row_values[i].text = String(row.on) if bool(row.getter.call()) else String(row.off)
			"stepper":
				var v: int = int(row.getter.call())
				row_values[i].text = ("< %d >" % v) if (sel and active) else str(v)
			"action":
				row_values[i].text = ""
