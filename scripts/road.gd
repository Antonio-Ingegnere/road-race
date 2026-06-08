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
const TREE_SPAWN_BASE   := 110.0  # base world-px interval between spawns per side
const TREE_SPAWN_JITTER := 40.0   # ± random jitter applied to each interval
const TREE_MIN_DIST     := 240.0  # minimum center-to-center distance between any two trees
const TREE_SPAWN_TRIES  := 6      # candidate X positions tried before giving up
const TREE_FRAME_COUNT := 9
const TREE_FRAME_DURATION := 0.14  # seconds per frame (~7 fps)

const OAK_FRAME_SIZE      := 128
const OAK_HALF            := 128.0   # half of 256x256 display size
const OAK_FRAME_COUNT     := 8
const OAK_COLS            := 8

const BLOSSOM_FRAME_SIZE  := 128
const BLOSSOM_HALF        := 64.0    # half of 128x128 display size (1x scale)
const BLOSSOM_FRAME_COUNT := 10
const BLOSSOM_COLS        := 10

const GRASS_TEX_SIZE := 512

const LANDSCAPE_GRASS    := 0
const LANDSCAPE_SEASHORE := 1
const LANDSCAPE_DESERT   := 2

const SEA_SAND_W         := 120.0
const SEA_WAVE_ZONE_W    := 220.0
const SEA_WAVE_COUNT     := 4
const SEA_WAVE_SPEED     := 0.20

const SEA_DEEP_COLOR     := Color(0.04, 0.18, 0.48)
const SEA_MID_COLOR      := Color(0.10, 0.40, 0.62)
const SEA_FOAM_COLOR     := Color(0.90, 0.95, 0.98)
const SEA_SAND_COLOR     := Color(0.88, 0.78, 0.56)
const SEA_WET_SAND_COLOR := Color(0.72, 0.64, 0.47)

const DESERT_SAND_COLOR  := Color(0.90, 0.78, 0.50)
const DESERT_LINE_COL    := Color(0.66, 0.46, 0.18, 0.42)
const DESERT_SPOT_COL    := Color(0.76, 0.56, 0.26, 0.48)
const DESERT_ROCK_COLOR  := Color(0.52, 0.36, 0.22)
const DESERT_ROCK_SHINE  := Color(0.68, 0.52, 0.36, 0.55)
const DESERT_SHRUB_DARK  := Color(0.12, 0.24, 0.08)
const DESERT_SHRUB_LITE  := Color(0.28, 0.46, 0.18, 0.55)
const DESERT_SHRUB_SHAD  := Color(0.10, 0.07, 0.03, 0.30)

const TW_SCALE         := 0.25
const TW_FRAME         := 128
const TW_ROLL_RADIUS   := 16.0   # TW_FRAME * TW_SCALE * 0.5
const TW_SPEED_MIN     := 60.0
const TW_SPEED_MAX     := 130.0
const TW_SPAWN_MIN     := 0.75
const TW_SPAWN_MAX     := 2.25
const TW_JUMP_ITVL_MIN := 0.8
const TW_JUMP_ITVL_MAX := 2.2
const TW_JUMP_H_MIN    := 5.0
const TW_JUMP_H_MAX    := 15.0
const TW_JUMP_DUR      := 0.55

var scroll_offset := 0.0
var _world_scroll := 0.0
var _car: Node2D
var _asphalt_tex: Texture2D
var _rotations: Array = []
var _tree_tex:    Texture2D
var _oak_tex:     Texture2D
var _blossom_tex: Texture2D
var _trees: Array = []   # Array of {"pos": Vector2, "type": int}  0=spruce 1=oak 2=blossom
var _tree_rng        := RandomNumberGenerator.new()
var _tree_dist_left  := 0.0
var _tree_dist_right := 55.0   # half-interval phase offset so sides don't sync
var _tree_next_left  := 110.0
var _tree_next_right := 110.0
var _tree_frame    := 0
var _oak_frame     := 0
var _blossom_frame := 0
var _tree_frame_timer := 0.0
var _grass_tex: ImageTexture
var _desert_tex: ImageTexture
var _cactus_tex:       Texture2D
var _cactus_small_tex: Texture2D
var _tw_tex: Texture2D
var _tumbleweeds: Array = []
var _tw_spawn_timer := 0.0
var _tw_next_spawn  := 0.0
var _dust: Array = []

