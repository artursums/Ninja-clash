extends SceneTree

var game: Node
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func run() -> void:
	game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	var state: Node = root.get_node("GameState")
	root.get_node("Settings").show_tutorial = false
	state.game_mode = state.Mode.HUMAN_VS_AI
	state.ai_difficulty = 2
	var pairs := [
		[Vector2(440, 101), Vector2(440, 277)],
		[Vector2(364, 90), Vector2(440, 208)],
		[Vector2(380, 135), Vector2(440, 435)],
		[Vector2(352, 149), Vector2(440, 281)],
	]
	for index in 4:
		state.selected_map_index = index
		for reverse in [false, true]:
			state.start_new_match()
			game._in_countdown = false
			var human: Node = game.players[0]
			var bot: Node = game.players[1]
			human.set_physics_process(false)
			human.position = pairs[index][0 if reverse else 1]
			human.hp = 1000
			bot.position = pairs[index][1 if reverse else 0]
			bot.hp = 1000
			bot.stash = 0
			bot.katana_charges = 3
			bot.bot_difficulty = 1 + index % 3
			bot._bot_think(Time.get_ticks_msec() / 1000.0)
			bot._bot_brain.reset()
			bot._bot_brain.rng.seed = 800 + index
			state.change_state(state.State.ROUND)
			var closest := INF
			var visited: Dictionary = {}
			var start := Time.get_ticks_msec()
			while Time.get_ticks_msec() - start < 10000:
				await physics_frame
				closest = minf(closest, bot.position.distance_to(human.position))
				var support: int = bot._bot_brain.navigation.support(bot.position)
				if support >= 0:
					visited[support] = true
				if closest < 45 and bot.is_on_floor() and visited.size() >= 2:
					break
			var label := "%s %s" % [root.get_node("Maps").get_map(index).name, "climb" if reverse else "descend"]
			print("PLAYTEST ", label, " closest=", snappedf(closest, 0.1), " ledges=", visited.keys(), " end=", bot.position)
			check(closest < 60, label + " reaches the stationary opponent instead of mirroring or camping")
			check(visited.size() >= 2, label + " traverses platforms")
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("/tmp/bot-playtest-%d-%s.png" % [index, str(reverse)])
	state.change_state(state.State.TITLE)
	game.queue_free()
	root.get_node("Audio").stop_music()
	await process_frame
	print("Bot playtest: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
