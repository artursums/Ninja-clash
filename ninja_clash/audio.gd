# PROTOTYPE - NOT FOR PRODUCTION
# Date: 2026-05-18
#
# Autoload: Audio
# Procedural beep SFX generated at startup via AudioStreamWAV. No audio assets shipped.
# Crude but lets the prototype simulate sound feedback for testing the full match loop.

extends Node

const SAMPLE_RATE := 22050
const SFX_DIR := "res://audio/sfx/"   # drop real <key>.ogg/.wav here to replace the beeps
const MENU_MUSIC_PATH := "res://audio/start-menu/Ninja Kintsugi.mp3"
const MATCH_MUSIC_PATH := "res://audio/gameplay/Steel Lanterns.mp3"   # starts after the countdown
const MUSIC_BUS := "Music"   # both buses route to Master; Settings drives their levels independently
const SFX_BUS := "SFX"

var _streams: Dictionary = {}
var _music_player: AudioStreamPlayer = null
var _current_music_path: String = ""

func _ready() -> void:
	# Keep music + menu SFX audible while the tree is paused (the pause overlay relies on this).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()   # before any player is routed, so bus names resolve
	_build_streams()
	_load_real_sfx_overrides()   # a real file at res://audio/sfx/<key>.ogg|wav replaces its beep
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = MUSIC_BUS   # follows the Settings music volume
	add_child(_music_player)
	# GameState is also an autoload; hook deferred so it's ready regardless of autoload order.
	call_deferred("_hook_game_state")

# Create the Music + SFX buses (each sending to Master) if they don't already exist, so the
# Settings menu can control music and effects volume independently. No bus layout asset needed.
func _ensure_buses() -> void:
	_ensure_bus(MUSIC_BUS)
	_ensure_bus(SFX_BUS)

func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	var idx: int = AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")

# Procedural placeholder SFX. Each key can be overridden by a real audio file (see _load_real_sfx_overrides).
func _build_streams() -> void:
	_streams["throw"] = _make_beep(880.0, 0.06, "sine", 0.3)
	_streams["hit"] = _make_beep(120.0, 0.18, "square", 0.4)
	_streams["dodge"] = _make_beep(440.0, 0.08, "sine", 0.25)
	_streams["block"] = _make_beep(1320.0, 0.05, "square", 0.3)   # bright metallic clink — blade parry
	_streams["round_start"] = _make_beep(660.0, 0.20, "sine", 0.35)
	_streams["countdown"] = _make_beep(440.0, 0.10, "square", 0.25)
	_streams["click"] = _make_beep(1000.0, 0.04, "square", 0.2)
	_streams["confirm"] = _make_beep(880.0, 0.12, "sine", 0.3)
	_streams["win_1"] = _make_beep(523.0, 0.18, "sine", 0.35)
	_streams["win_2"] = _make_beep(659.0, 0.18, "sine", 0.35)
	_streams["win_3"] = _make_beep(784.0, 0.35, "sine", 0.4)

# Upgrade path to real audio: if res://audio/sfx/<key>.ogg (or .wav) exists, use it instead of the
# generated beep — so the owner can drop in finished SFX with zero code changes.
func _load_real_sfx_overrides() -> void:
	for key in _streams.keys():
		for ext in ["ogg", "wav"]:
			var path: String = SFX_DIR + String(key) + "." + ext
			if ResourceLoader.exists(path):
				var s = load(path)
				if s is AudioStream:
					_streams[key] = s
				break

func _make_beep(freq: float, duration: float, wave: String, vol: float) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	var num_samples: int = int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(num_samples * 2)
	for i in num_samples:
		var t: float = float(i) / SAMPLE_RATE
		var env: float = 1.0 - (t / duration) * 0.85
		var sample: float
		match wave:
			"square":
				sample = (1.0 if sin(t * freq * TAU) > 0.0 else -1.0)
			_:
				sample = sin(t * freq * TAU)
		var s: int = int(clamp(sample * env * vol * 32767.0, -32768.0, 32767.0))
		data[i * 2] = s & 0xff
		data[i * 2 + 1] = (s >> 8) & 0xff
	stream.data = data
	return stream

func play(snd_name: String) -> void:
	if not _streams.has(snd_name):
		return
	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	p.stream = _streams[snd_name]
	p.bus = SFX_BUS   # follows the Settings effects volume
	add_child(p)
	p.play()
	p.finished.connect(func() -> void: p.queue_free())

func play_win_fanfare() -> void:
	play("win_1")
	await get_tree().create_timer(0.18).timeout
	play("win_2")
	await get_tree().create_timer(0.18).timeout
	play("win_3")


# === Background music ===

# Connect to GameState and apply music for the current screen. Deferred from _ready so the
# GameState autoload exists regardless of autoload order.
func _hook_game_state() -> void:
	if GameState != null and GameState.has_signal("state_changed"):
		GameState.state_changed.connect(_on_state_changed)
		_on_state_changed(GameState.current_state)   # start music for the boot state (TITLE)


# Music per screen:
#   • Menu screens (incl. the Match-End results) loop the menu track.
#   • The fight (ROUND / ROUND_END) plays the gameplay track — which therefore starts only AFTER
#     the countdown, since the countdown is MATCH_INTRO.
#   • MATCH_INTRO (the 3·2·1·FIGHT countdown) drops the menu loop so the count plays over tension;
#     but if the gameplay track is already going (a between-round countdown) it keeps playing.
# play_music is a no-op when the track is unchanged, so moving between screens never restarts it.
func _on_state_changed(new_state: int) -> void:
	var menu_states := [
		GameState.State.TITLE, GameState.State.MODE_SELECT,
		GameState.State.CLAN_SELECT, GameState.State.MAP_SELECT,
		GameState.State.MATCH_END,
	]
	var fight_states := [GameState.State.ROUND, GameState.State.ROUND_END]
	if new_state in menu_states:
		play_music(MENU_MUSIC_PATH)
	elif new_state in fight_states:
		play_music(_match_music_path())
	elif new_state == GameState.State.MATCH_INTRO:
		if _current_music_path == MENU_MUSIC_PATH:
			stop_music()   # silence under the first countdown; a between-round track keeps playing


# Resolve the fight track for the selected map: a map's "music" field overrides the default
# MATCH_MUSIC_PATH, so e.g. Neo Tokyo plays its own neon track. Falls back to the default.
func _match_music_path() -> String:
	var map: Dictionary = Maps.get_map(GameState.selected_map_index)
	var track: String = map.get("music", "")
	return track if not track.is_empty() else MATCH_MUSIC_PATH


# Play a looping music track. No-op if it's already the playing track (so menu-screen changes
# don't restart it). An empty path stops the music.
func play_music(path: String, loop: bool = true) -> void:
	if path.is_empty():
		stop_music()
		return
	if path == _current_music_path and _music_player.playing:
		return
	if not ResourceLoader.exists(path):
		push_warning("Audio: music not found: %s" % path)
		return
	var stream: AudioStream = load(path)
	if stream == null:
		return
	if "loop" in stream:
		stream.loop = loop   # AudioStreamMP3 / OggVorbis loop the whole file
	_music_player.stream = stream
	_current_music_path = path
	_music_player.play()


func stop_music() -> void:
	if _music_player != null:
		_music_player.stop()
	_current_music_path = ""
