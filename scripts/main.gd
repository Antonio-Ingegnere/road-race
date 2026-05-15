extends Node2D


func _ready() -> void:
	$ObstacleManager.hit_detected.connect(_on_hit)


func _process(_delta: float) -> void:
	$HUD/SpeedLabel.text = "%d km/h" % int($Car.speed_kmh)


func _on_hit() -> void:
	$Car.set_process(false)
	$GameOverlay.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if $GameOverlay.visible and event is InputEventKey and event.pressed:
		get_tree().reload_current_scene()
