class_name PlayerIntent
extends RefCounted
## Per-slot, per-tick player intent for Ninja Clash — plain serializable data, NO device refs.
## Produced by PlayerInputRouter from local devices today; for online (v2) the identical struct
## could arrive from a network packet without changing any gameplay code. See
## docs/architecture/ADR-0001-input-state-separation.md.

var move: Vector2 = Vector2.ZERO   ## x: left(-1)/right(+1), y: aim_up(-1)/aim_down(+1)
var jump_held: bool = false
var jump_pressed: bool = false
var throw_held: bool = false
var throw_pressed: bool = false
var katana_held: bool = false
var katana_pressed: bool = false
var dodge_held: bool = false
var dodge_pressed: bool = false
var slide_held: bool = false
var slide_pressed: bool = false
var defend_held: bool = false
var defend_pressed: bool = false
