extends Node2D

var pose_texture: Texture2D
var idle_texture: Texture2D
var run_texture: Texture2D
var swing_texture: Texture2D
var animation := "idle"
var phase := 0.0

func _draw() -> void:
	var sheet := pose_texture
	var frame := 0
	var bob := 0.0
	var torso_shift := 0.0
	var leg_lift := 0.0
	var stride := 0.0
	var squash := 1.0
	var cycle := phase * TAU
	match animation:
		"idle":
			if idle_texture != null and phase > 0:
				sheet = idle_texture
				frame = mini(int(phase*6),5)
			bob = -roundf(sin(cycle)*0.65)*0.5
		"run":
			if run_texture != null:
				sheet = run_texture
				frame = mini(int(phase*6),5)
			else:
				frame = 1 if phase < 0.5 else 2
			bob = -roundf(abs(sin(cycle*2)))*0.5
			stride = roundf(sin(cycle)*1.2)*0.5
			torso_shift = -0.5
		"rise":
			frame = 3
			leg_lift = roundf((1-phase)*3)*0.5
			bob = -roundf(phase*2)*0.5
		"fall":
			frame = 3
			stride = roundf(phase*2)*0.5
			bob = roundf(phase*2)*0.5
		"wall":
			frame = 3
			torso_shift = -1
			leg_lift = roundf(sin(cycle))*0.5
		"swing":
			if swing_texture != null:
				sheet = swing_texture
				frame = mini(int(phase*6),5)
			else:
				frame = 4
			torso_shift = -roundf(sin(phase*PI)*2)*0.5
			bob = roundf(sin(phase*PI))*0.5
		"throw":
			frame = 4 if phase < 0.7 else 0
			torso_shift = -roundf(sin(phase*PI)*2)*0.5
			bob = -roundf(sin(cycle))*0.5
		"dodge":
			frame = 3
			squash = 0.75 + sin(phase*PI)*0.0625
			torso_shift = -1
	# The original art faces left. Mirror once while baking; runtime facing is shared
	# with the katana. Half-source-pixel offsets add native world-pixel inbetweens.
	draw_set_transform(Vector2(40,11+32*(1-squash)),0,Vector2(-2,2*squash))
	piece(sheet,frame,Rect2(0,0,16,8),Vector2(0,bob))
	piece(sheet,frame,Rect2(0,8,16,4),Vector2(torso_shift,8+bob))
	piece(sheet,frame,Rect2(0,12,8,4),Vector2(-stride,12-leg_lift))
	piece(sheet,frame,Rect2(8,12,8,4),Vector2(8+stride,12+leg_lift))
	draw_set_transform(Vector2.ZERO)

func piece(sheet: Texture2D, frame: int, region: Rect2, point: Vector2) -> void:
	draw_texture_rect_region(sheet,Rect2(point,region.size),Rect2(region.position+Vector2(frame*16,0),region.size))
