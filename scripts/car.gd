extends Node2D

const KMH_TO_PXS := 5.0
const MIN_SPEED_KMH := 50.0
const MAX_SPEED_KMH := 220.0
const SPEED_CHANGE_RATE := 60.0  # km/h per second
const LATERAL_SPEED := 420.0
const ROAD_LEFT := 312.0
const ROAD_RIGHT := 712.0
const CAR_HALF_WIDTH := 42.0

var speed_kmh := MIN_SPEED_KMH


func _process(delta: float) -> void:
	if Input.is_action_pressed("ui_up"):
		speed_kmh = minf(speed_kmh + SPEED_CHANGE_RATE * delta, MAX_SPEED_KMH)
	if Input.is_action_pressed("ui_down"):
		speed_kmh = maxf(speed_kmh - SPEED_CHANGE_RATE * delta, MIN_SPEED_KMH)

	if Input.is_action_pressed("ui_left"):
		position.x -= LATERAL_SPEED * delta
	if Input.is_action_pressed("ui_right"):
		position.x += LATERAL_SPEED * delta

	position.x = clamp(position.x, ROAD_LEFT + CAR_HALF_WIDTH, ROAD_RIGHT - CAR_HALF_WIDTH)
