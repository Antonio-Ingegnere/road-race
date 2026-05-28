extends Node2D

const ROAD_LEFT  := 760.0
const ROAD_WIDTH := 400.0
const CAR_VIS_HW := 40.0
const CAR_VIS_HH := 64.0

const PUDDLE_TYPES   := 4
const SPAWN_INTERVAL := 1.5
const SPAWN_CHANCE   := 0.8
const DRIFT_CHANCE   := 0.8

const WATER_COLOR   := Color(0.20, 0.26, 0.40, 0.82)
const REFLECT_COLOR := Color(0.60, 0.68, 0.80, 0.50)
const DEEP_COLOR    := Color(0.12, 0.16, 0.28, 0.90)

var _puddles: Array = []
var _spawn_timer := 0.0
var _car: Node2D
var _enabled := false
var _drift_vel: float = 0.0


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("res://config.cfg") == OK:
		_enabled = bool(cfg.get_value("rain", "enabled", false))
	if not _enabled:
		set_process(false)
		return
	_car = get_parent().get_node("Car")


func _process(delta: float) -> void:
	var road_scroll: float = _car.speed_kmh * _car.KMH_TO_PXS * delta
	var screen_h: float = get_viewport_rect().size.y

	for p in _puddles:
		p["pos"] = p["pos"] + Vector2(0.0, road_scroll)
	_puddles = _puddles.filter(func(p) -> bool: return p["pos"].y < screen_h + 100.0)

	_spawn_timer += delta
	if _spawn_timer >= SPAWN_INTERVAL:
		_spawn_timer = 0.0
		if randf() < SPAWN_CHANCE:
			_spawn()

	_check_overlap()
	_apply_drift(delta)
	queue_redraw()


func _check_overlap() -> void:
	var cp := _car.position
	for p in _puddles:
		if p["hit"]:
			continue
		var op: Vector2 = p["pos"]
		if abs(cp.x - op.x) < CAR_VIS_HW + p["hw"] and abs(cp.y - op.y) < CAR_VIS_HH + p["hh"]:
			p["hit"] = true
			if randf() < DRIFT_CHANCE:
				var dir: float = 1.0 if randf() > 0.5 else -1.0
				_drift_vel = randf_range(200.0, 350.0) * dir


func _apply_drift(delta: float) -> void:
	if abs(_drift_vel) < 1.0:
		_drift_vel = 0.0
		return
	_car.position.x += _drift_vel * delta
	_drift_vel = move_toward(_drift_vel, 0.0, abs(_drift_vel) * 3.0 * delta)
	_car.position.x = clamp(
		_car.position.x,
		ROAD_LEFT + CAR_VIS_HW,
		ROAD_LEFT + ROAD_WIDTH - CAR_VIS_HW
	)


func _spawn() -> void:
	var x: float = ROAD_LEFT + randf() * ROAD_WIDTH
	var rot: float = randf_range(-0.3, 0.3)
	var t: int = randi() % PUDDLE_TYPES
	var sz: float = randf_range(0.8, 1.3)
	var hw: float
	var hh: float
	match t:
		0: hw = 40.0 * sz; hh = 18.0 * sz   # standard oval
		1: hw = 46.0 * sz; hh = 20.0 * sz   # elongated oval
		2: hw = 50.0 * sz; hh = 24.0 * sz   # cluster
		_: hw = 50.0 * sz; hh = 24.0 * sz   # wide shallow pool
	var puddle := {
		"pos":   Vector2(x, -80.0),
		"rot":   rot,
		"hit":   false,
		"type":  t,
		"size":  sz,
		"hw":    hw,
		"hh":    hh,
		"drops": [],
	}
	if t == 2:
		var n := randi_range(2, 4)
		for _i in range(n):
			puddle["drops"].append({
				"ox": randf_range(-60.0, 60.0),
				"oy": randf_range(-20.0, 20.0),
				"r":  randf_range(8.0, 18.0),
			})
	_puddles.append(puddle)


# Draws a filled ellipse by scaling a unit circle.
func _draw_ellipse(center: Vector2, rot: float, rx: float, ry: float, color: Color) -> void:
	draw_set_transform(center, rot, Vector2(rx, ry))
	draw_circle(Vector2.ZERO, 1.0, color)
	draw_set_transform(Vector2.ZERO)


func _draw() -> void:
	for p in _puddles:
		var pos: Vector2 = p["pos"]
		var rot: float = p["rot"]
		var sz: float = p["size"]
		match p["type"]:
			0:  # Standard oval (~2.2:1)
				_draw_ellipse(pos, rot, 40.0 * sz, 18.0 * sz, WATER_COLOR)
				_draw_ellipse(pos + Vector2(10.0, -4.0).rotated(rot), rot, 18.0 * sz, 8.0 * sz, REFLECT_COLOR)
			1:  # Elongated oval (~2.3:1)
				_draw_ellipse(pos, rot, 46.0 * sz, 20.0 * sz, WATER_COLOR)
				_draw_ellipse(pos + Vector2(12.0, 0.0).rotated(rot), rot, 22.0 * sz, 9.0 * sz, REFLECT_COLOR)
			2:  # Organic cluster
				_draw_ellipse(pos, rot, 32.0 * sz, 16.0 * sz, WATER_COLOR)
				for d in p["drops"]:
					var dp := pos + Vector2(d["ox"], d["oy"]).rotated(rot) * sz
					_draw_ellipse(dp, rot, d["r"] * sz, d["r"] * 0.65 * sz, WATER_COLOR)
			3:  # Wide shallow pool (~2.1:1)
				_draw_ellipse(pos, rot, 50.0 * sz, 24.0 * sz, DEEP_COLOR)
				_draw_ellipse(pos + Vector2(-8.0, -5.0).rotated(rot), rot, 24.0 * sz, 11.0 * sz, REFLECT_COLOR)
