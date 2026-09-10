extends SceneTree

const Arena := preload("res://arena_rules.gd")

# Run with a graphics backend after changing arena geometry or textures.
func _initialize() -> void:
	call_deferred("bake")

func bake() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(Arena.SIZE)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var game: Node2D = load("res://Main.tscn").instantiate()
	viewport.add_child(game)
	game.canvas.hide()
	game.arena_root.show()
	game.arena_root.get_node("ArenaCamera").zoom = Vector2.ONE
	for player in game.players:
		player.hide()
	for index in root.get_node("Maps").count():
		game._load_map(index)
		for node in game.current_map_nodes:
			if node.get_script() == preload("res://arena_ambience.gd"):
				node.set_process(false)
				node._elapsed = 1.0
				node.queue_redraw()
				node._light_layer.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var target: String = root.get_node("Maps").get_map(index).preview
		var error := viewport.get_texture().get_image().save_webp(target, false)
		if error != OK:
			push_error("Could not save arena preview: " + target)
			quit(1)
			return
	game.queue_free()
	await process_frame
	viewport.queue_free()
	await process_frame
	quit()
