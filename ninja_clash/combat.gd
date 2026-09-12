# Autoload: Combat
# Live-tunable parameters + per-slot score tracking. Round flow is driven by
# main.gd reacting to kill_logged (no more auto-respawn here).

extends Node

# === Live-tunable parameters (TuningPanel writes these) ===
var dodge_iframe_duration_s: float = 0.20
var shuriken_throw_velocity: float = 648.0   # 720 → 648 (−10%, the throw felt too fast); same for every character. Straight-down throws are exempt (they use DOWN_THROW_SPEED)
var pickup_radius_px: float = 12.0
var self_hit_immunity_s: float = 0.083
var wall_grab_fall_speed: float = 80.0

# === Katana clash (two blades meeting simultaneously) ===
# When both players land a katana swing on each other inside the same hit window,
# it is a CLASH, not a kill: lightning arcs between the blades, the whole scene
# freezes for a beat (action-movie hitstop), then time resumes and the fighters
# recoil a hair apart. None of these cost HP or katana charges.
var clash_freeze_duration_s: float = 0.20   # real-time hold while the lightning peaks
var clash_recoil_speed: float = 130.0       # px/s push-apart velocity on resume
var clash_recoil_duration_s: float = 0.12   # how long that velocity is held (~15 px of travel)
var clash_recoil_up: float = 0.0            # tiny upward pop on recoil (0 = pure horizontal)
var _clash_lock_until: float = 0.0          # de-dupe: both fighters detect the same clash

# === Match state === (up to 4 fighters for free-for-all)
var scores: Dictionary = {1: 0, 2: 0, 3: 0, 4: 0}
const STAT_KEYS := ["strikes", "throws", "hits", "blocks", "eliminations"]
var match_stats: Dictionary = {}

func record(slot: int, key: String) -> void:
	if slot < 1 or slot > 4 or not STAT_KEYS.has(key) or not GameState.is_round_active() or Net.is_client():
		return
	if not match_stats.has(slot):
		match_stats[slot] = {}
	match_stats[slot][key] = stat(slot, key) + 1

func stat(slot: int, key: String) -> int:
	return int(match_stats.get(slot, {}).get(key, 0))


# === Signals ===
signal score_changed
signal kill_logged(killer_slot: int, victim_slot: int)
# Emitted once per clash. main.gd spawns the FX, freezes time, and recoils both players.
signal clash_occurred(player_a: Node, player_b: Node, midpoint: Vector2)

# A fighter died. Scoring is decided at ROUND END (last ninja standing), so this just
# records the kill for the feed/FX and credits the ACTUAL killer (needed for free-for-all,
# where "the other player" is no longer well-defined).
func on_kill(victim_slot: int, killer_slot: int = 0) -> void:
	if killer_slot != victim_slot:
		record(killer_slot, "eliminations")
	if killer_slot < 1:
		killer_slot = victim_slot   # unknown source — keep the feed's clan lookup valid
	GameState.last_kill_killer = killer_slot
	GameState.last_kill_victim = victim_slot
	Audio.play("hit")
	kill_logged.emit(killer_slot, victim_slot)

# Last ninja standing takes the round.
func award_survivor(slot: int) -> void:
	scores[slot] = scores.get(slot, 0) + 1
	score_changed.emit()

func reset_scores() -> void:
	match_stats.clear()
	scores = {1: 0, 2: 0, 3: 0, 4: 0}
	emit_signal("score_changed")

# Called by BOTH fighters the instant their swings meet. The first call fires the
# clash; the second is swallowed by the short lock so the event happens exactly once.
# Always returns true so the caller knows to suppress its own strike damage.
func register_clash(a: Node, b: Node) -> bool:
	var t: float = Time.get_ticks_msec() / 1000.0
	if t < _clash_lock_until:
		return true   # already handled this clash — just cancel the damage
	_clash_lock_until = t + 0.45   # covers both fighters + the freeze window
	var midpoint: Vector2 = (a.global_position + b.global_position) * 0.5
	clash_occurred.emit(a, b, midpoint)
	return true
