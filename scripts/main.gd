extends Node2D


func _ready() -> void:
	$ObstacleManager.hit_detected.connect(_on_hit)


func _on_hit() -> void:
	$Car.set_process(false)
	$GameOverlay.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if $GameOverlay.visible and event is InputEventKey and event.pressed:
		get_tree().reload_current_scene()
