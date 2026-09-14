extends GutTest
const Rules := preload("res://perk_rules.gd")
const Player := preload("res://player.gd")
const Shot := preload("res://shuriken.gd")
const Director := preload("res://perk_director.gd")
const NC := preload("res://net_codec.gd")

func test_charges_are_finite_and_do_not_stack() -> void:
	var p = autofree(Player.new())
	assert_true(p.grant_perk(Rules.Kind.SEEKER))
	assert_false(p.grant_perk(Rules.Kind.RICOCHET))
	assert_eq(p.available_shurikens(),4)
	assert_eq(p.consume_perk(),Rules.Kind.SEEKER)
	assert_eq(p.consume_perk(),Rules.Kind.NONE)
	p.reverse_left = 2
	p.clear_perks()
	assert_eq(p.reverse_left,0.0)

func test_reversal_changes_horizontal_axis_and_ends() -> void:
	var p = autofree(Player.new())
	p.reverse_left = 3
	assert_eq(p.movement_axis(-1),1.0)
	assert_eq(p.movement_axis(1),-1.0)
	assert_eq(p.movement_axis(0),0.0)
	p.reverse_left = 0
	assert_eq(p.movement_axis(-1),-1.0)

func test_bag_is_without_replacement_and_swap_requires_three_alive() -> void:
	var director = autofree(Director.new())
	director.rng.seed = 193
	for cycle in 20:
		var drawn: Array = []
		for i in 4:
			drawn.append(director.next_kind(4))
		drawn.sort()
		assert_eq(drawn,[1,2,3,4])
	for i in 100:
		assert_ne(director.next_kind(2),Rules.Kind.SWAP)

func test_special_state_replicates_and_swap_snaps() -> void:
	var source = autofree(Player.new())
	var guest = autofree(Player.new())
	source.grant_perk(Rules.Kind.RICOCHET)
	source.reverse_left = 2.5
	source.position = Vector2(400,250)
	source.teleport_revision = 1
	NC.apply_player(guest,NC.encode_player(source,0),90)
	assert_eq(guest.perk_kind,Rules.Kind.RICOCHET)
	assert_eq(guest.perk_charges,1)
	assert_eq(guest.available_shurikens(),4)
	assert_eq(guest.reverse_left,2.5)
	assert_eq(guest.position,source.position)
	var shot = autofree(Shot.new())
	shot.perk_kind = Rules.Kind.RICOCHET
	shot.perk_left = 2.1
	shot.bounce_count = 3
	var copy = autofree(Shot.new())
	copy.apply_net(NC.encode_shuriken(shot))
	assert_eq(copy.bounce_count,3)
	assert_eq(copy.perk_left,2.1)
	assert_true(copy.can_hit_owner())

func test_sweep_reports_actual_surface_normals() -> void:
	var wall := Rect2(100,100,40,40)
	assert_eq(Rules.sweep(Vector2(50,120),Vector2(100,0),wall).normal,Vector2.LEFT)
	assert_eq(Rules.sweep(Vector2(120,50),Vector2(0,100),wall).normal,Vector2.UP)
	assert_eq(Rules.sweep(Vector2(180,120),Vector2(-100,0),wall).normal,Vector2.RIGHT)
	assert_eq(Rules.sweep(Vector2(120,180),Vector2(0,-100),wall).normal,Vector2.DOWN)
	assert_true(Rules.sweep(Vector2(50,50),Vector2(100,0),wall).is_empty())
