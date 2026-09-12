# ONLINE menu — host or join a 1v1 LAN/internet match (ADR-0003). Entered from the title
# screen's ONLINE button; leads into the shared online lobby (clan select) once connected.
#
#   HOST GAME — opens a server on port 24565 and shows this machine's LAN address(es)
#               while waiting; the match flow starts the moment the opponent connects.
#   JOIN GAME — connects to the address typed in the IP field (last address remembered).
#   BACK      — to the title screen.
#
# Navigation: ↑/↓ move (W/S and numpad 8/5 too, EXCEPT while typing in the IP field — there
# only the arrow keys move the cursor so typing letters/digits can't hijack it), confirm =
# jump/Enter, ◯/Esc = back/cancel. Reuses the pause-menu sprite kit for a consistent look.
extends Control

const UI = preload("res://menu_ui.gd")

const MENU := "res://sprites/menu/"

const ROWS: Array = ["HOST GAME", "JOIN GAME", "BACK"]
const ROW_HOST := 0
const ROW_JOIN := 1
const ROW_BACK := 2

const PLATE_W := 320.0
const PLATE_H := 46.0
const PLATE_STEP := 58.0
const PLATE_TOP := 116.0
const PLATE_CX := (800.0 - PLATE_W) / 2.0

const COL_SEL := Color("d4a830")    # gold — selected / headers
const COL_DIM := Color("f0eee8")    # idle item text
const COL_MUT := Color("8a8ea8")    # hints / secondary info
const COL_ERR := Color("c03030")    # failures

enum Mode { IDLE, HOSTING, JOINING }

var _mode: int = Mode.IDLE
var _cursor: int = 0
var _input_lockout_until: float = 0.0
var _arrow_up_was: bool = false     # manual edge detection for the arrow keys (unbound globally)
var _arrow_down_was: bool = false

var plates: Array = []
var row_labels: Array = []
var cursor_rect: TextureRect
var ip_edit: LineEdit
var ip_caption: Label
var status_label: Label
var hint_label: Label
var invite_edit: LineEdit


func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	visibility_changed.connect(_on_visibility_changed)
	Net.session_ended.connect(_on_session_ended)
	Net.room_created.connect(_on_room_created)
	Net.connection_status.connect(_on_connection_status)
	_refresh()


func _on_visibility_changed() -> void:
	if not visible:
		return
	_mode = Mode.HOSTING if Net.is_host() else Mode.IDLE   # never true on a fresh entry
	_cursor = 0
	ip_edit.text = Settings.last_join_ip
	if OS.has_feature("web"):
		ip_edit.text = Net.pending_invitation()
		if ip_edit.text != "":
			_cursor = ROW_JOIN
	_input_lockout_until = Time.get_ticks_msec() / 1000.0 + 0.2
	# Surface why we landed here after a drop ("OPPONENT LEFT", "CONNECTION LOST", …), once.
	status_label.text = Net.last_status
	if OS.has_feature("web") and ip_edit.text != "" and status_label.text == "":
		status_label.text = "INVITE READY — PRESS JOIN ROOM"
	status_label.add_theme_color_override("font_color", COL_ERR)
	Net.last_status = ""
	_refresh()


func _on_session_ended(reason: String) -> void:
	_mode = Mode.IDLE
	if visible:
		status_label.text = reason
		status_label.add_theme_color_override("font_color", COL_ERR)
		_refresh()


