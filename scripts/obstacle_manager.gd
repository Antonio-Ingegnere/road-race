extends Node2D

const ROAD_LEFT := 312.0
const ROAD_WIDTH := 400.0
const LANE_COUNT := 3
const OBS_SPEED_KMH := 50.0
const OBS_SCALE: float = 1.5

# Visible (opaque pixel) extents at rendered scale — measured from sprite content:
# car.png (42x64 @ 2x): opaque x=[1,40]  → vis_hw=40, vis_hh=64
# HondaCivic.png (64x64 @ 1.5x): opaque x=[9,54] → vis_hw=34.5, vis_hh=48
const CAR_VIS_HW := 40.0
const CAR_VIS_HH := 64.0
const OBS_VIS_HW := 34.5
const OBS_VIS_HH := 48.0

var _obs_tex: Texture2D
var _obs_tex_w: int
var _obs_tex_h: int

var _obstacles: Array[Vector2] = []
var _spawn_timer := 0.0
var _spawn_interval := 1.8
var _elapsed := 0.0
var _invincible_timer := 0.0
var _car: Node2D

signal hit_detected


func _ready() -> void:
	_car = get_parent().get_node("Car")

	_obs_tex = load("res://assets/HondaCivic.png")
	_obs_tex_w = _obs_tex.get_width()
	_obs_tex_h = _obs_tex.get_height()


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
	var cull_y := _obs_tex_h * OBS_SCALE * 0.5
	_obstacles = _obstacles.filter(func(p: Vector2) -> bool: return p.y < screen_h + cull_y)

	if _invincible_timer > 0.0:
		_invincible_timer -= delta
	else:
		var cp := _car.position
		for op in _obstacles:
			if abs(cp.x - op.x) < CAR_VIS_HW + OBS_VIS_HW and abs(cp.y - op.y) < CAR_VIS_HH + OBS_VIS_HH:
				hit_detected.emit()
				_invincible_timer = 2.0
				break

	_separate_car()

	queue_redraw()


func _separate_car() -> void:
	for op in _obstacles:
		var dx := _car.position.x - op.x
		if abs(dx) >= CAR_VIS_HW + OBS_VIS_HW or abs(_car.position.y - op.y) >= CAR_VIS_HH + OBS_VIS_HH:
			continue
		var push: float = CAR_VIS_HW + OBS_VIS_HW - abs(dx)
		_car.position.x += push if dx >= 0.0 else -push
	_car.position.x = clamp(_car.position.x, ROAD_LEFT + CAR_VIS_HW, ROAD_LEFT + ROAD_WIDTH - CAR_VIS_HW)




func get_obstacle_positions() -> Array[Vector2]:
	return _obstacles


func stop() -> void:
	set_process(false)


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
	if occupied.size() >= LANE_COUNT - 1:
		return
	var free_lanes: Array[int] = []
	for i in range(LANE_COUNT):
		if i not in occupied:
			free_lanes.append(i)
	var chosen: int = free_lanes[randi() % free_lanes.size()]
	_obstacles.append(Vector2(_lane_center(chosen), -_obs_tex_h * OBS_SCALE * 0.5))


func _draw() -> void:
	if not _obs_tex:
		return
	var half_w := _obs_tex_w * 0.5
	var half_h := _obs_tex_h * 0.5
	for p in _obstacles:
		draw_set_transform(p, 0.0, Vector2(OBS_SCALE, OBS_SCALE))
		draw_texture(_obs_tex, Vector2(-half_w, -half_h))
	draw_set_transform(Vector2.ZERO)
