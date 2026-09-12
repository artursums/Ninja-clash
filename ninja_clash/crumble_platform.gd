extends StaticBody2D

const WARNING_TIME := 0.65
const RESTORE_TIME := 4.0
enum Phase { INTACT, CRACKING, ABSENT }
var bounds := Rect2()
var tint := Color.WHITE
var atlas: Texture2D
var _fragments: Array[Dictionary] = []
var _cracks: Array[PackedVector2Array] = []
var _debris: DebrisLayer

class DebrisLayer extends Node2D:
	var platform: StaticBody2D
	func _draw() -> void:
		platform.draw_debris(self)

var phase := Phase.INTACT
var remaining := 0.0
var _shape: CollisionShape2D
var _age := 0.0

func _ready() -> void:
	position = bounds.get_center()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_shape = CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = bounds.size
	_shape.shape = rectangle
	add_child(_shape)
	add_to_group("crumble_platforms")
	_build_fragments()
	_debris = DebrisLayer.new()
	_debris.platform = self
	_debris.z_index = -1
	add_child(_debris)

func reset_platform() -> void:
	phase = Phase.INTACT
	remaining = 0.0
	collision_layer = 1
	_redraw()

func _physics_process(delta: float) -> void:
	if GameState.current_state != GameState.State.ROUND:
		return
	var previous_phase := phase
	_age += delta
	if not Net.is_client():
		if phase == Phase.INTACT:
			for body in get_tree().get_nodes_in_group("players"):
				if body.alive and body.is_on_floor() and body.velocity.y >= 0 and absf(body.position.y + 16 - bounds.position.y) < 3 and absf(body.position.x-position.x) < bounds.size.x/2+8:
					phase = Phase.CRACKING
					remaining = WARNING_TIME
					break
		else:
			remaining = maxf(0, remaining - delta)
			if remaining <= 0:
				if phase == Phase.CRACKING:
					phase = Phase.ABSENT
					remaining = RESTORE_TIME
					collision_layer = 0
					for rider in get_tree().get_nodes_in_group("players"):
						if not rider.alive and bounds.grow(2).has_point(rider.position+Vector2(0,16)):
							rider._corpse_settled = false
				elif _can_restore():
					reset_platform()
	if phase != Phase.INTACT or phase != previous_phase:
		_redraw()

func _can_restore() -> bool:
	# Include the headroom: a reforming slab must never trap a fighter's feet or head.
	var clearance := bounds.grow(4)
	for body in get_tree().get_nodes_in_group("players"):
		if clearance.intersects(Rect2(body.position-Vector2(10,16),Vector2(20,32))):
			return false
	return true

func apply_snapshot(value: Array) -> void:
	phase = int(value[0]) as Phase
	remaining = float(value[1])
	collision_layer = 0 if phase == Phase.ABSENT else 1
	_redraw()

func _redraw() -> void:
	queue_redraw()
	if is_instance_valid(_debris):
		_debris.queue_redraw()

func _build_fragments() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(bounds.position.x * 71 + bounds.position.y * 131)
	var left := -bounds.size.x / 2
	var top := -bounds.size.y / 2
	for row in 2:
		var x := 0.0
		while x < bounds.size.x:
			var width := minf(rng.randi_range(9, 15), bounds.size.x-x)
			var height := bounds.size.y/2
			var rect := Rect2(left+x, top+row*height, width, height)
			var center := rect.get_center()
			_fragments.append({"rect":rect, "source":Rect2(Vector2(16+x,40+row*height),rect.size),
				"velocity":Vector2(center.x * 2.6 + rng.randf_range(-22,22),rng.randf_range(-115,-55)-row*15),
				"spin":rng.randf_range(-7,7), "delay":rng.randf_range(0,0.045)})
			x += width
	for i in 3:
		var start := left + bounds.size.x*(i+1)/4
		var points := PackedVector2Array()
		for y in range(0,int(bounds.size.y)+1,2):
			points.append(Vector2(start+rng.randi_range(-2,2), top+y))
		_cracks.append(points)

