extends GutTest
## Tests for BotLogic.should_stomp (bot_logic.gd) — the last-resort head-stomp gate. The bot may only
## go for a head-stomp when fully disarmed (no shurikens, no katana charges) AND has no loose blade
## worth scavenging. Pure static logic, so it tests in isolation with no scene tree or autoloads.

const BotLogicScript := preload("res://bot_logic.gd")


func test_bot_logic_stomp_allowed_when_fully_disarmed_and_no_blade() -> void:
	assert_true(BotLogicScript.should_stomp(0, 0, false), "disarmed + no loose blade → stomp is the last resort")


func test_bot_logic_no_stomp_while_holding_shurikens() -> void:
	assert_false(BotLogicScript.should_stomp(2, 0, false), "has shurikens → never aim for the head")


func test_bot_logic_no_stomp_while_holding_a_katana_charge() -> void:
	assert_false(BotLogicScript.should_stomp(0, 1, false), "has a katana charge → never aim for the head")


func test_bot_logic_no_stomp_when_a_blade_is_scavengeable() -> void:
	assert_false(BotLogicScript.should_stomp(0, 0, true), "a reachable loose blade → re-arm instead of stomping")


func test_bot_logic_no_stomp_when_fully_stocked() -> void:
	assert_false(BotLogicScript.should_stomp(3, 3, true), "fully stocked → never stomp")


func test_aim_uses_nearest_octant_instead_of_diagonal_for_every_height_difference() -> void:
	assert_eq(BotLogicScript.aim_octant(Vector2(300, 40)), Vector2.RIGHT)
	assert_eq(BotLogicScript.aim_octant(Vector2(40, -300)), Vector2.UP)
	assert_eq(BotLogicScript.aim_octant(Vector2(-150, 150)), Vector2(-1, 1))

func test_threat_prediction_rejects_near_misses_and_departing_blades() -> void:
	assert_eq(BotLogicScript.impact_time(Vector2(100, 80), Vector2(-200, 0)), INF)
	assert_eq(BotLogicScript.impact_time(Vector2(100, 0), Vector2(200, 0)), INF)
	assert_almost_eq(BotLogicScript.impact_time(Vector2(100, 0), Vector2(-200, 0)), 0.5, 0.001)

func test_bot_tiers_keep_reaction_and_attack_windows_beatable() -> void:
	var tuning = load("res://bot_tuning.tres")
	for tier in 3:
		assert_gt(tuning.reaction_s[tier], 0.1)
		assert_gt(tuning.throw_cd[tier], 0.5)
		assert_lt(tuning.dodge_chance[tier], 0.9)
		assert_gt(tuning.plan_min_s[tier], tuning.perception_s[tier])
