# PROTOTYPE - NOT FOR PRODUCTION
# Question: Does the throw-dodge-retrieve loop with 1-hit-kill feel fun in 2P local?
# Date: 2026-05-18
#
# Autoload singleton: Combat
# Holds live-tunable parameters + match score + respawn coordination.
# Players + shurikens read these vars directly (no per-instance copies).

extends Node

# === Live-tunable parameters (TuningPanel writes these) ===
var dodge_iframe_duration_s: float = 0.20  # THE LEVER (concept "single most consequential balance lever")
var shuriken_throw_velocity: float = 200.0  # NAMED lever (concept: "reaction time required to dodge")
var pickup_radius_px: float = 12.0          # Retrieval feel
var self_hit_immunity_s: float = 0.083      # Spawn-throw self-hit window

# === Match state ===
var scores: Dictionary = {1: 0, 2: 0}

# === Signals ===
signal score_changed
signal respawn_requested(slot: int)

const RESPAWN_DELAY_S := 2.0

func on_kill(victim_slot: int) -> void:
	var winner_slot: int = 2 if victim_slot == 1 else 1
	scores[winner_slot] = scores.get(winner_slot, 0) + 1
	emit_signal("score_changed")
	# Respawn both players after a brief delay (prototype simplification — full Round Flow not needed)
	get_tree().create_timer(RESPAWN_DELAY_S).timeout.connect(_respawn_both)

func _respawn_both() -> void:
	for slot in [1, 2]:
		emit_signal("respawn_requested", slot)

func reset_scores() -> void:
	scores = {1: 0, 2: 0}
	emit_signal("score_changed")
