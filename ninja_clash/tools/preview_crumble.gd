extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(480,240)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var game: Node = load("res://Main.tscn").instantiate()
	viewport.add_child(game)
	game.canvas.hide()
	game.arena_root.show()
	game._load_map(0)
	for player in game.players:
		player.hide()
		player.set_physics_process(false)
	var platform: Node
	for node in game.current_map_nodes:
		if node.is_in_group("crumble_platforms"):
			platform = node
			break
	var camera: Camera2D = game.arena_root.get_node("ArenaCamera")
	camera.position = platform.position+Vector2(0,18)
	camera.zoom = Vector2(3,3)
	DirAccess.make_dir_recursive_absolute("/tmp/crumble-frames")
	for frame in 180:
		var time := frame/30.0
		platform._age = time
		if time < 0.5 or time >= 5.15:
			platform.reset_platform()
		elif time < 1.15:
			platform.apply_snapshot([1,1.15-time])
		else:
			platform.apply_snapshot([2,5.15-time])
		await process_frame
		await RenderingServer.frame_post_draw
		var error := viewport.get_texture().get_image().save_png("/tmp/crumble-frames/%03d.png" % frame)
		if error != OK:
			push_error("Could not capture crumble preview")
			quit(1)
			return
	game.queue_free()
	root.get_node("Audio").stop_music()
	await process_frame
	viewport.queue_free()
	await process_frame
	quit()
