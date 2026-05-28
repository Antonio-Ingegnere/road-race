extends Node2D

const ROAD_LEFT := 760.0
const ROAD_WIDTH := 400.0
const DASH_HEIGHT := 60.0
const DASH_GAP := 45.0
const DASH_WIDTH := 7.5
const TILE_SIZE := 96
const TILE_COLS := 12
const TILE_ROWS := 60

const TREE_HALF := 192.0         # half of 384x384 display size
const TREE_FRAME_SIZE := 256     # source frame dimensions in the sprite sheet
const TREE_COLS := 3             # sprite sheet columns
const TREE_SPAWN_DIST := 900.0   # world pixels between spawn checks
const TREE_SPAWN_CHANCE := 0.6   # probability each check produces a tree
const TREE_FRAME_COUNT := 9
const TREE_FRAME_DURATION := 0.14  # seconds per frame (~7 fps)

const GRASS_TEX_SIZE := 512

const LANDSCAPE_GRASS    := 0
const LANDSCAPE_SEASHORE := 1

const SEA_SAND_W         := 120.0
const SEA_WAVE_ZONE_W    := 220.0
const SEA_WAVE_COUNT     := 4
const SEA_WAVE_SPEED     := 0.20

const SEA_DEEP_COLOR     := Color(0.04, 0.18, 0.48)
const SEA_MID_COLOR      := Color(0.10, 0.40, 0.62)
const SEA_FOAM_COLOR     := Color(0.90, 0.95, 0.98)
const SEA_SAND_COLOR     := Color(0.88, 0.78, 0.56)
const SEA_WET_SAND_COLOR := Color(0.72, 0.64, 0.47)

var scroll_offset := 0.0
var _world_scroll := 0.0
var _car: Node2D
var _asphalt_tex: Texture2D
var _rotations: Array = []
var _tree_tex: Texture2D
var _trees: Array[Vector2] = []
var _tree_dist_acc := 0.0
var _tree_rng := RandomNumberGenerator.new()
var _tree_frame := 0
var _tree_frame_timer := 0.0
var _grass_tex: ImageTexture

var landscape_left  := LANDSCAPE_GRASS
var landscape_right := LANDSCAPE_GRASS
var _sea_time := 0.0


func _ready() -> void:
	_car = get_parent().get_node("Car")
	_asphalt_tex = load("res://assets/asphalt.png")
	_tree_tex = load("res://assets/anim_tree.png")
	_tree_rng.seed = 7331

	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for _r in range(TILE_ROWS):
		var row := []
		for _c in range(TILE_COLS):
			row.append(rng.randi_range(0, 3) * (PI / 2.0))
		_rotations.append(row)

	_grass_tex = _make_grass_tex()

	var cfg := ConfigFile.new()
	if cfg.load("res://config.cfg") == OK:
		landscape_left  = int(cfg.get_value("landscape", "left",  LANDSCAPE_GRASS))
		landscape_right = int(cfg.get_value("landscape", "right", LANDSCAPE_GRASS))


func _process(delta: float) -> void:
	var scroll_speed: float = _car.speed_kmh * _car.KMH_TO_PXS
	var scroll_px := scroll_speed * delta
	scroll_offset = fmod(scroll_offset + scroll_px, DASH_HEIGHT + DASH_GAP)
	_world_scroll += scroll_px
	_sea_time += delta

	for i in range(_trees.size()):
		_trees[i].y += scroll_px
	var screen_h := get_viewport_rect().size.y
	_trees = _trees.filter(func(p: Vector2) -> bool: return p.y < screen_h + TREE_HALF)

	_tree_dist_acc += scroll_px
	if _tree_dist_acc >= TREE_SPAWN_DIST:
		_tree_dist_acc -= TREE_SPAWN_DIST
		if _tree_rng.randf() < TREE_SPAWN_CHANCE:
			_spawn_tree()

	_tree_frame_timer += delta
	if _tree_frame_timer >= TREE_FRAME_DURATION:
		_tree_frame_timer -= TREE_FRAME_DURATION
		_tree_frame = (_tree_frame + 1) % TREE_FRAME_COUNT

	queue_redraw()


