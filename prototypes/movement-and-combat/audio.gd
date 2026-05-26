# PROTOTYPE - NOT FOR PRODUCTION
# Date: 2026-05-18
#
# Autoload: Audio
# Procedural beep SFX generated at startup via AudioStreamWAV. No audio assets shipped.
# Crude but lets the prototype simulate sound feedback for testing the full match loop.

extends Node

const SAMPLE_RATE := 22050

var _streams: Dictionary = {}

func _ready() -> void:
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
	p.bus = "Master"
	add_child(p)
	p.play()
	p.finished.connect(func() -> void: p.queue_free())

func play_win_fanfare() -> void:
	play("win_1")
	await get_tree().create_timer(0.18).timeout
	play("win_2")
	await get_tree().create_timer(0.18).timeout
	play("win_3")
