extends Node2D

const STATE_SITTING  := 0
const STATE_RUNNING  := 1
const STATE_BLINKING := 2

const ROAD_LEFT  := 760.0
const ROAD_RIGHT := 1160.0

const SIT_FRAME_W  := 64
const SIT_FRAME_H  := 64
const WALK_FRAME_W := 64
const WALK_FRAME_H := 63
const CAT_SCALE    := 0.75

const SITTING_FRAMES := 10
const WALKING_FRAMES := 9
const SITTING_FPS    := 7.0
const WALKING_FPS    := 10.0

const SIDE_OFFSET_MIN := 10.0
const SIDE_OFFSET_MAX := 25.0

const CAT_RUN_SPEED      := 220.0
const BLINK_SPEED_MUL    := 2.5
const SPAWN_INTERVAL := 5.5
const RUN_CHANCE     := 0.80
const BLINK_DURATION := 3.0
const BLINK_HALF     := 0.12

# Collision half-extents
const CAT_HIT_HW := 22.0
const CAT_HIT_HH := 22.0
const CAR_VIS_HW := 40.0
const CAR_VIS_HH := 64.0

var _tex_sit:  Texture2D
var _tex_walk: Texture2D
var _cats: Array = []
var _spawn_timer := 0.0
var _car: Node2D


func _ready() -> void:
	_car      = get_parent().get_node("Car")
	_tex_sit  = load("res://assets/CatOnaRoad_x64_animated-Sheet.png")
	_tex_walk = load("res://assets/WalkingCat-x64_animated-Sheet.png")


func _process(delta: float) -> void:
	var road_scroll: float = _car.speed_kmh * _car.KMH_TO_PXS * delta
	var screen_h: float    = get_viewport_rect().size.y

	for cat in _cats:
		cat["pos"] = cat["pos"] + Vector2(0.0, road_scroll)
		_update_cat(cat, delta)

	var half_h: float = SIT_FRAME_H * CAT_SCALE * 0.5
	_cats = _cats.filter(func(c) -> bool:
		return c["pos"].y < screen_h + half_h and not c["despawn"]
	)

	_spawn_timer += delta
	if _spawn_timer >= SPAWN_INTERVAL:
		_spawn_timer = 0.0
		_spawn()

	queue_redraw()


func _update_cat(cat: Dictionary, delta: float) -> void:
	match cat["state"]:
		STATE_SITTING:
			cat["anim_timer"] += delta
			if cat["anim_timer"] >= 1.0 / SITTING_FPS:
				cat["anim_timer"] -= 1.0 / SITTING_FPS
				cat["frame"] = (cat["frame"] + 1) % SITTING_FRAMES
			cat["sit_timer"] -= delta
			if cat["sit_timer"] <= 0.0:
				if randf() < RUN_CHANCE:
					cat["state"]      = STATE_RUNNING
					cat["frame"]      = 0
					cat["anim_timer"] = 0.0
				else:
					cat["sit_timer"] = 999.0  # won't run, scrolls off naturally

		STATE_RUNNING:
			cat["anim_timer"] += delta
			if cat["anim_timer"] >= 1.0 / WALKING_FPS:
				cat["anim_timer"] -= 1.0 / WALKING_FPS
				cat["frame"] = (cat["frame"] + 1) % WALKING_FRAMES

			cat["pos"].x += cat["run_dir"] * CAT_RUN_SPEED * delta

			if _car.is_processing():
				_check_collision(cat)

			var hw: float = WALK_FRAME_W * CAT_SCALE * 0.5
			if cat["run_dir"] > 0 and cat["pos"].x > ROAD_RIGHT + SIDE_OFFSET_MAX + hw:
				cat["despawn"] = true
			elif cat["run_dir"] < 0 and cat["pos"].x < ROAD_LEFT - SIDE_OFFSET_MAX - hw:
				cat["despawn"] = true

		STATE_BLINKING:
			cat["anim_timer"] += delta
			if cat["anim_timer"] >= 1.0 / WALKING_FPS:
				cat["anim_timer"] -= 1.0 / WALKING_FPS
				cat["frame"] = (cat["frame"] + 1) % WALKING_FRAMES

			cat["pos"].x += cat["run_dir"] * CAT_RUN_SPEED * BLINK_SPEED_MUL * delta

			cat["blink_timer"] -= delta
			if cat["blink_timer"] <= 0.0:
				cat["despawn"] = true

			var hw: float = WALK_FRAME_W * CAT_SCALE * 0.5
			if cat["run_dir"] > 0 and cat["pos"].x > ROAD_RIGHT + SIDE_OFFSET_MAX + hw:
				cat["despawn"] = true
			elif cat["run_dir"] < 0 and cat["pos"].x < ROAD_LEFT - SIDE_OFFSET_MAX - hw:
				cat["despawn"] = true


