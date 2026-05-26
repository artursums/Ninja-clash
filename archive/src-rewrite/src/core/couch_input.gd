class_name CouchInputSystem
extends Node
## The input layer for Four Clans and the ONLY system that touches Godot's raw Input/InputEvent
## (per ADR-0001 + Couch Input GDD Core Rule 2). It owns controller detection, slot assignment,
## hot-plug, the menu/gameplay input layer, and routing of player intent to gameplay systems via
## typed signals (discrete verbs) + a per-slot polled PlayerIntent snapshot (continuous state).
##
## Registered as the `CouchInput` autoload at runtime (class is CouchInputSystem to avoid a
## class_name/autoload clash). Instantiable for unit tests: drive the internal event methods
## (`_on_button_event`, `_on_motion_event`, `_on_connection_changed`, `_on_state_changed`)
## directly — no live device, per ADR-0001.
##
## See design/gdd/couch-input.md.
##
## SCOPE NOTE (Sprint 1 / T5): the per-slot MatchSetup clan-select state machine
## (Browsing/Locked/Ready + forced clan uniqueness + menu_invalid_action) and menu hold-to-repeat
## are DEFERRED to the MatchSetup / Clan Cosmetics work (VS tier) — they need clan data + MatchContext.
## The gameplay input path, slot lifecycle, layer switching, and core menu signals ship here.

enum Layer { MENU, GAMEPLAY }

# --- Signals (Couch Input GDD Core Rule 7) ---
## Discrete gameplay verbs (gameplay layer only).
signal throw_pressed(slot: int)
signal primary_action_pressed(slot: int)            ## A — Movement resolves jump-vs-dodge
## Pause — emitted from any layer; GSM debounces + validates. Carries the device id.
signal pause_requested(controller_id: int)
## Menu verbs (menu layer only).
signal menu_confirm(slot: int)
signal menu_cancel(slot: int)
signal menu_direction(slot: int, direction: Vector2)
signal menu_invalid_action(slot: int)               ## reserved for clan-select (deferred); declared for API stability
## Connection / slot lifecycle.
signal controller_connected(controller_id: int)
signal controller_disconnected(slot: int)           ## Round Flow consumes for mid-round elimination
signal all_controllers_disconnected()               ## GSM consumes for auto-pause

## Injected tuning (DI). Runtime autoload loads the .tres in _ready.
var config: CouchInputConfig = CouchInputConfig.new()
## Injected clock (DI) so the menu-nav debounce is testable.
var time_source: Callable = func() -> float: return Time.get_ticks_msec() / 1000.0

var current_layer: Layer = Layer.MENU
var current_state: int = GameStateManager.State.BOOT   ## last GSM state seen

var _slot_of_device: Dictionary = {}    # device:int -> slot:int (assigned controllers)
var _device_of_slot: Dictionary = {}    # slot:int -> device:int
var _connected_devices: Dictionary = {} # device:int -> true (physically present)
var _reserved_slots: Array[int] = []    # slots held after an InMatch/Paused disconnect
var _intent: Dictionary = {}            # slot:int -> PlayerIntent
var _raw_stick: Dictionary = {}         # slot:int -> Vector2 (raw left-stick axes)
var _dpad: Dictionary = {}              # slot:int -> Vector2 (current D-pad direction)
var _last_nav_emit: Dictionary = {}     # slot:int -> float (last menu_direction time)
var _axis_armed: Dictionary = {}        # slot:int -> Vector2 (per-axis: 1 = armed for a rising edge)


func _ready() -> void:
	# Runtime (autoload) only — tests run outside the tree so this does not fire.
	var cfg_path := "res://src/core/couch_input_config.tres"
	if ResourceLoader.exists(cfg_path):
		var loaded: Resource = load(cfg_path)
		if loaded is CouchInputConfig:
			config = loaded
	# Wire to the engine + GSM.
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	for device in Input.get_connected_joypads():
		_connected_devices[device] = true
	var gsm := get_node_or_null(^"/root/GameState")
	if gsm != null and gsm.has_signal("state_changed"):
		gsm.state_changed.connect(func(from_state: int, to_state: int) -> void: _on_state_changed(from_state, to_state))


