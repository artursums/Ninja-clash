extends SceneTree

var game: Node
var state: Node
var net: Node
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func unlock(screen: Control) -> void:
	screen._input_lockout_until = 0.0

func click_control(control: Control) -> void:
	var point: Vector2 = control.get_global_transform_with_canvas() * (control.size / 2.0)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event, true)

func run() -> void:
	game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	state = root.get_node("GameState")
	net = root.get_node("Net")
	await process_frame
	var title: Control = game.title_screen
	check(title._intro_active, "Boot starts the title assembly")
	click_control(title._buttons[0])
	check(not title._intro_active and state.current_state == state.State.TITLE, "Skipping the intro does not activate a menu item")
	check(title._halves[0].position.x == 0 and title._halves[1].position.x == 400, "Both picture halves meet without a gap")
	unlock(title)
	click_control(title._buttons[0])
	check(state.current_state == state.State.MODE_SELECT, "Local play opens mode selection")
	var modes: Control = game.mode_select_screen
	modes._choose(1)
	modes._choose_diff(3)
	unlock(modes)
	modes._continue()
	check(state.game_mode == state.Mode.HUMAN_VS_AI and state.ai_difficulty == 3, "Mode and AI rank reach match state")
	var clans: Control = game.clan_select_screen
	unlock(clans)
	check(clans._player_buttons[0].position.x >= 500 and clans._player_buttons[0].size.y >= 44, "Solo ready action is large and on the right")
	check(not clans._player_buttons[1].visible, "Solo mode hides the second player's action")
	clans._mouse_pick(0)
	clans._setup()
	check(state.current_state == state.State.MATCH_SETUP, "Rules open from clan selection")
	game.match_setup_screen._do_done()
	check(clans.p1_cursor == 0, "Unconfirmed clan survives rules detour")
	unlock(clans)
	clans._mouse_lock(1)
	check(state.current_state == state.State.MAP_SELECT, "Solo lock opens arena selection")
	check(state.p1_clan != state.p2_clan, "Solo opponent gets a different clan")
	var arenas: Control = game.map_select_screen
	unlock(arenas)
	for i in root.get_node("Maps").count():
		arenas._choose(i)
		check(arenas.thumb.texture != null, "Every arena has a preview")
		check(arenas.thumb.size == Vector2(458, 256), "Preview stays within its frame")
		check(arenas.cards[i].get_child(0).size == Vector2(78, 47), "Thumbnail does not expand to source image size")
	arenas._choose(0)
	arenas._step(-1)
	check(arenas.cursor == 3, "Arena navigation wraps left")
	arenas._step(1)
	check(arenas.cursor == 0, "Arena navigation wraps right")
	arenas._randomize()
	check(arenas.cursor != 0, "Random selects a different arena")
	check(state.current_state == state.State.MAP_SELECT, "Random does not launch a match")
	var remembered: int = arenas.cursor
	arenas._back()
	state.change_state(state.State.MAP_SELECT)
	check(arenas.cursor == remembered, "Arena selection survives going back")
	unlock(arenas)
	net.mode = net.NetMode.CLIENT
	arenas._refresh()
	arenas._choose(0)
	arenas._start()
	check(arenas.cursor == remembered and state.current_state == state.State.MAP_SELECT, "Guest cannot choose or start")
	arenas._on_remote_cursor(2)
	check(arenas.cursor == 2, "Guest mirrors host arena selection")
	check(arenas.host_controls[-1].disabled, "Guest fight button is disabled")
	arenas.hide()
	arenas._on_remote_cursor(1)
	arenas.show()
	check(arenas.cursor == 1, "Host cursor survives arriving before the screen-change packet")
	net.mode = net.NetMode.OFFLINE
	state.game_mode = state.Mode.HUMAN_VS_HUMAN
	state.change_state(state.State.CLAN_SELECT)
	unlock(clans)
	clans._mouse_pick(0)
	clans._mouse_lock(1)
	clans._mouse_pick(0)
	clans._mouse_lock(2)
	check(not clans.p2_confirmed, "Two players cannot lock the same clan")
	check(state.current_state == state.State.CLAN_SELECT, "Conflict stays on clan screen")
	clans._mouse_pick(2)
	clans._mouse_lock(2)
	check(state.current_state == state.State.MAP_SELECT, "Two different locks advance to arena")
	unlock(arenas)
	var settings: Node = root.get_node("Settings")
	var tutorial: bool = settings.show_tutorial
	settings.show_tutorial = false
	arenas._start()
	check(state.current_state == state.State.MATCH_INTRO, "Fight starts selected match")
	check(arenas._starting, "Fight is guarded against duplicate activation")
	settings.show_tutorial = tutorial
	state.change_state(state.State.ROUND)
	var pause: Control
	for control in game.find_children("*", "Control", true, false):
		if control.get_script() != null and control.get_script().resource_path == "res://pause_menu.gd":
			pause = control
			break
	pause._open()
	check(paused and pause.visible, "Pause freezes the local match and displays the menu")
	pause._enter_settings()
	check(pause._back_label.visible and pause._back_label.position.y + pause._back_label.size.y < 450, "Pause settings back row fits the viewport")
	pause._resume()
	check(not paused and not pause.visible, "Resume closes pause and unfreezes the match")
	state.change_state(state.State.TITLE)
	unlock(title)
	click_control(title._buttons[2])
	check(title._overlay == title.OVERLAY_OPTIONS, "Mouse opens options")
	var previous: int = state.current_state
	click_control(title._buttons[0])
	check(state.current_state == previous, "Modal options block clicks on the menu behind them")
	title._set_overlay(0)
	check(not title._intro_active, "Returning to title does not replay the entrance")
	await process_frame
	await process_frame
	var time_scale := Engine.time_scale
	Engine.time_scale = 0.05
	title._start_intro()
	await create_timer(1.2, true, false, true).timeout
	check(not title._intro_active and title._content.modulate.a == 1, "Title entrance completes independently of combat time scale")
	Engine.time_scale = time_scale
	game.queue_free()
	await process_frame
	print("Menu flow: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