var landscape_left  := LANDSCAPE_GRASS
var landscape_right := LANDSCAPE_GRASS
var _sea_time := 0.0


func _ready() -> void:
	_car = get_parent().get_node("Car")
	_asphalt_tex = load("res://assets/asphalt.png")
	_tree_tex    = load("res://assets/anim_tree.png")
	_oak_tex     = load("res://assets/OakTree_x128_animated-Sheet.png")
	_blossom_tex = load("res://assets/BlossomTree_x128_animated-Sheet.png")
	_tree_rng.seed = 7331

	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for _r in range(TILE_ROWS):
		var row := []
		for _c in range(TILE_COLS):
			row.append(rng.randi_range(0, 3) * (PI / 2.0))
		_rotations.append(row)

	_grass_tex  = _make_grass_tex()
	_desert_tex = _make_desert_tex()
	_cactus_tex       = load("res://assets/CactusBig_x128.png")
	_cactus_small_tex = load("res://assets/CactusSmall_x128.png")
	_tw_tex     = load("res://assets/Tumbleweed_x128.png")
	_tw_next_spawn = randf_range(TW_SPAWN_MIN, TW_SPAWN_MAX)

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
		_trees[i]["pos"].y += scroll_px
	var screen_h := get_viewport_rect().size.y
	_trees = _trees.filter(func(t) -> bool: return t["pos"].y < screen_h + TREE_HALF)
	_trees.sort_custom(func(a, b) -> bool: return a["pos"].y < b["pos"].y)

	_tree_dist_left  += scroll_px
	_tree_dist_right += scroll_px
	if _tree_dist_left >= _tree_next_left:
		_tree_dist_left  = 0.0
		_tree_next_left  = TREE_SPAWN_BASE + _tree_rng.randf_range(-TREE_SPAWN_JITTER, TREE_SPAWN_JITTER)
		_spawn_tree(0)
	if _tree_dist_right >= _tree_next_right:
		_tree_dist_right = 0.0
		_tree_next_right = TREE_SPAWN_BASE + _tree_rng.randf_range(-TREE_SPAWN_JITTER, TREE_SPAWN_JITTER)
		_spawn_tree(1)

	_tree_frame_timer += delta
	if _tree_frame_timer >= TREE_FRAME_DURATION:
		_tree_frame_timer -= TREE_FRAME_DURATION
		_tree_frame    = (_tree_frame    + 1) % TREE_FRAME_COUNT
		_oak_frame     = (_oak_frame     + 1) % OAK_FRAME_COUNT
		_blossom_frame = (_blossom_frame + 1) % BLOSSOM_FRAME_COUNT

	# Tumbleweeds (desert only)
	var screen_w: float = get_viewport_rect().size.x
	if landscape_left == LANDSCAPE_DESERT or landscape_right == LANDSCAPE_DESERT:
		_tw_spawn_timer += delta
		if _tw_spawn_timer >= _tw_next_spawn:
			_tw_spawn_timer = 0.0
			_tw_next_spawn  = randf_range(TW_SPAWN_MIN, TW_SPAWN_MAX)
			_tw_spawn(screen_w, screen_h)
	for tw in _tumbleweeds:
		tw["pos"].y += scroll_px
		tw["pos"].x += tw["vel_x"] * delta
		var bmin: float = tw["x0"] + TW_ROLL_RADIUS
		var bmax: float = tw["x1"] - TW_ROLL_RADIUS
		if tw["pos"].x < bmin:
			tw["pos"].x = bmin
			tw["vel_x"] = 0.0
		elif tw["pos"].x > bmax:
			tw["pos"].x = bmax
			tw["vel_x"] = 0.0
		tw["angle"]  = tw["angle"] + tw["vel_x"] * delta / TW_ROLL_RADIUS
		if tw["jumping"]:
			tw["jump_t"] += delta / TW_JUMP_DUR
			if tw["jump_t"] >= 1.0:
				tw["jumping"]    = false
				tw["jump_t"]     = 0.0
				tw["jump_timer"] = randf_range(TW_JUMP_ITVL_MIN, TW_JUMP_ITVL_MAX)
		else:
			tw["jump_timer"] -= delta
			if tw["jump_timer"] <= 0.0:
				tw["jumping"]     = true
				tw["jump_t"]      = 0.0
				tw["jump_height"] = randf_range(TW_JUMP_H_MIN, TW_JUMP_H_MAX)
	var tw_hw: float = TW_FRAME * TW_SCALE * 0.5
	_tumbleweeds = _tumbleweeds.filter(func(tw) -> bool:
		if tw["pos"].y > screen_h + tw_hw:
			return false
		var px: float = tw["pos"].x
		return px >= tw["x0"] - tw_hw and px <= tw["x1"] + tw_hw
	)

	# Emit dust from moving tumbleweeds
	for tw in _tumbleweeds:
		if abs(tw["vel_x"]) > 1.0 and not tw["jumping"] and randf() < 0.4:
			var ex: float = tw["pos"].x - sign(tw["vel_x"]) * TW_ROLL_RADIUS * 0.6
			_dust.append({
				"pos":      Vector2(ex + randf_range(-3.0, 3.0),
									tw["pos"].y + TW_ROLL_RADIUS * 0.7 + randf_range(-2.0, 2.0)),
				"vx":       randf_range(-6.0, 6.0) - tw["vel_x"] * 0.12,
				"vy":       randf_range(-14.0, -5.0),
				"age":      0.0,
				"lifetime": randf_range(0.6, 1.2),
				"radius":   randf_range(2.0, 4.5),
			})

	# Update dust particles
	for i in range(_dust.size() - 1, -1, -1):
		var p: Dictionary = _dust[i]
		p["pos"].y += scroll_px
		p["pos"].x += p["vx"] * delta
		p["pos"].y += p["vy"] * delta
		p["age"]   += delta
		if p["age"] >= p["lifetime"]:
			_dust.remove_at(i)

	queue_redraw()


