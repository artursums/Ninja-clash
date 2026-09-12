extends SceneTree

const Art := preload("res://fighter_art.gd")
const Pose := preload("res://tools/fighter_pose.gd")
const COLORS := ["cyan", "magenta", "green", "orange"]
func _initialize() -> void:
	call_deferred("bake")

func optional_texture(path: String) -> Texture2D:
	return load(path) if not path.is_empty() and ResourceLoader.exists(path) else null

func bake() -> void:
	var state: Node = root.get_node("GameState")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(576,384)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(viewport)
	var poses: Array[Node2D] = []
	for row in 8:
		for col in 12:
			var pose := Pose.new()
			pose.animation = Art.ANIMATIONS[row]
			pose.phase = minf(col,Art.COUNTS[row]-1)/float(Art.COUNTS[row])
			pose.position = Vector2(col*48,row*48)
			viewport.add_child(pose)
			poses.append(pose)
	for style in Art.STYLES.size():
		for color in COLORS:
			var original: Texture2D = load(state.skin_pose_path(color,style))
			var idle := optional_texture(state.skin_idle_path(color,style))
			var run := optional_texture(state.skin_walk_path(color,style))
			var swing := optional_texture(state.skin_swing_path(color,style))
			for pose in poses:
				pose.pose_texture = original
				pose.idle_texture = idle
				pose.run_texture = run
				pose.swing_texture = swing
				pose.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute(Art.path(style,color).get_base_dir())
			var error := viewport.get_texture().get_image().save_png(Art.path(style,color))
			if error != OK:
				push_error("Could not bake fighter: " + Art.path(style,color))
				quit(1)
				return
	viewport.queue_free()
	await process_frame
	quit()
