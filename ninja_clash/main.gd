## Composes the game scene and coordinates match setup, round flow and screen transitions.

extends Node2D

const FighterArt := preload("res://fighter_art.gd")

const ArenaFactory := preload("res://arena_factory.gd")
const Arena := preload("res://arena_rules.gd")
const MAP_W := int(Arena.WIDTH)
const MAP_H := int(Arena.HEIGHT)
const PLAYER_W := 20.0
const PLAYER_H := 32.0

const STAGE_DURATIONS: Array = [2.0, 0.8, 0.8, 0.8, 0.7]
const STAGE_TEXTS: Array = ["", "3", "2", "1", "FIGHT!"]
const STAGE_SOUNDS: Array = ["", "countdown", "countdown", "countdown", "round_start"]

const STAGE_TEXTURES: Array = [
	null,
	preload("res://sprites/countdown/countdown_3_premium_native.png"),
	preload("res://sprites/countdown/countdown_2_premium_native.png"),
	preload("res://sprites/countdown/countdown_1_premium_native.png"),
	preload("res://sprites/countdown/fight_premium_native.png"),
]

const ROUND_WORD_TEX := preload("res://sprites/round-counter/round_word_native.png")
const DIGIT_TEXS: Array = [
	preload("res://sprites/round-counter/digit_0_native.png"),
	preload("res://sprites/round-counter/digit_1_native.png"),
	preload("res://sprites/round-counter/digit_2_native.png"),
	preload("res://sprites/round-counter/digit_3_native.png"),
	preload("res://sprites/round-counter/digit_4_native.png"),
	preload("res://sprites/round-counter/digit_5_native.png"),
	preload("res://sprites/round-counter/digit_6_native.png"),
	preload("res://sprites/round-counter/digit_7_native.png"),
	preload("res://sprites/round-counter/digit_8_native.png"),
	preload("res://sprites/round-counter/digit_9_native.png"),
]
const ROUND_GAP_WORD := 24.0
const ROUND_GAP_DIGIT := 4.0

const WINS_TEX := preload("res://sprites/player-win/wins_native.png")
const PLAYER_TEXS: Array = [
	null,
	preload("res://sprites/player-win/p1_native.png"),
	preload("res://sprites/player-win/p2_native.png"),
	preload("res://sprites/player-win/p3_native.png"),
	preload("res://sprites/player-win/p4_native.png"),
]

var perk_director: Node2D
var round_clock: Node
var arena_root: Node2D
var sky_bg_solid: ColorRect
var sky_rect: TextureRect
var bg_decorations: Node2D
var fg_decorations: Node2D
var current_map_nodes: Array = []
var players: Array = []
var spawn_points: Array = []

var canvas: CanvasLayer
var title_screen: Control
var clan_select_screen: Control
var match_setup_screen: Control
var map_select_screen: Control
var match_end_screen: Control
var online_lobby_screen: Control
var online_menu_screen: Control
var welcome_screen: Control
var hud: Control
var mode_select_screen: Control
var banner_label: Label
var countdown_sprite: Sprite2D
var round_display: Node2D
var win_display: Node2D
var tutorial_overlay: Control
var loading_screen: Control
var is_loading := false
var pending_network_state: Dictionary = {}
var _load_generation := 0

var _in_countdown: bool = false
var _countdown_stage: int = 0
var _countdown_stage_until: float = 0.0
var _round_end_until: float = 0.0
var _round_winner_slot: int = 0
var _current_loaded_map: int = -1
var _clash_freeze_until: float = 0.0

