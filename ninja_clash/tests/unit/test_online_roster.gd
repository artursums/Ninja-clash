extends GutTest
const Roster = preload("res://online_roster.gd")

func test_names_are_required_trimmed_and_bounded() -> void:
	var roster = Roster.new()
	assert_false(roster.add(1, "   "))
	assert_false(roster.add(1, "\n\t\u200b"))
	assert_true(roster.add(1, "  Mari Õun  "))
	assert_eq(roster.member(1).name, "Mari Õun")
	assert_eq(Roster.clean_name("abcdefghijklmnopq"), "abcdefghijklmnop")
	assert_eq(Roster.clean_name("a\u202eb"), "ab")

func test_two_three_and_four_humans_can_start_but_never_one_or_five() -> void:
	for count in [2, 3, 4]:
		var roster = Roster.new()
		assert_true(roster.add(1, "Host"))
		assert_false(roster.can_start())
		for id in range(2, count + 1):
			assert_true(roster.add(id, "Guest %d" % id))
		for player in roster.members:
			assert_eq(roster.pick(player.peer, player.clan, 0, true, 0, 15), "")
		assert_true(roster.can_start())
		roster.locked = true
		assert_false(roster.add(10, "Late"))
		assert_false(roster.can_start())
	var full = Roster.new()
	for id in range(1, 5):
		full.add(id, str(id))
	assert_false(full.add(5, "Fifth"))

func test_every_present_player_must_be_ready_and_clans_cannot_conflict() -> void:
	var roster = Roster.new()
	for id in range(1, 4):
		roster.add(id, str(id))
	assert_eq(roster.pick(1, 3, 0, true, 0, 15), "")
	assert_ne(roster.pick(2, 3, 0, true, 0, 15), "")
	assert_eq(roster.pick(2, 1, 0, true, 0, 15), "")
	assert_false(roster.can_start())
	assert_eq(roster.pick(3, 2, 0, true, 0, 15), "")
	assert_true(roster.can_start())
	assert_eq(roster.pick(2, 1, 0, false, 0, 15), "")
	assert_false(roster.can_start())

func test_rules_revision_rejects_stale_ready_and_departure_preserves_identity() -> void:
	var roster = Roster.new()
	for id in [1, 24, 82, 105]:
		roster.add(id, "Player %d" % id)
	roster.invalidate_ready()
	assert_ne(roster.pick(24, 1, 0, true, 0, 15), "")
	assert_eq(roster.pick(24, 1, 0, true, 1, 15), "")
	roster.editing_rules = true
	assert_ne(roster.pick(82, 2, 0, true, 1, 15), "")
	roster.remove(24)
	assert_eq(roster.member(82).slot, 2)
	assert_eq(roster.member(105).slot, 3)
	assert_eq(roster.member(82).name, "Player 82")
	assert_true(roster.members.all(func(player): return not player.ready))
	assert_eq(roster.member(24), {})
