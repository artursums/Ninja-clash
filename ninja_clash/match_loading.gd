extends Control
## Holds resource references until scene construction has taken ownership of them.

const UI := preload("res://menu_ui.gd")
var resources: Array[Resource] = []
var phase: Label
var _bar: ColorRect
var _spinner: TextureRect

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	UI.image(self, UI.BACKGROUND, Rect2(0, 0, 800, 450)).stretch_mode = TextureRect.STRETCH_SCALE
	UI.fill(self, Rect2(0, 0, 800, 450), Color(0.025, 0.035, 0.07, 0.9))
	UI.label(self, "ENTERING THE ARENA", Rect2(100, 126, 600, 28), 18, UI.GOLD, true)
	phase = UI.label(self, "", Rect2(80, 168, 640, 46), 34, UI.IVORY, true)
	_spinner = UI.image(self, preload("res://sprites/shuriken.svg"), Rect2(383, 236, 34, 34))
	_spinner.pivot_offset = Vector2(17, 17)
	_spinner.modulate = UI.GOLD
	UI.fill(self, Rect2(240, 299, 320, 3), UI.EDGE)
	_bar = UI.fill(self, Rect2(240, 299, 0, 3), UI.GOLD)
	UI.label(self, "PREPARING YOUR FIGHT", Rect2(200, 316, 400, 24), 14, UI.MUTED, true)
	hide()

func open(arena_name: String) -> void:
	resources.clear()
	phase.text = arena_name.to_upper()
	_bar.size.x = 0
	show()

func _process(delta: float) -> void:
	if visible:
		_spinner.rotation += delta * 2.5

func prepare(paths: Array[String], still_needed: Callable) -> bool:
	var loaded: Array[Resource] = []
	for i in paths.size():
		if not still_needed.call():
			return false
		var path := paths[i]
		if ResourceLoader.load_threaded_request(path) != OK:
			push_error("Unable to request match resource: " + path)
			return false
		while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await get_tree().process_frame
		if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_LOADED:
			push_error("Unable to load match resource: " + path)
			return false
		loaded.append(ResourceLoader.load_threaded_get(path))
		if not still_needed.call():
			return false
		_bar.size.x = 288.0 * (i + 1) / paths.size()
		await get_tree().process_frame
	if not still_needed.call():
		return false
	resources = loaded
	return true

func complete() -> void:
	_bar.size.x = 320

func finish() -> void:
	hide()
	resources.clear()

static func collect_paths(value: Variant, paths: Array[String]) -> void:
	if value is Dictionary:
		for item in value.values():
			collect_paths(item, paths)
	elif value is Array:
		for item in value:
			collect_paths(item, paths)
	elif value is String and value.begins_with("res://") and ResourceLoader.exists(value) and not paths.has(value):
		paths.append(value)
