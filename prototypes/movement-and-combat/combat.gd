# PROTOTYPE - NOT FOR PRODUCTION
# Question: Does the throw-dodge-retrieve loop with 1-hit-kill feel fun in 2P local?
# Date: 2026-05-18
#
# Autoload: Combat
# Live-tunable parameters + per-slot score tracking. Round flow is driven by
# main.gd reacting to kill_logged (no more auto-respawn here).

extends Node

# === Live-tunable parameters (TuningPanel writes these) ===
var dodge_iframe_duration_s: float = 0.20
var shuriken_throw_velocity: float = 600.0
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

# === Match state ===
var scores: Dictionary = {1: 0, 2: 0}

# === Signals ===
signal score_changed
signal kill_logged(killer_slot: int, victim_slot: int)
# Emitted once per clash. main.gd spawns the FX, freezes time, and recoils both players.
signal clash_occurred(player_a: Node, player_b: Node, midpoint: Vector2)

func on_kill(victim_slot: int) -> void:
	var winner_slot: int = 2 if victim_slot == 1 else 1
	scores[winner_slot] = scores.get(winner_slot, 0) + 1
	GameState.last_kill_killer = winner_slot
	GameState.last_kill_victim = victim_slot
	Audio.play("hit")
	kill_logged.emit(winner_slot, victim_slot)
	score_changed.emit()

func reset_scores() -> void:
	scores = {1: 0, 2: 0}
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
