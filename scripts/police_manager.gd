extends Node2D

signal chase_ended
signal bullet_hit_car

# Police appears at the very top of the screen.
# Every cycle: wait 3 s → shoot 3 bullets → step 5 % of road length closer
# + slide laterally to player's lane.  Repeat until police reaches player.

const STATE_IDLE          := 0
const STATE_HOLDING       := 1  # stationary, 3-s pause before shooting
const STATE_SHOOTING      := 2  # frame 1 (policeman), firing bullets
const STATE_REPOSITIONING := 3  # smooth step down + slide to player lane

const FRAME_W      := 64
const FRAME_H      := 64
const POLICE_SCALE := 2.0
const POLICE_HW    := 64.0   # FRAME_W * POLICE_SCALE * 0.5
const POLICE_HH    := 64.0   # FRAME_H * POLICE_SCALE * 0.5

# Step is 5 % of the visible road ahead of the player each cycle
const STEP_FRAC    := 0.05
const STEP_SPEED   := 120.0  # px/s for the step-down animation
const LATERAL_SPEED:= 180.0  # px/s horizontal repositioning

const HOLD_WAIT         := 3.0
const POST_SHOOT_WAIT   := 1.0   # pause between last shot and repositioning
const REPOSITION_TIME   := 0.5   # seconds for the step-down animation
const SHOT_COUNT   := 3
const SHOT_INTERVAL:= 1.0

const BULLET_W     := 12.0
const BULLET_H     := 50.0
const BULLET_SPEED := 550.0   # px/s downward toward player

const BLINK_HALF   := 0.15
const LIGHT_R      := 5.0

const POLICE_SPEED_KMH  := 200.0  # police can't exceed this; player outruns at higher speed
const KMH_TO_PXS        := 7.5
const CAR_HIT_HW        := 40.0   # player car collision half-width
const CAR_HIT_HH        := 64.0   # player car collision half-height
const BULLET_INVINCIBLE := 1.5    # seconds of invincibility after a bullet hit

# Light offsets: sprite px (24,26),(28,30) red; (35,26),(39,30) blue → ×2 scale
const RED_OFF1 := Vector2(-16.0, -12.0)
const RED_OFF2 := Vector2( -8.0,  -4.0)
const BLU_OFF1 := Vector2(  6.0, -12.0)
const BLU_OFF2 := Vector2( 14.0,  -4.0)

var _car:         Node2D
var _tex:         Texture2D
var _state:       int   = STATE_IDLE
var _pos:         Vector2
var _target_y:    float = 0.0
var _target_x:    float = 0.0
var _state_timer: float = 0.0
var _shot_timer:  float = 0.0
var _shots_done:  int   = 0
var _bullets:     Array = []
var _blink_phase:       float = 0.0
var _bullet_inv_timer:  float = 0.0
var _reposition_timer:  float = 0.0


func _ready() -> void:
	_car = get_parent().get_node("Car")
	_tex = load("res://assets/PoliceCar-Sheet.png")
	set_process(false)


func start_chase() -> void:
	_pos         = Vector2(_car.position.x, POLICE_HH)   # top of screen
	_target_y    = POLICE_HH
	_target_x    = _car.position.x
	_state       = STATE_HOLDING
	_state_timer = HOLD_WAIT
	_blink_phase      = 0.0
	_bullet_inv_timer = 0.0
	_reposition_timer = 0.0
	_bullets.clear()
	_shots_done  = 0
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_blink_phase += delta
	if _bullet_inv_timer > 0.0:
		_bullet_inv_timer -= delta

	# When player exceeds police speed cap the police falls behind and drifts off screen
	# Overtake drift: only during HOLDING/SHOOTING — not while police is actively stepping down
	if _state != STATE_REPOSITIONING:
		var spd: float    = _car.speed_kmh
		var excess: float = maxf(0.0, spd - POLICE_SPEED_KMH)
		if excess > 0.0:
			_pos.y += excess * KMH_TO_PXS * delta
			if _pos.y > get_viewport_rect().size.y + POLICE_HH:   # fully off screen bottom → player escaped
				_end_chase()
				return

	_update_state(delta)
	_update_bullets(delta)
	_check_body_collision()
	queue_redraw()


