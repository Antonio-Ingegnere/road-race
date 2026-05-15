extends Node2D

const ROAD_LEFT := 312.0
const ROAD_WIDTH := 400.0
const LANE_COUNT := 3
const OBS_SPEED_KMH := 50.0
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
	var obs_scroll: float = (_car.speed_kmh - OBS_SPEED_KMH) * _car.KMH_TO_PXS * delta
	for i in range(_obstacles.size()):
		_obstacles[i].y += obs_scroll
	_obstacles = _obstacles.filter(func(p: Vector2) -> bool: return p.y < screen_h + OBS_H)

	var cp := _car.position
	for op in _obstacles:
		if abs(cp.x - op.x) < CAR_HW + OBS_HW and abs(cp.y - op.y) < CAR_HH + OBS_HH:
			hit_detected.emit()
			set_process(false)
			return

	queue_redraw()


func _lane_center(lane: int) -> float:
	return ROAD_LEFT + (ROAD_WIDTH / LANE_COUNT) * (lane + 0.5)


func _occupied_lanes() -> Array[int]:
	var lanes: Array[int] = []
	for op in _obstacles:
		var lane := int((op.x - ROAD_LEFT) / (ROAD_WIDTH / LANE_COUNT))
		if lane not in lanes:
			lanes.append(lane)
	return lanes


func _spawn() -> void:
	var occupied := _occupied_lanes()
	# Never fill all lanes simultaneously — always leave at least one free
	if occupied.size() >= LANE_COUNT - 1:
		return
	var free_lanes: Array[int] = []
	for i in range(LANE_COUNT):
		if i not in occupied:
			free_lanes.append(i)
	var chosen: int = free_lanes[randi() % free_lanes.size()]
	_obstacles.append(Vector2(_lane_center(chosen), -OBS_H * 0.5))


func _draw() -> void:
	for p in _obstacles:
		_draw_obstacle_car(p)


func _draw_obstacle_car(p: Vector2) -> void:
	var hw := OBS_W * 0.5
	var hh := OBS_H * 0.5
	# Body
	draw_rect(Rect2(p.x - hw, p.y - hh, OBS_W, OBS_H), Color(0.72, 0.10, 0.10))
	# Windshield (top — front of car, facing away from player)
	draw_rect(Rect2(p.x - hw + 10, p.y - hh + 18, OBS_W - 20, 22), Color(0.50, 0.72, 0.90, 0.85))
	# Headlights (very top)
	draw_rect(Rect2(p.x - hw + 6, p.y - hh + 4, 16, 10), Color(1.00, 1.00, 0.70))
	draw_rect(Rect2(p.x + hw - 22, p.y - hh + 4, 16, 10), Color(1.00, 1.00, 0.70))
	# Rear window (bottom — back of car, facing player)
	draw_rect(Rect2(p.x - hw + 10, p.y + hh - 38, OBS_W - 20, 20), Color(0.50, 0.72, 0.90, 0.75))
	# Taillights (very bottom, closest to player)
	draw_rect(Rect2(p.x - hw + 6, p.y + hh - 12, 16, 8), Color(0.95, 0.20, 0.20))
	draw_rect(Rect2(p.x + hw - 22, p.y + hh - 12, 16, 8), Color(0.95, 0.20, 0.20))
	# Wheels
	draw_rect(Rect2(p.x - hw - 8, p.y - hh + 12, 10, 24), Color(0.12, 0.12, 0.12))
	draw_rect(Rect2(p.x + hw - 2, p.y - hh + 12, 10, 24), Color(0.12, 0.12, 0.12))
	draw_rect(Rect2(p.x - hw - 8, p.y + hh - 36, 10, 24), Color(0.12, 0.12, 0.12))
	draw_rect(Rect2(p.x + hw - 2, p.y + hh - 36, 10, 24), Color(0.12, 0.12, 0.12))
