extends Node2D

const SPEED := 300.0
const ROAD_LEFT := 312.0
const ROAD_RIGHT := 712.0  # ROAD_LEFT + ROAD_WIDTH (400)
const CAR_HALF_WIDTH := 42.0  # half of 84 px (42px sprite * 2x scale)


func _process(delta: float) -> void:
	if Input.is_action_pressed("ui_left"):
		position.x -= SPEED * delta
	if Input.is_action_pressed("ui_right"):
		position.x += SPEED * delta

	position.x = clamp(position.x, ROAD_LEFT + CAR_HALF_WIDTH, ROAD_RIGHT - CAR_HALF_WIDTH)