func _update_state(delta: float) -> void:
	match _state:
		STATE_HOLDING:
			_state_timer -= delta
			if _state_timer <= 0.0:
				_state      = STATE_SHOOTING
				_shots_done = 0
				_shot_timer = 0.0

		STATE_SHOOTING:
			_shot_timer -= delta
			if _shot_timer <= 0.0 and _shots_done < SHOT_COUNT:
				_fire_bullet()
				_shots_done += 1
				_shot_timer  = SHOT_INTERVAL
				if _shots_done == SHOT_COUNT:
					_state_timer = POST_SHOOT_WAIT
			elif _shots_done >= SHOT_COUNT:
				_state_timer -= delta
				if _state_timer <= 0.0:
					var road_len: float = _car.position.y - POLICE_HH
					_target_y = maxf(_pos.y, minf(_pos.y + road_len * STEP_FRAC,
									  _car.position.y - POLICE_HH))
					_target_x      = _car.position.x
					var t_y: float = maxf(0.0, _target_y - _pos.y) / STEP_SPEED
					var t_x: float = abs(_target_x - _pos.x) / LATERAL_SPEED
					_reposition_timer = maxf(t_y, t_x) + 0.05
					_state            = STATE_REPOSITIONING

		STATE_REPOSITIONING:
			_reposition_timer -= delta
			_pos.y = minf(_pos.y + STEP_SPEED * delta, _target_y)
			var dx: float = _target_x - _pos.x
			_pos.x += signf(dx) * minf(LATERAL_SPEED * delta, abs(dx))
			if _reposition_timer <= 0.0:
				_pos.y       = _target_y
				_pos.x       = _target_x
				_state       = STATE_HOLDING
				_state_timer = HOLD_WAIT


func _check_body_collision() -> void:
	if _bullet_inv_timer > 0.0 or not _car.is_processing():
		return
	var cp: Vector2 = _car.position
	if abs(cp.x - _pos.x) < CAR_HIT_HW + POLICE_HW \
			and abs(cp.y - _pos.y) < CAR_HIT_HH + POLICE_HH:
		_bullet_inv_timer = BULLET_INVINCIBLE
		bullet_hit_car.emit()


func _fire_bullet() -> void:
	_bullets.append({"pos": _pos + Vector2(30.0, POLICE_HH * 0.6), "alive": true})


func _update_bullets(delta: float) -> void:
	var screen_h: float  = get_viewport_rect().size.y
	var car_pos: Vector2 = _car.position
	for b in _bullets:
		var p: Vector2 = b["pos"]
		p.y += BULLET_SPEED * delta
		b["pos"] = p
		if p.y > screen_h + BULLET_H:
			b["alive"] = false
		elif _bullet_inv_timer <= 0.0 and _car.is_processing():
			if abs(p.x - car_pos.x) < CAR_HIT_HW + BULLET_W * 0.5 \
					and abs(p.y + BULLET_H * 0.5 - car_pos.y) < CAR_HIT_HH + BULLET_H * 0.5:
				b["alive"]        = false
				_bullet_inv_timer = BULLET_INVINCIBLE
				bullet_hit_car.emit()
	_bullets = _bullets.filter(func(bullet) -> bool: return bullet["alive"])


func _end_chase() -> void:
	_state = STATE_IDLE
	_bullets.clear()
	set_process(false)
	chase_ended.emit()
	queue_redraw()


func _draw() -> void:
	if _state == STATE_IDLE:
		return

	var hw: float = FRAME_W * 0.5
	var hh: float = FRAME_H * 0.5
	var fr: int   = 1 if _state == STATE_SHOOTING else 0

	draw_set_transform(_pos, 0.0, Vector2(POLICE_SCALE, POLICE_SCALE))
	draw_texture_rect_region(
		_tex,
		Rect2(-hw, -hh, FRAME_W, FRAME_H),
		Rect2(fr * FRAME_W, 0, FRAME_W, FRAME_H)
	)
	draw_set_transform(Vector2.ZERO)

	# Bullets travel downward toward player
	var bullet_col := Color(1.0, 0.95, 0.25)
	for b in _bullets:
		var bp: Vector2 = b["pos"]
		draw_rect(Rect2(bp.x - BULLET_W * 0.5, bp.y, BULLET_W, BULLET_H), bullet_col)

	# Red / blue lights alternate every BLINK_HALF seconds
	var red_on: bool  = fmod(_blink_phase, BLINK_HALF * 2.0) < BLINK_HALF
	var red_col  := Color(1.0, 0.08, 0.05, 1.0) if red_on     else Color(0.25, 0.0, 0.0, 0.5)
	var blue_col := Color(0.15, 0.2,  1.0, 1.0)  if not red_on else Color(0.0,  0.0, 0.25, 0.5)
	draw_circle(_pos + RED_OFF1, LIGHT_R, red_col)
	draw_circle(_pos + RED_OFF2, LIGHT_R, red_col)
	draw_circle(_pos + BLU_OFF1, LIGHT_R, blue_col)
	draw_circle(_pos + BLU_OFF2, LIGHT_R, blue_col)
