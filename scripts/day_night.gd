extends CanvasLayer

const CYCLE := 60.0
const DAY_END   := 20.0 / CYCLE
const DUSK_END  := 30.0 / CYCLE
const NIGHT_END := 50.0 / CYCLE

const COLOR_CLEAR    := Color(0.00, 0.00, 0.00, 0.00)
const COLOR_TWILIGHT := Color(0.55, 0.15, 0.05, 0.45)
const COLOR_NIGHT    := Color(0.00, 0.02, 0.15, 0.78)

var intensity: float = 0.0  # 0 = full day, 1 = full night (read by lights.gd)

var _time := 0.0
@onready var _overlay: ColorRect = $Overlay


func _process(delta: float) -> void:
	_time = fmod(_time + delta, CYCLE)
	var p := _time / CYCLE
	intensity = _compute_intensity(p)
	_overlay.color = _sky_color(intensity)


func _compute_intensity(p: float) -> float:
	if p < DAY_END:
		return 0.0
	elif p < DUSK_END:
		return (p - DAY_END) / (DUSK_END - DAY_END)
	elif p < NIGHT_END:
		return 1.0
	else:
		return 1.0 - (p - NIGHT_END) / (1.0 - NIGHT_END)


func _sky_color(i: float) -> Color:
	if i < 0.5:
		return COLOR_CLEAR.lerp(COLOR_TWILIGHT, i * 2.0)
	else:
		return COLOR_TWILIGHT.lerp(COLOR_NIGHT, (i - 0.5) * 2.0)