# --- Raw InputEvent adapter (the ONLY place that reads InputEvent). Thin: delegates to the
#     testable internal handlers below. ---
const _DEBUG_KEY_DEVICE := 1000   ## synthetic device id for the dev keyboard fallback


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		_on_button_event(event.device, event.button_index, event.pressed)
	elif event is InputEventJoypadMotion:
		_on_motion_event(event.device, event.axis, event.axis_value)
	elif config.debug_keyboard_input and event is InputEventKey and not event.echo:
		# Dev-only keyboard fallback (DEBUG_KEYBOARD_INPUT) — maps keys to a synthetic gamepad so
		# the same slot/intent path is exercised. WASD/arrows = move, Space = A, K = throw, Enter = pause.
		var button := _debug_key_to_button(event.physical_keycode)
		if button >= 0:
			_on_button_event(_DEBUG_KEY_DEVICE, button, event.pressed)


func _debug_key_to_button(key: int) -> int:
	match key:
		KEY_A, KEY_LEFT: return JOY_BUTTON_DPAD_LEFT
		KEY_D, KEY_RIGHT: return JOY_BUTTON_DPAD_RIGHT
		KEY_W, KEY_UP: return JOY_BUTTON_DPAD_UP
		KEY_S, KEY_DOWN: return JOY_BUTTON_DPAD_DOWN
		KEY_SPACE: return JOY_BUTTON_A
		KEY_K: return JOY_BUTTON_X
		KEY_ENTER: return JOY_BUTTON_START
	return -1


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	_on_connection_changed(device, connected)


# === Public API ===

## Current per-tick intent for a slot. Gameplay simulation polls this each physics tick (ADR-0001).
func get_intent(slot: int) -> PlayerIntent:
	if _intent.has(slot):
		return _intent[slot]
	return PlayerIntent.new()


## Slots currently assigned to a connected controller, ascending.
func active_slots() -> Array[int]:
	var slots: Array[int] = []
	for slot in _device_of_slot.keys():
		slots.append(slot)
	slots.sort()
	return slots


# === Internal, testable event handlers ===

## GSM state changed → switch the active input layer (gameplay iff InMatch; Core Rule 9).
func _on_state_changed(_from_state: int, to_state: int) -> void:
	current_state = to_state
	current_layer = Layer.GAMEPLAY if to_state == GameStateManager.State.IN_MATCH else Layer.MENU


func _on_button_event(device: int, button_index: int, pressed: bool) -> void:
	if pressed:
		_connected_devices[device] = true   # a button event implies the device is present
	# Unassigned device: a button press joins (menu layer only), and is consumed (Core Rule 4).
	if not _slot_of_device.has(device):
		if pressed and current_layer == Layer.MENU:
			var free := _next_free_slot()
			if free != 0:
				_assign_device_to_slot(device, free)
		return

	var slot: int = _slot_of_device[device]
	var intent: PlayerIntent = _intent[slot]

	match button_index:
		JOY_BUTTON_A:
			intent.primary_held = pressed
			if pressed:
				if current_layer == Layer.GAMEPLAY:
					primary_action_pressed.emit(slot)
				else:
					menu_confirm.emit(slot)
		JOY_BUTTON_X:
			intent.throw_held = pressed
			if pressed and current_layer == Layer.GAMEPLAY:
				throw_pressed.emit(slot)
		JOY_BUTTON_B:
			if pressed and current_layer == Layer.MENU:
				menu_cancel.emit(slot)
		JOY_BUTTON_START:
			if pressed:
				pause_requested.emit(device)   # GSM debounces + validates; sacred in any layer
		JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN:
			_apply_dpad(slot, button_index, pressed)


func _on_motion_event(device: int, axis: int, value: float) -> void:
	if not _slot_of_device.has(device):
		return   # stick motion never joins — only a button press does
	if axis != JOY_AXIS_LEFT_X and axis != JOY_AXIS_LEFT_Y:
		return

	var slot: int = _slot_of_device[device]
	var raw: Vector2 = _raw_stick.get(slot, Vector2.ZERO)
	if axis == JOY_AXIS_LEFT_X:
		raw.x = value
	else:
		raw.y = value
	_raw_stick[slot] = raw

	if current_layer == Layer.GAMEPLAY:
		_refresh_move(slot)
	else:
		_update_menu_axis(slot, raw)


func _on_connection_changed(device: int, connected: bool) -> void:
	if connected:
		_connected_devices[device] = true
		controller_connected.emit(device)
		# Reconnect reclaims the lowest-numbered Reserved slot, if any (Core Rule 5 / Edge Cases).
		if not _reserved_slots.is_empty():
			var slot: int = _reserved_slots.min()
			_reserved_slots.erase(slot)
			_assign_device_to_slot(device, slot)
		return

	# Disconnect.
	_connected_devices.erase(device)
	if not _slot_of_device.has(device):
		return
	var slot: int = _slot_of_device[device]
	_unassign_device(device)
	# In a live or paused match the slot is HELD (Reserved); elsewhere it is released immediately.
	if current_state == GameStateManager.State.IN_MATCH or current_state == GameStateManager.State.PAUSED:
		if not _reserved_slots.has(slot):
			_reserved_slots.append(slot)
	controller_disconnected.emit(slot)
	if current_state == GameStateManager.State.IN_MATCH and _connected_devices.is_empty():
		all_controllers_disconnected.emit()


