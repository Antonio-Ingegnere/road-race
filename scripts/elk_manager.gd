extends Node2D

const ROAD_LEFT := 312.0
const ROAD_WIDTH := 400.0

const FRAME_W   := 64
const FRAME_H   := 64
const ELK_SCALE := 2.0

const SIDE_OFFSET_MIN := 5.0
const SIDE_OFFSET_MAX := 20.0

const SPAWN_INTERVAL := 4.0

const STAND_MIN := 0.6
const STAND_MAX := 1.4
const EAT_MIN   := 0.6
const EAT_MAX   := 1.2

var _tex: Texture2D
var _elks: Array = []
var _spawn_timer := 0.0
var _car: Node2D
var _spawn_chance := 0.8


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("res://config.cfg") == OK:
		var enabled := bool(cfg.get_value("elk", "enabled", true))
		if not enabled:
			set_process(false)
			return
		_spawn_chance = float(cfg.get_value("elk", "spawn_chance", 0.8))
	_car = get_parent().get_node("Car")
	_tex = load("res://assets/Elk_Animated_x64-Sheet.png")


func _process(delta: float) -> void:
	var road_scroll: float = _car.speed_kmh * _car.KMH_TO_PXS * delta
	var screen_h: float = get_viewport_rect().size.y

	for elk in _elks:
		elk["pos"] = elk["pos"] + Vector2(0.0, road_scroll)
		elk["state_timer"] -= delta
		if elk["state_timer"] <= 0.0:
			if elk["state"] == 0:  # standing → eating
				elk["state"] = 1
				elk["frame"] = 1
				elk["state_timer"] = randf_range(EAT_MIN, EAT_MAX)
			else:  # eating → standing
				elk["state"] = 0
				elk["frame"] = 0
				elk["state_timer"] = randf_range(STAND_MIN, STAND_MAX)

	_elks = _elks.filter(
		func(e) -> bool: return e["pos"].y < screen_h + FRAME_H * ELK_SCALE * 0.5
	)

	_spawn_timer += delta
	if _spawn_timer >= SPAWN_INTERVAL:
		_spawn_timer = 0.0
		if randf() < _spawn_chance:
			_spawn()

	queue_redraw()


func _spawn() -> void:
	var right := bool(randi() % 2)
	var offset: float = randf_range(SIDE_OFFSET_MIN, SIDE_OFFSET_MAX)
	var hw: float = FRAME_W * ELK_SCALE * 0.5
	var x: float = ROAD_LEFT + ROAD_WIDTH + offset + hw if right \
		else ROAD_LEFT - offset - hw
	var state := randi() % 2
	_elks.append({
		"pos": Vector2(x, -FRAME_H * ELK_SCALE * 0.5),
		"right": right,
		"state": state,
		"frame": state,
		"state_timer": randf_range(STAND_MIN, STAND_MAX) if state == 0 else randf_range(EAT_MIN, EAT_MAX),
	})


func _draw() -> void:
	if _tex == null:
		return
	var hw: float = FRAME_W * 0.5
	var hh: float = FRAME_H * 0.5
	for elk in _elks:
		var src := Rect2(elk["frame"] * FRAME_W, 0, FRAME_W, FRAME_H)
		# Right side: keep as-is. Left side: flip horizontally via negative x scale.
		var sx: float = ELK_SCALE if elk["right"] else -ELK_SCALE
		draw_set_transform(elk["pos"], 0.0, Vector2(sx, ELK_SCALE))
		draw_texture_rect_region(_tex, Rect2(-hw, -hh, FRAME_W, FRAME_H), src)
	draw_set_transform(Vector2.ZERO)