func _ready() -> void:
	print("[MAIN] _ready()")
	add_child(preload("res://input_bindings.gd").new())
	_build_arena()
	perk_director = preload("res://perk_director.gd").new()
	arena_root.add_child(perk_director)
	round_clock = preload("res://round_clock.gd").new()
	add_child(round_clock)
	round_clock.expired.connect(_on_round_timeout)
	_build_overlays()
	Net.register_main(self)
	GameState.state_changed.connect(_on_state_changed)
	Combat.kill_logged.connect(_on_kill_logged)
	Combat.clash_occurred.connect(_on_clash)
	GameState.change_state(GameState.State.WELCOME)
	_handle_dev_args()
	if OS.is_debug_build() and OS.has_feature("web"):
		var probe := Node.new()
		probe.set_script(load("res://dev_web_probe.gd"))
		add_child(probe)
	print("[MAIN] _ready() complete")

func _handle_dev_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--host":
			Net.player_name = "Host"
			var err: String = Net.host_game()
			print("[DEV] host_game: ", "ok" if err == "" else err)
		elif arg.begins_with("--join="):
			Net.player_name = "Guest"
			var err: String = Net.join_game(arg.substr(7))
			print("[DEV] join_game: ", "ok" if err == "" else err)
			GameState.change_state(GameState.State.ONLINE_MENU)
		elif arg == "--online-autotest":
			var driver := Node.new()
			driver.set_script(load("res://dev_online_autotest.gd"))
			add_child(driver)

func _build_arena() -> void:
	arena_root = Node2D.new()
	arena_root.name = "ArenaRoot"
	add_child(arena_root)
	var camera := Camera2D.new()
	camera.name = "ArenaCamera"
	camera.position = Arena.SIZE * 0.5
	camera.zoom = Arena.UI_SIZE / Arena.SIZE
	arena_root.add_child(camera)

	sky_bg_solid = ColorRect.new()
	sky_bg_solid.position = Vector2.ZERO
	sky_bg_solid.size = Vector2(MAP_W, MAP_H)
	sky_bg_solid.color = Color("0a081a")
	sky_bg_solid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky_bg_solid.z_index = -15
	arena_root.add_child(sky_bg_solid)

	sky_rect = TextureRect.new()
	sky_rect.position = Vector2.ZERO
	sky_rect.size = Arena.SIZE
	sky_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sky_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	sky_rect.z_index = -10
	arena_root.add_child(sky_rect)

	var DecoScript: Script = load("res://decorations.gd")
	bg_decorations = Node2D.new()
	bg_decorations.set_script(DecoScript)
	bg_decorations.z_index = -5
	arena_root.add_child(bg_decorations)

	fg_decorations = Node2D.new()
	fg_decorations.set_script(DecoScript)
	fg_decorations.z_index = -2
	arena_root.add_child(fg_decorations)

	spawn_points = Maps.get_map(GameState.selected_map_index).spawn_points.duplicate()
	_ensure_player_count(GameState.num_players())

func _player_spawn(slot: int) -> Vector2:
	var pts: Array = spawn_points
	var idx: int = slot - 1
	if idx >= 0 and idx < pts.size():
		return pts[idx]

	push_warning("Spawn: slot %d has no dedicated spawn (only %d points); using spread fallback" % [slot, pts.size()])
	return Vector2(120.0 + idx * 240.0, 424.0)

func _make_player(slot: int) -> CharacterBody2D:
	var p: CharacterBody2D = CharacterBody2D.new()
	p.set_script(load("res://player.gd"))
	p.slot = slot
	p.facing = 1 if slot <= 2 else -1
	p.position = _player_spawn(slot)
	var col: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(PLAYER_W, PLAYER_H)
	col.shape = rect
	p.add_child(col)
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = "Visual"
	sprite.centered = true
	sprite.hframes = FighterArt.COLUMNS
	sprite.vframes = FighterArt.ANIMATIONS.size()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.texture = load(FighterArt.path(0, GameState.get_clan(slot).sprite))
	sprite.material = null
	p.add_child(sprite)
	arena_root.add_child(p)
	return p

func _ensure_player_count(n: int) -> void:
	while players.size() < n:
		players.append(_make_player(players.size() + 1))
	while players.size() > n:
		var p = players.pop_back()
		p.queue_free()

