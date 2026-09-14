extends Node

enum Phase { DISABLED, NORMAL, SUDDEN_DEATH, FINISHED }
const OVERTIME_SECONDS := 20.0
signal expired(overtime: bool)
var remaining := 0.0
var duration := 0.0
var phase: int = Phase.DISABLED

func _ready() -> void:
	add_to_group("round_clock")

func start(seconds: float) -> void:
	duration = maxf(0, seconds)
	remaining = duration
	phase = Phase.NORMAL if duration > 0 else Phase.DISABLED

func start_overtime() -> void:
	duration = OVERTIME_SECONDS
	remaining = duration
	phase = Phase.SUDDEN_DEATH

func stop() -> void:
	if phase != Phase.DISABLED:
		phase = Phase.FINISHED

func _physics_process(delta: float) -> void:
	if GameState.is_round_active():
		advance(delta, not Net.is_client())

func advance(delta: float, authority: bool = true) -> void:
	if phase not in [Phase.NORMAL, Phase.SUDDEN_DEATH]:
		return
	remaining = maxf(0, remaining - delta)
	if remaining == 0 and authority:
		var overtime := phase == Phase.SUDDEN_DEATH
		phase = Phase.FINISHED
		expired.emit(overtime)

func snapshot() -> Array:
	return [phase, remaining, duration]

func apply_snapshot(row: Array) -> void:
	if row.size() == 3:
		phase = int(row[0])
		remaining = maxf(0, float(row[1]))
		duration = maxf(0, float(row[2]))

static func time_text(seconds: float) -> String:
	var value := ceili(maxf(0, seconds))
	return "%d:%02d" % [value / 60, value % 60]
