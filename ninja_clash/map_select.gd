extends Control

const UI = preload("res://menu_ui.gd")
const ROLL_DURATION := 3.25
const TRAVEL_DURATION := 2.65
const SETTLE_DURATION := 0.3
const REEL_STEP := 190.0
var cursor := 0
var thumb: TextureRect
var name_label: Label
var cards: Array[Button] = []
var preview_textures: Array[Texture2D] = []
var host_controls: Array[Button] = []
var _input_lockout_until := 0.0
var _starting := false
var _focus_index := 0
var _spinning := false
var _roll_start := 0.0
var _roll_from := 0
var _roll_target := 0
var _roll_steps := 0
var _roll_tick := -1
var _reel_view: Control
var _reel: Control
var _reel_images: Array[TextureRect] = []
var _reel_names: Array[Label] = []
var _reel_glow: ColorRect
var _roll_landed := false
var _fight: Button
var _random: Button
var _back_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	visibility_changed.connect(_on_visibility_changed)
	Net.map_cursor_changed.connect(_on_remote_cursor)
	Net.map_roll_started.connect(_on_remote_roll)
	_refresh()

func _on_visibility_changed() -> void:
	_spinning = false
	_reel_view.hide()
	if visible:
		cursor = posmod(GameState.selected_map_index, Maps.count())
		_focus_index = cursor
		_starting = false
		_input_lockout_until = Time.get_ticks_msec()/1000.0+0.2
		if Net.is_host():
			Net.send_map_cursor(cursor)
		_refresh()

func _on_remote_cursor(index: int) -> void:
	if not Net.is_client():
		return
	cursor = posmod(index, Maps.count())
	GameState.selected_map_index = cursor
	if visible:
		_refresh()

func _on_remote_roll(from: int, target: int) -> void:
	if Net.is_client() and visible:
		_begin_roll(from, target)

func _preview(data: Dictionary) -> Texture2D:
	var path: String = data.get("preview", data.get("background", ""))
	return load(path) if ResourceLoader.exists(path) else UI.BACKGROUND

func _build() -> void:
	UI.backdrop(self,0.84,false)
	UI.header(self,"CHOOSE YOUR ARENA",2)
	UI.panel(self,Rect2(30,106,466,264),UI.GOLD)
	thumb = UI.image(self,null,Rect2(34,110,458,256))
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	thumb.clip_contents = true
	UI.fill(self,Rect2(34,320,458,46),Color(0.025,0.03,0.07,0.9))
	name_label = UI.label(self,"",Rect2(48,326,430,32),26)
	for i in Maps.count():
		var data: Dictionary = Maps.get_map(i)
		var texture := _preview(data)
		preview_textures.append(texture)
		var card := UI.button(self,"",Rect2(520,108+i*65,248,57),_choose.bind(i))
		cards.append(card)
		var miniature := UI.image(card,texture,Rect2(5,5,78,47))
		miniature.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		miniature.clip_contents = true
		UI.label(card,data.name.to_upper(),Rect2(94,8,146,40),16)
	_back_button = UI.button(self,"BACK",Rect2(32,379,110,34),_back,17)
	_random = UI.button(self,"RANDOM",Rect2(520,379,100,34),_randomize,17)
	_fight = UI.button(self,"FIGHT",Rect2(630,376,138,40),_start,24)
	host_controls.assign([_back_button,_random,_fight])
	_reel_view = Control.new()
	_reel_view.position = Vector2(34,110)
	_reel_view.size = Vector2(458,256)
	_reel_view.clip_contents = true
	_reel_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_reel_view)
	UI.fill(_reel_view,Rect2(0,0,458,256),UI.INK)
	_reel = Control.new()
	_reel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reel_view.add_child(_reel)
	for i in 20:
		var tile := UI.image(_reel,null,Rect2(73,41-(i-1)*REEL_STEP,312,174))
		_reel_images.append(tile)
		UI.fill(tile,Rect2(0,142,312,32),Color(0.025,0.03,0.07,0.93))
		_reel_names.append(UI.label(tile,"",Rect2(8,144,296,26),19,UI.IVORY,true))
	UI.fill(_reel_view,Rect2(0,0,458,38),Color(0.025,0.03,0.07,1.0))
	UI.fill(_reel_view,Rect2(0,218,458,38),Color(0.025,0.03,0.07,0.78))
	UI.label(_reel_view,"RANDOM ARENA",Rect2(0,5,458,28),18,UI.GOLD,true)
	for rect in [Rect2(69,37,320,2),Rect2(69,217,320,2),Rect2(69,37,2,182),Rect2(387,37,2,182)]:
		UI.fill(_reel_view,rect,UI.GOLD)
	UI.label(_reel_view,"▶",Rect2(40,113,26,30),22,UI.GOLD,true)
	UI.label(_reel_view,"◀",Rect2(392,113,26,30),22,UI.GOLD,true)
	_reel_glow = UI.fill(_reel_view,Rect2(73,41,312,174),Color(UI.GOLD,0))
	_reel_view.hide()

func _can_choose() -> bool:
	return visible and not Net.is_client() and not _starting and not _spinning and Time.get_ticks_msec()/1000.0 >= _input_lockout_until

func _choose(index: int, commit: bool = true) -> void:
	if not _can_choose():
		return
	cursor = posmod(index,Maps.count())
	GameState.selected_map_index = cursor
	_focus_index = Maps.count()+1 if commit else cursor
	Net.send_map_cursor(cursor)
	Audio.play("click")
	_refresh()

func _step(direction: int) -> void:
	_navigate(Vector2i(0,direction))