func _build_overlays() -> void:
	canvas = CanvasLayer.new()
	add_child(canvas)

	var TitleScript: Script = load("res://title_screen.gd")
	title_screen = Control.new()
	title_screen.hide()
	title_screen.set_script(TitleScript)
	canvas.add_child(title_screen)

	var ModeSelScript: Script = load("res://mode_select.gd")
	mode_select_screen = Control.new()
	mode_select_screen.set_script(ModeSelScript)
	canvas.add_child(mode_select_screen)

	online_lobby_screen = Control.new()
	online_lobby_screen.set_script(load("res://online_lobby.gd"))
	canvas.add_child(online_lobby_screen)

	var ClanSelScript: Script = load("res://clan_select.gd")
	clan_select_screen = Control.new()
	clan_select_screen.set_script(ClanSelScript)
	canvas.add_child(clan_select_screen)

	var MatchSetupScript: Script = load("res://match_setup.gd")
	match_setup_screen = Control.new()
	match_setup_screen.set_script(MatchSetupScript)
	canvas.add_child(match_setup_screen)

	var MapSelScript: Script = load("res://map_select.gd")
	map_select_screen = Control.new()
	map_select_screen.set_script(MapSelScript)
	canvas.add_child(map_select_screen)

	var MatchEndScript: Script = load("res://match_end.gd")
	match_end_screen = Control.new()
	match_end_screen.set_script(MatchEndScript)
	canvas.add_child(match_end_screen)

	var OnlineScript: Script = load("res://online_menu.gd")
	online_menu_screen = Control.new()
	online_menu_screen.set_script(OnlineScript)
	canvas.add_child(online_menu_screen)
	welcome_screen = Control.new()
	welcome_screen.set_script(load("res://welcome_screen.gd"))
	welcome_screen.completed.connect(func() -> void:
		if GameState.current_state == GameState.State.WELCOME:
			GameState.change_state(GameState.State.ONLINE_MENU if Net.pending_invitation() != "" else GameState.State.TITLE))
	canvas.add_child(welcome_screen)

	var HudScript: Script = load("res://hud.gd")
	hud = Control.new()
	hud.set_script(HudScript)
	hud.anchor_right = 1.0
	hud.anchor_bottom = 1.0
	canvas.add_child(hud)

	banner_label = Label.new()
	banner_label.position = Vector2(0, 130)
	banner_label.size = Vector2(800, 90)
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner_label.add_theme_font_size_override("font_size", 64)
	banner_label.add_theme_color_override("font_color", Color("f0eee8"))
	banner_label.text = ""
	canvas.add_child(banner_label)

	countdown_sprite = Sprite2D.new()
	countdown_sprite.position = Vector2(400, 175)
	countdown_sprite.visible = false
	canvas.add_child(countdown_sprite)

	round_display = Node2D.new()
	round_display.position = Vector2(400, 175)
	round_display.visible = false
	canvas.add_child(round_display)

	win_display = Node2D.new()
	win_display.position = Vector2(400, 175)
	win_display.visible = false
	canvas.add_child(win_display)

	var pause_layer: CanvasLayer = CanvasLayer.new()
	pause_layer.layer = 20
	pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(pause_layer)
	var pause_menu: Control = Control.new()
	pause_menu.set_script(load("res://pause_menu.gd"))
	pause_layer.add_child(pause_menu)

	var tutorial_layer: CanvasLayer = CanvasLayer.new()
	tutorial_layer.layer = 15
	add_child(tutorial_layer)
	tutorial_overlay = Control.new()
	tutorial_overlay.set_script(load("res://tutorial_overlay.gd"))
	tutorial_layer.add_child(tutorial_overlay)
	tutorial_overlay.closed.connect(_start_countdown)
	var loading_layer := CanvasLayer.new()
	loading_layer.layer = 20
	add_child(loading_layer)
	loading_screen = preload("res://match_loading.gd").new()
	loading_layer.add_child(loading_screen)

