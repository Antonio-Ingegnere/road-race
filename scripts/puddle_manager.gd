extends Node2D

const ROAD_LEFT  := 312.0
const ROAD_WIDTH := 400.0
const CAR_VIS_HW := 40.0
const CAR_VIS_HH := 64.0

const PUDDLE_SCALE    := 1.5
const SPAWN_INTERVAL  := 1.5
const SPAWN_CHANCE    := 0.8
const DRIFT_CHANCE    := 0.8

# Opaque half-extents at PUDDLE_SCALE (measured: vis_hw=32, vis_hh=12.5 at 1x)
const HIT_HW := 48.0   # 32.0 * 1.5
const HIT_HH := 18.75  # 12.5 * 1.5

var _tex: Texture2D
var _tex_hw: float
var _tex_hh: float

var _puddles: Array = []  # {"pos": Vector2, "rot": float, "hit": bool}
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
	_tex = load("res://assets/puddle.png")
	_tex_hw = _tex.get_width() * 0.5
	_tex_hh = _tex.get_height() * 0.5


func _process(delta: float) -> void:
	var road_scroll: float = _car.speed_kmh * _car.KMH_TO_PXS * delta
	var screen_h: float = get_viewport_rect().size.y

	for p in _puddles:
		p["pos"] = p["pos"] + Vector2(0.0, road_scroll)
	_puddles = _puddles.filter(func(p) -> bool: return p["pos"].y < screen_h + _tex_hh * PUDDLE_SCALE)

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
		if abs(cp.x - op.x) < CAR_VIS_HW + HIT_HW and abs(cp.y - op.y) < CAR_VIS_HH + HIT_HH:
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
	var rot: float = (randi() % 2) * PI
	_puddles.append({"pos": Vector2(x, -_tex_hh * PUDDLE_SCALE), "rot": rot, "hit": false})


func _draw() -> void:
	for p in _puddles:
		draw_set_transform(p["pos"], p["rot"], Vector2(PUDDLE_SCALE, PUDDLE_SCALE))
		draw_texture(_tex, Vector2(-_tex_hw, -_tex_hh))
	draw_set_transform(Vector2.ZERO)