func _spawn_tree() -> void:
	var screen_w := get_viewport_rect().size.x
	var side := _tree_rng.randi() % 2
	var x: float
	if side == 0:
		x = _tree_rng.randf_range(TREE_HALF, ROAD_LEFT - TREE_HALF)
	else:
		x = _tree_rng.randf_range(ROAD_LEFT + ROAD_WIDTH + TREE_HALF, screen_w - TREE_HALF)
	_trees.append(Vector2(x, -TREE_HALF))


func _make_grass_tex() -> ImageTexture:
	const SIZE := GRASS_TEX_SIZE
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var base := Color(0.18, 0.50, 0.20)
	img.fill(base)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7777
	# Blades use posmod so they wrap at texture edges — seamless in all directions
	for _i in range(800):
		var bx := rng.randi_range(0, SIZE - 1)
		var by := rng.randi_range(0, SIZE - 1)
		var h := rng.randi_range(7, 14)
		var lean := rng.randf_range(-0.10, 0.10)
		var brightness := rng.randf_range(0.68, 1.38)
		var bc := Color(
			clampf(base.r * brightness, 0.0, 1.0),
			clampf(base.g * brightness, 0.0, 1.0),
			clampf(base.b * brightness, 0.0, 1.0)
		)
		for j in range(h):
			var px: int = posmod(bx + int(lean * j), SIZE)
			var py: int = posmod(by - j, SIZE)
			img.set_pixel(px, py, bc)
	return ImageTexture.create_from_image(img)


func _draw() -> void:
	var size := get_viewport_rect().size
	var half := TILE_SIZE * 0.5  # = 48; texture is 64px source drawn at 1.5x scale

	# Grass background (base fill)
	draw_rect(Rect2(0.0, 0.0, size.x, size.y), Color(0.18, 0.50, 0.20))

	# Tiled asphalt
	if _asphalt_tex:
		var tile_start_y := fmod(_world_scroll, TILE_SIZE) - TILE_SIZE
		var ty := tile_start_y
		while ty < size.y:
			var world_row := posmod(floori((ty - _world_scroll) / float(TILE_SIZE)), TILE_ROWS)
			var col_idx := 0
			var tx := ROAD_LEFT
			while tx < ROAD_LEFT + ROAD_WIDTH + TILE_SIZE:
				var rot: float = _rotations[world_row][col_idx % TILE_COLS]
				draw_set_transform(Vector2(tx + half, ty + half), rot, Vector2(1.5, 1.5))
				draw_texture(_asphalt_tex, Vector2(-32.0, -32.0))
				col_idx += 1
				tx += TILE_SIZE
			ty += TILE_SIZE
		draw_set_transform(Vector2.ZERO)

	# Seamless grass shoulders — single 512×512 texture scrolled continuously.
	if _grass_tex:
		var scale := 1.5
		var tex_src := float(GRASS_TEX_SIZE)
		var scroll_y := fmod(_world_scroll / scale, tex_src) - tex_src
		var draw_h := size.y / scale + tex_src
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(scale, scale))
		if landscape_left == LANDSCAPE_GRASS:
			draw_texture_rect(_grass_tex, Rect2(0.0, scroll_y, ROAD_LEFT / scale, draw_h), true)
		var rx := (ROAD_LEFT + ROAD_WIDTH) / scale
		if landscape_right == LANDSCAPE_GRASS:
			draw_texture_rect(_grass_tex, Rect2(rx, scroll_y, (size.x - ROAD_LEFT - ROAD_WIDTH) / scale, draw_h), true)
		draw_set_transform(Vector2.ZERO)
	if landscape_left == LANDSCAPE_SEASHORE:
		_draw_seashore_left(size)
	if landscape_right == LANDSCAPE_SEASHORE:
		_draw_seashore_right(size)

	# Trees on grass shoulders (animated sprite sheet: 3x3 grid of 256x256 frames, drawn at 128x128)
	if _tree_tex:
		var frame_col := _tree_frame % TREE_COLS
		var frame_row := _tree_frame / TREE_COLS
		var src := Rect2(frame_col * TREE_FRAME_SIZE, frame_row * TREE_FRAME_SIZE, TREE_FRAME_SIZE, TREE_FRAME_SIZE)
		for p in _trees:
			var on_left := p.x < ROAD_LEFT
			if on_left and landscape_left == LANDSCAPE_SEASHORE:
				continue
			if not on_left and landscape_right == LANDSCAPE_SEASHORE:
				continue
			draw_texture_rect_region(_tree_tex, Rect2(p.x - TREE_HALF, p.y - TREE_HALF, TREE_HALF * 2, TREE_HALF * 2), src)

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