func _spawn_tree(side: int) -> void:
	var screen_w := get_viewport_rect().size.x
	var tree_type: int = _tree_rng.randi() % 3   # 0=spruce  1=oak  2=blossom
	var half: float = ([TREE_HALF, OAK_HALF, BLOSSOM_HALF] as Array)[tree_type]
	var x_min: float
	var x_max: float
	if side == 0:
		x_min = half
		x_max = ROAD_LEFT - half
	else:
		x_min = ROAD_LEFT + ROAD_WIDTH + half
		x_max = screen_w - half
	if x_max <= x_min:
		return

	for _attempt in range(TREE_SPAWN_TRIES):
		var cx: float = _tree_rng.randf_range(x_min, x_max)
		var candidate := Vector2(cx, -half)
		var too_close := false
		for t in _trees:
			if t["pos"].distance_to(candidate) < TREE_MIN_DIST:
				too_close = true
				break
		if not too_close:
			_trees.append({"pos": candidate, "type": tree_type, "flip": bool(randi() % 2)})
			return


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


func _make_desert_tex() -> ImageTexture:
	const SIZE := GRASS_TEX_SIZE
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.90, 0.78, 0.50))
	# Horizontal sand ripple lines — subtle wavy dark stripes every 7 px
	for y in range(0, SIZE, 7):
		var phase := float(y) * 0.153
		for x in range(SIZE):
			var wy2: int = posmod(y + int(round(
				2.1 * sin(float(x) * 0.037 + phase) +
				1.0 * sin(float(x) * 0.081 + phase * 0.65))), SIZE)
			var c := img.get_pixel(x, wy2)
			img.set_pixel(x, wy2, c.darkened(0.065))
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
	elif landscape_left == LANDSCAPE_DESERT:
		_draw_desert_left(size)
	if landscape_right == LANDSCAPE_SEASHORE:
		_draw_seashore_right(size)
	elif landscape_right == LANDSCAPE_DESERT:
		_draw_desert_right(size)


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

	_draw_shore_deco(size, _shore_x_left, -1.0, 0)

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

	_draw_shore_deco(size, _shore_x_right, 1.0, 999983)

	for i in range(SEA_WAVE_COUNT):
		var phase := fmod(float(i) / SEA_WAVE_COUNT + _sea_time * SEA_WAVE_SPEED, 1.0)
		var wx    := wave_end - phase * SEA_WAVE_ZONE_W
		var alpha := sin(phase * PI) * 0.88
		_draw_wave_line(size, wx,
			Color(SEA_FOAM_COLOR.r, SEA_FOAM_COLOR.g, SEA_FOAM_COLOR.b, alpha),
			_sea_time, float(i) * 1.618 + 10.0)


