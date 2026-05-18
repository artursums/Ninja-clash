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
	CLAN_SELECT,
	MAP_SELECT,
	MATCH_INTRO,
	ROUND,
	ROUND_END,
	MATCH_END,
}

# Clan registry — index = clan id. Colors aligned to pixel-art sprite palettes
# in sprites/ninjas/ (so HUD tile matches in-game ninja sprite).
const CLANS: Array = [
	{"name": "SHADOW", "color": Color("eb50af"), "secondary": Color("ffaad7"), "sprite": "magenta"},
	{"name": "STORM",  "color": Color("50d2e6"), "secondary": Color("aaf0fa"), "sprite": "cyan"},
	{"name": "FROST",  "color": Color("8cdc64"), "secondary": Color("c3f5a5"), "sprite": "green"},
	{"name": "FIRE",   "color": Color("ff9132"), "secondary": Color("ffc382"), "sprite": "orange"},
]

var current_state: int = State.TITLE
var p1_clan: int = 3   # default Fire
var p2_clan: int = 1   # default Storm
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
	var idx: int = p1_clan if slot == 1 else p2_clan
	return CLANS[idx]

func is_round_active() -> bool:
	return current_state == State.ROUND

func start_new_match() -> void:
	current_round = 1
	match_winner_slot = 0
	Combat.reset_scores()
	change_state(State.MATCH_INTRO)

func advance_round_or_end_match() -> void:
	var p1_score: int = Combat.scores.get(1, 0)
	var p2_score: int = Combat.scores.get(2, 0)
	if p1_score >= target_score:
		match_winner_slot = 1
		change_state(State.MATCH_END)
	elif p2_score >= target_score:
		match_winner_slot = 2
		change_state(State.MATCH_END)
	else:
		current_round += 1
		change_state(State.MATCH_INTRO)
