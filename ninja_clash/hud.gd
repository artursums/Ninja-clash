# Minimal HUD: map name banner (mid-screen, fades after 2s) + the running match score.
# Per-player stash count is shown above each ninja's head (built in main.gd, owned by player).
# (The kill feed — "<clan> eliminated <clan>" — was removed; not wanted.)
#
# Score bar (top-centre): one pip row per fighter — ● rounds won / ○ still needed — in the
# fighter's clan colour, with a "FIRST TO N" caption. Mid-match a player must always know the
# tally and the goal without waiting for the match-end screen.

extends Control

const PIP_FULL := "●"
const PIP_EMPTY := "○"
const SCORE_Y := 4.0

var map_banner_label: Label
var _map_banner_clear_at: float = 0.0
var score_labels: Array = []   # one Label per fighter slot (rebuilt when the fighter count changes)
var score_caption: Label       # "FIRST TO N"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_right = 1.0
	anchor_bottom = 1.0
	_build_map_banner()
	_build_score_bar()
	Combat.score_changed.connect(_refresh_score)
	GameState.state_changed.connect(func(_s: int) -> void: _refresh_score())

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

# === Match score bar ==========================================================

func _build_score_bar() -> void:
	score_caption = Label.new()
	score_caption.position = Vector2(0, SCORE_Y)
	score_caption.size = Vector2(800, 14)
	score_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_caption.add_theme_font_size_override("font_size", 10)
	score_caption.add_theme_color_override("font_color", Color("8a8ea8"))
	score_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(score_caption)
	_refresh_score()

# Rebuild/update the per-fighter pip rows. Layout: all rows in one line centred under the
# caption — "P1 ●●○○○   P2 ●○○○○" (4 rows in the free-for-all).
func _refresh_score() -> void:
	if score_caption == null:
		return
	var n: int = GameState.num_players()
	while score_labels.size() < n:
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(lbl)
		score_labels.append(lbl)
	var target: int = maxi(GameState.target_score, 1)
	score_caption.text = "FIRST TO %d" % target
	var texts: Array = []
	var widths: Array = []
	var total_w: float = 0.0
	const CHAR_W := 8.0    # approx px per glyph at size 13 — good enough for centring
	const GAP := 26.0
	for slot in range(1, score_labels.size() + 1):
		var lbl: Label = score_labels[slot - 1]
		if slot > n:
			lbl.visible = false
			texts.append(""); widths.append(0.0)
			continue
		var won: int = Combat.scores.get(slot, 0)
		# Long targets stay compact: pips up to 9 rounds, plain "3/12" beyond.
		var body: String
		if target <= 9:
			body = PIP_FULL.repeat(mini(won, target)) + PIP_EMPTY.repeat(maxi(target - won, 0))
		else:
			body = "%d/%d" % [won, target]
		var txt: String = "P%d %s" % [slot, body]
		texts.append(txt)
		var w: float = txt.length() * CHAR_W
		widths.append(w)
		total_w += w + (GAP if slot < n else 0.0)
	var x: float = (800.0 - total_w) / 2.0
	for slot in range(1, n + 1):
		var lbl: Label = score_labels[slot - 1]
		lbl.visible = true
		lbl.text = texts[slot - 1]
		lbl.position = Vector2(x, SCORE_Y + 13.0)
		lbl.size = Vector2(widths[slot - 1] + 20.0, 16)
		lbl.add_theme_color_override("font_color", GameState.get_clan(slot).color)
		x += widths[slot - 1] + GAP
