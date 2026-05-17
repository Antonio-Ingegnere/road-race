extends Node2D

const ROAD_LEFT := 312.0
const ROAD_WIDTH := 400.0
const LANE_COUNT := 3
const OBS_SPEED_KMH := 50.0
const OBS_SCALE: float = 2.0
const OBS_TEX_SIZE := 64

# car.png (42x64 @ 2x): opaque x=[1,40] → vis_hw=40, vis_hh=64
const CAR_VIS_HW := 40.0
const CAR_VIS_HH := 64.0

# Per obstacle type: [vis_hw, vis_hh, texture_path]
# Bounds measured from opaque pixel extents at scale 2x.
const OBS_TYPE_DATA := [
	[46.0, 64.0, "res://assets/HondaCivic.png"],    # 0
	[44.0, 64.0, "res://assets/JeepWrangler2.png"], # 1
]

var _textures: Array[Texture2D] = []
var _obstacles: Array = []  # each: {"pos": Vector2, "type": int}
var _spawn_timer := 0.0
var _spawn_interval := 1.8
var _elapsed := 0.0
var _invincible_timer := 0.0
var _car: Node2D

signal hit_detected


func _ready() -> void:
	_car = get_parent().get_node("Car")
	for entry in OBS_TYPE_DATA:
		_textures.append(load(entry[2]))


func _process(delta: float) -> void:
	_elapsed += delta
	_spawn_interval = max(0.7, 1.8 - _elapsed * 0.025)

	_spawn_timer += delta
	if _spawn_timer >= _spawn_interval:
		_spawn_timer = 0.0
		_spawn()

	var screen_h := get_viewport_rect().size.y
	var obs_scroll: float = (_car.speed_kmh - OBS_SPEED_KMH) * _car.KMH_TO_PXS * delta
	for o in _obstacles:
		o["pos"] = o["pos"] + Vector2(0.0, obs_scroll)
	var cull_y: float = OBS_TEX_SIZE * OBS_SCALE * 0.5
	_obstacles = _obstacles.filter(func(o) -> bool: return o["pos"].y < screen_h + cull_y)

	if _invincible_timer > 0.0:
		_invincible_timer -= delta
	else:
		var cp := _car.position
		for o in _obstacles:
			var t: int = o["type"]
			var op: Vector2 = o["pos"]
			var vis_hw: float = OBS_TYPE_DATA[t][0]
			var vis_hh: float = OBS_TYPE_DATA[t][1]
			var dx: float = abs(cp.x - op.x)
			var dy: float = abs(cp.y - op.y)
			if dx < CAR_VIS_HW + vis_hw and dy < CAR_VIS_HH + vis_hh:
				hit_detected.emit()
				_invincible_timer = 2.0
				break

	_separate_car()
	queue_redraw()


func _separate_car() -> void:
	for o in _obstacles:
		var t: int = o["type"]
		var op: Vector2 = o["pos"]
		var vis_hw: float = OBS_TYPE_DATA[t][0]
		var vis_hh: float = OBS_TYPE_DATA[t][1]
		var dx: float = _car.position.x - op.x
		var adx: float = abs(dx)
		var ady: float = abs(_car.position.y - op.y)
		if adx >= CAR_VIS_HW + vis_hw or ady >= CAR_VIS_HH + vis_hh:
			continue
		var push: float = CAR_VIS_HW + vis_hw - adx
		if dx >= 0.0:
			_car.position.x += push
		else:
			_car.position.x -= push
	_car.position.x = clamp(_car.position.x, ROAD_LEFT + CAR_VIS_HW, ROAD_LEFT + ROAD_WIDTH - CAR_VIS_HW)


func get_obstacle_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for o in _obstacles:
		positions.append(o["pos"])
	return positions


func stop() -> void:
	set_process(false)


func _lane_center(lane: int) -> float:
	return ROAD_LEFT + (ROAD_WIDTH / LANE_COUNT) * (lane + 0.5)


func _occupied_lanes() -> Array[int]:
	var lanes: Array[int] = []
	for o in _obstacles:
		var lane := int((o["pos"].x - ROAD_LEFT) / (ROAD_WIDTH / LANE_COUNT))
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
	var type_idx: int = randi() % OBS_TYPE_DATA.size()
	_obstacles.append({
		"pos": Vector2(_lane_center(chosen), -OBS_TEX_SIZE * OBS_SCALE * 0.5),
		"type": type_idx,
	})


func _draw() -> void:
	var half: float = OBS_TEX_SIZE * 0.5
	for o in _obstacles:
		var t: int = o["type"]
		draw_set_transform(o["pos"], 0.0, Vector2(OBS_SCALE, OBS_SCALE))
		draw_texture(_textures[t], Vector2(-half, -half))
	draw_set_transform(Vector2.ZERO)
