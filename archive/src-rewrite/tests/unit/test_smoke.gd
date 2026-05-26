extends GutTest
## Smoke test — proves the production project + GUT harness run headless.
## Real per-system suites join this from Sprint 1 / T4 (Game State Manager) onward.


func test_arithmetic_sanity() -> void:
	assert_eq(2 + 2, 4, "GUT is executing assertions")


func test_running_on_godot_4_6_plus() -> void:
	var info: Dictionary = Engine.get_version_info()
	assert_true(
		info.major == 4 and info.minor >= 6,
		"production project targets Godot 4.6+ (got %d.%d)" % [info.major, info.minor]
	)
