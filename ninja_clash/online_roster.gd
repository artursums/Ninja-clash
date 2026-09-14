extends RefCounted

const MAX_PLAYERS := 4
const MAX_NAME_LENGTH := 16
var members: Array = []
var rules_revision := 0
var locked := false
var editing_rules := false

static func clean_name(value: String) -> String:
	var result := ""
	for character in value.strip_edges():
		var code := character.unicode_at(0)
		if code < 32 or (code >= 127 and code <= 159) or code in [0x200B, 0x200C, 0x200D, 0x2060, 0xFEFF] or (code >= 0x202A and code <= 0x202E) or (code >= 0x2066 and code <= 0x2069):
			continue
		result += character
	return result.strip_edges().left(MAX_NAME_LENGTH)

func member(peer: int) -> Dictionary:
	for player in members:
		if int(player.peer) == peer:
			return player
	return {}

func add(peer: int, display_name: String) -> bool:
	var name_value := clean_name(display_name)
	if locked or members.size() >= MAX_PLAYERS or peer < 1 or name_value == "" or not member(peer).is_empty():
		return false
	var clan := 3
	for choice in [3, 1, 2, 0]:
		if not members.any(func(player): return int(player.clan) == choice):
			clan = choice
			break
	members.append({"peer": peer, "slot": members.size() + 1, "name": name_value, "clan": clan, "skin": 0, "ready": false})
	return true

func remove(peer: int) -> void:
	members = members.filter(func(player): return int(player.peer) != peer)
	for index in members.size():
		members[index].slot = index + 1
	invalidate_ready()

func invalidate_ready() -> void:
	rules_revision += 1
	for player in members:
		player.ready = false

func pick(peer: int, clan: int, skin: int, ready: bool, revision: int, skin_count: int) -> String:
	var player := member(peer)
	if player.is_empty() or locked:
		return "THE MATCH IS STARTING"
	if clan < 0 or clan >= 4 or skin < 0 or skin >= skin_count:
		return "INVALID CHARACTER"
	if ready and (editing_rules or revision != rules_revision):
		return "THE RULES CHANGED — CHECK THEM AND READY AGAIN"
	for other in members:
		if other.peer != peer and other.ready and other.clan == clan:
			return "%s HAS LOCKED THIS CLAN" % other.name
	player.clan = clan
	player.skin = skin
	player.ready = ready
	return ""

func can_start() -> bool:
	return not locked and not editing_rules and members.size() >= 2 and members.size() <= MAX_PLAYERS and members.all(func(player): return player.ready)
