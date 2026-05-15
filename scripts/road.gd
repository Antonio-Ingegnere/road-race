extends Node2D

const ROAD_LEFT := 312.0
const ROAD_WIDTH := 400.0
const DASH_HEIGHT := 40.0
const DASH_GAP := 30.0
const DASH_WIDTH := 5.0
const TILE_SIZE := 64
const TILE_COLS := 8
const TILE_ROWS := 60

var scroll_offset := 0.0
var _world_scroll := 0.0
var _car: Node2D
var _asphalt_tex: Texture2D
var _rotations: Array = []


func _ready() -> void:
	_car = get_parent().get_node("Car")
	_asphalt_tex = load("res://assets/asphalt.png")
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for _r in range(TILE_ROWS):
		var row := []
		for _c in range(TILE_COLS):
			row.append(rng.randi_range(0, 3) * (PI / 2.0))
		_rotations.append(row)


func _process(delta: float) -> void:
	var scroll_speed: float = _car.speed_kmh * _car.KMH_TO_PXS
	var scroll_px := scroll_speed * delta
	scroll_offset = fmod(scroll_offset + scroll_px, DASH_HEIGHT + DASH_GAP)
	_world_scroll += scroll_px
	queue_redraw()


func _draw() -> void:
	var size := get_viewport_rect().size
	var half := TILE_SIZE * 0.5

	# Grass background
	draw_rect(Rect2(0.0, 0.0, size.x, size.y), Color(0.18, 0.50, 0.20))

	# Tiled asphalt
	# Tile world positions satisfy: ty = n*TILE_SIZE + _world_scroll for integer n
	# So the topmost tile on screen starts at fmod(_world_scroll, TILE_SIZE) - TILE_SIZE
	if _asphalt_tex:
		var tile_start_y := fmod(_world_scroll, TILE_SIZE) - TILE_SIZE
		var ty := tile_start_y
		while ty < size.y:
			# Stable world row: same formula gives same index as the tile scrolls down
			var world_row := posmod(floori((ty - _world_scroll) / float(TILE_SIZE)), TILE_ROWS)
			var col_idx := 0
			var tx := ROAD_LEFT
			while tx < ROAD_LEFT + ROAD_WIDTH + TILE_SIZE:
				var rot: float = _rotations[world_row][col_idx % TILE_COLS]
				draw_set_transform(Vector2(tx + half, ty + half), rot)
				draw_texture(_asphalt_tex, Vector2(-half, -half))
				col_idx += 1
				tx += TILE_SIZE
			ty += TILE_SIZE
		draw_set_transform(Vector2.ZERO)

	# Redraw grass on both sides to clip tile spillover at road edges
	draw_rect(Rect2(0.0, 0.0, ROAD_LEFT, size.y), Color(0.18, 0.50, 0.20))
	draw_rect(Rect2(ROAD_LEFT + ROAD_WIDTH, 0.0, size.x - ROAD_LEFT - ROAD_WIDTH, size.y), Color(0.18, 0.50, 0.20))

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
		var dy := scroll_offset - DASH_HEIGHT
		while dy < size.y:
			draw_rect(
				Rect2(cx - DASH_WIDTH * 0.5, dy, DASH_WIDTH, DASH_HEIGHT),
				Color(1.0, 1.0, 0.8, 0.9)
			)
			dy += DASH_HEIGHT + DASH_GAP
