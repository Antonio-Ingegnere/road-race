extends Node2D

const ROAD_LEFT := 312.0
const ROAD_WIDTH := 400.0
const SCROLL_SPEED := 250.0
const OBS_W := 80.0
const OBS_H := 128.0
# Hitbox half-extents used for collision (slightly smaller than visuals)
const CAR_HW := 34.0
const CAR_HH := 54.0
const OBS_HW := 30.0
const OBS_HH := 52.0

var _obstacles: Array[Vector2] = []
var _spawn_timer := 0.0
var _spawn_interval := 1.8
var _elapsed := 0.0
var _car: Node2D

signal hit_detected


func _ready() -> void:
	_car = get_parent().get_node("Car")


func _process(delta: float) -> void:
	_elapsed += delta
	_spawn_interval = max(0.7, 1.8 - _elapsed * 0.025)

	_spawn_timer += delta
	if _spawn_timer >= _spawn_interval:
		_spawn_timer = 0.0
		_spawn()

	var screen_h := get_viewport_rect().size.y
	for i in range(_obstacles.size()):
		_obstacles[i].y += SCROLL_SPEED * delta
	_obstacles = _obstacles.filter(func(p: Vector2) -> bool: return p.y < screen_h + OBS_H)

	var cp := _car.position
	for op in _obstacles:
		if abs(cp.x - op.x) < CAR_HW + OBS_HW and abs(cp.y - op.y) < CAR_HH + OBS_HH:
			hit_detected.emit()
			set_process(false)
			return

	queue_redraw()


func _spawn() -> void:
	var margin := OBS_W * 0.5 + 6.0
	var x := randf_range(ROAD_LEFT + margin, ROAD_LEFT + ROAD_WIDTH - margin)
	_obstacles.append(Vector2(x, -OBS_H * 0.5))


func _draw() -> void:
	for p in _obstacles:
		_draw_obstacle_car(p)


func _draw_obstacle_car(p: Vector2) -> void:
	var hw := OBS_W * 0.5
	var hh := OBS_H * 0.5
	# Body
	draw_rect(Rect2(p.x - hw, p.y - hh, OBS_W, OBS_H), Color(0.72, 0.10, 0.10))
	# Rear window (top — back of oncoming car)
	draw_rect(Rect2(p.x - hw + 10, p.y - hh + 18, OBS_W - 20, 20), Color(0.50, 0.72, 0.90, 0.75))
	# Taillights (very top)
	draw_rect(Rect2(p.x - hw + 6, p.y - hh + 4, 16, 8), Color(0.95, 0.20, 0.20))
	draw_rect(Rect2(p.x + hw - 22, p.y - hh + 4, 16, 8), Color(0.95, 0.20, 0.20))
	# Windshield (near bottom — front faces player)
	draw_rect(Rect2(p.x - hw + 10, p.y + hh - 42, OBS_W - 20, 22), Color(0.50, 0.72, 0.90, 0.85))
	# Headlights (very bottom)
	draw_rect(Rect2(p.x - hw + 6, p.y + hh - 14, 16, 10), Color(1.00, 1.00, 0.70))
	draw_rect(Rect2(p.x + hw - 22, p.y + hh - 14, 16, 10), Color(1.00, 1.00, 0.70))
	# Wheels
	draw_rect(Rect2(p.x - hw - 8, p.y - hh + 12, 10, 24), Color(0.12, 0.12, 0.12))
	draw_rect(Rect2(p.x + hw - 2, p.y - hh + 12, 10, 24), Color(0.12, 0.12, 0.12))
	draw_rect(Rect2(p.x - hw - 8, p.y + hh - 36, 10, 24), Color(0.12, 0.12, 0.12))
	draw_rect(Rect2(p.x + hw - 2, p.y + hh - 36, 10, 24), Color(0.12, 0.12, 0.12))
