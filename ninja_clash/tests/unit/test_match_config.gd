extends GutTest
## Tests for MatchConfig persistence (match_config.gd) — save/load round-trip, defaults on a missing
## file, clamp-on-load, and the key invariant that an untouched config reproduces the standard
## loadout (HP / katana charges / start shurikens read from PlayerTuning). Uses a temp path so the
## real user://match_config.cfg is untouched. The instances live outside the scene tree, so the
## GameState-coupled bits (target_score apply) are no-ops here and exercised at runtime instead.

const MatchConfigScript := preload("res://match_config.gd")
const TuningScript := preload("res://player_tuning.gd")
const TUNING_PATH := "res://player_tuning.tres"

var _path: String = "user://test_match_config_%d.cfg" % (randi() % 100000)


func after_each() -> void:
	if FileAccess.file_exists(_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_path))


func test_match_config_save_load_roundtrip() -> void:
	# Arrange
	var c = autofree(MatchConfigScript.new())
	c.katana_enabled = false
	c.katana_recharge = false
	c.katana_charges = 1
	c.shurikens_enabled = false
	c.start_shurikens = 2
	c.infinite_shurikens = true
	c.max_hp = 7
	c.target_score = 9
	# Act
	c.save_to(_path)
	var c2 = autofree(MatchConfigScript.new())
	c2.load_from(_path)
	# Assert
	assert_false(c2.katana_enabled)
	assert_false(c2.katana_recharge)
	assert_eq(c2.katana_charges, 1)
	assert_false(c2.shurikens_enabled)
	assert_eq(c2.start_shurikens, 2)
	assert_true(c2.infinite_shurikens)
	assert_eq(c2.max_hp, 7)
	assert_eq(c2.target_score, 9)


func test_match_config_load_missing_file_keeps_defaults() -> void:
	# Arrange / Act
	var c = autofree(MatchConfigScript.new())
	c.load_from("user://nope_%d.cfg" % (randi() % 100000))
	# Assert — field-initializer defaults are the standard ruleset
	assert_true(c.katana_enabled)
	assert_true(c.katana_recharge)
	assert_false(c.infinite_shurikens)
	assert_true(c.shurikens_enabled)


func test_match_config_load_clamps_out_of_range() -> void:
	# Arrange — write values outside the allowed ranges
	var cfg := ConfigFile.new()
	cfg.set_value("match_config", "katana_charges", 99)     # over MAX_KATANA_CHARGES
	cfg.set_value("match_config", "start_shurikens", 99)    # over STASH_CAP
	cfg.set_value("match_config", "max_hp", 0)              # under min (1)
	cfg.set_value("match_config", "target_score", 999)      # over MAX_TARGET_SCORE
	cfg.save(_path)
	# Act
	var c = autofree(MatchConfigScript.new())
	c.load_from(_path)
	# Assert
	assert_eq(c.katana_charges, MatchConfigScript.MAX_KATANA_CHARGES, "katana charges clamped on load")
	assert_eq(c.start_shurikens, MatchConfigScript.STASH_CAP, "start shurikens clamped to stash cap")
	assert_eq(c.max_hp, 1, "max hp clamped to min on load")
	assert_eq(c.target_score, MatchConfigScript.MAX_TARGET_SCORE, "target score clamped on load")


func test_match_config_defaults_match_current_loadout() -> void:
	# Arrange — the tuning resource is the source of truth for the standard loadout
	var tuning = load(TUNING_PATH)
	# Act — capture data-driven defaults (as the autoload does on boot)
	var c = autofree(MatchConfigScript.new())
	c.capture_defaults()
	# Assert — an untouched config equals today's behaviour
	assert_eq(c.max_hp, int(tuning.max_hp), "default HP comes from PlayerTuning")
	assert_eq(c.katana_charges, int(tuning.max_katana), "default katana charges come from PlayerTuning")
	assert_eq(c.start_shurikens, int(tuning.start_shurikens), "default start shurikens come from PlayerTuning")
	assert_true(c.katana_enabled, "katana on by default")
	assert_true(c.katana_recharge, "per-round recharge by default")
	assert_true(c.shurikens_enabled, "shurikens on by default")
	assert_false(c.infinite_shurikens, "finite shurikens by default")
	assert_eq(c.effective_start_shurikens(), int(tuning.start_shurikens), "effective start = start when enabled")
	assert_eq(c.effective_katana_charges(), int(tuning.max_katana), "effective charges = charges when enabled")
