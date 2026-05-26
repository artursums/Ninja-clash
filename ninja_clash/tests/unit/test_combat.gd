extends GutTest
## Tests for the Combat autoload's pure logic: per-slot scoring + the live-tunable defaults.
## (on_kill / register_clash touch other autoloads + nodes — those need the real-scene integration
## approach, a noted follow-up. These cover the parts that are cleanly unit-testable.)

const CombatScript := preload("res://combat.gd")


func test_award_survivor_increments_that_slot() -> void:
	var c = autofree(CombatScript.new())   # untyped: combat.gd has no class_name
	c.award_survivor(1)
	assert_eq(c.scores[1], 1)
	c.award_survivor(1)
	assert_eq(c.scores[1], 2)


func test_award_survivor_is_per_slot() -> void:
	var c = autofree(CombatScript.new())   # untyped: combat.gd has no class_name
	c.award_survivor(2)
	assert_eq(c.scores[2], 1)
	assert_eq(c.scores[1], 0, "other slots unaffected")


func test_award_survivor_emits_score_changed() -> void:
	var c = autofree(CombatScript.new())   # untyped: combat.gd has no class_name
	watch_signals(c)
	c.award_survivor(3)
	assert_signal_emitted(c, "score_changed")


func test_reset_scores_zeroes_all_slots() -> void:
	var c = autofree(CombatScript.new())   # untyped: combat.gd has no class_name
	c.award_survivor(1)
	c.award_survivor(2)
	c.reset_scores()
	assert_eq(c.scores, {1: 0, 2: 0, 3: 0, 4: 0})


func test_default_tunables_match_validated_values() -> void:
	var c = autofree(CombatScript.new())   # untyped: combat.gd has no class_name
	assert_almost_eq(c.dodge_iframe_duration_s, 0.20, 0.0001, "the project's single key balance lever")
	assert_almost_eq(c.shuriken_throw_velocity, 648.0, 0.001)
	assert_almost_eq(c.pickup_radius_px, 12.0, 0.001)
	assert_almost_eq(c.self_hit_immunity_s, 0.083, 0.0001)
