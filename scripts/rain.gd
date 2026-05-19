extends Node2D

const DROP_SPEED := 700.0
const DROP_DIR   := Vector2(-0.21, 0.98)  # slight left lean, ~normalized
const DROP_LEN   := 15.0

var _drops: PackedVector2Array


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
	_drops.resize(count)
	for i in range(count):
		_drops[i] = Vector2(randf() * vp.size.x, randf() * vp.size.y)


func _process(delta: float) -> void:
	var vp := get_viewport_rect()
	var step: Vector2 = DROP_DIR * DROP_SPEED * delta
	for i in range(_drops.size()):
		var p: Vector2 = _drops[i] + step
		if p.y > vp.size.y:
			p = Vector2(randf() * vp.size.x, -DROP_LEN)
		_drops[i] = p
	queue_redraw()


func _draw() -> void:
	var color := Color(0.75, 0.88, 1.00, 0.40)
	var tail: Vector2 = DROP_DIR * DROP_LEN
	for p in _drops:
		draw_line(p, p + tail, color, 1.0)
