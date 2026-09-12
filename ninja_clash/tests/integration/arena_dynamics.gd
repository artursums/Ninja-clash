extends SceneTree

const Arena := preload("res://arena_rules.gd")
var Crumble: Script
var checks := 0
var failures := 0
var game: Node

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func clear_at(point: Vector2, walls: Array) -> bool:
	var body := Rect2(point-Vector2(9.9,15.9),Vector2(19.8,31.8))
	for wall in walls:
		if Rect2(wall.center-wall.size/2,wall.size).intersects(body):
			return false
	return true

func run() -> void:
	Crumble = load("res://crumble_platform.gd")
	game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	var state: Node = root.get_node("GameState")
	root.get_node("Settings").show_tutorial = false
	state.game_mode = state.Mode.HUMAN_VS_HUMAN
	for index in 4:
		state.selected_map_index = index
		state.start_new_match()
		game._in_countdown = false
		for player in game.players:
			player.set_physics_process(false)
			player.collision_layer = 0
		for platform in get_nodes_in_group("crumble_platforms"):
			platform.set_physics_process(false)
		await physics_frame
		await process_frame
		var data: Dictionary = root.get_node("Maps").get_map(index)
		var probe: CharacterBody2D = game.players[0]
		probe.collision_mask = 1
		var crossings := 0
		for wall in data.walls:
			var rect := Rect2(wall.center-wall.size/2,wall.size)
			if rect.position.x != 0 or rect.position.y < 40:
				continue
			var y := rect.position.y-16.1
			if not clear_at(Vector2(18,y),data.walls):
				continue
			for direction in [-1,1]:
				for speed in [158.4,400.0]:
					probe.position = Vector2(18 if direction < 0 else Arena.WIDTH-18,y)
					var crossed := false
					for frame in 20:
						probe.velocity = Vector2(direction*speed,1400.0/60)
						probe.move_and_slide()
						var before: Vector2 = probe.position
						probe._check_screen_wrap()
						crossed = crossed or absf(before.x-probe.position.x) > 400
						check(absf(probe.position.y-y) < 0.25,data.name+" keeps floor height while running/dashing through a seam")
						check(clear_at(probe.position,data.walls),data.name+" side arrival does not embed the fighter")
						if crossed and (probe.position.x > 12 and probe.position.x < Arena.WIDTH-12):
							break
					check(crossed,data.name+" floor connects across the screen")
					crossings += 1
		check(crossings >= 4,data.name+" has a tested floor crossing in both directions")
		var vertical_crossings := 0
		for x in range(12, int(Arena.WIDTH)-12, 8):
			if not clear_at(Vector2(x,8),data.walls) or not clear_at(Vector2(x,Arena.HEIGHT-8),data.walls):
				continue
			for direction in [-1,1]:
				probe.position = Vector2(x,8 if direction < 0 else Arena.HEIGHT-8)
				var crossed := false
				for frame in 8:
					probe.velocity = Vector2(0,direction*320)
					probe.move_and_slide()
					var before: Vector2 = probe.position
					probe._check_screen_wrap()
					crossed = crossed or absf(before.y-probe.position.y) > 200
					check(clear_at(probe.position,data.walls),data.name+" vertical arrival keeps full body clear")
				check(crossed,data.name+" vertical portal is traversable")
				vertical_crossings += 1
		check(vertical_crossings >= 2,data.name+" has an open vertical route")
		state.current_state = state.State.ROUND
		check(get_nodes_in_group("crumble_platforms").size() == data.crumble_platforms.size(),"All authored slabs instantiate")
		for platform in get_nodes_in_group("crumble_platforms"):
			if platform.is_queued_for_deletion():
				continue
			await verify_crumble(platform,probe)
		print("Verified seams and crumbling: ",data.name)
	state.change_state(state.State.TITLE)
	game.queue_free()
	root.get_node("Audio").stop_music()
	await process_frame
	print("Arena dynamics: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func verify_crumble(platform: StaticBody2D, fighter: CharacterBody2D) -> void:
	var covered_area := 0.0
	check(platform._fragments.size() >= 8 and platform._fragments.size() <= 18,"Debris has a fixed, bounded fragment budget")
	for index in platform._fragments.size():
		var fragment: Dictionary = platform._fragments[index]
		covered_area += fragment.rect.get_area()
		check(Rect2(-platform.bounds.size/2,platform.bounds.size).encloses(fragment.rect),"Fragments originate inside the actual slab")
		check(Rect2(Vector2.ZERO,platform.atlas.get_size()).encloses(fragment.source),"Fragments sample the detailed masonry atlas")
		check(platform.fragment_pose(index,0.6).origin.distance_to(platform.fragment_pose(index,0).origin) > 5,"Breaking moves the stone pieces instead of only fading them")
		check(platform.fragment_pose(index,1.0).origin.y > platform.fragment_pose(index,0.2).origin.y,"Gravity carries fragments downward after the burst")
	check(is_equal_approx(covered_area,platform.bounds.get_area()),"The original slab is fully accounted for by its fragments")
	fighter.position = Vector2(platform.position.x,platform.bounds.position.y-16.1)
	fighter.velocity = Vector2(0,30)
	fighter.move_and_slide()
	platform._physics_process(1.0/60)
	check(platform.phase == Crumble.Phase.CRACKING,"Landing starts a visible warning")
	platform._physics_process(0.3)
	check(platform.collision_layer == 1,"The warning leaves time to jump away")
	var blade: Node = load("res://shuriken.gd").new()
	blade.thrower_slot = 1
	game.arena_root.add_child(blade)
	blade.set_physics_process(false)
	blade.position = platform.position
	blade._on_body_entered(platform)
	check(blade.stuck,"A blade can stick in an intact slab")
	fighter.alive = false
	fighter._corpse_settled = true
	platform._physics_process(0.4)
	check(not fighter._corpse_settled,"A settled corpse falls when its supporting slab breaks")
	fighter.alive = true
	check(platform.phase == Crumble.Phase.ABSENT and platform.collision_layer == 0,"The broken slab has no collision")
	blade._physics_process(1.0/60)
	check(not blade.stuck and blade.ricocheted,"A spent blade falls harmlessly when its support breaks")
	blade.queue_free()
	fighter.position = platform.position
	platform._physics_process(5.0)
	check(platform.phase == Crumble.Phase.ABSENT,"Reforming waits for a fighter inside its bounds")
	fighter.position = Vector2(440,60)
	platform._physics_process(0.1)
	check(platform.phase == Crumble.Phase.INTACT and platform.collision_layer == 1,"An empty slab restores collision")
	var net: Node = root.get_node("Net")
	net.mode = net.NetMode.CLIENT
	var packet := {"map":game._current_loaded_map,"c":[]}
	for node in game.current_map_nodes:
		if node.is_in_group("crumble_platforms"):
			packet.c.append([Crumble.Phase.ABSENT,2.0] if node == platform else [node.phase,node.remaining])
	net._snapshot(packet)
	platform._physics_process(5.0)
	net.mode = net.NetMode.OFFLINE
	check(platform.collision_layer == 0 and platform.remaining == 2.0,"Client applies the host's broken state")
	var snap: Dictionary = root.get_node("Net")._build_snapshot()
	check(snap.c.any(func(value): return value[0] == Crumble.Phase.ABSENT),"World snapshots include dynamic terrain")
	platform.reset_platform()
	net.mode = net.NetMode.CLIENT
	packet.map = (game._current_loaded_map+1)%4
	net._snapshot(packet)
	net.mode = net.NetMode.OFFLINE
	check(platform.phase == Crumble.Phase.INTACT and platform.collision_layer == 1,"Round reset restores all slabs")
	await process_frame
