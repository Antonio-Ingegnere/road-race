extends Node2D

signal elk_hit_car

const STATE_STAND      := 0
const STATE_EAT        := 1
const STATE_JUMP_RAISE := 2  # head-up base frame, brief pause before takeoff
const STATE_JUMP_OUT   := 3  # flying from side → road lane
const STATE_ON_ROAD    := 4  # landed on road, acts as obstacle
const STATE_JUMP_BACK  := 5  # flying from road lane → opposite side

const ROAD_LEFT  := 760.0
const ROAD_WIDTH := 400.0
const LANE_COUNT := 3

const FRAME_W   := 64
const FRAME_H   := 64
const ELK_SCALE := 2.25

const SIDE_OFFSET_MIN := 3.75
const SIDE_OFFSET_MAX := 15.0

const SPAWN_INTERVAL := 4.0

const STAND_MIN := 0.6
const STAND_MAX := 1.4
const EAT_MIN   := 0.6
const EAT_MAX   := 1.2

const JUMP_RAISE_TIME := 0.18
const ON_ROAD_TIME    := 0.90
# Duration of each jump-sheet frame (seconds); must sum to JUMP_TOTAL_TIME
const JUMP_FRAME_TIMES := [0.09, 0.11, 0.11, 0.09]
const JUMP_TOTAL_TIME  := 0.40

const ELK_HIT_HW := 49.5
const ELK_HIT_HH := 49.5
const CAR_VIS_HW  := 40.0
const CAR_VIS_HH  := 64.0

const SHADOW_RADIUS  := 31.5
const JUMP_ARC_HEIGHT := 36.0  # px upward at the arc peak

var _tex_base: Texture2D
var _tex_jump: Texture2D
var _elks: Array = []
var _spawn_timer  := 0.0
var _stop_spawning := false
var _car: Node2D
var _obstacle_mgr: Node
var _spawn_chance := 0.8
var _jump_chance  := 0.9


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("res://config.cfg") == OK:
		var enabled := bool(cfg.get_value("elk", "enabled", true))
		if not enabled:
			set_process(false)
			return
		_spawn_chance = float(cfg.get_value("elk", "spawn_chance", 0.8))
		_jump_chance  = float(cfg.get_value("elk", "jump_chance",  0.9))
	_car         = get_parent().get_node("Car")
	_obstacle_mgr = get_parent().get_node("ObstacleManager")
	_tex_base    = load("res://assets/Elk_Animated_x64-Sheet.png")
	_tex_jump    = load("res://assets/JumpingElk_x64-Sheet.png")


func _process(delta: float) -> void:
	var road_scroll: float = _car.speed_kmh * _car.KMH_TO_PXS * delta
	var screen_h: float = get_viewport_rect().size.y

	for elk in _elks:
		elk["pos"] = elk["pos"] + Vector2(0.0, road_scroll)
		_update_elk(elk, delta)

	_elks = _elks.filter(
		func(e) -> bool: return e["pos"].y < screen_h + FRAME_H * ELK_SCALE * 0.5
	)

	if not _stop_spawning:
		_spawn_timer += delta
		if _spawn_timer >= SPAWN_INTERVAL:
			_spawn_timer = 0.0
			if randf() < _spawn_chance:
				_spawn()

	var any_airborne := false
	for elk in _elks:
		if elk["state"] in [STATE_JUMP_OUT, STATE_ON_ROAD, STATE_JUMP_BACK]:
			any_airborne = true
			break
	z_index = 1 if any_airborne else 0

	queue_redraw()


func stop_spawning() -> void:
	_stop_spawning = true


func start_spawning() -> void:
	_stop_spawning = false


# ── State machine ──────────────────────────────────────────────────────────────