func fragment_pose(index: int, elapsed: float) -> Transform2D:
	var fragment: Dictionary = _fragments[index]
	var time := maxf(0,elapsed-fragment.delay)
	var point: Vector2 = fragment.rect.get_center() + fragment.velocity*time + Vector2(0,270*time*time)
	return Transform2D(snappedf(fragment.spin*time,PI/12),point.round())

func _draw() -> void:
	var rect := Rect2(-bounds.size/2,bounds.size)
	if phase == Phase.ABSENT:
		if remaining < 0.7:
			# Small corner brackets identify an absent surface without suggesting support.
			for corner in [rect.position,Vector2(rect.end.x-4,rect.position.y)]:
				draw_rect(Rect2(corner,Vector2(4,1)),tint.darkened(0.3))
				draw_rect(Rect2(corner,Vector2(1,3)),tint.darkened(0.5))
		return
	var progress := clampf(1.0-remaining/WARNING_TIME,0,1) if phase == Phase.CRACKING else 0.0
	for index in _fragments.size():
		var fragment: Dictionary = _fragments[index]
		var shake := Vector2.ZERO
		if progress > 0.45 and fragment.rect.position.y > rect.position.y:
			shake = Vector2(roundf(sin(_age*75+index)*progress),0)
		draw_texture_rect_region(atlas,Rect2(fragment.rect.position+shake,fragment.rect.size),fragment.source)
	for index in _cracks.size():
		var points: PackedVector2Array = _cracks[index]
		var count := clampi(3+int(progress*(points.size()-3)),3,points.size())
		var crack := points.slice(0,count)
		draw_polyline(crack,Color("111820"),1 if progress < 0.7 else 2)
		if progress > 0.6:
			var highlight := PackedVector2Array()
			for point in crack:
				highlight.append(point+Vector2(1,0))
			draw_polyline(highlight,tint.lightened(0.15),1)
	# Two chipped corners distinguish weathered slabs even before a landing.
	draw_rect(Rect2(rect.position+Vector2(2,0),Vector2(3,1)),tint.darkened(0.75))
	draw_rect(Rect2(rect.end-Vector2(6,2),Vector2(4,2)),tint.darkened(0.7))

func draw_debris(layer: Node2D) -> void:
	if phase == Phase.CRACKING:
		var progress := 1.0-remaining/WARNING_TIME
		if progress > 0.2:
			for i in 5:
				var age := fmod(_age*2+i*0.19,0.6)
				var point := Vector2(-bounds.size.x/2+(i+1)*bounds.size.x/6,bounds.size.y/2+age*age*40)
				layer.draw_rect(Rect2(point.floor(),Vector2(1,2)),tint.darkened(0.4))
		return
	if phase != Phase.ABSENT:
		return
	var elapsed := RESTORE_TIME-remaining
	if elapsed >= 1.45:
		return
	for index in _fragments.size():
		var fragment: Dictionary = _fragments[index]
		layer.draw_set_transform_matrix(fragment_pose(index,elapsed))
		layer.draw_texture_rect_region(atlas,Rect2(-fragment.rect.size/2,fragment.rect.size),fragment.source)
	layer.draw_set_transform(Vector2.ZERO)
	for i in 18:
		var direction := -1 if i%2 == 0 else 1
		var point := Vector2((i%7-3)*8,0)+Vector2(direction*(28+i%5*17),-35-i%4*20)*elapsed+Vector2(0,210*elapsed*elapsed)
		layer.draw_rect(Rect2(point.round(),Vector2(1+i%2,1+i%3)),tint.darkened(0.25+i%3*0.15))
	if elapsed < 0.52:
		for i in 9:
			var age := maxf(0,elapsed-i%3*0.015)
			var point := Vector2((i-4)*bounds.size.x/10,3)+Vector2((i-4)*14,-14-i%3*7)*age
			var size := maxf(1,roundf((1-age/0.52)*(3+minf(age*42,5))))
			layer.draw_rect(Rect2(point.round()-Vector2(size,size)/2,Vector2(size,size)),tint.darkened(0.55+i%3*0.06))
			if size > 3:
				layer.draw_rect(Rect2(point.round()-Vector2(size/2,size/2),Vector2(size-2,2)),tint.darkened(0.35))
