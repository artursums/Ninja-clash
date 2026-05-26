class_name SettingsStore
extends Node
## Persists + applies player settings (audio, window) to user://settings.cfg. Registered as the
## `Settings` autoload: loads + applies on boot. Pure load/save/clamp is unit-tested; apply()
## drives AudioServer/DisplayServer (side effects) and is exercised at runtime.
##
## A settings MENU (to change these) is part of the menu/UI polish stream; this is the
## persistence + apply foundation it will bind to.

const DEFAULT_PATH := "user://settings.cfg"
const SECTION := "settings"

var master_volume: float = 1.0   ## 0..1 (linear)
var fullscreen: bool = false


func _ready() -> void:
	load_from(DEFAULT_PATH)
	apply()


# --- Mutators (clamp + apply + persist) ---

func set_master_volume(v: float) -> void:
	master_volume = clampf(v, 0.0, 1.0)
	apply()
	save_to(DEFAULT_PATH)


func set_fullscreen(on: bool) -> void:
	fullscreen = on
	apply()
	save_to(DEFAULT_PATH)


# --- Persistence (pure I/O — unit-tested with a temp path) ---

func load_from(path: String) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return   # no file yet → keep defaults
	master_volume = clampf(float(cfg.get_value(SECTION, "master_volume", master_volume)), 0.0, 1.0)
	fullscreen = bool(cfg.get_value(SECTION, "fullscreen", fullscreen))


func save_to(path: String) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, "master_volume", master_volume)
	cfg.set_value(SECTION, "fullscreen", fullscreen)
	cfg.save(path)


# --- Apply (side effects: audio bus + window mode) ---

func apply() -> void:
	var master_bus := 0
	if master_volume <= 0.0:
		AudioServer.set_bus_mute(master_bus, true)
	else:
		AudioServer.set_bus_mute(master_bus, false)
		AudioServer.set_bus_volume_db(master_bus, linear_to_db(master_volume))
	var win := get_window()
	if win != null:
		win.mode = Window.MODE_FULLSCREEN if fullscreen else Window.MODE_WINDOWED