func _check_collision(cat: Dictionary) -> void:
	var cp: Vector2  = _car.position
	var op: Vector2  = cat["pos"]
	if abs(cp.x - op.x) < CAR_VIS_HW + CAT_HIT_HW \
			and abs(cp.y - op.y) < CAR_VIS_HH + CAT_HIT_HH:
		cat["state"]       = STATE_BLINKING
		cat["blink_timer"] = BLINK_DURATION


func _spawn() -> void:
	var right := bool(randi() % 2)
	var offset: float = randf_range(SIDE_OFFSET_MIN, SIDE_OFFSET_MAX)
	var hw: float     = SIT_FRAME_W * CAT_SCALE * 0.5
	var x: float      = ROAD_RIGHT + offset + hw if right else ROAD_LEFT - offset - hw
	var run_dir: float = -1.0 if right else 1.0
	_cats.append({
		"pos":        Vector2(x, -SIT_FRAME_H * CAT_SCALE * 0.5),
		"right":      right,
		"run_dir":    run_dir,
		"state":      STATE_SITTING,
		"frame":      0,
		"anim_timer": 0.0,
		"sit_timer":  randf_range(0.8, 2.5),
		"blink_timer": 0.0,
		"despawn":    false,
	})


func _draw() -> void:
	for cat in _cats:
		if cat["despawn"]:
			continue

		var state: int = cat["state"]

		if state == STATE_BLINKING:
			var visible_now: bool = fmod(cat["blink_timer"], BLINK_HALF * 2.0) >= BLINK_HALF
			if not visible_now:
				continue

		# Left-side cat (right=false) faces road → right (+scale)
		# Right-side cat (right=true) faces road → left (-scale)
		# Running: sign matches run_dir
		# Both sprites face left naturally.
		# Sitting: left-side cat (right=false) must face right → flip; right-side → no flip.
		# Running/blinking: face the direction of travel.
		var sx: float
		if state == STATE_SITTING:
			sx = CAT_SCALE if cat["right"] else -CAT_SCALE
		else:
			sx = -CAT_SCALE * cat["run_dir"]

		draw_set_transform(cat["pos"], 0.0, Vector2(sx, CAT_SCALE))

		match state:
			STATE_SITTING:
				draw_texture_rect_region(
					_tex_sit,
					Rect2(-SIT_FRAME_W * 0.5, -SIT_FRAME_H * 0.5, SIT_FRAME_W, SIT_FRAME_H),
					Rect2(cat["frame"] * SIT_FRAME_W, 0, SIT_FRAME_W, SIT_FRAME_H)
				)
			STATE_RUNNING, STATE_BLINKING:
				draw_texture_rect_region(
					_tex_walk,
					Rect2(-WALK_FRAME_W * 0.5, -WALK_FRAME_H * 0.5, WALK_FRAME_W, WALK_FRAME_H),
					Rect2(cat["frame"] * WALK_FRAME_W, 0, WALK_FRAME_W, WALK_FRAME_H)
				)

	draw_set_transform(Vector2.ZERO)
