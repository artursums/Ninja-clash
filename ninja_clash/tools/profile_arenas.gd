extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280,720)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var game: Node = load("res://Main.tscn").instantiate()
	viewport.add_child(game)
	game.arena_root.get_node("ArenaCamera").zoom = Vector2(1280,720)/Vector2(880,495)
	game.canvas.hide()
	game.arena_root.show()
	for player in game.players:
		player.hide()
		player.set_physics_process(false)
	var results: Array = []
	for index in 4:
		game._load_map(index)
		for frame in 30:
			await process_frame
		var timings: Array[float] = []
		var draw_calls := 0.0
		var previous := Time.get_ticks_usec()
		for frame in 180:
			await process_frame
			var now := Time.get_ticks_usec()
			timings.append((now-previous)/1000.0)
			previous = now
			draw_calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		var sum := 0.0
		for timing in timings:
			sum += timing
		timings.sort()
		var result := {"map":root.get_node("Maps").get_map(index).name,"mean_frame_ms":snappedf(sum/timings.size(),0.01),
			"p95_frame_ms":snappedf(timings[int(timings.size()*0.95)],0.01),"draw_calls":snappedf(draw_calls/timings.size(),0.1),
			"render_memory_mib":snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576,0.1)}
		results.append(result)
		print("ARENA PROFILE ",JSON.stringify(result))
	var file := FileAccess.open("/tmp/arena-render-profile.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"viewport":str(viewport.size),"frames_per_arena":180,"results":results},"\t"))
	game.queue_free()
	root.get_node("Audio").stop_music()
	await process_frame
	viewport.queue_free()
	await process_frame
	quit()
