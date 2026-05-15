extends Node2D

const ROAD_LEFT := 312.0
const ROAD_WIDTH := 400.0
const LANE_COUNT := 3
const OBS_SPEED_KMH := 50.0
const OBS_SCALE: float = 1.5

# Player car sprite dims at texture resolution; Sprite2D renders at scale 2
const CAR_TEX_W := 42
const CAR_TEX_H := 64
const CAR_SCR_HW := 42.0  # half-width on screen  = CAR_TEX_W * 2 / 2
const CAR_SCR_HH := 64.0  # half-height on screen = CAR_TEX_H * 2 / 2

var _obs_tex: Texture2D
var _obs_mask: PackedByteArray
var _obs_tex_w: int
var _obs_tex_h: int
var _car_mask: PackedByteArray

var _obstacles: Array[Vector2] = []
var _spawn_timer := 0.0
var _spawn_interval := 1.8
var _elapsed := 0.0
var _car: Node2D

signal hit_detected


func _ready() -> void:
	_car = get_parent().get_node("Car")

	var obs_img := Image.new()
	obs_img.load("res://assets/HondaCivic.png")
	_obs_tex_w = obs_img.get_width()
	_obs_tex_h = obs_img.get_height()
	_obs_mask = _build_alpha_mask(obs_img, _obs_tex_w, _obs_tex_h)
	_obs_tex = ImageTexture.create_from_image(obs_img)

	var car_img := Image.new()
	car_img.load("res://assets/car.png")
	_car_mask = _build_alpha_mask(car_img, CAR_TEX_W, CAR_TEX_H)


func _build_alpha_mask(img: Image, w: int, h: int) -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(w * h)
	for y in range(h):
		for x in range(w):
			mask[y * w + x] = 1 if img.get_pixel(x, y).a > 0.1 else 0
	return mask


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

	var cp := _car.position
	for op in _obstacles:
		if _pixel_collision(op, cp):
			hit_detected.emit()
			set_process(false)
			return

	queue_redraw()


func _pixel_collision(op: Vector2, car_pos: Vector2) -> bool:
	var obs_hw := _obs_tex_w * OBS_SCALE * 0.5
	var obs_hh := _obs_tex_h * OBS_SCALE * 0.5

	var ix1 := int(maxf(op.x - obs_hw, car_pos.x - CAR_SCR_HW))
	var ix2 := int(minf(op.x + obs_hw, car_pos.x + CAR_SCR_HW))
	var iy1 := int(maxf(op.y - obs_hh, car_pos.y - CAR_SCR_HH))
	var iy2 := int(minf(op.y + obs_hh, car_pos.y + CAR_SCR_HH))

	if ix1 >= ix2 or iy1 >= iy2:
		return false

	for py in range(iy1, iy2, 2):
		for px in range(ix1, ix2, 2):
			var otx := int((px - op.x) / OBS_SCALE + _obs_tex_w * 0.5)
			var oty := int((py - op.y) / OBS_SCALE + _obs_tex_h * 0.5)
			var ptx := int((px - car_pos.x) / 2.0 + CAR_TEX_W * 0.5)
			var pty := int((py - car_pos.y) / 2.0 + CAR_TEX_H * 0.5)

			if otx >= 0 and otx < _obs_tex_w and oty >= 0 and oty < _obs_tex_h:
				if ptx >= 0 and ptx < CAR_TEX_W and pty >= 0 and pty < CAR_TEX_H:
					if _obs_mask[oty * _obs_tex_w + otx] and _car_mask[pty * CAR_TEX_W + ptx]:
						return true
	return false


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