func _update_elk(elk: Dictionary, delta: float) -> void:
	match elk["state"]:
		STATE_STAND, STATE_EAT:
			elk["state_timer"] -= delta
			if elk["state_timer"] <= 0.0:
				if randf() < _jump_chance:
					_begin_jump_raise(elk)
				else:
					_switch_pose(elk)

		STATE_JUMP_RAISE:
			elk["state_timer"] -= delta
			if elk["state_timer"] <= 0.0:
				_begin_jump_out(elk)

		STATE_JUMP_OUT:
			_advance_jump_frame(elk, delta)
			elk["pos"].x = lerpf(elk["jump_start_x"], elk["land_x"], elk["jump_t"])
			if elk["jump_frame"] >= 4:
				_begin_on_road(elk)

		STATE_ON_ROAD:
			elk["state_timer"] -= delta
			if _car.is_processing():
				_check_car_collision(elk)
			if elk["state_timer"] <= 0.0:
				_begin_jump_back(elk)

		STATE_JUMP_BACK:
			_advance_jump_frame(elk, delta)
			elk["pos"].x = lerpf(elk["land_x"], elk["dest_x"], elk["jump_t"])
			if elk["jump_frame"] >= 4:
				_finish_jump(elk)


func _switch_pose(elk: Dictionary) -> void:
	if elk["state"] == STATE_STAND:
		elk["state"] = STATE_EAT
		elk["frame"] = 1
		elk["state_timer"] = randf_range(EAT_MIN, EAT_MAX)
	else:
		elk["state"] = STATE_STAND
		elk["frame"] = 0
		elk["state_timer"] = randf_range(STAND_MIN, STAND_MAX)


func _begin_jump_raise(elk: Dictionary) -> void:
	var lane := _free_lane()
	if lane == -1:  # all lanes blocked — skip jump
		_switch_pose(elk)
		return
	var offset: float = randf_range(SIDE_OFFSET_MIN, SIDE_OFFSET_MAX)
	var hw: float = FRAME_W * ELK_SCALE * 0.5
	elk["land_x"] = _lane_center(lane)
	elk["dest_x"] = ROAD_LEFT - offset - hw if elk["right"] \
		else ROAD_LEFT + ROAD_WIDTH + offset + hw
	elk["state"]      = STATE_JUMP_RAISE
	elk["frame"]      = 0
	elk["state_timer"] = JUMP_RAISE_TIME


func _begin_jump_out(elk: Dictionary) -> void:
	elk["state"]            = STATE_JUMP_OUT
	elk["jump_frame"]       = 0
	elk["jump_frame_timer"] = JUMP_FRAME_TIMES[0]
	elk["jump_elapsed"]     = 0.0
	elk["jump_t"]           = 0.0
	elk["jump_start_x"]     = elk["pos"].x


func _advance_jump_frame(elk: Dictionary, delta: float) -> void:
	elk["jump_elapsed"]     += delta
	elk["jump_frame_timer"] -= delta
	while elk["jump_frame_timer"] <= 0.0 and elk["jump_frame"] < 4:
		elk["jump_frame"] += 1
		if elk["jump_frame"] < 4:
			elk["jump_frame_timer"] += JUMP_FRAME_TIMES[elk["jump_frame"]]
	elk["jump_t"] = clampf(elk["jump_elapsed"] / JUMP_TOTAL_TIME, 0.0, 1.0)


func _begin_on_road(elk: Dictionary) -> void:
	elk["state"]       = STATE_ON_ROAD
	elk["pos"].x       = elk["land_x"]
	elk["state_timer"] = ON_ROAD_TIME


func _check_car_collision(elk: Dictionary) -> void:
	var cp := _car.position
	var ep: Vector2 = elk["pos"]
	if abs(cp.x - ep.x) < CAR_VIS_HW + ELK_HIT_HW \
		and abs(cp.y - ep.y) < CAR_VIS_HH + ELK_HIT_HH:
		elk_hit_car.emit()
		_begin_jump_back(elk)


func _begin_jump_back(elk: Dictionary) -> void:
	elk["state"]            = STATE_JUMP_BACK
	elk["jump_frame"]       = 0
	elk["jump_frame_timer"] = JUMP_FRAME_TIMES[0]
	elk["jump_elapsed"]     = 0.0
	elk["jump_t"]           = 0.0


