class_name MapLoader
extends RefCounted
## Instantiates a map's MapScene (design/gdd/map.md — Core Rule 2: `MapLoader.load`, States table).
## Round Flow calls this on InMatch entry. Returns null on failure so the caller can fall back to
## MainMenu with an error toast (Edge Case: missing/corrupt map).

## Load + instantiate the scene for a map id. Returns the scene root, or null on failure.
static func load_map(id: StringName) -> Node:
	var map := MapRegistry.get_map(id)
	if map == null:
		push_error("MapLoader: no map registered with id '%s'" % id)
		return null
	if map.scene_path.is_empty() or not ResourceLoader.exists(map.scene_path):
		push_error("MapLoader: map '%s' has no loadable scene at '%s'" % [id, map.scene_path])
		return null
	var packed: PackedScene = load(map.scene_path)
	if packed == null:
		push_error("MapLoader: failed to load scene for '%s'" % id)
		return null
	return packed.instantiate()