func _on_state_changed(s: int) -> void:
	var interrupted_loading := is_loading
	if is_loading:
		_load_generation += 1
		is_loading = false
		pending_network_state.clear()
		loading_screen.finish()

	if Engine.time_scale != 1.0:
		Engine.time_scale = 1.0
	_clash_freeze_until = 0.0
	var S = GameState.State
	welcome_screen.visible = (s == S.WELCOME)
	title_screen.visible = (s == S.TITLE)
	mode_select_screen.visible = (s == S.MODE_SELECT)
	clan_select_screen.visible = (s == S.CLAN_SELECT)
	match_setup_screen.visible = (s == S.MATCH_SETUP)
	map_select_screen.visible = (s == S.MAP_SELECT)
	match_end_screen.visible = (s == S.MATCH_END)
	online_menu_screen.visible = (s == S.ONLINE_MENU)
	online_lobby_screen.visible = (s == S.ONLINE_LOBBY)
	arena_root.visible = (s == S.MATCH_INTRO or s == S.ROUND or s == S.ROUND_END or s == S.MATCH_END)
	hud.visible = (s == S.MATCH_INTRO or s == S.ROUND or s == S.ROUND_END)
	win_display.visible = false

	if s not in [S.MATCH_INTRO, S.ROUND, S.ROUND_END]:
		_in_countdown = false
		countdown_sprite.hide()
		round_display.hide()
		tutorial_overlay.hide()
		banner_label.text = ""
	if s == S.MATCH_INTRO:
		if (GameState.current_round == 1 or interrupted_loading) and DisplayServer.get_name() != "headless":
			_load_match_intro()
		else:
			_enter_match_intro()
	elif s == S.ROUND:
		_enter_round()
	elif s == S.ROUND_END:
		_enter_round_end()
	elif s == S.TITLE:
		banner_label.text = ""
		_clear_shurikens()

func _load_match_intro() -> void:
	_load_generation += 1
	var generation := _load_generation
	var still_needed := func() -> bool: return generation == _load_generation and GameState.current_state == GameState.State.MATCH_INTRO
	is_loading = true
	_in_countdown = false
	arena_root.hide()
	hud.hide()
	loading_screen.open(Maps.get_map(GameState.selected_map_index).name)
	# Give both Godot and the browser compositor a frame before loading or creating nodes.
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	if not still_needed.call():
		return
	var paths: Array[String] = []
	loading_screen.collect_paths(Maps.get_map(GameState.selected_map_index), paths)
	for slot in range(1, GameState.num_players() + 1):
		var clan: Dictionary = GameState.get_clan(slot)
		loading_screen.collect_paths(FighterArt.path(GameState.skin_index(slot), clan.sprite), paths)
		loading_screen.collect_paths("res://sprites/katanas/katana_%s_6frame_native_144x16.png" % clan.sprite, paths)
	var prepared: bool = await loading_screen.prepare(paths, still_needed)
	if not still_needed.call():
		return
	if not prepared:
		Net.leave("UNABLE TO LOAD ARENA")
		GameState.change_state(GameState.State.TITLE)
		return
	_enter_match_intro()
	arena_root.show()
	hud.show()
	loading_screen.complete()
	# First-use texture upload and shader compilation happen underneath the opaque overlay.
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	if not still_needed.call():
		return
	is_loading = false
	loading_screen.finish()
	_finish_match_intro()
	if not pending_network_state.is_empty():
		var pending := pending_network_state.duplicate(true)
		pending_network_state.clear()
		Net._apply_state(pending.state, pending.bundle)