func _wet_width(screen_y: float) -> float:
	var wy := screen_y - _world_scroll
	return SEA_SAND_W * 0.40 \
		+ 12.0 * sin(wy * 0.0061 + 0.95) \
		+  7.0 * sin(wy * 0.0127 + 1.83)


func _shore_x_left(screen_y: float) -> float:
	var wy := screen_y - _world_scroll
	var base := ROAD_LEFT - SEA_SAND_W
	return base \
		+ 22.0 * sin(wy * 0.0042 + 0.30) \
		+ 13.0 * sin(wy * 0.0089 + 1.40) \
		+  7.0 * sin(wy * 0.0167 + 0.80) \
		+  4.0 * sin(wy * 0.0304 + 2.10)


func _shore_x_deep_left(screen_y: float) -> float:
	var wy := screen_y - _world_scroll
	var base := ROAD_LEFT - SEA_SAND_W - SEA_WAVE_ZONE_W
	return base \
		+ 25.0 * sin(wy * 0.0038 + 1.10) \
		+ 15.0 * sin(wy * 0.0071 + 2.50) \
		+  8.0 * sin(wy * 0.0153 + 1.80) \
		+  5.0 * sin(wy * 0.0281 + 0.40)


func _shore_x_right(screen_y: float) -> float:
	var wy := screen_y - _world_scroll
	var base := ROAD_LEFT + ROAD_WIDTH + SEA_SAND_W
	return base \
		- 22.0 * sin(wy * 0.0042 + 1.70) \
		- 13.0 * sin(wy * 0.0089 + 0.50) \
		-  7.0 * sin(wy * 0.0167 + 2.30) \
		-  4.0 * sin(wy * 0.0304 + 3.10)


func _shore_x_deep_right(screen_y: float) -> float:
	var wy := screen_y - _world_scroll
	var base := ROAD_LEFT + ROAD_WIDTH + SEA_SAND_W + SEA_WAVE_ZONE_W
	return base \
		- 25.0 * sin(wy * 0.0038 + 2.50) \
		- 15.0 * sin(wy * 0.0071 + 0.80) \
		-  8.0 * sin(wy * 0.0153 + 3.20) \
		-  5.0 * sin(wy * 0.0281 + 1.60)


func _draw_seashore_left(size: Vector2) -> void:
	var shore_edge := ROAD_LEFT
	var wave_x     := shore_edge - SEA_SAND_W - SEA_WAVE_ZONE_W

	draw_rect(Rect2(0.0, 0.0, shore_edge, size.y), SEA_DEEP_COLOR)

	var sl  := PackedVector2Array()
	var slw := PackedVector2Array()
	var sd  := PackedVector2Array()
	var y := 0.0
	while y <= size.y:
		var sx := _shore_x_left(y)
		sl.append(Vector2(sx, y))
		slw.append(Vector2(sx + _wet_width(y), y))
		sd.append(Vector2(_shore_x_deep_left(y), y))
		y += 8.0

	# Mid water: between sd (deep/mid boundary) and sl (shoreline)
	var mid := PackedVector2Array()
	for pt in sd:
		mid.append(pt)
	for i in range(sl.size() - 1, -1, -1):
		mid.append(sl[i])
	draw_polygon(mid, PackedColorArray([SEA_MID_COLOR]))

	var dry := PackedVector2Array()
	for pt in slw:
		dry.append(pt)
	dry.append(Vector2(shore_edge, size.y))
	dry.append(Vector2(shore_edge, 0.0))
	draw_polygon(dry, PackedColorArray([SEA_SAND_COLOR]))

	var wet := PackedVector2Array()
	for pt in slw:
		wet.append(pt)
	for i in range(sl.size() - 1, -1, -1):
		wet.append(sl[i])
	draw_polygon(wet, PackedColorArray([SEA_WET_SAND_COLOR]))

	for i in range(SEA_WAVE_COUNT):
		var phase := fmod(float(i) / SEA_WAVE_COUNT + _sea_time * SEA_WAVE_SPEED, 1.0)
		var wx    := wave_x + phase * SEA_WAVE_ZONE_W
		var alpha := sin(phase * PI) * 0.88
		_draw_wave_line(size, wx,
			Color(SEA_FOAM_COLOR.r, SEA_FOAM_COLOR.g, SEA_FOAM_COLOR.b, alpha),
			_sea_time, float(i) * 1.618)


