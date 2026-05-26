class_name PlayerInputRouter
extends Node
## The ONLY reader of Godot Input for the SIMULATION — the ADR-0001 input/state-separation pattern
## brought into Ninja Clash so online (v2) stays viable. Each physics tick it snapshots every
## slot's action states, so gameplay reads a CAPTURED intent rather than the live device. That
## means a future network layer can feed the same per-slot snapshot and the simulation is unchanged.
## Registered as the `PlayerInput` autoload (name differs from class_name to avoid a Godot clash).
##
## NOTE: menu scripts (clan_select, map_select, …) still read Input directly. That is UI navigation,
## NOT part of the replicated simulation, so it does not affect netcode determinism — routing it is
## a later cleanup, not online-blocking.

const SLOTS := [1, 2]   ## prototype human slots (extend to 4 when 4-player input lands)
const ACTIONS := ["left", "right", "aim_up", "aim_down", "jump", "throw", "katana", "dodge", "slide", "defend"]

var _held: Dictionary = {}      ## full action name -> bool (held this tick)
var _pressed: Dictionary = {}   ## full action name -> bool (just-pressed this tick)


func _physics_process(_delta: float) -> void:
	capture()   # autoloads tick before scene nodes, so the snapshot is ready when players read it


## Snapshot every slot's action states for this tick. The sole place that reads Godot Input.
func capture() -> void:
	for slot in SLOTS:
		for a in ACTIONS:
			var action := "p%d_%s" % [slot, a]
			if InputMap.has_action(action):
				_held[action] = Input.is_action_pressed(action)
				_pressed[action] = Input.is_action_just_pressed(action)


## Held state from this tick's snapshot (consumed by player.gd `_held`).
func held(action: String) -> bool:
	return _held.get(action, false)


## Just-pressed edge from this tick's snapshot (consumed by player.gd `_pressed`).
func pressed(action: String) -> bool:
	return _pressed.get(action, false)


## The online-facing contract: this slot's intent as plain serializable data this tick.
## (What a netcode layer would replicate; gameplay could read this instead of `_held`/`_pressed`.)
func get_intent(slot: int) -> PlayerIntent:
	var p := "p%d_" % slot
	var i := PlayerIntent.new()
	i.move = Vector2(
		(1.0 if held(p + "right") else 0.0) - (1.0 if held(p + "left") else 0.0),
		(1.0 if held(p + "aim_down") else 0.0) - (1.0 if held(p + "aim_up") else 0.0)
	)
	i.jump_held = held(p + "jump");     i.jump_pressed = pressed(p + "jump")
	i.throw_held = held(p + "throw");   i.throw_pressed = pressed(p + "throw")
	i.katana_held = held(p + "katana"); i.katana_pressed = pressed(p + "katana")
	i.dodge_held = held(p + "dodge");   i.dodge_pressed = pressed(p + "dodge")
	i.slide_held = held(p + "slide");   i.slide_pressed = pressed(p + "slide")
	i.defend_held = held(p + "defend"); i.defend_pressed = pressed(p + "defend")
	return i