func _enter_match_intro() -> void:
	_round_winner_slot = 0
	# Clear the previous round's result so "DRAW" doesn't sit behind the next countdown.
	banner_label.text = ""
	round_clock.start(MatchConfig.round_time_seconds)
	_clear_shurikens()
	if _current_loaded_map != GameState.selected_map_index:
		_load_map(GameState.selected_map_index)
	for node in current_map_nodes:
		if node.has_method("reset_platform"):
			node.reset_platform()
	_ensure_player_count(GameState.num_players())
	for p in players:
		var clan = GameState.get_clan(p.slot)
		var sprite: Sprite2D = p.get_node("Visual")
		var skin_idx: int = GameState.skin_index(p.slot)
		sprite.texture = load(FighterArt.path(skin_idx, clan.sprite))
		sprite.hframes = FighterArt.COLUMNS
		sprite.vframes = FighterArt.ANIMATIONS.size()
		sprite.frame = 0
		sprite.scale = Vector2.ONE
		sprite.offset = Vector2.ZERO
		sprite.material = null
		sprite.modulate = Color.WHITE
		var kat_path := "res://sprites/fighters/katana.png"
		var old_kat: Node = p.get_node_or_null("Katana")
		if old_kat != null:
			old_kat.name = "_old_katana"
			old_kat.queue_free()
		var kat := Sprite2D.new()
		kat.name = "Katana"
		kat.texture = load(kat_path)
		kat.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		kat.material = FighterArt.material_for(clan.color)
		kat.visible = false
		p.add_child(kat)
		p.katana_sprite = kat

		for child in p.get_children():
			if String(child.name).begins_with("Indicators"):
				child.name = "_old_indicators"
				child.queue_free()
		var ind_root: Node2D = Node2D.new()
		ind_root.name = "Indicators"

		ind_root.z_index = 100
		p.add_child(ind_root)
		var cc: Color = clan.color

		const ROW_GAP := 8.5
		var stash_row: int = MatchConfig.STASH_CAP if MatchConfig.shurikens_enabled else 0
		var katana_row: int = MatchConfig.effective_katana_charges()
		var y: float = -24.0
		var hres: Dictionary = _make_icon_grid(ind_root, MatchConfig.max_hp, "res://sprites/heart.svg", -1, 1, 0.5, 7.0, ROW_GAP, 5, y, Color(0.95, 0.25, 0.30, 1.0))
		p.heart_icons = hres["icons"]
		y = hres["top_y"] - ROW_GAP
		var sres: Dictionary = _make_icon_grid(ind_root, stash_row, "res://sprites/shuriken.svg", -1, 1, 0.5, 6.5, ROW_GAP, 99, y, Color(cc.r, cc.g, cc.b, 1.0))
		p.stash_icons = sres["icons"]
		if stash_row > 0:
			y = sres["top_y"] - ROW_GAP

		var kres: Dictionary = _make_icon_grid(ind_root, katana_row, "res://sprites/katanas/katana_%s_6frame_native_144x16.png" % clan.sprite, 2, 6, 0.5, 6.0, ROW_GAP, 99, y, Color(0.85, 0.88, 0.95, 1.0))
		p.katana_icons = kres["icons"]
		if katana_row > 0:
			y = kres["top_y"] - ROW_GAP

		var gb_y: float = y - 1.5
		var gb_bg: ColorRect = ColorRect.new()
		gb_bg.color = Color(0.0, 0.0, 0.0, 0.55)
		gb_bg.size = Vector2(26.0, 4.0)
		gb_bg.position = Vector2(-13.0, gb_y)
		gb_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ind_root.add_child(gb_bg)
		var gb_fill: ColorRect = ColorRect.new()
		gb_fill.color = Color(0.4, 0.8, 1.0, 0.95)
		gb_fill.size = Vector2(26.0, 4.0)
		gb_fill.position = Vector2(-13.0, gb_y)
		gb_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ind_root.add_child(gb_fill)
		p.guard_bar_bg = gb_bg
		p.guard_bar_fill = gb_fill
		p.respawn(_player_spawn(p.slot))
		p.is_bot = GameState.slot_is_bot(p.slot)
		p.bot_difficulty = GameState.ai_difficulty
		if p.is_bot:
			p._prepare_bot()

	_separate_overlapping_spawns()

	if not is_loading:
		_finish_match_intro()