func _build() -> void:
	UI.backdrop(self, 0.82)
	UI.panel(self, Rect2(192, 96, 416, 288))
	var menu_theme := Theme.new()
	menu_theme.default_font = UI.FONT
	theme = menu_theme
	var head := Label.new()
	head.text = "ONLINE"
	head.position = Vector2(0, 26)
	head.size = Vector2(800, 40)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 34)
	head.add_theme_color_override("font_color", COL_SEL)
	add_child(head)

	var sub := Label.new()
	sub.text = "1v1 over LAN / internet — host is P1, guest is P2"
	if OS.has_feature("web"):
		sub.text = "Create a room, share the invite, play a friend"
	sub.position = Vector2(0, 66)
	sub.size = Vector2(800, 20)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", COL_MUT)
	add_child(sub)

	for i in ROWS.size():
		var y: float = _row_y(i)
		var plate := UI.button(self, "", Rect2(PLATE_CX, y, PLATE_W, PLATE_H), _mouse_activate.bind(i))
		plates.append(plate)
		var lbl := Label.new()
		lbl.text = String(ROWS[i])
		lbl.position = Vector2(PLATE_CX, y)
		lbl.size = Vector2(PLATE_W, PLATE_H)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 22)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(lbl)
		row_labels.append(lbl)

	cursor_rect = TextureRect.new()
	cursor_rect.texture = load(MENU + "pause_cursor_native.png")
	cursor_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cursor_rect.stretch_mode = TextureRect.STRETCH_SCALE
	cursor_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cursor_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cursor_rect.size = Vector2(28, 32)
	add_child(cursor_rect)

	# Host address field — sits under the JOIN row; grabs focus while JOIN is highlighted.
	ip_caption = Label.new()
	ip_caption.text = "HOST ADDRESS"
	if OS.has_feature("web"):
		ip_caption.text = "ROOM / INVITE"
	ip_caption.position = Vector2(PLATE_CX, _row_y(ROW_JOIN) + PLATE_H + 4.0)
	ip_caption.size = Vector2(120, 30)
	ip_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ip_caption.add_theme_font_size_override("font_size", 12)
	ip_caption.add_theme_color_override("font_color", COL_MUT)
	add_child(ip_caption)

	ip_edit = LineEdit.new()
	ip_edit.position = Vector2(PLATE_CX + 126.0, _row_y(ROW_JOIN) + PLATE_H + 4.0)
	ip_edit.size = Vector2(PLATE_W - 126.0, 30)
	ip_edit.placeholder_text = "192.168.x.x"
	ip_edit.max_length = 64
	if OS.has_feature("web"):
		ip_edit.placeholder_text = "Room code or link"
		ip_edit.max_length = 512
	ip_edit.add_theme_font_size_override("font_size", 16)
	ip_edit.text_submitted.connect(func(_t: String) -> void: _start_join())
	add_child(ip_edit)

	status_label = Label.new()
	status_label.position = Vector2(0, 328)
	status_label.size = Vector2(800, 60)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(status_label)

	invite_edit = LineEdit.new()
	invite_edit.position = Vector2(208, 354)
	invite_edit.size = Vector2(384, 26)
	invite_edit.editable = false
	invite_edit.add_theme_font_size_override("font_size", 12)
	invite_edit.visible = false
	add_child(invite_edit)

	hint_label = Label.new()
	hint_label.position = Vector2(0, 414)
	hint_label.size = Vector2(800, 22)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 12)
	hint_label.add_theme_color_override("font_color", COL_MUT)
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint_label)


func _row_y(i: int) -> float:
	# The IP field occupies the slot under JOIN, so BACK sits one step lower.
	return PLATE_TOP + i * PLATE_STEP + (38.0 if i > ROW_JOIN else 0.0)


# --- Input ------------------------------------------------------------------

func _nav_action(suffix: String) -> bool:
	return Input.is_action_just_pressed("p1_" + suffix) or Input.is_action_just_pressed("p2_" + suffix)


func _confirm_pressed() -> bool:
	return _nav_action("jump") or _nav_action("confirm")


# Arrow-key edges polled manually: the arrows are deliberately NOT InputMap actions, so they
# still navigate while the IP LineEdit has focus (where letters/digits would fire W/S/numpad
# actions and hijack the cursor mid-typing).
func _arrow_edge(key: int, was: bool) -> Dictionary:
	var down: bool = Input.is_physical_key_pressed(key)
	return {"edge": down and not was, "down": down}


func _process(_delta: float) -> void:
	if not visible:
		return
	if Time.get_ticks_msec() / 1000.0 < _input_lockout_until:
		return

	if _mode != Mode.IDLE:
		# Waiting / connecting: only cancel is live.
		if _mode == Mode.HOSTING and Net.invitation_code != "" and _confirm_pressed():
			_copy_invitation()
			return
		if Input.is_action_just_pressed("menu_cancel"):
			Audio.play("click")
			Net.leave("")
			_mode = Mode.IDLE
			status_label.text = ""
			_refresh()
		elif _mode == Mode.JOINING and not Net.is_online():
			_mode = Mode.IDLE   # attempt died silently (status arrives via session_ended)
			_refresh()
		return

	var typing: bool = ip_edit.has_focus()
	var up := _arrow_edge(KEY_UP, _arrow_up_was)
	var down := _arrow_edge(KEY_DOWN, _arrow_down_was)
	_arrow_up_was = up["down"]
	_arrow_down_was = down["down"]
	var nav_up: bool = up["edge"] or (not typing and _nav_action("aim_up"))
	var nav_down: bool = down["edge"] or (not typing and _nav_action("aim_down"))

	if Input.is_action_just_pressed("menu_cancel"):
		Audio.play("click")
		Net.leave("")
		GameState.change_state(GameState.State.TITLE)
		return
	if nav_up:
		_cursor = (_cursor + ROWS.size() - 1) % ROWS.size()
		Audio.play("click")
		_refresh()
	elif nav_down:
		_cursor = (_cursor + 1) % ROWS.size()
		Audio.play("click")
		_refresh()
	elif not typing and _confirm_pressed():
		match _cursor:
			ROW_HOST: _start_host()
			ROW_JOIN: _start_join()
			ROW_BACK:
				Audio.play("click")
				GameState.change_state(GameState.State.TITLE)


