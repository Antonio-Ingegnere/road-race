extends Node2D

const KMH_TO_PXS := 7.5
const MIN_SPEED_KMH := 50.0
const MAX_SPEED_KMH := 220.0
const ROAD_LEFT := 760.0
const ROAD_RIGHT := 1160.0
const CAR_HALF_WIDTH := 42.0

const ENGINE_LEVELS  := [20.0,  40.0,  60.0]   # accel km/h per second; top = original
const BRAKE_LEVELS   := [30.0,  60.0, 150.0]   # decel km/h per second; medium = original
const LATERAL_LEVELS := [210.0, 420.0, 630.0]  # lateral speed px/s; medium = original

var speed_kmh := MIN_SPEED_KMH

var _tilt_deg: float = 0.0
var _accel_rate:    float = ENGINE_LEVELS[2]
var _brake_rate:    float = BRAKE_LEVELS[1]
var _lateral_speed: float = LATERAL_LEVELS[1]

var _shadow_tex: Texture2D
var _shadow_hw: float
var _shadow_hh: float


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("res://config.cfg") == OK:
		var eng: int = int(cfg.get_value("car", "engine",     2))
		var sus: int = int(cfg.get_value("car", "suspension", 1))
		var brk: int = int(cfg.get_value("car", "brakes",     1))
		_accel_rate    = ENGINE_LEVELS[clampi(eng, 0, 2)]
		_lateral_speed = LATERAL_LEVELS[clampi(sus, 0, 2)]
		_brake_rate    = BRAKE_LEVELS[clampi(brk, 0, 2)]
	_shadow_tex = load("res://assets/car.png")
	_shadow_hw = _shadow_tex.get_width() * 0.5
	_shadow_hh = _shadow_tex.get_height() * 0.5


func _process(delta: float) -> void:
	if Input.is_action_pressed("ui_up"):
		speed_kmh = minf(speed_kmh + _accel_rate * delta, MAX_SPEED_KMH)
	if Input.is_action_pressed("ui_down"):
		speed_kmh = maxf(speed_kmh - _brake_rate * delta, MIN_SPEED_KMH)

	if Input.is_action_pressed("ui_left"):
		position.x -= _lateral_speed * delta
	if Input.is_action_pressed("ui_right"):
		position.x += _lateral_speed * delta

	position.x = clamp(position.x, ROAD_LEFT + CAR_HALF_WIDTH, ROAD_RIGHT - CAR_HALF_WIDTH)

	var target_tilt: float = 0.0
	if Input.is_action_pressed("ui_left"):
		target_tilt = -5.0
	elif Input.is_action_pressed("ui_right"):
		target_tilt = 5.0
	_tilt_deg = lerpf(_tilt_deg, target_tilt, delta * 12.0)
	get_node("Sprite2D").rotation_degrees = _tilt_deg

	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2(6.0, 7.5), 0.0, Vector2(2.0, 2.0))
	draw_texture(_shadow_tex, Vector2(-_shadow_hw, -_shadow_hh), Color(0.0, 0.0, 0.0, 0.40))
	draw_set_transform(Vector2.ZERO)