func _finish_match_intro() -> void:
	if GameState.current_round == 1 and Settings.show_tutorial:
		tutorial_overlay.open()
	else:
		_start_countdown()

func _enter_round() -> void:
	round_clock.start(MatchConfig.round_time_seconds)
	perk_director.begin_round()
	_in_countdown = false
	banner_label.text = ""

	countdown_sprite.visible = false
	round_display.visible = false

func _separate_overlapping_spawns() -> void:
	var too_close: bool = false
	for i in players.size():
		for j in range(i + 1, players.size()):
			if players[i].position.distance_to(players[j].position) < 120.0:
				too_close = true
	if not too_close:
		return

	var report: String = ""
	for p in players:
		report += " slot%d=(%.0f,%.0f)" % [p.slot, p.position.x, p.position.y]
	push_warning("Spawn safety net FIRED (round %d):%s — re-placing at canonical spawns" % [GameState.current_round, report])
	print("[SPAWN-FIX] round %d overlap detected:%s" % [GameState.current_round, report])
	for p in players:
		p.position = _player_spawn(p.slot)
		p.velocity = Vector2.ZERO

func _enter_round_end() -> void:
	round_clock.stop()
	_round_end_until = Time.get_ticks_msec() / 1000.0 + 1.6
	var winner_slot: int = _round_winner_slot
	if winner_slot > 0:
		_show_round_winner(winner_slot)
	else:
		banner_label.text = "DRAW"

func _start_countdown() -> void:
	_in_countdown = true
	_countdown_stage = 0
	_advance_countdown_stage()

func _advance_countdown_stage() -> void:
	if _countdown_stage == 0:

		countdown_sprite.visible = false
		_show_round_number(GameState.current_round)
		round_display.visible = true
		_pop_node(round_display, 1.25)
	else:

		round_display.visible = false
		countdown_sprite.texture = STAGE_TEXTURES[_countdown_stage]
		countdown_sprite.visible = true
		_pop_node(countdown_sprite, 2.0 if _countdown_stage >= 4 else 1.5)
		var snd: String = STAGE_SOUNDS[_countdown_stage]
		if snd != "":
			Audio.play(snd)
	_countdown_stage_until = Time.get_ticks_msec() / 1000.0 + STAGE_DURATIONS[_countdown_stage]

func _show_round_number(n: int) -> void:
	for c in round_display.get_children():
		c.free()
	var digits: String = str(maxi(n, 0))
	var total: float = float(ROUND_WORD_TEX.get_width()) + ROUND_GAP_WORD
	for ch in digits:
		total += float(DIGIT_TEXS[int(ch)].get_width()) + ROUND_GAP_DIGIT
	total -= ROUND_GAP_DIGIT
	var x: float = -total * 0.5
	x = _place_glyph(round_display, ROUND_WORD_TEX, x) + ROUND_GAP_WORD
	for ch in digits:
		x = _place_glyph(round_display, DIGIT_TEXS[int(ch)], x) + ROUND_GAP_DIGIT

func _show_round_winner(slot: int) -> void:
	for c in win_display.get_children():
		c.free()
	if slot < 1 or slot >= PLAYER_TEXS.size() or PLAYER_TEXS[slot] == null:
		win_display.visible = false
		return
	var p_tex: Texture2D = PLAYER_TEXS[slot]
	var total: float = float(p_tex.get_width()) + ROUND_GAP_WORD + float(WINS_TEX.get_width())
	var x: float = -total * 0.5
	x = _place_glyph(win_display, p_tex, x) + ROUND_GAP_WORD
	_place_glyph(win_display, WINS_TEX, x)
	win_display.visible = true
	_pop_node(win_display, 1.4)

func _place_glyph(parent: Node2D, tex: Texture2D, x: float) -> float:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.position = Vector2(x, -tex.get_height() * 0.5)
	parent.add_child(s)
	return x + tex.get_width()

func _pop_node(node: Node2D, from: float) -> void:
	node.scale = Vector2(from, from)
	node.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(node, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "modulate:a", 1.0, 0.14)

