extends Node2D

const CAR_FRONT_OFFSET := 64.0
const OBS_REAR_OFFSET  := 48.0

const CONE_LENGTH  := 300.0
const CONE_HW_NEAR := 32.0
const CONE_HW_FAR  := 150.0

# Obstacle headlights — 60% of player cone
const OBS_CONE_LENGTH  := 180.0
const OBS_CONE_HW_NEAR := 19.0
const OBS_CONE_HW_FAR  := 90.0

var _car: Node2D
var _obstacle_manager: Node2D
var _day_night: CanvasLayer


func _ready() -> void:
	var main := get_parent().get_parent()
	_car = main.get_node("Car")
	_obstacle_manager = main.get_node("ObstacleManager")
	_day_night = main.get_node("DayNight")
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var night: float = _day_night.intensity
	if night < 0.05:
		return

	_draw_headlights(_car.position, night)

	for op in _obstacle_manager.get_obstacle_positions():
		_draw_obs_headlights(op, night)
		_draw_taillights(op, night)


func _draw_headlights(car_pos: Vector2, night: float) -> void:
	var near_y := car_pos.y - CAR_FRONT_OFFSET
	var far_y  := near_y - CONE_LENGTH
	var bright := Color(1.00, 0.95, 0.70, night * 0.575)
	var fade   := Color(1.00, 0.95, 0.70, 0.00)
	# Left beam (inner right edge expanded 10% further right)
	draw_polygon(
		PackedVector2Array([
			Vector2(car_pos.x - 32, near_y),
			Vector2(car_pos.x - 10, near_y),
			Vector2(car_pos.x + 23,  far_y),
			Vector2(car_pos.x - 150, far_y),
		]),
		PackedColorArray([bright, bright, fade, fade])
	)
	# Right beam (inner left edge expanded 10% further left)
	draw_polygon(
		PackedVector2Array([
			Vector2(car_pos.x + 10,  near_y),
			Vector2(car_pos.x + 32,  near_y),
			Vector2(car_pos.x + 150, far_y),
			Vector2(car_pos.x - 23,  far_y),
		]),
		PackedColorArray([bright, bright, fade, fade])
	)


func _draw_obs_headlights(op: Vector2, night: float) -> void:
	var near_y := op.y - OBS_REAR_OFFSET
	var far_y  := near_y - OBS_CONE_LENGTH
	var bright := Color(1.00, 0.95, 0.70, night * 0.575)
	var fade   := Color(1.00, 0.95, 0.70, 0.00)
	# Left beam
	draw_polygon(
		PackedVector2Array([
			Vector2(op.x - 19, near_y),
			Vector2(op.x - 6,  near_y),
			Vector2(op.x + 14, far_y),
			Vector2(op.x - 90, far_y),
		]),
		PackedColorArray([bright, bright, fade, fade])
	)
	# Right beam
	draw_polygon(
		PackedVector2Array([
			Vector2(op.x + 6,  near_y),
			Vector2(op.x + 19, near_y),
			Vector2(op.x + 90, far_y),
			Vector2(op.x - 14, far_y),
		]),
		PackedColorArray([bright, bright, fade, fade])
	)


func _draw_taillights(op: Vector2, night: float) -> void:
	var rear_y := op.y + OBS_REAR_OFFSET
	var red  := Color(1.00, 0.10, 0.08, night * 0.633)
	var fade := Color(1.00, 0.10, 0.08, 0.00)
	draw_polygon(
		PackedVector2Array([
			Vector2(op.x - 30, rear_y),
			Vector2(op.x + 30, rear_y),
			Vector2(op.x + 60, rear_y + 45.0),
			Vector2(op.x - 60, rear_y + 45.0),
		]),
		PackedColorArray([red, red, fade, fade])
	)