func _finish_jump(elk: Dictionary) -> void:
	elk["pos"].x  = elk["dest_x"]
	elk["right"]  = not elk["right"]  # now on the opposite side
	var st := randi() % 2
	elk["state"]       = st
	elk["frame"]       = st
	elk["state_timer"] = randf_range(STAND_MIN, STAND_MAX) if st == 0 \
		else randf_range(EAT_MIN, EAT_MAX)


# ── Spawn ──────────────────────────────────────────────────────────────────────

func _spawn() -> void:
	var right := bool(randi() % 2)
	var offset: float = randf_range(SIDE_OFFSET_MIN, SIDE_OFFSET_MAX)
	var hw: float = FRAME_W * ELK_SCALE * 0.5
	var x: float = ROAD_LEFT + ROAD_WIDTH + offset + hw if right \
		else ROAD_LEFT - offset - hw
	var st := randi() % 2
	_elks.append({
		"pos":             Vector2(x, -FRAME_H * ELK_SCALE * 0.5),
		"right":           right,
		"state":           st,
		"frame":           st,
		"state_timer":     randf_range(0.1, 0.35),  # decide to jump almost immediately
		"jump_frame":      0,
		"jump_frame_timer": 0.0,
		"jump_elapsed":    0.0,
		"jump_t":          0.0,
		"jump_start_x":    x,
		"land_x":          0.0,
		"dest_x":          0.0,
	})


# ── Draw ───────────────────────────────────────────────────────────────────────

func _draw() -> void:
	var hw: float = FRAME_W * 0.5
	var hh: float = FRAME_H * 0.5

	for elk in _elks:
		var state: int = elk["state"]

		# Shadow stays on the ground at the landing spot (no arc offset)
		if state == STATE_JUMP_RAISE or state == STATE_JUMP_OUT:
			draw_circle(Vector2(elk["land_x"], elk["pos"].y), SHADOW_RADIUS,
				Color(0.0, 0.0, 0.0, 0.30))

		# Arc offset: bulge upward (−y) during both jump phases
		var arc_y: float = 0.0
		if state == STATE_JUMP_OUT or state == STATE_JUMP_BACK:
			arc_y = -sin(elk["jump_t"] * PI) * JUMP_ARC_HEIGHT
		var draw_pos: Vector2 = elk["pos"] + Vector2(0.0, arc_y)

		# Base sprite faces right; jump sprite faces left — both use the same rule:
		# right=true → no flip, right=false → flip.
		var sx: float = ELK_SCALE if elk["right"] else -ELK_SCALE

		draw_set_transform(draw_pos, 0.0, Vector2(sx, ELK_SCALE))

		match state:
			STATE_STAND, STATE_EAT, STATE_JUMP_RAISE:
				draw_texture_rect_region(
					_tex_base,
					Rect2(-hw, -hh, FRAME_W, FRAME_H),
					Rect2(elk["frame"] * FRAME_W, 0, FRAME_W, FRAME_H)
				)
			STATE_JUMP_OUT, STATE_ON_ROAD, STATE_JUMP_BACK:
				var jf: int = mini(elk["jump_frame"], 3)
				draw_texture_rect_region(
					_tex_jump,
					Rect2(-hw, -hh, FRAME_W, FRAME_H),
					Rect2(jf * FRAME_W, 0, FRAME_W, FRAME_H)
				)

	draw_set_transform(Vector2.ZERO)


# ── Helpers ────────────────────────────────────────────────────────────────────

func _lane_center(lane: int) -> float:
	return ROAD_LEFT + (ROAD_WIDTH / LANE_COUNT) * (lane + 0.5)


func _free_lane() -> int:
	var obs_positions: Array[Vector2] = _obstacle_mgr.get_obstacle_positions()
	var blocked: Array[int] = []
	for op in obs_positions:
		var lane := clampi(int((op.x - ROAD_LEFT) / (ROAD_WIDTH / LANE_COUNT)), 0, LANE_COUNT - 1)
		if lane not in blocked:
			blocked.append(lane)
	var free: Array[int] = []
	for i in range(LANE_COUNT):
		if i not in blocked:
			free.append(i)
	if free.is_empty():
		return -1
	return free[randi() % free.size()]
