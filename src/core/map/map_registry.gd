class_name MapRegistry
extends RefCounted
## Discovers shippable maps by scanning MAPS_DIR for MapResource .tres files
## (design/gdd/map.md — Core Rule 2: `MapRegistry.all_maps()`). UI Flow / MatchSetup query this.

const MAPS_DIR := "res://src/gameplay/maps/"


## All maps found in MAPS_DIR, sorted by id.
static func all_maps() -> Array[MapResource]:
	var maps: Array[MapResource] = []
	var dir := DirAccess.open(MAPS_DIR)
	if dir == null:
		return maps
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir():
			var clean := fname.trim_suffix(".remap")   # exported builds append .remap
			if clean.ends_with(".tres"):
				var res: Resource = load(MAPS_DIR + clean)
				if res is MapResource:
					maps.append(res)
		fname = dir.get_next()
	dir.list_dir_end()
	maps.sort_custom(func(a: MapResource, b: MapResource) -> bool: return String(a.id) < String(b.id))
	return maps


## Map ids must be unique across the registry (Edge Case). Returns the duplicated ids ([] == ok).
static func duplicate_ids() -> Array[StringName]:
	var seen := {}
	var dupes: Array[StringName] = []
	for m in all_maps():
		if seen.has(m.id) and not dupes.has(m.id):
			dupes.append(m.id)
		seen[m.id] = true
	return dupes


static func get_map(id: StringName) -> MapResource:
	for m in all_maps():
		if m.id == id:
			return m
	return null