func _on_kill_logged(_killer: int, _victim: int) -> void:
	if GameState.current_state != GameState.State.ROUND:
		return

	var alive_count: int = 0
	_round_winner_slot = 0
	for p in players:
		if p.alive:
			alive_count += 1
			_round_winner_slot = p.slot
	if alive_count <= 1:
		_finish_round(_round_winner_slot if alive_count == 1 else 0)

func _finish_round(winner: int) -> void:
	if Net.is_client() or GameState.current_state != GameState.State.ROUND:
		return
	_round_winner_slot = winner
	if winner > 0:
		Combat.award_survivor(winner)
	round_clock.stop()
	GameState.change_state(GameState.State.ROUND_END)

func _on_round_timeout(overtime: bool) -> void:
	if Net.is_client() or GameState.current_state != GameState.State.ROUND:
		return
	if overtime:
		_finish_round(0)
		return
	var best_hp := 0
	var leaders: Array = []
	for p in players:
		if not p.alive:
			continue
		if p.hp > best_hp:
			best_hp = p.hp
			leaders.clear()
		if p.hp == best_hp:
			leaders.append(p)
	if leaders.size() <= 1:
		_finish_round(leaders[0].slot if not leaders.is_empty() else 0)
		return
	for p in players:
		if not p.alive:
			continue
		if leaders.has(p):
			p.hp = 1
			p.hurt_iframe_until = 0
		else:
			p.hp = 0
			p._die(Vector2.ZERO, 0, false)
	round_clock.start_overtime()
	Audio.play("countdown")

func _on_clash(a: Node, b: Node, midpoint: Vector2) -> void:

	_spawn_fx("res://sprites/fx/clash_lightning_5frame_native_160x32.png", 5, midpoint, 12.0, 2.0)

	var dir_a: int = 1 if a.global_position.x >= b.global_position.x else -1
	var until: float = Time.get_ticks_msec() / 1000.0 + Combat.clash_freeze_duration_s
	if a.has_method("apply_clash_recoil"):
		a.apply_clash_recoil(dir_a)
		a.frozen_until = until
	if b.has_method("apply_clash_recoil"):
		b.apply_clash_recoil(-dir_a)
		b.frozen_until = until
	Audio.play("hit")

func _spawn_fx(tex_path: String, frame_count: int, pos: Vector2, fps: float, scale: float) -> void:
	if not ResourceLoader.exists(tex_path):
		return
	var fx: Sprite2D = Sprite2D.new()
	fx.set_script(load("res://fx_anim.gd"))
	fx.frame_count = frame_count
	fx.fps = fps
	fx.texture = load(tex_path)
	fx.position = pos
	fx.scale = Vector2(scale, scale)
	fx.z_index = 60
	arena_root.add_child(fx)
	Net.relay_strip_fx(tex_path, frame_count, fps, pos, fx.scale, 60)

func _process(_delta: float) -> void:
	var t: float = Time.get_ticks_msec() / 1000.0

	if _clash_freeze_until > 0.0 and t >= _clash_freeze_until:
		_clash_freeze_until = 0.0
		Engine.time_scale = 1.0
	if _in_countdown and t >= _countdown_stage_until:
		_countdown_stage += 1
		if _countdown_stage >= STAGE_DURATIONS.size():
			_in_countdown = false
			banner_label.text = ""
			countdown_sprite.visible = false
			round_display.visible = false

			if not Net.is_client():
				_separate_overlapping_spawns()
				GameState.change_state(GameState.State.ROUND)
		else:
			_advance_countdown_stage()
	if GameState.current_state == GameState.State.ROUND_END and not Net.is_client():
		if t >= _round_end_until:
			GameState.advance_round_or_end_match()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var s = GameState.current_state
		var S = GameState.State

		if event.keycode == KEY_ESCAPE:

			if s == S.MATCH_INTRO and tutorial_overlay != null and tutorial_overlay.visible:
				return

			if Net.is_online():
				return
			if s == S.MATCH_INTRO or s == S.ROUND_END:
				print("[MAIN] ESC during transition -> TITLE")
				GameState.change_state(S.TITLE)
				get_viewport().set_input_as_handled()

