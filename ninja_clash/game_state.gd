# PROTOTYPE - NOT FOR PRODUCTION
# Question: Does the throw-dodge-retrieve loop with 1-hit-kill feel fun in 2P local?
# Date: 2026-05-18
#
# Autoload: GameState
# Screen state machine + clan selections + match progress. Reactive systems
# (HUD, arena, screens) subscribe to state_changed.

extends Node

enum State {
	TITLE,
	MODE_SELECT,
	CLAN_SELECT,
	MAP_SELECT,
	MATCH_INTRO,
	ROUND,
	ROUND_END,
	MATCH_END,
	MATCH_SETUP,   # Fight Setup / Variants screen (opened from clan select); appended so enum values don't shift
}

# Who controls each fighter this match. FFA = P1 (human) vs three bots, free-for-all.
enum Mode { HUMAN_VS_HUMAN, HUMAN_VS_AI, AI_VS_AI, FFA }

# AI skill tier — named after ninja ranks. GENIN (1) is already a competent fighter;
# CHUNIN (2) is hard; JONIN (3) is brutal.
const DIFFICULTY_NAMES: Array = ["", "GENIN", "CHUNIN", "JONIN"]

# Clan registry — index = clan id. Colors aligned to pixel-art sprite palettes
# in sprites/ninjas/ (so HUD tile matches in-game ninja sprite).
const CLANS: Array = [
	{"name": "SHADOW", "color": Color("eb50af"), "secondary": Color("ffaad7"), "sprite": "magenta"},
	{"name": "STORM",  "color": Color("50d2e6"), "secondary": Color("aaf0fa"), "sprite": "cyan"},
	{"name": "FROST",  "color": Color("8cdc64"), "secondary": Color("c3f5a5"), "sprite": "green"},
	{"name": "FIRE",   "color": Color("ff9132"), "secondary": Color("ffc382"), "sprite": "orange"},
]

# Skins — an appearance STYLE layered on top of a clan's COLOUR. "base" is the classic
# ninja; "elemental" is the colour's alternate elemental look; the rest are costume sets.
# Every style resolves to a valid sprite for any of the four clan colours.
const SKIN_STYLES: Array = ["base", "elemental", "ronin", "chef", "cyber", "edo", "office", "pirate", "vacation", "pig", "endobot", "neko", "stalker", "ironclad", "bakeneko"]
const SKIN_LABELS: Array = ["CLASSIC", "ELEMENTAL", "RONIN", "CHEF", "CYBER", "EDO", "OFFICE", "PIRATE", "VACATION", "PIGGY", "ENDOBOT", "NEKO", "STALKER", "IRONCLAD", "BAKENEKO"]
const ELEMENTAL_BY_COLOR := {"magenta": "wraith", "cyan": "tempest", "green": "glacier", "orange": "inferno"}

# Costume styles that ship the full richer animation set (6-frame idle/walk/swing
# alongside the 5-pose sheet), stored under costumes/<style>/<color>_*.png.
const RICH_SKINS: Array = ["pig", "endobot", "neko", "stalker", "ironclad", "bakeneko"]

var current_state: int = State.TITLE
var game_mode: int = Mode.HUMAN_VS_HUMAN
var ai_difficulty: int = 1   # 1=GENIN, 2=CHUNIN, 3=JONIN
var p1_clan: int = 3   # default Fire
var p2_clan: int = 1   # default Storm
var p3_clan: int = 2   # FFA bot — default Frost
var p4_clan: int = 0   # FFA bot — default Shadow
var p1_skin: int = 0   # skin STYLE index (into SKIN_STYLES); humans cycle theirs in clan select
var p2_skin: int = 0
var p3_skin: int = 0   # FFA/AI bots stay Classic
var p4_skin: int = 0
var selected_map_index: int = 0
var current_round: int = 1
var target_score: int = 5
var match_winner_slot: int = 0
var last_kill_killer: int = 0
var last_kill_victim: int = 0

signal state_changed(new_state: int)

func change_state(s: int) -> void:
	current_state = s
	print("[STATE] -> ", State.keys()[s])
	state_changed.emit(s)

