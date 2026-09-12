extends Node
## Read-only telemetry for real browser input tests; never attached in release builds.

var _elapsed := 0.0

func _ready() -> void:
	if not OS.is_debug_build() or not OS.has_feature("web") or not JavaScriptBridge.eval("window.__ninjaTest === true", true):
		queue_free()

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < 0.1:
		return
	_elapsed = 0.0
	var fighters: Array = []
	for p in get_tree().get_nodes_in_group("players"):
		fighters.append({"slot": p.slot, "x": p.position.x, "y": p.position.y, "hp": p.hp, "stash": p.stash})
	var main: Node = get_parent()
	var data := {"state": GameState.State.keys()[GameState.current_state], "mode": Net.mode,
		"peer": Net._peer_id, "room": Net.invitation_code, "fighters": fighters,
		"shurikens": get_tree().get_nodes_in_group("shurikens").size(), "puppets": Net._puppet_shurikens.size(),
		"remoteHeld": Net._remote_held_mask, "status": main.online_menu_screen.status_label.text,
		"map": GameState.selected_map_index, "scores": Combat.scores,
		"tutorial": main.tutorial_overlay.visible, "signalingDone": Net._web_room != null and Net._web_room._signaling_done}
	JavaScriptBridge.eval("window.__ninjaState = " + JSON.stringify(data), true)
