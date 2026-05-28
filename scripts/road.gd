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


func _process(delta: float) -> void:
	var scroll_speed: float = _car.speed_kmh * _car.KMH_TO_PXS
	var scroll_px := scroll_speed * delta
	scroll_offset = fmod(scroll_offset + scroll_px, DASH_HEIGHT + DASH_GAP)
	_world_scroll += scroll_px

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
		draw_texture_rect(_grass_tex, Rect2(0.0, scroll_y, ROAD_LEFT / scale, draw_h), true)
		var rx := (ROAD_LEFT + ROAD_WIDTH) / scale
		draw_texture_rect(_grass_tex, Rect2(rx, scroll_y, (size.x - ROAD_LEFT - ROAD_WIDTH) / scale, draw_h), true)
		draw_set_transform(Vector2.ZERO)

	# Trees on grass shoulders (animated sprite sheet: 3x3 grid of 256x256 frames, drawn at 128x128)
	if _tree_tex:
		var frame_col := _tree_frame % TREE_COLS
		var frame_row := _tree_frame / TREE_COLS
		var src := Rect2(frame_col * TREE_FRAME_SIZE, frame_row * TREE_FRAME_SIZE, TREE_FRAME_SIZE, TREE_FRAME_SIZE)
		for p in _trees:
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
