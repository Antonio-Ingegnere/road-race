extends Node2D

const DROP_SPEED    := 700.0
const DROP_DIR      := Vector2(-0.21, 0.98)
const DROP_LEN_BASE := 15.0

const SPLASH_LIFETIME   := 0.22
const SPLASH_MAX_RADIUS := 16.0

var _drops:       PackedVector2Array
var _drop_speeds: PackedFloat32Array
var _drop_lens:   PackedFloat32Array
var _drop_alphas: PackedFloat32Array

var _splashes: Array  # each: [x, y, age]
var _spawn_width: float = 0.0  # screen width + rightward margin to compensate leftward drift


func _ready() -> void:
	var cfg := ConfigFile.new()
	var enabled := false
	var count := 300
	if cfg.load("res://config.cfg") == OK:
		enabled = bool(cfg.get_value("rain", "enabled", false))
		count = int(cfg.get_value("rain", "drop_count", 300))
	if not enabled:
		set_process(false)
		return
	var vp := get_viewport_rect()
	var drift: float = vp.size.y * abs(DROP_DIR.x / DROP_DIR.y)
	_spawn_width = vp.size.x + drift
	_drops.resize(count)
	_drop_speeds.resize(count)
	_drop_lens.resize(count)
	_drop_alphas.resize(count)
	for i in range(count):
		_drops[i] = Vector2(randf() * _spawn_width, randf() * vp.size.y)
		_randomize_drop(i)


func _randomize_drop(i: int) -> void:
	_drop_speeds[i] = randf_range(0.75, 1.3)
	_drop_lens[i]   = randf_range(0.6, 1.6)
	_drop_alphas[i] = randf_range(0.22, 0.52)


func _process(delta: float) -> void:
	var vp := get_viewport_rect()
	for i in range(_drops.size()):
		var p: Vector2 = _drops[i] + DROP_DIR * (DROP_SPEED * _drop_speeds[i] * delta)
		if p.y > vp.size.y:
			_splashes.append([p.x, vp.size.y, 0.0])
			p = Vector2(randf() * _spawn_width, -DROP_LEN_BASE * _drop_lens[i])
			_randomize_drop(i)
		_drops[i] = p

	var si := 0
	while si < _splashes.size():
		_splashes[si][2] += delta
		if _splashes[si][2] >= SPLASH_LIFETIME:
			_splashes.remove_at(si)
		else:
			si += 1

	queue_redraw()


func _draw() -> void:
	var tail_base: Vector2 = DROP_DIR * DROP_LEN_BASE

	for i in range(_drops.size()):
		draw_line(
			_drops[i],
			_drops[i] + tail_base * _drop_lens[i],
			Color(0.75, 0.88, 1.00, _drop_alphas[i]),
			1.0
		)

	for s in _splashes:
		var t: float = s[2] / SPLASH_LIFETIME
		var alpha: float = (1.0 - t) * 0.45
		var r: float = SPLASH_MAX_RADIUS * t
		var pos := Vector2(s[0], s[1])
		var color := Color(0.80, 0.90, 1.00, alpha)
		# Expanding ripple ring
		draw_arc(pos, maxf(r, 0.5), 0.0, TAU, 12, color, 1.0)
		# Two spray lines shooting upward
		draw_line(pos, pos + Vector2(-r * 1.4, -r * 1.1), color, 1.0)
		draw_line(pos, pos + Vector2( r * 1.4, -r * 1.1), color, 1.0)
