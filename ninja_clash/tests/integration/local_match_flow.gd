extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	var game: Node = load("res://Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var state: Node = root.get_node("GameState")
	root.get_node("Settings").show_tutorial = false
	root.get_node("MatchConfig").capture_defaults()
	for count in range(2, 5):
		state.change_state(state.State.MODE_SELECT)
		var modes: Control = game.mode_select_screen
		modes._choose(0)
		modes._input_lockout_until = 0
		modes._continue()
		check(modes._choice_open, "Local play requires a party size")
		modes._input_lockout_until = 0
		modes._confirm_choice(count - 1)
		check(state.num_players() == count, "Party size reaches the match state")
		var clans: Control = game.clan_select_screen
		clans._input_lockout_until = 0
		check(clans.selection.clans.size() == count, "Each human gets a clan selector")
		for index in count:
			clans._mouse_slot = index + 1
			clans._mouse_pick(index)
			clans._mouse_lock(index + 1)
		check(state.current_state == state.State.MAP_SELECT, "All ready players advance together")
		game.map_select_screen._input_lockout_until = 0
		game.map_select_screen._start()
		await process_frame
		check(game.players.size() == count, "Arena creates the requested number of fighters")
		check(not game.tutorial_overlay.visible, "Disabled tutorial does not interrupt the match")
		for fighter in game.players:
			check(not fighter.is_bot and not state.slot_is_bot(fighter.slot), "Local multiplayer has no CPU slots")
			check(fighter.hp == 5 and fighter.stash == 3 and fighter.katana_charges == 3, "Every fighter receives the standard loadout")
		state.change_state(state.State.TITLE)
		await process_frame
	game.queue_free()
	await process_frame
	print("Local multiplayer: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
