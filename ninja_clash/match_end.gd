# Match-end screen. Shows the winning clan + round tally, then offers three choices:
#   CHOOSE CHARACTERS → CLAN_SELECT (re-pick clans, same mode)
#   CHOOSE ARENA      → MAP_SELECT  (re-pick map, same clans)
#   MAIN MENU         → TITLE
# Navigate ↑/↓ (either player / any pad), confirm ✕/Space, ◯/Esc → main menu.
# Reuses the pause-menu sprite kit (backdrop + wooden button plates + pointer) for a consistent look.
extends Control

const MENU := "res://sprites/menu/"

const PLATE_W := 320.0
const PLATE_H := 46.0
const PLATE_STEP := 60.0
const PLATE_TOP := 224.0
const PLATE_CX := (800.0 - PLATE_W) / 2.0

const COL_SEL := Color("d4a830")    # highlighted item
const COL_DIM := Color("f0eee8")    # idle item text

# Option labels; the state each routes to is resolved at runtime by _option_state() (autoload enum
# values aren't safe to embed in a const initializer).
const OPT_TEXT: Array = ["CHOOSE CHARACTERS", "CHOOSE ARENA", "MAIN MENU"]

func _option_state(i: int) -> int:
	match i:
		0: return GameState.State.CLAN_SELECT
		1: return GameState.State.MAP_SELECT
		_: return GameState.State.TITLE

var winner_label: Label
var subline: Label
var tally_label: Label
var hint_label: Label
var plates: Array = []     # button-plate TextureRects
var opt_labels: Array = []
var cursor_rect: TextureRect
var _cursor: int = 0
var _input_lockout_until: float = 0.0


func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	visibility_changed.connect(_on_visibility_changed)


func _on_visibility_changed() -> void:
	if visible:
		_cursor = 0
		_refresh()
		_input_lockout_until = Time.get_ticks_msec() / 1000.0 + 1.0
		Audio.play_win_fanfare()


func _build() -> void:
	var backdrop := TextureRect.new()
	backdrop.texture = load(MENU + "pause_backdrop_native.png")
	backdrop.anchor_right = 1.0
	backdrop.anchor_bottom = 1.0
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	winner_label = _label(0, 60, 800, 80, 60)
	winner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	subline = _label(0, 142, 800, 28, 18)
	subline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subline.text = "match victory"
	subline.add_theme_color_override("font_color", COL_SEL)

	tally_label = _label(0, 176, 800, 30, 22)
	tally_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tally_label.add_theme_color_override("font_color", COL_DIM)

	for i in OPT_TEXT.size():
		var y: float = PLATE_TOP + i * PLATE_STEP
		var plate := _tex_sized(load(MENU + "pause_button_normal_native.png"), PLATE_CX, y, PLATE_W, PLATE_H)
		plates.append(plate)
		var lbl := _label(PLATE_CX, y, PLATE_W, PLATE_H, 22)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.text = String(OPT_TEXT[i])
		opt_labels.append(lbl)

	cursor_rect = _tex_sized(load(MENU + "pause_cursor_native.png"), 0, 0, 28, 32)

	hint_label = _label(0, 414, 800, 22, 12)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.text = "↑/↓ select     ✕ / Space / Enter confirm     ◯ / Esc — highlight main menu"
	hint_label.add_theme_color_override("font_color", Color("6a6e88"))


# --- Node helpers ---

func _tex_sized(tex: Texture2D, x: float, y: float, w: float, h: float) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.position = Vector2(x, y)
	tr.size = Vector2(w, h)
	add_child(tr)
	return tr

func _label(x: float, y: float, w: float, h: float, font_size: int) -> Label:
	var lbl := Label.new()
	lbl.position = Vector2(x, y)
	lbl.size = Vector2(w, h)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lbl)
	return lbl


# --- Refresh / input ---

func _refresh() -> void:
	var winner_slot: int = GameState.match_winner_slot
	var clan: Dictionary = GameState.get_clan(winner_slot)
	winner_label.text = "%s WINS" % clan.name
	winner_label.add_theme_color_override("font_color", clan.color)

	var parts: PackedStringArray = PackedStringArray()
	for slot in range(1, GameState.num_players() + 1):
		# "P<N> CLAN score" — a first-timer shouldn't have to remember which clan they picked;
		# the winner's row gets a star so the big headline maps to a line at a glance.
		var mark: String = "★ " if slot == winner_slot else ""
		parts.append("%sP%d %s %d" % [mark, slot, GameState.get_clan(slot).name, Combat.scores.get(slot, 0)])
	tally_label.text = "    ·    ".join(parts)

	for i in plates.size():
		var sel: bool = (i == _cursor)
		plates[i].texture = load(MENU + "pause_button_%s_native.png" % ("hover" if sel else "normal"))
		opt_labels[i].add_theme_color_override("font_color", COL_SEL if sel else COL_DIM)
		# Online guest: the options belong to the host — shown dimmed, watch-only.
		plates[i].modulate.a = 0.4 if Net.is_client() else 1.0
		opt_labels[i].modulate.a = 0.4 if Net.is_client() else 1.0

	var cy: float = PLATE_TOP + _cursor * PLATE_STEP
	cursor_rect.position = Vector2(PLATE_CX - 38.0, cy + (PLATE_H - 32.0) / 2.0)
	cursor_rect.visible = not Net.is_client()
	if Net.is_client():
		hint_label.text = "P1 (host) chooses what happens next      ESC / ◯ — leave the session"


func _nav(suffix: String) -> bool:
	return Input.is_action_just_pressed("p1_" + suffix) or Input.is_action_just_pressed("p2_" + suffix)


func _process(_delta: float) -> void:
	if not visible:
		return
	if Time.get_ticks_msec() / 1000.0 < _input_lockout_until:
		return
	# Online guest: the host drives the rematch flow; the guest may only leave the session.
	if Net.is_client():
		if Input.is_action_just_pressed("menu_cancel"):
			Audio.play("click")
			Net.leave("")
			GameState.change_state(GameState.State.ONLINE_MENU)
		return
	if Input.is_action_just_pressed("menu_cancel"):
		# Esc no longer discards the results instantly (an accidental press right after the
		# fanfare used to throw the match screen away) — it highlights MAIN MENU; confirm executes.
		Audio.play("click")
		_cursor = OPT_TEXT.size() - 1
		_refresh()
		return
	if _nav("aim_up"):
		_cursor = (_cursor + OPT_TEXT.size() - 1) % OPT_TEXT.size()
		Audio.play("click")
		_refresh()
	elif _nav("aim_down"):
		_cursor = (_cursor + 1) % OPT_TEXT.size()
		Audio.play("click")
		_refresh()
	elif Input.is_action_just_pressed("p1_jump") or Input.is_action_just_pressed("p2_jump") \
			or Input.is_action_just_pressed("p1_confirm") or Input.is_action_just_pressed("p2_confirm"):
		Audio.play("confirm")
		GameState.change_state(_option_state(_cursor))
