extends Node2D

const MAX_LIVES := 3
const BLINK_DURATION := 2.0
const BLINK_HALF_PERIOD := 0.1  # visible/hidden each for 0.1s → 5 Hz blink

var _lives := MAX_LIVES
var _blink_timer := 0.0


func _ready() -> void:
	$ObstacleManager.hit_detected.connect(_on_hit)
	$ElkManager.elk_hit_car.connect(_on_hit)
	_update_lives()


func _process(delta: float) -> void:
	$HUD/SpeedLabel.text = "%d km/h" % int($Car.speed_kmh)

	if _blink_timer > 0.0:
		_blink_timer -= delta
		$Car/Sprite2D.visible = fmod(_blink_timer, BLINK_HALF_PERIOD * 2) >= BLINK_HALF_PERIOD
		if _blink_timer <= 0.0:
			$Car/Sprite2D.visible = true


func _on_hit() -> void:
	_lives -= 1
	_update_lives()
	if _lives <= 0:
		$Car/Sprite2D.visible = true
		$Car.set_process(false)
		$ObstacleManager.stop()
		$ElkManager.set_process(false)
		$GameOverlay.visible = true
	else:
		_blink_timer = BLINK_DURATION


func _update_lives() -> void:
	$HUD/LivesLabel.text = "Lives: %d" % _lives


func _unhandled_input(event: InputEvent) -> void:
	if $GameOverlay.visible and event is InputEventKey and event.pressed:
		get_tree().reload_current_scene()
