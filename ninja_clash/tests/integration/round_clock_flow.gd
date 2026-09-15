extends SceneTree
const Rules := preload("res://perk_rules.gd")
var game: Node
var state: Node
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(description)

func begin() -> void:
	state.start_new_match()
	state.change_state(state.State.ROUND)
	for p in game.players:
		p.set_physics_process(false)
		p.is_bot = false

func run() -> void:
	game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	state = root.get_node("GameState")
	root.get_node("Settings").show_tutorial = false
	var config = root.get_node("MatchConfig")
	var combat = root.get_node("Combat")
	var net = root.get_node("Net")
	state.game_mode = state.Mode.FFA
	state.selected_map_index = 2
	game.round_clock.set_physics_process(false)
	config.round_time_seconds = 60
	begin()
	check(game.round_clock.remaining == 60, "New round starts with the configured timer")
	game.round_clock.start(0)
	game.round_clock.advance(500)
	check(state.current_state == state.State.ROUND, "Disabled timer cannot end a round")
	for i in 4:
		game.players[i].hp = 5-i
	game.round_clock.start(1)
	game.round_clock.advance(1)
	check(state.current_state == state.State.ROUND_END and combat.scores[1] == 1, "Highest remaining health wins at timeout")
	game.round_clock.advance(50)
	check(combat.scores[1] == 1, "Timeout awards the round only once")
	begin()
	for i in 4:
		game.players[i].hp = 4 if i < 2 else 2
	game.round_clock.start(1)
	game.round_clock.advance(1)
	check(state.current_state == state.State.ROUND and game.round_clock.remaining == 20, "Tied leaders enter a bounded overtime")
	check(game.players[0].hp == 1 and game.players[1].hp == 1, "Overtime contenders have one heart")
	check(not game.players[2].alive and not game.players[3].alive, "Lower-health contenders are removed from overtime")
	check(combat.stat(1,"eliminations") == 0 and combat.stat(2,"eliminations") == 0, "Timeout elimination gives no kill credit")
	state.last_kill_killer = 3
	game.round_clock.advance(20)
	check(state.current_state == state.State.ROUND_END and game._round_winner_slot == 0 and game.banner_label.text == "DRAW", "Overtime draw never displays an earlier killer as winner")
	check(combat.scores.values().all(func(score): return score == 0), "Draw awards nobody a point")
	state.advance_round_or_end_match()
	check(state.current_state == state.State.MATCH_INTRO and game._in_countdown and game.banner_label.text == "", "Draw banner is cleared before the next round's countdown")
	begin()
	var p = game.players[0]
	p.stash = 3
	p.grant_perk(Rules.Kind.RICOCHET)
	check(p.available_shurikens() == 4, "Three ordinary blades plus one perk equals four throws")
	p._throw_shuriken(Vector2.RIGHT)
	var blades := get_nodes_in_group("shurikens")
	check(p.stash == 3 and p.perk_charges == 0 and blades[-1].perk_kind == Rules.Kind.RICOCHET, "Special throw goes first without consuming ordinary ammunition")
	p._throw_shuriken(Vector2.RIGHT)
	check(p.stash == 2, "Next ordinary throw consumes ordinary ammunition")
	for kind in [1,2,3,4]:
		p.clear_perks()
		p.stash = 0
		p.grant_perk(kind)
		p._throw_shuriken(Vector2.UP)
		blades = get_nodes_in_group("shurikens")
		check(p.stash == 0 and p.perk_charges == 0 and blades[-1].perk_kind == kind, "Every perk can fire from an empty stash: %d" % kind)
	config.infinite_shurikens = true
	p.grant_perk(Rules.Kind.RICOCHET)
	p._throw_shuriken(Vector2.UP)
	check(p.available_shurikens() == 0, "Infinite ordinary ammo does not duplicate special throws")
	config.infinite_shurikens = false
	var router = root.get_node("PlayerInput")
	begin()
	await physics_frame
	await process_frame
	p = game.players[0]
	p.stash = 0
	p.grant_perk(Rules.Kind.RICOCHET)
	var event := InputEventKey.new()
	event.keycode = KEY_L
	event.physical_keycode = KEY_L
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	router.capture()
	p._physics_process(1.0/60)
	check(p.is_aiming, "Empty stash still permits aiming a held special blade")
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	router.capture()
	p._physics_process(1.0/60)
	check(p.perk_kind == 0, "Releasing throw fires the special blade with no ordinary ammo")
	var maps = root.get_node("Maps")
	var navigation = load("res://bot_navigation.gd").new()
	for map_index in maps.count():
		state.selected_map_index = map_index
		begin()
		await physics_frame
		await process_frame
		var data: Dictionary = maps.get_map(map_index)
		navigation.configure(data, load("res://player_tuning.tres"))
		var candidates: Array = game.perk_director.candidates()
		check(candidates.size() == data.perk_anchors.size(), "%s: every authored anchor has solid support and headroom" % data.name)
		for point in candidates:
			var destination: int = navigation.nearest_ledge(point)
			for spawn: Vector2 in data.spawn_points:
				var origin: int = navigation.nearest_ledge(spawn)
				check(origin == destination or not navigation.route(origin,destination).is_empty(), "%s: pickup %s is reachable from every spawn" % [data.name,point])
	config.round_time_seconds = 90
	var bundle: Dictionary = net._build_state_bundle()
	check(bundle.cfg.round_time_seconds == 90, "Shared lobby rules contain round time")
	check(net._build_snapshot().clock == game.round_clock.snapshot(), "Host snapshots include the actual round clock")
	game.queue_free()
	await process_frame
	print("Round clock and perk inventory: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