func _load_map(index: int) -> void:
	_current_loaded_map = index
	for n in current_map_nodes:
		if is_instance_valid(n):
			n.queue_free()
	current_map_nodes.clear()

	var data: Dictionary = Maps.get_map(index)
	spawn_points = data.spawn_points.duplicate()

	var using_image: bool = ArenaFactory.apply_sky(sky_bg_solid, sky_rect, data.get("sky_top", data.bg_color), data.get("sky_bot", data.bg_color), data.get("background", ""))

	sky_rect.modulate = data.get("background_tint", Color.WHITE)
	sky_bg_solid.visible = not using_image

	bg_decorations.commands = [] if using_image else data.get("bg_decorations", [])
	bg_decorations.queue_redraw()

	fg_decorations.commands = data.get("fg_decorations", [])
	fg_decorations.queue_redraw()

	var terrain := Node2D.new()
	terrain.set_script(preload("res://arena_terrain.gd"))
	terrain.walls = data.walls
	terrain.atlas = load(data.walls[0].sprite)
	terrain.edge_color = data.wall_edge_color
	terrain.theme = data.ambience
	arena_root.add_child(terrain)
	current_map_nodes.append(terrain)
	for w in data.walls:
		var body := ArenaFactory.make_solid(arena_root, w.center, w.size, data.wall_color, data.wall_edge_color, true)
		current_map_nodes.append(body)

	for index_in_map in data.crumble_platforms.size():
		var platform := preload("res://crumble_platform.gd").new()
		platform.name = "Crumble%d" % index_in_map
		platform.bounds = data.crumble_platforms[index_in_map]
		platform.tint = data.wall_edge_color
		platform.atlas = terrain.atlas
		arena_root.add_child(platform)
		current_map_nodes.append(platform)

	for d in data.get("deco_sprites", []):
		var deco := ArenaFactory.make_decoration(arena_root, d)
		if deco != null:
			current_map_nodes.append(deco)

	var amb := Node2D.new()
	amb.set_script(preload("res://arena_ambience.gd"))
	amb.theme = data.get("ambience", "cistern")
	amb.lamp_anchors = data.lamp_anchors
	arena_root.add_child(amb)
	current_map_nodes.append(amb)

	print("[MAIN] Loaded map %d: %s" % [index, data.name])

func _make_icon_grid(parent: Node2D, count: int, tex_path: String, frame: int, hframes: int,
		icon_scale: float, h_spacing: float, v_spacing: float, per_row: int,
		baseline_y: float, mod_color: Color) -> Dictionary:
	var icons: Array = []
	if count <= 0:
		return {"icons": icons, "top_y": baseline_y}
	var tex: Texture2D = load(tex_path) if ResourceLoader.exists(tex_path) else null
	var rows: int = int(ceil(float(count) / float(per_row)))
	for i in count:
		var row: int = i / per_row
		var col: int = i % per_row
		var in_row: int = per_row if row < rows - 1 else count - per_row * (rows - 1)
		var icon: Sprite2D = Sprite2D.new()
		icon.texture = tex
		if hframes > 1:
			icon.hframes = hframes
			icon.frame = frame
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		icon.scale = Vector2(icon_scale, icon_scale)
		icon.position = Vector2((col - (in_row - 1) * 0.5) * h_spacing, baseline_y - row * v_spacing)
		icon.modulate = mod_color
		parent.add_child(icon)
		icons.append(icon)
	return {"icons": icons, "top_y": baseline_y - (rows - 1) * v_spacing}

func _clear_shurikens() -> void:
	if perk_director != null:
		perk_director.reset()
	for child in arena_root.get_children():
		if child is Area2D:
			child.queue_free()