func _navigate(direction: Vector2i) -> void:
	if not _can_choose():
		return
	var count := Maps.count()
	var next := _focus_index
	if _focus_index < count:
		if direction.y < 0:
			next = maxi(0,_focus_index-1)
		elif direction.y > 0:
			next = _focus_index+1 if _focus_index < count-1 else count+1
	elif direction.y < 0:
		next = cursor if _focus_index == count+2 else count-1
	elif direction.x != 0:
		var row := [count+2,count,count+1]
		var column := row.find(_focus_index)
		next = row[clampi(column+direction.x,0,2)]
	if next == _focus_index:
		return
	_focus_index = next
	if next < count:
		_choose(next,false)
	else:
		Audio.play("click")
		_refresh()

func _randomize() -> void:
	if not _can_choose():
		return
	var target := randi_range(0,Maps.count()-1)
	Net.send_map_roll(cursor,target)
	_begin_roll(cursor,target)

func _begin_roll(from: int, target: int) -> void:
	_spinning = true
	_roll_from = posmod(from,Maps.count())
	_roll_target = posmod(target,Maps.count())
	_roll_steps = Maps.count()*3+posmod(_roll_target-_roll_from,Maps.count())
	_roll_start = Time.get_ticks_msec()/1000.0
	_roll_tick = -1
	_roll_landed = false
	_reel_glow.color.a = 0
	for i in _reel_images.size():
		var index := posmod(i-1+_roll_from,Maps.count())
		_reel_images[i].texture = preview_textures[index]
		_reel_names[i].text = Maps.get_map(index).name.to_upper()
	_reel.position = Vector2.ZERO
	_reel_view.show()
	_refresh()

func _animate_roll(elapsed: float) -> void:
	var progress := clampf(elapsed/TRAVEL_DURATION,0,1)
	const ACCEL := 0.15
	var speed := 1.0/(ACCEL/2.0+(1.0-ACCEL)/3.0)
	var distance: float
	if progress < ACCEL:
		distance = speed*progress*progress/(2.0*ACCEL)
	else:
		var braking := (progress-ACCEL)/(1.0-ACCEL)
		distance = speed*(ACCEL/2.0+(1.0-ACCEL)*(1.0-pow(1.0-braking,3))/3.0)
	var settle := clampf((elapsed-TRAVEL_DURATION)/SETTLE_DURATION,0,1)
	var overshoot := 7.0*distance
	if elapsed >= TRAVEL_DURATION:
		overshoot = 7.0*cos(settle*PI*1.5)*pow(1.0-settle,2)
		if not _roll_landed:
			_roll_landed = true
			Audio.play("confirm")
		_reel_glow.color.a = 0.2*pow(1.0-settle,2)
	_reel.position.y = roundf(_roll_steps*REEL_STEP*distance+overshoot)
	var tick := int(roundf(_roll_steps*distance))
	if tick != _roll_tick:
		_roll_tick = tick
		Audio.play("click")
	for i in _reel_images.size():
		var offset := absf(_reel_images[i].position.y+_reel.position.y-41.0)
		var brightness := lerpf(1.0,0.48,clampf(offset/REEL_STEP,0,1))
		_reel_images[i].modulate = Color(brightness,brightness,brightness)
	if elapsed >= ROLL_DURATION:
		_finish_roll()

func _finish_roll() -> void:
	_spinning = false
	_reel_view.hide()
	cursor = _roll_target
	GameState.selected_map_index = cursor
	_focus_index = Maps.count()+1
	_input_lockout_until = Time.get_ticks_msec()/1000.0+0.2
	if Net.is_host():
		Net.send_map_cursor(cursor)
	_refresh()

func _back() -> void:
	if not _can_choose():
		return
	Audio.play("click")
	GameState.change_state(GameState.State.CLAN_SELECT)

func _start() -> void:
	if not _can_choose():
		return
	_starting = true
	GameState.selected_map_index = cursor
	Audio.play("confirm")
	GameState.start_new_match()

func _confirm_selection() -> void:
	if _focus_index == Maps.count():
		_randomize()
	elif _focus_index == Maps.count()+1:
		_start()
	elif _focus_index == Maps.count()+2:
		_back()
	else:
		_choose(cursor)

func _process(_delta: float) -> void:
	if not visible:
		return
	if _spinning:
		_animate_roll(Time.get_ticks_msec()/1000.0-_roll_start)
		return
	if not _can_choose():
		return
	if Input.is_action_just_pressed("menu_cancel"):
		if _focus_index == Maps.count()+1:
			_focus_index = cursor
			_refresh()
		else:
			_back()
	elif Input.is_action_just_pressed("menu_random"):
		_randomize()
	elif UI.nav("aim_up") or UI.nav("aim_down"):
		_step(1 if UI.nav("aim_down") else -1)
	elif UI.nav("left") or UI.nav("right"):
		_navigate(Vector2i(1 if UI.nav("right") else -1,0))
	elif UI.confirm():
		_confirm_selection()

func _refresh() -> void:
	thumb.texture = preview_textures[cursor]
	name_label.text = Maps.get_map(cursor).name.to_upper()
	for i in cards.size():
		UI.select(cards[i],i == cursor,UI.MUTED if _focus_index >= Maps.count() else UI.GOLD)
		cards[i].disabled = Net.is_client() or _spinning
	for button in host_controls:
		button.disabled = Net.is_client() or _spinning
	UI.select(_random,_focus_index == Maps.count())
	UI.select(_back_button,_focus_index == Maps.count()+2)
	UI.select(_fight,_focus_index == Maps.count()+1)
