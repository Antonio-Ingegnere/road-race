extends Node2D

const FRAME_W      := 128
const FRAME_H      := 128
const FRAME_COUNT  := 5
const MERMAID_SCALE := 1.5
const ANIM_FPS     := 6.0

const ROAD_LEFT       := 760.0
const ROAD_WIDTH      := 400.0
const SEA_SAND_W      := 120.0
const SEA_WAVE_ZONE_W := 220.0

const RIPPLE_MAX_RADIUS := 72.0
const RIPPLE_EXPAND_SPD := 32.0  # px/s
const RIPPLE_COUNT      := 3     # simultaneous rings, evenly spaced

# Rock surface distances from ripple origin (pos + (0,38)), ray-cast per direction.
# Covers the full bottom half θ = 0° to 180° in 25 steps (every 7.5°).
# Each ring originates here and expands outward by the current expansion amount.
const ROCK_ARC_FIRST_IDX := 0    # index in the N=48 full-circle grid
const ROCK_ARC_N         := 25   # number of arc points (i=0..24 inclusive)
const ROCK_BASE_R: Array = [
	88.00, 92.00, 74.00, 67.50, 46.00, 35.00, 33.00, 31.00,
	28.50, 25.00, 24.00, 23.00, 24.50, 26.00, 27.00, 31.50,
	33.50, 36.50, 41.00, 40.00, 42.50, 48.00, 82.00, 95.00, 92.50,
]

const SPAWN_INTERVAL     := 3.5
const DARK_THRESHOLD     := 0.25
const LANDSCAPE_SEASHORE := 1

var _tex:         Texture2D
var _mermaids:    Array = []
var _spawn_timer: float = 0.0
var _car:         Node2D
var _road:        Node2D
var _day_night:   Node


func _ready() -> void:
	_car       = get_parent().get_node("Car")
	_road      = get_parent().get_node("Road")
	_day_night = get_parent().get_node("DayNight")
	_tex       = load("res://assets/Mermaids_animated-Sheet.png")


func _process(delta: float) -> void:
	var road_scroll: float = _car.speed_kmh * _car.KMH_TO_PXS * delta
	var screen_h: float = get_viewport_rect().size.y

	for m in _mermaids:
		m["pos"].y += road_scroll
		m["anim_timer"] += delta
		if m["anim_timer"] >= 1.0 / ANIM_FPS:
			m["anim_timer"] -= 1.0 / ANIM_FPS
			m["frame"] = (m["frame"] + 1) % FRAME_COUNT
		m["ripple_phase"] = fmod(
			m["ripple_phase"] + RIPPLE_EXPAND_SPD * delta, RIPPLE_MAX_RADIUS)

	var half_h: float = FRAME_H * MERMAID_SCALE * 0.5
	_mermaids = _mermaids.filter(func(m) -> bool: return m["pos"].y < screen_h + half_h)

	if _is_dark() and _ocean_visible():
		_spawn_timer += delta
		if _spawn_timer >= SPAWN_INTERVAL:
			_spawn_timer = 0.0
			_spawn()

	queue_redraw()


func _is_dark() -> bool:
	return _day_night.intensity >= DARK_THRESHOLD


func _ocean_visible() -> bool:
	return _road.landscape_left == LANDSCAPE_SEASHORE \
		or _road.landscape_right == LANDSCAPE_SEASHORE


func _spawn() -> void:
	var size := get_viewport_rect().size
	var half_w: float = FRAME_W * MERMAID_SCALE * 0.5

	var left_ok:  bool = _road.landscape_left  == LANDSCAPE_SEASHORE
	var right_ok: bool = _road.landscape_right == LANDSCAPE_SEASHORE

	var right_x_min := ROAD_LEFT + ROAD_WIDTH + SEA_SAND_W + SEA_WAVE_ZONE_W + half_w + 10.0
	if right_x_min + half_w >= size.x - 10.0:
		right_ok = false

	var sides: Array = []
	if left_ok:
		sides.append(0)
	if right_ok:
		sides.append(1)
	if sides.is_empty():
		return

	var side: int = sides[randi() % sides.size()]
	var x: float
	if side == 0:
		var x_min := half_w + 10.0
		var x_max := ROAD_LEFT - SEA_SAND_W - SEA_WAVE_ZONE_W - half_w - 10.0
		if x_max <= x_min:
			return
		x = randf_range(x_min, x_max)
	else:
		x = randf_range(right_x_min, size.x - half_w - 10.0)

	_mermaids.append({
		"pos":          Vector2(x, -FRAME_H * MERMAID_SCALE),
		"frame":        randi() % FRAME_COUNT,
		"anim_timer":   0.0,
		"ripple_phase": randf_range(0.0, RIPPLE_MAX_RADIUS),
	})


func _draw() -> void:
	if not _is_dark():
		return

	var hw := FRAME_W * 0.5
	var hh := FRAME_H * 0.5

	# Ripples behind sprites — no transform, absolute screen coords
	for m in _mermaids:
		var rp: Vector2 = m["pos"] + Vector2(0.0, 38.0)
		var step: float = RIPPLE_MAX_RADIUS / RIPPLE_COUNT
		for i in range(RIPPLE_COUNT):
			var radius: float = fmod(m["ripple_phase"] + i * step, RIPPLE_MAX_RADIUS)
			var t: float = radius / RIPPLE_MAX_RADIUS
			var alpha: float = (1.0 - t) * 0.55
			var pts := PackedVector2Array()
			for j in range(ROCK_ARC_N):
				var theta: float = (ROCK_ARC_FIRST_IDX + j) * TAU / 48.0
				var dist: float = ROCK_BASE_R[j] + radius
				pts.append(rp + Vector2(cos(theta) * dist, sin(theta) * dist))
			draw_polyline(pts, Color(0.55, 0.78, 0.92, alpha), 1.5, true)

	# Sprites on top
	for m in _mermaids:
		draw_set_transform(m["pos"], 0.0, Vector2(MERMAID_SCALE, MERMAID_SCALE))
		draw_texture_rect_region(
			_tex,
			Rect2(-hw, -hh, FRAME_W, FRAME_H),
			Rect2(m["frame"] * FRAME_W, 0, FRAME_W, FRAME_H)
		)

	draw_set_transform(Vector2.ZERO)
