extends GutTest
## Regression guard for the SFX set: every sound key the game plays must exist as a stream.
## (Catches an accidental removal. The real-file override path is exercised at runtime.)

const AudioScript := preload("res://audio.gd")

const EXPECTED_KEYS := [
	"throw", "hit", "dodge", "block", "round_start",
	"countdown", "click", "confirm", "win_1", "win_2", "win_3",
]


func test_build_streams_has_every_expected_sfx() -> void:
	var a = autofree(AudioScript.new())   # untyped: audio.gd has no class_name
	a._build_streams()
	for key in EXPECTED_KEYS:
		assert_true(a._streams.has(key), "SFX key present: %s" % key)
		assert_true(a._streams[key] is AudioStream, "%s resolves to an AudioStream" % key)
