extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func run() -> void:
	var game: Node = load("res://Main.tscn").instantiate()
	root.add_child(game)
	var state: Node = root.get_node("GameState")
	var net: Node = root.get_node("Net")
	var inputs: Node = root.get_node("PlayerInput")
	var combat: Node = root.get_node("Combat")
	var settings: Node = root.get_node("Settings")
	settings.show_tutorial = false
	for count in [2, 3, 4]:
		net.player_name = "Host"
		check(net.host_game(0) == "", "Desktop room starts")
		for index in range(1, count):
			var id := 100 + index
			var action: String = ["right", "left", "defend"][index - 1]
			net.lobby.add(id, "Human %d" % (index + 1))
			net._remote_inputs[id] = {"held": 1 << NetCodec.ACTIONS.find(action), "pressed": 1 << NetCodec.ACTIONS.find("jump"), "seen": Time.get_ticks_msec() / 1000.0}
		var stale_generation: int = net._start_generation
		net._starting = true
		net.return_to_lobby()
		net._on_room_locked("", stale_generation)
		check(state.current_state == state.State.ONLINE_LOBBY, "Stale Start response cannot start a new lobby")
		for player in net.lobby.members:
			net.lobby.pick(player.peer, player.clan, 0, true, net.lobby.rules_revision, state.skin_count())
		net.start_lobby_match()
		check(state.current_state == state.State.MATCH_INTRO, "Explicit host Start enters countdown")
		check(game.players.size() == count, "Arena has exactly %d fighters" % count)
		for player in game.players:
			check(not player.is_bot, "Every online fighter is human")
			check(player.position == game.spawn_points[player.slot - 1], "Each fighter has an authored spawn")
		inputs.capture()
		for slot in range(2, count + 1):
			var action: String = ["right", "left", "defend"][slot - 2]
			check(inputs.held("p%d_%s" % [slot, action]), "Independent remote input reaches slot %d" % slot)
			for other_action in ["right", "left", "defend"]:
				if other_action != action:
					check(not inputs.held("p%d_%s" % [slot, other_action]), "Another peer cannot steer this fighter")
			check(inputs.pressed("p%d_jump" % slot), "Remote jump reaches slot %d" % slot)
		inputs.capture()
		for slot in range(2, count + 1):
			check(not inputs.pressed("p%d_jump" % slot), "Remote jump is consumed once")
		net._remote_inputs[101].seen = Time.get_ticks_msec() / 1000.0 - 1.0
		net._physics_process(0.0)
		inputs.capture()
		check(not inputs.held("p2_right"), "Stalled guest input expires independently")
		if count >= 3:
			check(inputs.held("p3_left"), "A stalled guest does not clear another guest's input")
		combat.scores[count] = state.target_score
		state.advance_round_or_end_match()
		check(state.current_state == state.State.MATCH_END, "Final-slot player can win the match")
		check(state.match_winner_slot == count, "Winner slot is correct")
		check(game.match_end_screen.winner_label.text == "Human %d" % count, "Results display the winner's name")
		net.return_to_lobby()
		check(state.current_state == state.State.ONLINE_LOBBY, "Rematch returns to ready lobby")
		check(net.player_name == "Host", "Rematch preserves session name")
		check(net.lobby.members.all(func(player): return not player.ready), "Rematch requires new readiness")
		net.leave()
		check(net.player_name == "", "Leaving clears session name")
		check(state.online_players.is_empty(), "Leaving clears online fighter configuration")
		await process_frame
	state.game_mode = state.Mode.FFA
	check(state.num_players() == 4 and state.slot_is_bot(2), "Offline FFA still uses bots")
	state.game_mode = state.Mode.HUMAN_VS_HUMAN
	check(state.num_players() == 2 and not state.slot_is_bot(2), "Offline duel remains unchanged")
	game.queue_free()
	await process_frame
	print("Online integration: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
