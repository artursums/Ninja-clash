extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(800,450)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var game: Node = load("res://Main.tscn").instantiate()
	viewport.add_child(game)
	var state: Node = root.get_node("GameState")
	state.change_state(state.State.MAP_SELECT)
	var screen: Control = game.map_select_screen
	screen.set_process(false)
	screen._begin_roll(0,3)
	DirAccess.make_dir_recursive_absolute("/tmp/carousel-frames")
	for frame in int((screen.ROLL_DURATION+0.65)*30):
		if screen._spinning:
			screen._animate_roll(frame/30.0)
		await process_frame
		await RenderingServer.frame_post_draw
		var error := viewport.get_texture().get_image().save_png("/tmp/carousel-frames/%03d.png" % frame)
		if error != OK:
			push_error("Could not capture carousel frame")
			quit(1)
			return
	game.queue_free()
	root.get_node("Audio").stop_music()
	await process_frame
	viewport.queue_free()
	await process_frame
	quit()
