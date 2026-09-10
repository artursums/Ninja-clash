extends GutTest

const AmbienceScript := preload("res://verdant_cistern_ambience.gd")


func test_verdant_cistern_ambience_instantiates() -> void:
	var ambience: Node2D = autofree(AmbienceScript.new())
	add_child(ambience)
	await wait_process_frames(1)
	assert_eq(ambience.z_index, -6)
