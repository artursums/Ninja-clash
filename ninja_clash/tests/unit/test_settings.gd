extends GutTest
## Tests for SettingsStore persistence (settings_store.gd) — save/load round-trip, defaults on a
## missing file, and clamp-on-load. Uses a temp path so the real user://settings.cfg is untouched;
## apply() (AudioServer/window side effects) is exercised at runtime, not here.

const SettingsScript := preload("res://settings_store.gd")

var _path: String = "user://test_settings_%d.cfg" % (randi() % 100000)


func after_each() -> void:
	if FileAccess.file_exists(_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_path))


func test_save_load_roundtrip() -> void:
	var s = autofree(SettingsScript.new())
	s.master_volume = 0.4
	s.fullscreen = true
	s.save_to(_path)
	var s2 = autofree(SettingsScript.new())
	s2.load_from(_path)
	assert_almost_eq(s2.master_volume, 0.4, 0.001)
	assert_true(s2.fullscreen)


func test_load_missing_file_keeps_defaults() -> void:
	var s = autofree(SettingsScript.new())
	s.load_from("user://nope_%d.cfg" % (randi() % 100000))
	assert_almost_eq(s.master_volume, 1.0, 0.001)
	assert_false(s.fullscreen)


func test_load_clamps_out_of_range_volume() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("settings", "master_volume", 5.0)   # out of range
	cfg.save(_path)
	var s = autofree(SettingsScript.new())
	s.load_from(_path)
	assert_almost_eq(s.master_volume, 1.0, 0.001, "volume clamped to [0,1] on load")