func _draw_shore_deco(size: Vector2, shore_fn: Callable, toward_water: float, seed_base: int) -> void:
	const SPACING    := 70.0
	const ROCK_COLOR := Color(0.27, 0.23, 0.19)
	const ROCK_SHINE := Color(0.42, 0.37, 0.32, 0.55)
	const WEED_DARK  := Color(0.05, 0.20, 0.08, 0.90)
	const WEED_MID   := Color(0.14, 0.36, 0.16, 0.85)

	var rng      := RandomNumberGenerator.new()
	var wy_start := -_world_scroll
	var wy_end   := size.y - _world_scroll
	var wy: float = ceil(wy_start / SPACING) * SPACING

	while wy <= wy_end:
		var sy       := wy + _world_scroll
		var sx: float = shore_fn.call(sy)
		rng.seed     = int(wy) * 7919 + seed_base

		# Rocks: scattered around the shoreline into both sand and water
		var rock_count := rng.randi_range(0, 2)
		for _r in range(rock_count):
			var dist := rng.randf_range(-38.0, 28.0)  # neg = into sand, pos = into water
			var rx   := rng.randf_range(5.0, 12.0)
			var ry   := rng.randf_range(3.5,  8.0)
			var rot  := rng.randf_range(-1.3,  1.3)
			var pos  := Vector2(sx + toward_water * dist, sy + rng.randf_range(-22.0, 22.0))
			draw_set_transform(pos, rot, Vector2(rx, ry))
			draw_circle(Vector2.ZERO, 1.0, ROCK_COLOR)
			draw_set_transform(Vector2.ZERO)
			var hi := pos + Vector2(-rx * 0.25, -ry * 0.30).rotated(rot)
			draw_set_transform(hi, rot, Vector2(rx * 0.40, ry * 0.35))
			draw_circle(Vector2.ZERO, 1.0, ROCK_SHINE)
			draw_set_transform(Vector2.ZERO)

		# Seaweed: curved blade patches in the shallow water
		if rng.randf() < 0.45:
			var dist   := rng.randf_range(25.0, 75.0)
			var wpos   := Vector2(sx + toward_water * dist, sy + rng.randf_range(-14.0, 14.0))
			var blades := rng.randi_range(5, 9)
			for _b in range(blades):
				var angle  := rng.randf_range(-PI, PI)
				var length := rng.randf_range(14.0, 30.0)
				var bend   := rng.randf_range(-0.50, 0.50)
				var width  := rng.randf_range(1.8, 3.2)
				var col    := WEED_DARK if rng.randf() < 0.55 else WEED_MID
				var bx     := wpos.x + rng.randf_range(-5.0, 5.0)
				var by     := wpos.y + rng.randf_range(-4.0, 4.0)
				var pts    := PackedVector2Array()
				for s in range(5):
					var t := float(s) / 4.0
					pts.append(Vector2(
						bx + cos(angle + bend * t) * length * t,
						by + sin(angle + bend * t) * length * t))
				draw_polyline(pts, col, width, true)

		wy += SPACING


func _draw_desert_left(size: Vector2) -> void:
	_draw_desert_base(0.0, ROAD_LEFT, size)
	_draw_desert_ridgelines(0.0, ROAD_LEFT, size)
	_draw_desert_spots(0.0, ROAD_LEFT, size)
	_draw_desert_deco(size, 0.0, ROAD_LEFT, 0)
	_draw_desert_tumbleweeds(0.0, ROAD_LEFT)


