extends SceneTree
const Rules := preload("res://perk_rules.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game: Node = load("res://Main.tscn").instantiate()
	root.add_child(game)
	root.get_node("Settings").show_tutorial = false
	var state: Node = root.get_node("GameState")
	state.game_mode = state.Mode.FFA
	state.selected_map_index = 2
	state.start_new_match()
	state.change_state(state.State.ROUND)
	game.perk_director.set_physics_process(false)
	game.perk_director.reset()
	for i in 4:
		var p: Node = game.players[i]
		p.set_physics_process(false)
		p.grant_perk(i+1)
		game.perk_director.add_pickup(i+1,Vector2(160+i*180,240),0 if i%2 else 0.5)
	game.players[0].reverse_left = 2.5
	for frame in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/ninja-perks-preview.png")
	game.queue_free()
	await process_frame
	quit()
