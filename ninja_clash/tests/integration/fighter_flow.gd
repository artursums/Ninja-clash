extends SceneTree

const Art := preload("res://fighter_art.gd")
var checks := 0
var failures := 0
var game: Node
var fighter: Node2D
var state: Node

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func projectile(offset: Vector2, previous: Vector2 = Vector2.INF) -> Node2D:
	var star: Node2D = load("res://shuriken.gd").new()
	star.thrower_slot = 2
	star.position = fighter.position + offset
	game.arena_root.add_child(star)
	star.set_physics_process(false)
	star._previous_position = star.global_position if previous == Vector2.INF else fighter.position + previous
	return star

func run() -> void:
	game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	state = root.get_node("GameState")
	state.game_mode = state.Mode.HUMAN_VS_HUMAN
	state.start_new_match()
	game._in_countdown = false
	for player in game.players:
		player.set_physics_process(false)
		player.collision_layer = 0
	for node in game.current_map_nodes:
		node.queue_free()
	game.current_map_nodes.clear()
	await process_frame
	await physics_frame
	fighter = game.players[0]
	fighter.position = Vector2(400,250)
	fighter.facing = 1
	fighter.is_swinging = true
	var hp: int = fighter.hp
	var charges: int = fighter.katana_charges
	for elapsed in [0.04, 0.15, 0.26]:
		fighter.swing_start_t = 10.0 - elapsed
		var star := projectile(Vector2(42,24))
		check(fighter._try_katana_parry(star, 10.0), "Early, central and late swing all deflect")
		check(star.thrower_slot == 1 and star.velocity_v.x > 0, "Parry transfers ownership and redirects")
		check(star._sprite.hframes == 9 and star._trail.size() == 4, "Original shuriken strip and afterimages remain")
		check(not fighter._try_katana_parry(star, 10.0), "Same blade cannot retrigger its owner's parry")
		star.free()
	fighter.swing_start_t = 9.85
	var fast := projectile(Vector2(-9,20), Vector2(70,20))
	check(fighter._try_katana_parry(fast, 10.0), "Crossing projectile is caught between ticks")
	fast.free()
	fighter.facing = -1
	var left := projectile(Vector2(-40,-24))
	check(fighter._try_katana_parry(left,10.0) and left.velocity_v.x < 0, "Left-facing parry mirrors reach and reflection")
	left.free()
	fighter.facing = 1
	for offset in [Vector2(-14,0), Vector2(48,0), Vector2(30,29)]:
		var miss := projectile(offset)
		check(not fighter._try_katana_parry(miss,10.0), "Outside reach does not parry")
		miss.free()
	for property in ["stuck", "consumed", "puppet"]:
		var unavailable := projectile(Vector2(20,0))
		unavailable.set(property, true)
		check(not fighter._try_katana_parry(unavailable,10.0), "Ineligible projectile is ignored")
		unavailable.free()
	var late := projectile(Vector2(20,0))
	check(not fighter._try_katana_parry(late,10.2), "Parry closes at the end of the followthrough")
	late.free()
	fighter.swing_start_t = Time.get_ticks_msec() / 1000.0 - 0.15
	var contact := projectile(Vector2(10,0))
	check(not fighter.hit_by_shuriken(contact), "Contact callback keeps a parried projectile in play")
	check(contact.thrower_slot == 1 and fighter.hp == hp, "Contact callback resolves parry before damage")
	check(fighter.katana_charges == charges, "Deflections do not spend melee charges")
	contact.free()
	var wall := StaticBody2D.new()
	wall.position = fighter.position + Vector2(20,0)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4,80)
	shape.shape = rect
	wall.add_child(shape)
	game.arena_root.add_child(wall)
	await physics_frame
	await process_frame
	fighter.swing_start_t = 9.85
	var covered := projectile(Vector2(40,0))
	check(not fighter._try_katana_parry(covered,10.0), "Terrain blocks a parry through a wall")
	covered.free()
	wall.free()
	check(state.skin_count() == Art.STYLES.size(), "Every selectable style has new artwork")
	for style in Art.STYLES.size():
		var texture: Texture2D = load(Art.path(style,state.get_clan(1).sprite))
		check(texture.get_size() == Vector2(576,384), "Every costume has the full atlas")
		var pixels := texture.get_image()
		for row in Art.ANIMATIONS.size():
			var unique: Dictionary = {}
			for frame in Art.COUNTS[row]:
				var cell := pixels.get_region(Rect2i(frame*48,row*48,48,48))
				check(cell.get_used_rect().size != Vector2i.ZERO, "Animation frame contains visible art")
				unique[hash(cell.get_data())] = true
			check(unique.size() >= 2, "Every movement state changes its pose")
		state.p1_skin = style
		game._enter_match_intro()
		check(fighter.visual.texture == texture and fighter.visual.hframes == 12 and fighter.visual.vframes == 8, "Match uses selected costume's full animation grid")
		var portrait: Texture2D = game.clan_select_screen.Portraits.texture(state.clan_index(1), state.SKIN_STYLES[style])
		check(portrait.resource_path.begins_with("res://sprites/portraits/"), "Selection uses the illustrated portrait collection")
		await process_frame
	for clan in state.CLANS:
		for style in Art.STYLES.size():
			var atlas: Texture2D = load(Art.path(style,clan.sprite))
			var source: Texture2D = load(state.skin_pose_path(clan.sprite,style))
			var original := source.get_image().get_region(Rect2i(0,0,16,16))
			original.resize(32,32,Image.INTERPOLATE_NEAREST)
			original.flip_x()
			var neutral := atlas.get_image().get_region(Rect2i(8,11,32,32))
			var identical := true
			for y in 32:
				for x in 32:
					var before := original.get_pixel(x,y)
					var after := neutral.get_pixel(x,y)
					if before.a != after.a or (before.a > 0 and before != after):
						identical = false
			check(identical, "Every clan and costume preserves the original neutral pixels")
	check(fighter.stash_icons[0].texture.resource_path == "res://sprites/shuriken.svg", "Original above-head shuriken icon")
	check(fighter.katana_icons[0].hframes == 6 and fighter.katana_icons[0].frame == 2 and fighter.katana_icons[0].rotation == 0, "Original vertical katana charge icon")
	game.queue_free()
	await process_frame
	print("Fighter flow: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