func _draw_desert_right(size: Vector2) -> void:
	var x0 := ROAD_LEFT + ROAD_WIDTH
	_draw_desert_base(x0, size.x, size)
	_draw_desert_ridgelines(x0, size.x, size)
	_draw_desert_spots(x0, size.x, size)
	_draw_desert_deco(size, x0, size.x, 112237)
	_draw_desert_tumbleweeds(x0, size.x)


func _tw_spawn(screen_w: float, screen_h: float) -> void:
	var sides: Array = []
	if landscape_left  == LANDSCAPE_DESERT:
		sides.append(0)
	if landscape_right == LANDSCAPE_DESERT:
		sides.append(1)
	if sides.is_empty():
		return
	var side: int  = sides[randi() % sides.size()]
	var hw: float  = TW_FRAME * TW_SCALE * 0.5
	var x0: float  = 0.0       if side == 0 else ROAD_LEFT + ROAD_WIDTH
	var x1: float  = ROAD_LEFT if side == 0 else screen_w
	if x1 - hw <= x0 + hw:
		return
	var x: float     = randf_range(x0 + hw, x1 - hw)
	var going_right: bool = randf() < 0.5
	var speed: float = randf_range(TW_SPEED_MIN, TW_SPEED_MAX)
	var vel_x: float = speed if going_right else -speed
	_tumbleweeds.append({
		"pos":         Vector2(x, -hw),
		"vel_x":       vel_x,
		"angle":       randf_range(0.0, TAU),
		"jumping":     false,
		"jump_t":      0.0,
		"jump_timer":  randf_range(TW_JUMP_ITVL_MIN, TW_JUMP_ITVL_MAX),
		"jump_height": randf_range(TW_JUMP_H_MIN, TW_JUMP_H_MAX),
		"x0":          x0,
		"x1":          x1,
	})


func _draw_desert_tumbleweeds(x0: float, x1: float) -> void:
	if not _tw_tex:
		return
	var hw := TW_FRAME * 0.5
	var hh := TW_FRAME * 0.5

	# Dust (drawn first, behind sprites)
	for p in _dust:
		var px: float = p["pos"].x
		if px < x0 - 20.0 or px > x1 + 20.0:
			continue
		var t: float     = p["age"] / p["lifetime"]
		var alpha: float = (1.0 - t) * (1.0 - t) * 0.50
		var r: float     = p["radius"] * (1.0 + t * 2.0)
		draw_circle(p["pos"], r, Color(0.85, 0.72, 0.48, alpha))

	for tw in _tumbleweeds:
		var tx: float = tw["pos"].x
		if tx < x0 - hw or tx > x1 + hw:
			continue
		var arc_y: float = 0.0
		if tw["jumping"]:
			arc_y = -sin(tw["jump_t"] * PI) * tw["jump_height"]
		var shadow_r: float = hw * TW_SCALE * 0.72 * (1.0 - abs(arc_y) / TW_JUMP_H_MAX * 0.45)
		draw_set_transform(tw["pos"], 0.0, Vector2(shadow_r, shadow_r * 0.22))
		draw_circle(Vector2.ZERO, 1.0, Color(0.0, 0.0, 0.0, 0.22))
		draw_set_transform(Vector2.ZERO)
		var draw_pos: Vector2 = tw["pos"] + Vector2(0.0, arc_y)
		draw_set_transform(draw_pos, tw["angle"], Vector2(TW_SCALE, TW_SCALE))
		draw_texture_rect(_tw_tex, Rect2(-hw, -hh, TW_FRAME, TW_FRAME), false)
	draw_set_transform(Vector2.ZERO)


