extends GutTest
## Unit tests for the online wire formats (net_codec.gd, ADR-0003). Pure data — no network,
## no autoloads — so they run headless in GUT `-s` mode like the rest of the suite.

const NC = preload("res://net_codec.gd")
const Router = preload("res://player_input_router.gd")
const PlayerScript = preload("res://player.gd")


func test_actions_list_matches_router() -> void:
	# The intent bitmask is indexed by NetCodec.ACTIONS; the host feeds it back through
	# PlayerInputRouter, so the two action lists must stay identical (same order!).
	assert_eq(NC.ACTIONS, Router.ACTIONS)


func test_pack_mask_roundtrip() -> void:
	var values := {"left": true, "jump": true, "defend": true}
	var mask: int = NC.pack_mask(values)
	for a in NC.ACTIONS:
		assert_eq(NC.mask_has(mask, a), values.get(a, false), "bit for %s" % a)


func test_pack_mask_empty_and_full() -> void:
	assert_eq(NC.pack_mask({}), 0)
	var all := {}
	for a in NC.ACTIONS:
		all[a] = true
	var mask: int = NC.pack_mask(all)
	assert_eq(mask, (1 << NC.ACTIONS.size()) - 1)


func test_mask_has_unknown_action_is_false() -> void:
	assert_false(NC.mask_has(0x3FF, "no_such_action"))


func test_player_snapshot_roundtrip() -> void:
	var src = autofree(CharacterBody2D.new())
	src.set_script(PlayerScript)
	src.slot = 2
	src.position = Vector2(123.0, 45.0)
	src.velocity = Vector2(-80.0, 12.5)
	src.facing = -1
	src.hp = 3
	src.stash = 4
	src.katana_charges = 1
	src.guard_meter = 2.5
	src.is_swinging = true
	src.swing_start_t = 9.8          # phase 0.2 at now=10.0
	src.is_defending = false
	src.is_aiming = true
	src.aim_dir = Vector2(1, -1)
	src._aim_locked_dir = Vector2(0.7071, -0.7071)
	src.hurt_iframe_until = 10.3     # 0.3 s of hurt flash left at now=10.0

	var arr: Array = NC.encode_player(src, 10.0)
	assert_eq(arr.size(), NC.P.SIZE)

	var dst = autofree(CharacterBody2D.new())
	dst.set_script(PlayerScript)
	NC.apply_player(dst, arr, 100.0)   # a different client clock — phases must rebase

	assert_eq(dst.net_target_pos, Vector2(123.0, 45.0))
	assert_true(dst.net_has_target)
	assert_eq(dst.velocity, Vector2(-80.0, 12.5))
	assert_eq(dst.facing, -1)
	assert_eq(dst.hp, 3)
	assert_eq(dst.stash, 4)
	assert_eq(dst.katana_charges, 1)
	assert_almost_eq(dst.guard_meter, 2.5, 0.001)
	assert_true(dst.is_swinging)
	assert_almost_eq(dst.swing_start_t, 99.8, 0.001)     # same 0.2 s phase on the client clock
	assert_true(dst.is_aiming)
	assert_almost_eq(dst.hurt_iframe_until, 100.3, 0.001)
	assert_almost_eq(dst._aim_locked_dir.x, 0.7071, 0.001)


func test_player_snapshot_death_transition_sets_topple() -> void:
	var src = autofree(CharacterBody2D.new())
	src.set_script(PlayerScript)
	src.alive = false
	src.velocity = Vector2(-50.0, 0.0)
	var arr: Array = NC.encode_player(src, 5.0)

	var dst = autofree(CharacterBody2D.new())
	dst.set_script(PlayerScript)
	dst.alive = true                     # was alive → snapshot kills it
	NC.apply_player(dst, arr, 50.0)
	assert_false(dst.alive)
	assert_almost_eq(dst.death_time, 50.0, 0.001)   # topple clock starts on the client's clock
	assert_eq(dst.death_spin_dir, -1)               # matches the knockback direction


func test_shuriken_snapshot_layout() -> void:
	# The S enum indices are the wire layout — pin them so a reorder can't silently
	# desync encode_shuriken (host) from apply_net (client puppet).
	var arr: Array = [7, 10.0, 20.0, 300.0, -20.0, false, 1, true]
	assert_eq(arr.size(), NC.S.SIZE)
	assert_eq(int(arr[NC.S.ID]), 7)
	assert_eq(Vector2(arr[NC.S.X], arr[NC.S.Y]), Vector2(10, 20))
	assert_eq(Vector2(arr[NC.S.VX], arr[NC.S.VY]), Vector2(300, -20))
	assert_false(bool(arr[NC.S.STUCK]))
	assert_eq(int(arr[NC.S.THROWER]), 1)
	assert_true(bool(arr[NC.S.RICOCHET]))
