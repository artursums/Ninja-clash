class_name PlayerIntent
extends RefCounted
## Per-slot player intent — plain value data, no device references (ADR-0001). Produced by
## CouchInput from local devices in v1; a future NetworkInput layer could produce the identical
## struct from remote packets without changing any gameplay system. Movement resolves the
## contextual jump-vs-dodge semantic from `primary_held` + its own character state.

var move: Vector2 = Vector2.ZERO      ## movement axis, deadzoned, components in [-1, 1]
var aim: Vector2 = Vector2.ZERO       ## aim-direction intent (defaults to the move direction)
var primary_held: bool = false        ## A (bottom face) currently held
var throw_held: bool = false          ## X (left face) currently held


## A standalone copy — useful for snapshotting a tick of input (e.g. future netcode / replay).
func clone() -> PlayerIntent:
	var c := PlayerIntent.new()
	c.move = move
	c.aim = aim
	c.primary_held = primary_held
	c.throw_held = throw_held
	return c