func _draw_desert_base(x0: float, x1: float, size: Vector2) -> void:
	if _desert_tex:
		var scale  := 1.5
		var tsrc   := float(GRASS_TEX_SIZE)
		var sy     := fmod(_world_scroll / scale, tsrc) - tsrc
		var draw_h := size.y / scale + tsrc
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(scale, scale))
		draw_texture_rect(_desert_tex, Rect2(x0 / scale, sy, (x1 - x0) / scale, draw_h), true)
		draw_set_transform(Vector2.ZERO)
	else:
		draw_rect(Rect2(x0, 0.0, x1 - x0, size.y), DESERT_SAND_COLOR)


func _draw_desert_ridgelines(x0: float, x1: float, size: Vector2) -> void:
	var zone_w  := x1 - x0
	var n_lines: int = max(2, int(zone_w / 76.0))
	for i in range(n_lines):
		var base_x := x0 + (float(i) + 0.5) * (zone_w / float(n_lines))
		var seed   := float(i) * 1337.0 + x0 * 0.11
		var pts    := PackedVector2Array()
		var y      := 0.0
		while y <= size.y:
			var wy := y - _world_scroll
			var x  := base_x \
					 + 15.0 * sin(wy * 0.0044 + seed * 2.09) \
					 +  8.0 * sin(wy * 0.0092 + seed * 1.37) \
					 +  4.0 * sin(wy * 0.0191 + seed * 0.83)
			pts.append(Vector2(x, y))
			y += 9.0
		if pts.size() >= 2:
			draw_polyline(pts, DESERT_LINE_COL, 2.0, true)


func _draw_desert_spots(x0: float, x1: float, size: Vector2) -> void:
	const SPACING := 52.0

	var rng      := RandomNumberGenerator.new()
	var wy_start := -_world_scroll
	var wy_end   := size.y - _world_scroll
	var wy: float = ceil(wy_start / SPACING) * SPACING

	while wy <= wy_end:
		rng.seed = int(wy) * 2311 + int(x0)
		var sy := wy + _world_scroll
		var count := rng.randi_range(2, 5)
		for _s in range(count):
			var sx := rng.randf_range(x0 + 15.0, x1 - 15.0)
			var r  := rng.randf_range(3.5, 8.0)
			draw_set_transform(Vector2(sx, sy + rng.randf_range(-18.0, 18.0)), 0.0, Vector2(r, r * 0.68))
			draw_circle(Vector2.ZERO, 1.0, DESERT_SPOT_COL)
			draw_set_transform(Vector2.ZERO)
		wy += SPACING


func _draw_desert_deco(size: Vector2, x0: float, x1: float, seed_base: int) -> void:
	const SPACING := 95.0
	const MARGIN  := 25.0

	var rng      := RandomNumberGenerator.new()
	var wy_start := -_world_scroll
	var wy_end   := size.y - _world_scroll
	var wy: float = ceil(wy_start / SPACING) * SPACING

	while wy <= wy_end:
		var sy := wy + _world_scroll
		rng.seed = int(wy) * 6547 + seed_base

		var rock_count := rng.randi_range(0, 2)
		for _r in range(rock_count):
			var rx  := rng.randf_range(7.0, 18.0)
			var ry  := rng.randf_range(5.0, 13.0)
			var rot := rng.randf_range(-0.8, 0.8)
			var px  := rng.randf_range(x0 + MARGIN, x1 - MARGIN)
			var py  := sy + rng.randf_range(-30.0, 30.0)
			var pos := Vector2(px, py)
			draw_set_transform(pos, rot, Vector2(rx, ry))
			draw_circle(Vector2.ZERO, 1.0, DESERT_ROCK_COLOR)
			draw_set_transform(Vector2.ZERO)
			var hi := pos + Vector2(-rx * 0.25, -ry * 0.30).rotated(rot)
			draw_set_transform(hi, rot, Vector2(rx * 0.40, ry * 0.35))
			draw_circle(Vector2.ZERO, 1.0, DESERT_ROCK_SHINE)
			draw_set_transform(Vector2.ZERO)

		if rng.randf() < 0.55:
			var cx := rng.randf_range(x0 + MARGIN, x1 - MARGIN)
			var cy := sy + rng.randf_range(-20.0, 20.0)
			_draw_desert_shrub(Vector2(cx, cy), rng)

		if rng.randf() < 0.30:
			var cax   := rng.randf_range(x0 + MARGIN + 20.0, x1 - MARGIN - 20.0)
			var cay   := sy + rng.randf_range(-20.0, 20.0)
			var ctype := rng.randi() % 2
			var cflip := bool(rng.randi() % 2)
			if ctype == 0:
				_draw_desert_cactus(Vector2(cax, cay), cflip)
			else:
				_draw_desert_cactus_small(Vector2(cax, cay), cflip)

		wy += SPACING