func _draw_seashore_right(size: Vector2) -> void:
	var shore_edge := ROAD_LEFT + ROAD_WIDTH
	var wave_end   := shore_edge + SEA_SAND_W + SEA_WAVE_ZONE_W

	draw_rect(Rect2(shore_edge, 0.0, size.x - shore_edge, size.y), SEA_DEEP_COLOR)

	var sl  := PackedVector2Array()
	var slw := PackedVector2Array()
	var sd  := PackedVector2Array()
	var y := 0.0
	while y <= size.y:
		var sx := _shore_x_right(y)
		sl.append(Vector2(sx, y))
		slw.append(Vector2(sx - _wet_width(y), y))
		sd.append(Vector2(_shore_x_deep_right(y), y))
		y += 8.0

	# Mid water: between sl (shoreline) and sd (deep/mid boundary)
	var mid := PackedVector2Array()
	for pt in sl:
		mid.append(pt)
	for i in range(sd.size() - 1, -1, -1):
		mid.append(sd[i])
	draw_polygon(mid, PackedColorArray([SEA_MID_COLOR]))

	var dry := PackedVector2Array()
	dry.append(Vector2(shore_edge, 0.0))
	dry.append(Vector2(shore_edge, size.y))
	for i in range(slw.size() - 1, -1, -1):
		dry.append(slw[i])
	draw_polygon(dry, PackedColorArray([SEA_SAND_COLOR]))

	var wet := PackedVector2Array()
	for pt in slw:
		wet.append(pt)
	for i in range(sl.size() - 1, -1, -1):
		wet.append(sl[i])
	draw_polygon(wet, PackedColorArray([SEA_WET_SAND_COLOR]))

	for i in range(SEA_WAVE_COUNT):
		var phase := fmod(float(i) / SEA_WAVE_COUNT + _sea_time * SEA_WAVE_SPEED, 1.0)
		var wx    := wave_end - phase * SEA_WAVE_ZONE_W
		var alpha := sin(phase * PI) * 0.88
		_draw_wave_line(size, wx,
			Color(SEA_FOAM_COLOR.r, SEA_FOAM_COLOR.g, SEA_FOAM_COLOR.b, alpha),
			_sea_time, float(i) * 1.618 + 10.0)


func _draw_wave_line(size: Vector2, base_x: float, color: Color, t: float, seed: float) -> void:
	var pts := PackedVector2Array()
	var y := 0.0
	while y <= size.y:
		var x := base_x
		x += 13.0 * sin(y * 0.0118 + t * 1.27 + seed * 2.09)
		x +=  7.0 * sin(y * 0.0211 - t * 0.83 + seed * 1.55)
		x +=  4.0 * sin(y * 0.0379 + t * 0.51 + seed * 0.79)
		x +=  2.5 * sin(y * 0.0673 - t * 1.64 + seed * 3.17)
		pts.append(Vector2(x, y))
		y += 7.0
	if pts.size() >= 2:
		draw_polyline(pts, color, 3.5, true)
