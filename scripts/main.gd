extends Node2D

const MAX_LIVES := 3
const BLINK_DURATION := 2.0
const BLINK_HALF_PERIOD := 0.1  # visible/hidden each for 0.1s → 5 Hz blink

var _lives := MAX_LIVES
var _blink_timer    := 0.0
var _police_active  := false


func _ready() -> void:
	_apply_resolution.call_deferred()
	$ObstacleManager.hit_detected.connect(_on_hit)
	$ElkManager.elk_hit_car.connect(_on_hit)
	$CatManager.cat_hit_car.connect(_on_cat_hit)
	$PoliceManager.chase_ended.connect(_on_chase_ended)
	$PoliceManager.bullet_hit_car.connect(_on_hit)
	_update_lives()


func _apply_resolution() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("res://config.cfg") != OK:
		return
	var res_str: String = str(cfg.get_value("display", "resolution", "1280x720"))
	var parts := res_str.split("x")
	if parts.size() != 2:
		return
	var w := int(parts[0])
	var h := int(parts[1])
	var win := get_window()
	win.mode = Window.MODE_WINDOWED
	win.size = Vector2i(w, h)
	var screen := DisplayServer.screen_get_usable_rect()
	win.position = screen.position + (screen.size - win.size) / 2


func _process(delta: float) -> void:
	$HUD/SpeedLabel.text = "%d km/h" % int($Car.speed_kmh)

	if _blink_timer > 0.0:
		_blink_timer -= delta
		$Car/Sprite2D.visible = fmod(_blink_timer, BLINK_HALF_PERIOD * 2) >= BLINK_HALF_PERIOD
		if _blink_timer <= 0.0:
			$Car/Sprite2D.visible = true


func _on_cat_hit() -> void:
	if _police_active:
		return
	_police_active = true
	$ObstacleManager.start_police_mode()
	$ElkManager.set_process(false)
	$CatManager.stop_spawning()
	$PoliceManager.start_chase()


func _on_chase_ended() -> void:
	_police_active = false
	$ObstacleManager.stop_police_mode()
	$ElkManager.set_process(true)
	$ElkManager.start_spawning()
	$CatManager.start_spawning()


func _on_hit() -> void:
	_lives -= 1
	_update_lives()
	if _lives <= 0:
		$Car/Sprite2D.visible = true
		$Car.set_process(false)
		$ObstacleManager.stop()
		$ElkManager.set_process(false)
		$CatManager.set_process(false)
		$PoliceManager.set_process(false)
		$GameOverlay.visible = true
	else:
		_blink_timer = BLINK_DURATION


func _update_lives() -> void:
	$HUD/LivesLabel.text = "Lives: %d" % _lives


func _unhandled_input(event: InputEvent) -> void:
	if $GameOverlay.visible and event is InputEventKey and event.pressed:
		get_tree().reload_current_scene()
