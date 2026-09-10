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


# --- should_guard: block only when a throw is incoming, dodge is on cooldown, and meter is healthy ---

func test_bot_logic_guard_when_under_fire_and_dodge_on_cooldown() -> void:
	assert_true(BotLogicScript.should_guard(true, true, 1.0, 0.6), "incoming + no dodge + meter → block")


func test_bot_logic_no_guard_without_incoming() -> void:
	assert_false(BotLogicScript.should_guard(false, true, 1.0, 0.6), "nothing incoming → no block")


func test_bot_logic_no_guard_when_dodge_available() -> void:
	assert_false(BotLogicScript.should_guard(true, false, 1.0, 0.6), "dodge ready → prefer dodge over block")


func test_bot_logic_no_guard_on_low_meter() -> void:
	assert_false(BotLogicScript.should_guard(true, true, 0.3, 0.6), "meter below threshold → don't commit a block")


# --- pick_high_ground: nearest perch above BOTH the foe and us, else -1 (Y grows downward) ---

func test_bot_logic_high_ground_picks_nearest_perch_above_foe() -> void:
	var self_pos := Vector2(400, 400)
	var foe_pos := Vector2(300, 380)
	var platforms := [
		Rect2(Vector2(380, 90), Vector2(140, 12)),   # cx=450, above both — nearer (hd=50)
		Rect2(Vector2(180, 180), Vector2(160, 12)),  # cx=260, above both — farther (hd=140)
	]
	assert_eq(BotLogicScript.pick_high_ground(platforms, self_pos, foe_pos, 24.0), 0, "picks the nearer high perch")


func test_bot_logic_high_ground_none_when_no_perch_above_foe() -> void:
	var self_pos := Vector2(400, 400)
	var foe_pos := Vector2(300, 380)
	var platforms := [Rect2(Vector2(380, 390), Vector2(140, 12))]  # top=390, below the foe
	assert_eq(BotLogicScript.pick_high_ground(platforms, self_pos, foe_pos, 24.0), -1, "no perch above the foe → -1")


func test_bot_logic_high_ground_skips_perch_not_above_self() -> void:
	var self_pos := Vector2(400, 100)
	var foe_pos := Vector2(300, 380)
	var platforms := [Rect2(Vector2(380, 200), Vector2(140, 12))]  # above foe but below us → no height gain
	assert_eq(BotLogicScript.pick_high_ground(platforms, self_pos, foe_pos, 24.0), -1, "perch not above us → -1")