func _start_host() -> void:
	Audio.play("confirm")
	var err: String = Net.host_game()
	if err != "":
		status_label.text = err
		status_label.add_theme_color_override("font_color", COL_ERR)
		_refresh()
		return
	_mode = Mode.HOSTING
	if OS.has_feature("web"):
		status_label.text = "CREATING ROOM…"
		status_label.add_theme_color_override("font_color", COL_SEL)
		_refresh()
		return
	var ips: Array = Net.local_ipv4_addresses()
	var where: String = " / ".join(PackedStringArray(ips.slice(0, 2))) if not ips.is_empty() else "?"
	status_label.text = "WAITING FOR OPPONENT…\nLAN ADDRESS: %s   ·   UDP %d" % [where, Net.DEFAULT_PORT]
	status_label.add_theme_color_override("font_color", COL_SEL)
	_refresh()


func _start_join() -> void:
	var ip: String = ip_edit.text.strip_edges()
	if ip == "":
		status_label.text = "TYPE THE HOST'S ADDRESS FIRST"
		status_label.add_theme_color_override("font_color", COL_ERR)
		_cursor = ROW_JOIN
		_refresh()
		return
	Audio.play("confirm")
	if not OS.has_feature("web"):
		Settings.set_last_join_ip(ip)
	var err: String = Net.join_game(ip)
	if err != "":
		status_label.text = err
		status_label.add_theme_color_override("font_color", COL_ERR)
		_refresh()
		return
	_mode = Mode.JOINING
	status_label.text = "JOINING ROOM…" if OS.has_feature("web") else "CONNECTING TO %s …" % ip
	status_label.add_theme_color_override("font_color", COL_SEL)
	_refresh()


# --- Rendering ----------------------------------------------------------------

func _refresh() -> void:
	var idle: bool = (_mode == Mode.IDLE)
	var can_share: bool = OS.has_feature("web") and _mode == Mode.HOSTING and Net.invitation_code != ""
	invite_edit.visible = can_share
	if can_share:
		invite_edit.text = Net.invitation_url()
	for i in ROWS.size():
		var sel: bool = idle and i == _cursor
		UI.select(plates[i], sel)
		plates[i].disabled = not idle and i != ROW_BACK
		row_labels[i].add_theme_color_override("font_color", COL_SEL if sel else COL_DIM)
		plates[i].modulate.a = 1.0 if idle or i == ROW_BACK else 0.35
		row_labels[i].modulate.a = 1.0 if idle or i == ROW_BACK else 0.35
		row_labels[i].text = "CANCEL" if i == ROW_BACK and not idle else ROWS[i]
		if OS.has_feature("web") and i != ROW_BACK:
			row_labels[i].text = "CREATE ROOM" if i == ROW_HOST else "JOIN ROOM"
		if can_share and i == ROW_HOST:
			plates[i].disabled = false
			plates[i].modulate.a = 1.0
			row_labels[i].modulate.a = 1.0
			row_labels[i].text = "COPY INVITE LINK"
	cursor_rect.visible = idle
	cursor_rect.position = Vector2(PLATE_CX - 38.0, _row_y(_cursor) + (PLATE_H - 32.0) / 2.0)
	ip_caption.modulate.a = 1.0 if idle else 0.35
	ip_edit.editable = idle
	ip_edit.modulate.a = 1.0 if idle else 0.35
	# The IP field types only while JOIN is the highlighted row.
	if idle and _cursor == ROW_JOIN:
		if not ip_edit.has_focus():
			ip_edit.grab_focus()
			ip_edit.caret_column = ip_edit.text.length()
	elif ip_edit.has_focus():
		ip_edit.release_focus()
	if _mode == Mode.IDLE:
		hint_label.text = "↑/↓ — SELECT      ENTER / SPACE / ✕ — CONFIRM      ESC / ◯ — BACK"
	else:
		hint_label.text = "ESC / ◯ — CANCEL"
		if can_share:
			hint_label.text = "KEEP THIS TAB OPEN WHILE PLAYING      ESC / ◯ — CANCEL"

func _mouse_activate(row: int) -> void:
	if _mode != Mode.IDLE:
		if row == ROW_HOST and OS.has_feature("web") and Net.invitation_code != "":
			_copy_invitation()
			return
		if row == ROW_BACK:
			Net.leave("")
			_mode = Mode.IDLE
			status_label.text = ""
			_refresh()
		return
	_cursor = row
	match row:
		ROW_HOST: _start_host()
		ROW_JOIN: _start_join()
		ROW_BACK: GameState.change_state(GameState.State.TITLE)


func _on_room_created(code: String) -> void:
	status_label.text = "ROOM %s — WAITING FOR YOUR FRIEND" % code
	status_label.add_theme_color_override("font_color", COL_SEL)
	_refresh()


func _copy_invitation() -> void:
	DisplayServer.clipboard_set(Net.invitation_url())
	status_label.text = "SHARE THE INVITE LINK BELOW WITH YOUR FRIEND"


func _on_connection_status(message: String) -> void:
	status_label.text = message
	status_label.add_theme_color_override("font_color", COL_SEL)
