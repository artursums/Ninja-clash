extends GutTest
const Clock := preload("res://round_clock.gd")
const Config := preload("res://match_config.gd")

func test_clock_expires_once_and_disabled_clock_never_expires() -> void:
	var clock = autofree(Clock.new())
	watch_signals(clock)
	clock.start(0)
	clock.advance(500)
	assert_signal_not_emitted(clock, "expired")
	clock.start(60)
	clock.advance(59.5)
	assert_eq(Clock.time_text(clock.remaining), "0:01")
	clock.advance(0.5)
	clock.advance(60)
	assert_signal_emit_count(clock, "expired", 1)
	assert_eq(clock.remaining, 0.0)

func test_client_clock_never_resolves_the_round() -> void:
	var clock = autofree(Clock.new())
	watch_signals(clock)
	clock.start(1)
	clock.advance(2, false)
	assert_signal_not_emitted(clock, "expired")
	var host = autofree(Clock.new())
	host.start_overtime()
	host.advance(1.5)
	clock.apply_snapshot(host.snapshot())
	assert_eq(clock.snapshot(), host.snapshot())
	assert_eq(Clock.time_text(clock.remaining), "0:19")

func test_config_defaults_and_persistence_include_round_time() -> void:
	var path := "user://test_round_time.cfg"
	var config = autofree(Config.new())
	assert_eq(config.round_time_seconds, 60)
	for seconds in [0,90,300]:
		config.round_time_seconds = seconds
		config.save_to(path)
		var restored = autofree(Config.new())
		restored.load_from(path)
		assert_eq(restored.round_time_seconds, seconds)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	assert_eq(Config.normalize_round_time(-20), 0)
	assert_eq(Config.normalize_round_time(5), 30)
	assert_eq(Config.normalize_round_time(9999), 300)
	config.capture_defaults()
	assert_eq(config.round_time_seconds, 60)
