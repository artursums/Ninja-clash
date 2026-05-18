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

# === Match state ===
var scores: Dictionary = {1: 0, 2: 0}

# === Signals ===
signal score_changed
signal kill_logged(killer_slot: int, victim_slot: int)

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
