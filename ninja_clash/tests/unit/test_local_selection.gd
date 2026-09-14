extends GutTest

const Selection := preload("res://local_selection.gd")
const Bindings := preload("res://input_bindings.gd")

func test_each_local_party_size_requires_every_player() -> void:
	for count in range(1, 5):
		var selection := Selection.new()
		selection.configure(range(count))
		for index in count:
			assert_false(selection.all_ready())
			assert_true(selection.toggle_ready(index))
		assert_true(selection.all_ready())

func test_clan_reservations_can_be_released() -> void:
	var selection := Selection.new()
	selection.configure([0, 0, 2, 3])
	assert_true(selection.toggle_ready(0))
	assert_false(selection.choose(0, 1))
	assert_false(selection.toggle_ready(1))
	assert_true(selection.toggle_ready(0))
	assert_true(selection.toggle_ready(1))
	assert_true(selection.choose(0, -1))
	assert_eq(selection.clans[0], 3)
	assert_eq(selection.next_unready(0), 2)
	selection.configure([2, 1])
	assert_eq(selection.ready, [false, false])
	assert_false(selection.toggle_ready(3))

func test_controllers_fill_slots_after_keyboard_players() -> void:
	assert_eq(Bindings.controller_slots(2, 0), [])
	assert_eq(Bindings.controller_slots(2, 1), [2])
	assert_eq(Bindings.controller_slots(3, 1), [3])
	assert_eq(Bindings.controller_slots(3, 2), [2, 3])
	assert_eq(Bindings.controller_slots(4, 2), [3, 4])
	assert_eq(Bindings.controller_slots(4, 3), [2, 3, 4])
	assert_eq(Bindings.controller_slots(4, 4), [1, 2, 3, 4])
	assert_eq(Bindings.controller_slots(1, 1), [1])