func get_clan(slot: int) -> Dictionary:
	return CLANS[clan_index(slot)]

func clan_index(slot: int) -> int:
	match slot:
		1: return p1_clan
		2: return p2_clan
		3: return p3_clan
		_: return p4_clan

func skin_count() -> int:
	return SKIN_STYLES.size()

func skin_index(slot: int) -> int:
	match slot:
		1: return p1_skin
		2: return p2_skin
		3: return p3_skin
		_: return p4_skin

func skin_label(style_idx: int) -> String:
	return String(SKIN_LABELS[style_idx % SKIN_LABELS.size()])

# Pose sheet (80×16, 5 frames) for a clan colour + skin style.
func skin_pose_path(color: String, style_idx: int) -> String:
	var style: String = String(SKIN_STYLES[style_idx % SKIN_STYLES.size()])
	if style == "base":
		return "res://sprites/ninjas/ninja_%s_native_80x16.png" % color
	if style == "elemental":
		return "res://sprites/ninjas/ninja_%s_%s_native_80x16.png" % [color, ELEMENTAL_BY_COLOR.get(color, "")]
	return "res://sprites/ninjas/costumes/%s/%s_native_80x16.png" % [style, color]

# Resolves a 96×16 6-frame animation sheet (tag = "idle"/"walk"/"swing") for the
# style, or "" if the style has none (player then falls back to its pose frames).
func _skin_anim_path(color: String, style_idx: int, tag: String) -> String:
	var style: String = String(SKIN_STYLES[style_idx % SKIN_STYLES.size()])
	if style == "base":
		return "res://sprites/ninjas/ninja_%s_%s_6frame_native_96x16.png" % [color, tag]
	if style in RICH_SKINS:
		return "res://sprites/ninjas/costumes/%s/%s_%s_6frame_native_96x16.png" % [style, color, tag]
	return ""

# Idle sheet (96×16, 6 frames) — "" = none (player falls back to the pose idle).
func skin_idle_path(color: String, style_idx: int) -> String:
	return _skin_anim_path(color, style_idx, "idle")

# Walk sheet (96×16, 6 frames) — richer run cycle. "" = none (player falls back to the 2-frame pose walk).
func skin_walk_path(color: String, style_idx: int) -> String:
	return _skin_anim_path(color, style_idx, "walk")

# Swing sheet (96×16, 6 frames) — full katana-slash body animation. "" = none (player falls back to the pose attack frame).
func skin_swing_path(color: String, style_idx: int) -> String:
	return _skin_anim_path(color, style_idx, "swing")

# 2 for the duel modes, 4 for the free-for-all.
func num_players() -> int:
	return 4 if game_mode == Mode.FFA else 2

# True for fighters the computer controls this match.
func slot_is_bot(slot: int) -> bool:
	match game_mode:
		Mode.HUMAN_VS_AI: return slot == 2
		Mode.AI_VS_AI:    return true
		Mode.FFA:         return slot != 1   # P1 is human, the other three are bots
		_:                return false       # HUMAN_VS_HUMAN

# FFA: P1 keeps their pick; the three bots take the remaining clans in order.
func assign_ffa_clans() -> void:
	var rest: Array = []
	for i in CLANS.size():
		if i != p1_clan:
			rest.append(i)
	p2_clan = rest[0]
	p3_clan = rest[1]
	p4_clan = rest[2]

func is_round_active() -> bool:
	return current_state == State.ROUND

# Which fighters are AI-controlled this match (P1 is the human side in HUMAN_VS_AI).
func p1_is_bot() -> bool:
	return game_mode == Mode.AI_VS_AI

func p2_is_bot() -> bool:
	return game_mode == Mode.HUMAN_VS_AI or game_mode == Mode.AI_VS_AI

func start_new_match() -> void:
	current_round = 1
	match_winner_slot = 0
	Combat.reset_scores()
	change_state(State.MATCH_INTRO)

func advance_round_or_end_match() -> void:
	for slot in range(1, num_players() + 1):
		if Combat.scores.get(slot, 0) >= target_score:
			match_winner_slot = slot
			change_state(State.MATCH_END)
			return
	current_round += 1
	change_state(State.MATCH_INTRO)