# === Helpers ===

func _next_free_slot() -> int:
	for slot in range(1, config.max_controllers + 1):
		if not _device_of_slot.has(slot) and not _reserved_slots.has(slot):
			return slot
	return 0   # all full → caller ignores silently


func _assign_device_to_slot(device: int, slot: int) -> void:
	_slot_of_device[device] = slot
	_device_of_slot[slot] = device
	if not _intent.has(slot):
		_intent[slot] = PlayerIntent.new()
	_raw_stick[slot] = Vector2.ZERO
	_dpad[slot] = Vector2.ZERO
	_axis_armed[slot] = Vector2.ONE   # ready for a rising edge on either axis


func _unassign_device(device: int) -> void:
	var slot: int = _slot_of_device[device]
	_slot_of_device.erase(device)
	_device_of_slot.erase(slot)
	# Zero the slot's intent — a gone controller produces no input.
	if _intent.has(slot):
		_intent[slot] = PlayerIntent.new()
	_raw_stick[slot] = Vector2.ZERO
	_dpad[slot] = Vector2.ZERO


## Radial deadzone with smooth ramp + >1.0 clamp (GDD Formula). Pure function of `raw` + config.
func _process_stick(raw: Vector2) -> Vector2:
	var mag := minf(raw.length(), 1.0)   # clamp misreported >1.0 magnitudes
	if mag < config.deadzone:
		return Vector2.ZERO
	var scale := (mag - config.deadzone) / (1.0 - config.deadzone)
	return raw.normalized() * clampf(scale, 0.0, 1.0)


func _apply_dpad(slot: int, button_index: int, pressed: bool) -> void:
	var v: Vector2 = _dpad.get(slot, Vector2.ZERO)
	match button_index:
		JOY_BUTTON_DPAD_LEFT:
			v.x = -1.0 if pressed else (0.0 if v.x < 0.0 else v.x)
		JOY_BUTTON_DPAD_RIGHT:
			v.x = 1.0 if pressed else (0.0 if v.x > 0.0 else v.x)
		JOY_BUTTON_DPAD_UP:
			v.y = -1.0 if pressed else (0.0 if v.y < 0.0 else v.y)
		JOY_BUTTON_DPAD_DOWN:
			v.y = 1.0 if pressed else (0.0 if v.y > 0.0 else v.y)
	_dpad[slot] = v

	if current_layer == Layer.GAMEPLAY:
		_refresh_move(slot)
	elif pressed and v != Vector2.ZERO:
		# D-pad is already discrete — emit one menu_direction per press, debounce-gated.
		_try_menu_direction(slot, v)


## Recompute the polled move vector (D-pad wins when held, else the processed stick).
func _refresh_move(slot: int) -> void:
	var intent: PlayerIntent = _intent[slot]
	var dpad: Vector2 = _dpad.get(slot, Vector2.ZERO)
	intent.move = dpad if dpad != Vector2.ZERO else _process_stick(_raw_stick.get(slot, Vector2.ZERO))
	intent.aim = intent.move   # v1: aim follows the held movement direction


## Analog stick → discrete menu_direction on a rising edge over the threshold (GDD Formula).
func _update_menu_axis(slot: int, raw: Vector2) -> void:
	var armed: Vector2 = _axis_armed.get(slot, Vector2.ONE)
	var th := config.menu_discrete_threshold
	# X axis: fire once on a rising edge above the threshold; re-arm when it falls back below.
	if absf(raw.x) < th:
		armed.x = 1.0
	elif armed.x > 0.5:
		armed.x = 0.0
		_try_menu_direction(slot, Vector2(signf(raw.x), 0.0))
	# Y axis.
	if absf(raw.y) < th:
		armed.y = 1.0
	elif armed.y > 0.5:
		armed.y = 0.0
		_try_menu_direction(slot, Vector2(0.0, signf(raw.y)))
	_axis_armed[slot] = armed


func _try_menu_direction(slot: int, direction: Vector2) -> void:
	var now: float = time_source.call()
	if now - _last_nav_emit.get(slot, -INF) < config.menu_nav_debounce_s:
		return
	_last_nav_emit[slot] = now
	menu_direction.emit(slot, direction)
