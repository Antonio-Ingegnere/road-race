extends Node2D

const SCROLL_SPEED := 250.0
const ROAD_LEFT := 312.0
const ROAD_WIDTH := 400.0
const DASH_HEIGHT := 40.0
const DASH_GAP := 30.0
const DASH_WIDTH := 5.0

var scroll_offset := 0.0


func _process(delta: float) -> void:
	scroll_offset = fmod(scroll_offset + SCROLL_SPEED * delta, DASH_HEIGHT + DASH_GAP)
	queue_redraw()


func _draw() -> void:
	var size := get_viewport_rect().size

	# Grass
	draw_rect(Rect2(0.0, 0.0, size.x, size.y), Color(0.18, 0.50, 0.20))

	# Road surface
	draw_rect(Rect2(ROAD_LEFT, 0.0, ROAD_WIDTH, size.y), Color(0.40, 0.40, 0.42))

	# Road shoulder lines
	draw_line(Vector2(ROAD_LEFT, 0.0), Vector2(ROAD_LEFT, size.y), Color(1.0, 1.0, 1.0, 0.85), 4.0)
	draw_line(
		Vector2(ROAD_LEFT + ROAD_WIDTH, 0.0),
		Vector2(ROAD_LEFT + ROAD_WIDTH, size.y),
		Color(1.0, 1.0, 1.0, 0.85),
		4.0
	)

	# Lane dividers at 1/3 and 2/3 of road width
	for i in [1, 2]:
		var cx: float = ROAD_LEFT + ROAD_WIDTH * (i / 3.0)
		var y := scroll_offset - DASH_HEIGHT
		while y < size.y:
			draw_rect(
				Rect2(cx - DASH_WIDTH * 0.5, y, DASH_WIDTH, DASH_HEIGHT),
				Color(1.0, 1.0, 0.8, 0.9)
			)
			y += DASH_HEIGHT + DASH_GAP
