extends SceneTree
const Rules := preload("res://perk_rules.gd")
var Shot: Script
var game: Node
var state: Node
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func shot(kind: int, pos: Vector2, velocity: Vector2) -> Area2D:
	var node: Area2D = Shot.new()
	node.perk_kind = kind
	node.thrower_slot = 1
	node.position = pos
	node.velocity_v = velocity
	node.throw_time = -10
	game.arena_root.add_child(node)
	node.set_physics_process(false)
	return node

func run() -> void:
	Shot = load("res://shuriken.gd")
	game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	state = root.get_node("GameState")
	root.get_node("Settings").show_tutorial = false
	state.game_mode = state.Mode.FFA
	state.selected_map_index = 2
	state.start_new_match()
	state.change_state(state.State.ROUND)
	game.perk_director.set_physics_process(false)
	for p in game.players:
		p.set_physics_process(false)
		p.is_bot = false
		p.alive = false
		p.collision_layer = 0
	for wall in get_nodes_in_group("arena_solids") + get_nodes_in_group("crumble_platforms"):
		wall.collision_layer = 0
	var fixture: Array = []
	for rect in [Rect2(780,0,100,495),Rect2(0,0,780,60),Rect2(0,60,60,435),Rect2(60,430,720,65)]:
		var wall: Node = game._make_wall(rect.get_center(),rect.size,Color.WHITE,Color.WHITE,true)
		fixture.append(wall)
	await physics_frame
	await process_frame
	var s := shot(Rules.Kind.RICOCHET,Vector2(750,220),Vector2(300,0))
	s._move_perk(Vector2(50,0))
	check(s.bounce_count == 1 and s.velocity_v.x < 0,"Right wall causes exactly one reflection")
	s.position = Vector2(400,90)
	s.velocity_v = Vector2(0,-300)
	s._move_perk(Vector2(0,-50))
	check(s.bounce_count == 2 and s.velocity_v.y > 0,"Ceiling counts as second surface")
	s.position = Vector2(400,400)
	s.velocity_v = Vector2(0,300)
	s._move_perk(Vector2(0,50))
	check(s.bounce_count == 3 and s.velocity_v.y < 0,"Floor counts as third surface")
	s.position = Vector2(90,300)
	s.velocity_v = Vector2(-300,0)
	s._move_perk(Vector2(-60,0))
	check(s.bounce_count == 3 and s.stuck,"Fourth terrain contact sticks; never a fourth bounce")
	s.free()
	var a = game.players[0]
	var b = game.players[1]
	for p in [a,b]:
		p.alive = true
		p.collision_layer = 1
		p.hp = 5
		p.hurt_iframe_until = 0
		p.is_defending = false
		p.is_iframe = false
	a.position = Vector2(200,300)
	b.position = Vector2(650,300)
	s = shot(Rules.Kind.RICOCHET,Vector2(230,300),Vector2(-300,0))
	s.bounce_count = 1
	check(a.hit_by_shuriken(s) and a.hp == 4,"Bounced perk can damage its owner")
	s.free()
	a.hurt_iframe_until = 0
	a.hp = 5
	s = shot(Rules.Kind.MISDIRECTION,Vector2(620,300),Vector2(300,0))
	check(b.hit_by_shuriken(s) and b.reverse_left == Rules.REVERSE_SECONDS and b.hp == 4,"Reverse applies only with a damaging hit")
	b.hurt_iframe_until = 0
	b.reverse_left = 1
	b.hit_by_shuriken(s)
	check(b.reverse_left == 1,"Further reverse hits cannot extend the timer")
	s.free()
	b.reverse_left = 0
	b.hurt_iframe_until = 0
	b.is_iframe = true
	s = shot(Rules.Kind.MISDIRECTION,Vector2(620,300),Vector2(300,0))
	b.stash = 0
	check(b.hit_by_shuriken(s) and b.reverse_left == 0 and b.stash == 1,"Dash catches a special blade without the curse")
	s.free()
	b.is_iframe = false
	b.position = Vector2(600,300)
	var barrier: Node = game._make_wall(Vector2(440,270),Vector2(20,180),Color.WHITE,Color.WHITE,true)
	await physics_frame
	await process_frame
	s = shot(Rules.Kind.SWAP,Vector2(220,300),Vector2(500,0))
	var hp: int = b.hp
	s._move_perk(Vector2(440,0))
	check(s.consumed and a.position == Vector2(600,300) and b.position == Vector2(200,300),"Phase shot crosses a solid wall and swaps first enemy")
	check(b.hp == hp and a.velocity == Vector2.ZERO and b.velocity == Vector2.ZERO,"Swap deals no damage or inherited momentum")
	await process_frame
	var c = game.players[2]
	c.alive = true
	c.collision_layer = 1
	c.position = a.position
	await physics_frame
	await process_frame
	check(not b.swap_with(a),"Swap refuses a destination overlapping a third fighter")
	c.alive = false
	c.collision_layer = 0
	for p in [a,b]:
		p.hp = 5
		p.hurt_iframe_until = 0
	a.position = Vector2(350,270)
	b.position = Vector2(530,270)
	s = shot(Rules.Kind.SEEKER,Vector2(370,270),Vector2(648,0))
	check(s.seeker_target == b.slot,"Seeker chooses nearest opponent at launch")
	var went_around := false
	for frame in 119:
		if s.consumed or s.stuck:
			break
		s._physics_process(1.0/60)
		if s.position.y < 174 or s.position.y > 366:
			went_around = true
	check(went_around,"Seeker routes around an occluding platform")
	check(not s.stuck,"Seeker avoids the platform rather than embedding in it")
	print("SEEKER end=",s.position," hp=",b.hp," left=",s.perk_left)
	if not s.consumed:
		s.free()
	await process_frame
	s = shot(Rules.Kind.SEEKER,Vector2(350,100),Vector2(300,0))
	s.perk_left = 0.01
	s._physics_process(0.02)
	check(s.perk_kind == Rules.Kind.NONE and not s.consumed,"Expired seeker continues as an ordinary blade")
	s.free()
	s = shot(Rules.Kind.SEEKER,Vector2(350,100),Vector2(300,0))
	s.deflect(2,-1)
	check(s.perk_kind == Rules.Kind.NONE and s.thrower_slot == 2 and s.velocity_v.x < 0,"Katana deflection transfers ownership and breaks tracking")
	s.free()
	s = shot(Rules.Kind.RICOCHET,Vector2(350,100),Vector2(300,0))
	s.perk_left = 0.01
	s._physics_process(0.02)
	check(s.perk_kind == Rules.Kind.NONE and s.ricocheted and not s.can_hit_owner(),"Ricochet timeout ends the hazard without destroying ammunition")
	s.free()
	s = shot(Rules.Kind.SWAP,Vector2(440,270),Vector2(300,0))
	s.perk_left = 0.01
	s._physics_process(0.02)
	check(s.consumed,"Phase blade expires without materializing inside a wall")
	await process_frame
	barrier.free()
	var director = game.perk_director
	director.reset()
	a.clear_perks()
	b.clear_perks()
	director.add_pickup(Rules.Kind.SEEKER,a.position,0)
	b.position = a.position
	director.advance(0)
	check(a.perk_charges+b.perk_charges == 1 and director.pickups.is_empty(),"Simultaneous pickup grants only one player the perk")
	director.add_pickup(Rules.Kind.SWAP,Vector2(400,100),0)
	director.advance(0)
	check(director.pickups.is_empty(),"Swap pickup is removed when only two fighters remain")
	director.add_pickup(Rules.Kind.RICOCHET,Vector2(400,100),0)
	director.advance(8.1)
	check(director.pickups.is_empty(),"Unclaimed capsule expires")
	var seen := {}
	for i in 200:
		director.begin_round()
		check(director.events[0].at >= 5 and director.events[0].at <= 9,"First warning occurs before 6–10 second spawn")
		var kind := "double" if director.events[0].count == 2 else "sequential" if director.events.size() == 2 else "single"
		seen[kind] = true
	check(seen.size() == 3,"Schedule includes single, sequential and simultaneous variants")
	director.add_pickup(Rules.Kind.RICOCHET,Vector2(400,100),0)
	var clone = load("res://perk_director.gd").new()
	clone.apply_snapshot(director.snapshot())
	check(clone.snapshot() == director.snapshot(),"Client receives identical capsule position, type and lifetime")
	clone.free()
	a.reverse_left = 3
	a.respawn(Vector2(300,414))
	check(a.perk_kind == 0 and a.reverse_left == 0,"Round respawn clears charges and confusion")
	a.respawn(Vector2(300,250))
	a.reverse_left = 0.05
	Input.action_press(a.input_right)
	root.get_node("PlayerInput").capture()
	a._physics_process(1.0/60)
	check(a.velocity.x < 0 and a._aim_direction().x > 0,"Captured right input moves left while aiming stays right")
	a.reverse_left = 0.001
	a.velocity = Vector2.ZERO
	a._physics_process(1.0/60)
	check(a.reverse_left == 0 and a.velocity.x > 0,"Real physics timer restores movement without releasing the key")
	Input.action_release(a.input_right)
	root.get_node("PlayerInput").capture()
	state.change_state(state.State.TITLE)
	check(director.pickups.is_empty() and director.events.is_empty(),"Leaving the match removes pickups and scheduled events")
	game.queue_free()
	await process_frame
	print("Perk integration: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
