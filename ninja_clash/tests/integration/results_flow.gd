extends SceneTree

var game: Node
var state: Node
var combat: Node
var net: Node
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/menu-polish-"+label+".png")

func press(screen: Control, action: String) -> void:
	screen.set_process(false)
	Input.action_press(action)
	screen._process(0.0)
	Input.action_release(action)
	await process_frame
	await process_frame
	screen.set_process(true)

func run() -> void:
	game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	state = root.get_node("GameState")
	combat = root.get_node("Combat")
	net = root.get_node("Net")
	await process_frame
	root.get_node("Settings").show_tutorial = false
	state.change_state(state.State.MODE_SELECT)
	var modes: Control = game.mode_select_screen
	modes._input_lockout_until = 0
	modes._choose(1)
	await capture("modes")
	modes._continue()
	modes._input_lockout_until = 0
	await press(modes,"p1_aim_down")
	check(modes.diff == 2 and modes._rank_open,"Down selects Chunin inside the mandatory rank dialog")
	await capture("rank")
	await press(modes,"menu_cancel")
	check(not modes._rank_open and state.current_state == state.State.MODE_SELECT,"Cancel returns to mode cards")
	modes._continue()
	modes._input_lockout_until = 0
	await press(modes,"p1_confirm")
	check(state.current_state == state.State.CLAN_SELECT and state.ai_difficulty == 2,"Confirm commits the chosen rank")
	state.change_state(state.State.MAP_SELECT)
	var maps: Control = game.map_select_screen
	maps._input_lockout_until = 0
	maps._choose(0,false)
	await press(maps,"p1_right")
	check(maps.cursor == 0,"Horizontal input no longer changes maps")
	await press(maps,"p1_aim_down")
	check(maps.cursor == 1,"Vertical input changes maps")
	await press(maps,"p1_confirm")
	check(maps._focus_index == 5 and state.current_state == state.State.MAP_SELECT,"First confirm moves focus to Fight")
	await capture("arena")
	await press(maps,"p1_left")
	check(maps._focus_index == 4,"Left from Fight reaches Random")
	await press(maps,"p1_left")
	check(maps._focus_index == 6,"Left from Random reaches Back")
	await press(maps,"p1_left")
	check(maps._focus_index == 6,"Left edge does not wrap to the opposite side")
	await press(maps,"p1_right")
	await press(maps,"p1_right")
	check(maps._focus_index == 5,"Right follows Back, Random, Fight in screen order")
	await press(maps,"p1_aim_up")
	check(maps.cursor == 3 and maps._focus_index == 3,"Up from Fight reaches the arena directly above it")
	await press(maps,"p1_aim_down")
	check(maps._focus_index == 5,"Down from the last arena reaches Fight")
	await press(maps,"p1_aim_down")
	check(maps._focus_index == 5,"Bottom edge does not wrap to a top item")
	maps._begin_roll(1,3)
	maps._roll_start = Time.get_ticks_msec()/1000.0-1.0
	maps._animate_roll(0.5)
	var first_offset: float = maps._reel.position.y
	maps._animate_roll(1.0)
	check(maps._reel.position.x == 0 and maps._reel.position.y > first_offset,"Carousel moves downward without horizontal drift")
	await capture("carousel")
	maps._animate_roll(maps.TRAVEL_DURATION+maps.SETTLE_DURATION)
	check(maps._spinning and maps._fight.disabled,"Landed arena stays visible briefly before Fight unlocks")
	check(is_equal_approx(maps._reel.position.y,maps._roll_steps*maps.REEL_STEP),"Landing settles exactly in the selection frame")
	maps._animate_roll(maps.ROLL_DURATION)
	check(maps.cursor == 3 and maps._focus_index == 5,"Carousel lands on the announced map and selects Fight")
	for start in 4:
		for target in 4:
			maps._begin_roll(start,target)
			maps._animate_roll(maps.ROLL_DURATION)
			check(maps.cursor == target,"Every reel start/target combination lands accurately")
	net.mode = net.NetMode.CLIENT
	maps._on_remote_roll(0,2)
	check(maps._spinning,"Guest receives the host's carousel animation")
	maps._animate_roll(maps.ROLL_DURATION)
	check(maps.cursor == 2 and maps._fight.disabled,"Guest sees the same result without gaining Fight authority")
	net.mode = net.NetMode.OFFLINE
	maps._begin_roll(2,1)
	state.change_state(state.State.MODE_SELECT)
	check(not maps._spinning,"Leaving the screen cancels carousel processing")
	state.game_mode = state.Mode.HUMAN_VS_HUMAN
	state.selected_map_index = 0
	state.start_new_match()
	game._in_countdown = false
	for fighter in game.players:
		fighter.set_physics_process(false)
		fighter.collision_layer = 0
	state.change_state(state.State.ROUND)
	game._show_round_winner(1)
	check(game.win_display.get_child_count() == 2,"Round winner uses only the original player and wins glyphs")
	game.win_display.hide()
	var attacker: Node = game.players[0]
	var victim: Node = game.players[1]
	attacker._start_swing(Time.get_ticks_msec()/1000.0)
	attacker._throw_shuriken(Vector2.RIGHT)
	game._clear_shurikens()
	check(combat.stat(1,"strikes") == 1 and combat.stat(1,"throws") == 1,"Production attack paths count swings and emitted projectiles")
	victim.is_iframe = false
	victim.hurt_iframe_until = 0
	victim.is_defending = true
	victim.facing = -1
	victim.hp = 3
	check(not victim.take_damage(1,Vector2.RIGHT*100,1),"Guard blocks the incoming strike")
	check(combat.stat(2,"blocks") == 1 and combat.stat(1,"hits") == 0,"A block never counts as a landed hit")
	victim.is_defending = false
	check(victim.take_damage(1,Vector2.RIGHT*100,1),"An open target takes damage")
	check(not victim.take_damage(1,Vector2.RIGHT*100,1),"Hurt immunity rejects duplicate damage")
	check(combat.stat(1,"hits") == 1,"Only accepted damage counts as a hit")
	victim.hurt_iframe_until = 0
	victim.hp = 1
	victim.take_damage(1,Vector2.RIGHT*100,1)
	check(combat.stat(1,"hits") == 2 and combat.stat(1,"eliminations") == 1,"The lethal hit and elimination are both attributed to their attacker")
	var retained: Dictionary = combat.match_stats.duplicate(true)
	state.current_state = state.State.ROUND_END
	combat.record(1,"throws")
	check(combat.match_stats == retained,"Non-combat time cannot add match statistics")
	game._enter_match_intro()
	game._in_countdown = false
	check(combat.match_stats == retained,"Statistics accumulate across rounds")
	state.game_mode = state.Mode.FFA
	state.assign_ffa_clans()
	state.start_new_match()
	game._in_countdown = false
	check(combat.match_stats.is_empty(),"A new match starts fresh statistics")
	for fighter in game.players:
		fighter.set_physics_process(false)
	combat.scores = {1:5,2:3,3:1,4:2}
	for slot in range(1,5):
		combat.match_stats[slot] = {"strikes":18+slot*4,"throws":25-slot*3,"hits":13-slot*2,"blocks":slot*2,"eliminations":6-slot}
	state.p1_skin = 2
	state.target_score = 5
	state.change_state(state.State.ROUND)
	await capture("hud")
	state.match_winner_slot = 1
	state.change_state(state.State.MATCH_END)
	var results: Control = game.match_end_screen
	await create_timer(0.5,true,false,true).timeout
	for slot in range(1,5):
		state.match_winner_slot = slot
		results._refresh()
		check(results.portrait.texture == results.Portraits.texture(state.clan_index(slot),state.SKIN_STYLES[state.skin_index(slot)]),"Every winning slot shows the selected portrait")
	state.match_winner_slot = 1
	results._refresh()
	check(results.stat_values[0][0].text == "22" and results.stat_headers[3].visible,"FFA results show all four participants' real counters")
	await capture("victory-ffa")
	state.game_mode = state.Mode.HUMAN_VS_HUMAN
	results._refresh()
	check(not results.stat_headers[2].visible,"Duel hides unused result columns")
	await capture("victory-duel")
	var bundle: Dictionary = net._build_state_bundle()
	combat.match_stats.clear()
	net.mode = net.NetMode.CLIENT
	net._apply_state(state.State.MATCH_END,bundle)
	check(combat.stat(1,"strikes") == 22 and results.stat_values[0][0].text == "22","Reliable match state transfers statistics before the client displays results")
	check(results.actions[0].disabled and not results.actions[3].disabled,"Guest can leave but cannot launch a rematch")
	combat.record(1,"strikes")
	check(combat.stat(1,"strikes") == 22,"Puppet actions cannot duplicate host statistics")
	net.mode = net.NetMode.OFFLINE
	results._input_lockout_until = 0
	results._activate(0)
	check(state.current_state == state.State.MATCH_INTRO and combat.match_stats.is_empty(),"Rematch clears the record and starts the next match")
	state.change_state(state.State.TITLE)
	game.queue_free()
	root.get_node("Audio").stop_music()
	await process_frame
	print("Results and selection: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