func _draw_desert_shrub(pos: Vector2, rng: RandomNumberGenerator) -> void:
	var s      := rng.randf_range(0.65, 1.40)
	var base_r := rng.randf_range(12.0, 22.0) * s

	# Ground shadow — elongated teardrop to lower-right
	var shad_len := base_r * rng.randf_range(1.5, 2.3)
	var shad_pos := pos + Vector2(0.70, 0.35) * shad_len * 0.55
	var shad_rot := atan2(0.35, 0.70)
	draw_set_transform(shad_pos, shad_rot, Vector2(shad_len * 0.48, base_r * 0.68))
	draw_circle(Vector2.ZERO, 1.0, DESERT_SHRUB_SHAD)
	draw_set_transform(Vector2.ZERO)

	# Main body
	draw_set_transform(pos, 0.0, Vector2(base_r, base_r * 0.88))
	draw_circle(Vector2.ZERO, 1.0, DESERT_SHRUB_DARK)
	draw_set_transform(Vector2.ZERO)

	# Satellite blobs give an irregular, bushy silhouette
	var blob_count := rng.randi_range(4, 7)
	for _b in range(blob_count):
		var angle := rng.randf_range(0.0, TAU)
		var dist  := base_r * rng.randf_range(0.52, 0.86)
		var br    := base_r * rng.randf_range(0.30, 0.55)
		var bp    := pos + Vector2(cos(angle) * dist, sin(angle) * dist)
		draw_set_transform(bp, 0.0, Vector2(br, br * 0.88))
		draw_circle(Vector2.ZERO, 1.0, DESERT_SHRUB_DARK)
		draw_set_transform(Vector2.ZERO)

	# Spiky radiating spines (illustration style)
	var spine_count := rng.randi_range(8, 14)
	for sp in range(spine_count):
		var angle    := float(sp) / float(spine_count) * TAU + rng.randf_range(-0.18, 0.18)
		var sp_len   := base_r * rng.randf_range(0.90, 1.30)
		var sp_start := pos + Vector2(cos(angle) * base_r * 0.25, sin(angle) * base_r * 0.25)
		var sp_end   := pos + Vector2(cos(angle) * sp_len, sin(angle) * sp_len)
		draw_line(sp_start, sp_end, DESERT_SHRUB_DARK, 1.5, true)

	# Highlight patch (upper-left, lit side)
	var hi := pos + Vector2(-base_r * 0.22, -base_r * 0.26)
	draw_set_transform(hi, 0.0, Vector2(base_r * 0.40, base_r * 0.30))
	draw_circle(Vector2.ZERO, 1.0, DESERT_SHRUB_LITE)
	draw_set_transform(Vector2.ZERO)


func _draw_desert_cactus(pos: Vector2, flip_v: bool) -> void:
	if not _cactus_tex:
		return
	const HALF := 64.0
	var sv: float = -1.0 if flip_v else 1.0
	draw_set_transform(pos, 0.0, Vector2(sv, 1.0))
	draw_texture_rect(_cactus_tex, Rect2(-HALF, -HALF, HALF * 2, HALF * 2), false)
	draw_set_transform(Vector2.ZERO)


func _draw_desert_cactus_small(pos: Vector2, flip_v: bool) -> void:
	if not _cactus_small_tex:
		return
	const HALF := 64.0
	var sv: float = -1.0 if flip_v else 1.0
	draw_set_transform(pos, 0.0, Vector2(sv, 1.0))
	draw_texture_rect(_cactus_small_tex, Rect2(-HALF, -HALF, HALF * 2, HALF * 2), false)
	draw_set_transform(Vector2.ZERO)


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
