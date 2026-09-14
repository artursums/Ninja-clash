extends RefCounted
## Local readiness and exclusive clan reservations, independent of UI and input devices.

var clans: Array[int] = []
var ready: Array[bool] = []

func configure(initial_clans: Array) -> void:
	clans.clear()
	ready.clear()
	for clan in initial_clans.slice(0, 4):
		clans.append(posmod(int(clan), 4))
		ready.append(false)

func choose(index: int, clan: int) -> bool:
	if index < 0 or index >= clans.size() or ready[index]:
		return false
	clans[index] = posmod(clan, 4)
	return true

func toggle_ready(index: int) -> bool:
	if index < 0 or index >= clans.size():
		return false
	if not ready[index]:
		for other in clans.size():
			if other != index and ready[other] and clans[other] == clans[index]:
				return false
	ready[index] = not ready[index]
	return true

func all_ready() -> bool:
	return not ready.is_empty() and ready.all(func(value: bool) -> bool: return value)

func next_unready(after: int) -> int:
	for offset in clans.size():
		var index := (after + offset + 1) % clans.size()
		if not ready[index]:
			return index
	return after
