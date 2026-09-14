extends SceneTree

var checks := 0
var failures := 0
var game: Node
var audio: Node
var fighter: Node

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func catch_sounds() -> int:
	var count := 0
	for node in audio.get_children():
		if node is AudioStreamPlayer and node.stream == audio._streams["catch"]:
			check(node.bus == "SFX" and node.playing, "Catch feedback plays through the effects volume bus")
			count += 1
	return count

func blade(ricocheted: bool = false) -> Node:
	var star: Node = load("res://shuriken.gd").new()
	star.thrower_slot = 2
	star.throw_time = -10.0
	star.velocity_v = Vector2(-200, 0)
	star.ricocheted = ricocheted
	game.arena_root.add_child(star)
	star.set_physics_process(false)
	return star

func run() -> void:
	game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	audio = root.get_node("Audio")
	var state: Node = root.get_node("GameState")
	var net: Node = root.get_node("Net")
	game.set_process(false)
	for player in game.players:
		player.set_physics_process(false)
	await physics_frame
	await process_frame
	state.current_state = state.State.ROUND
	fighter = game.players[0]
	fighter.is_iframe = true
	fighter.stash = 2
	var before := catch_sounds()
	var caught := blade()
	caught._on_body_entered(fighter)
	check(fighter.stash == 3 and caught.consumed, "A successful dodge catch adds the blade to the stash")
	check(catch_sounds() == before + 1, "A successful catch plays one confirmation")
	caught._on_body_entered(fighter)
	check(catch_sounds() == before + 1 and fighter.stash == 3, "Repeated contact cannot duplicate the catch or sound")
	fighter.stash = 5
	var full := blade()
	before = catch_sounds()
	full._on_body_entered(fighter)
	check(not full.consumed and fighter.stash == 5 and catch_sounds() == before, "A full stash deflects without a false catch confirmation")
	full.queue_free()
	fighter.is_iframe = false
	fighter.stash = 2
	var ricochet := blade(true)
	before = catch_sounds()
	ricochet._on_body_entered(fighter)
	check(ricochet.consumed and fighter.stash == 3 and catch_sounds() == before + 1, "Catching a ricochet also confirms the successful catch")
	fighter.is_defending = true
	fighter.facing = 1
	fighter.hurt_iframe_until = 0.0
	var guarded := blade()
	before = catch_sounds()
	guarded._on_body_entered(fighter)
	check(not guarded.consumed and fighter.stash == 3 and catch_sounds() == before, "Katana blocking does not play the catch confirmation")
	guarded.queue_free()
	check("catch" in net.RELAY_SFX, "The host relays catch feedback to online players")
	net.mode = net.NetMode.CLIENT
	before = catch_sounds()
	net._sfx("catch")
	check(catch_sounds() == before + 1, "An online guest plays the received catch sound once")
	net.mode = net.NetMode.OFFLINE
	var stream: AudioStreamWAV = audio._streams["catch"]
	check(stream.get_length() >= 0.08 and stream.get_length() <= 0.2, "Catch confirmation stays short")
	var audible := false
	for sample in stream.data:
		if sample != 0:
			audible = true
			break
	check(audible, "Catch confirmation contains audible PCM samples")
	game.queue_free()
	await process_frame
	print("Catch feedback: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
