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
const MUSIC_BUS := "Music"   ## created by the Audio autoload; routes to Master
const SFX_BUS := "SFX"

var master_volume: float = 1.0   ## 0..1 (linear) — overall "sound" level (Master bus)
var music_volume: float = 1.0    ## 0..1 (linear) — Music bus
var sfx_volume: float = 1.0      ## 0..1 (linear) — SFX bus (effects)
var fullscreen: bool = false
var show_tutorial: bool = true   ## HOW TO PLAY overlay before each match's first countdown
var last_join_ip: String = ""    ## last address typed on the ONLINE join screen (convenience)


func _ready() -> void:
	load_from(DEFAULT_PATH)
	apply()


# --- Mutators (clamp + apply + persist) ---

func set_master_volume(v: float) -> void:
	master_volume = clampf(v, 0.0, 1.0)
	apply()
	save_to(DEFAULT_PATH)


func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	apply()
	save_to(DEFAULT_PATH)


func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	apply()
	save_to(DEFAULT_PATH)


func set_fullscreen(on: bool) -> void:
	fullscreen = on
	apply()
	save_to(DEFAULT_PATH)


func set_show_tutorial(on: bool) -> void:
	show_tutorial = on
	save_to(DEFAULT_PATH)   # no apply(): read directly by main.gd at match start


func set_last_join_ip(ip: String) -> void:
	last_join_ip = ip.strip_edges()
	save_to(DEFAULT_PATH)   # no apply(): read directly by the online menu


# --- Persistence (pure I/O — unit-tested with a temp path) ---

func load_from(path: String) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return   # no file yet → keep defaults
	master_volume = clampf(float(cfg.get_value(SECTION, "master_volume", master_volume)), 0.0, 1.0)
	music_volume = clampf(float(cfg.get_value(SECTION, "music_volume", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(cfg.get_value(SECTION, "sfx_volume", sfx_volume)), 0.0, 1.0)
	fullscreen = bool(cfg.get_value(SECTION, "fullscreen", fullscreen))
	show_tutorial = bool(cfg.get_value(SECTION, "show_tutorial", show_tutorial))
	last_join_ip = String(cfg.get_value(SECTION, "last_join_ip", last_join_ip))


func save_to(path: String) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, "master_volume", master_volume)
	cfg.set_value(SECTION, "music_volume", music_volume)
	cfg.set_value(SECTION, "sfx_volume", sfx_volume)
	cfg.set_value(SECTION, "fullscreen", fullscreen)
	cfg.set_value(SECTION, "show_tutorial", show_tutorial)
	cfg.set_value(SECTION, "last_join_ip", last_join_ip)
	cfg.save(path)


# --- Apply (side effects: audio bus + window mode) ---

func apply() -> void:
	_apply_bus("Master", master_volume)   # bus 0 always exists
	_apply_bus(MUSIC_BUS, music_volume)   # created by the Audio autoload (skipped if absent, e.g. in unit tests)
	_apply_bus(SFX_BUS, sfx_volume)
	var win := get_window()
	if win != null:
		win.mode = Window.MODE_FULLSCREEN if fullscreen else Window.MODE_WINDOWED


# Set a bus's linear volume (mute at 0). No-op if the bus doesn't exist yet — keeps apply() safe
# during boot ordering and in unit tests, where only the default Master bus is present.
func _apply_bus(bus_name: String, v: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	if v <= 0.0:
		AudioServer.set_bus_mute(idx, true)
	else:
		AudioServer.set_bus_mute(idx, false)
		AudioServer.set_bus_volume_db(idx, linear_to_db(v))
