extends CanvasLayer

const CYCLE := 60.0          # total seconds: 20 day + 10 dusk + 20 night + 10 dawn
const DAY_END   := 20.0 / CYCLE
const DUSK_END  := 30.0 / CYCLE
const NIGHT_END := 50.0 / CYCLE

const COLOR_CLEAR    := Color(0.00, 0.00, 0.00, 0.00)
const COLOR_TWILIGHT := Color(0.55, 0.15, 0.05, 0.45)
const COLOR_NIGHT    := Color(0.00, 0.02, 0.15, 0.78)

var _time := 0.0
@onready var _overlay: ColorRect = $Overlay


func _process(delta: float) -> void:
	_time = fmod(_time + delta, CYCLE)
	_overlay.color = _sky_color(_time / CYCLE)


func _sky_color(p: float) -> Color:
	var intensity: float
	if p < DAY_END:
		intensity = 0.0
	elif p < DUSK_END:
		intensity = (p - DAY_END) / (DUSK_END - DAY_END)
	elif p < NIGHT_END:
		intensity = 1.0
	else:
		intensity = 1.0 - (p - NIGHT_END) / (1.0 - NIGHT_END)

	if intensity < 0.5:
		return COLOR_CLEAR.lerp(COLOR_TWILIGHT, intensity * 2.0)
	else:
		return COLOR_TWILIGHT.lerp(COLOR_NIGHT, (intensity - 0.5) * 2.0)
