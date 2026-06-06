extends Node2D

# Draws trees (Road) and elk (ElkManager) in a single Y-sorted pass so that
# objects lower on screen (closer to camera) correctly appear in front.

var _road:    Node2D
var _elk_mgr: Node2D


func _ready() -> void:
	_road    = get_parent().get_node("Road")
	_elk_mgr = get_parent().get_node("ElkManager")


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var items: Array = []

	# ── Trees ──────────────────────────────────────────────────────────────────
	var spruce_src := Rect2(
		(_road._tree_frame % _road.TREE_COLS) * _road.TREE_FRAME_SIZE,
		(_road._tree_frame / _road.TREE_COLS) * _road.TREE_FRAME_SIZE,
		_road.TREE_FRAME_SIZE, _road.TREE_FRAME_SIZE)
	var oak_src := Rect2(
		(_road._oak_frame % _road.OAK_COLS) * _road.OAK_FRAME_SIZE, 0,
		_road.OAK_FRAME_SIZE, _road.OAK_FRAME_SIZE)
	var blossom_src := Rect2(
		(_road._blossom_frame % _road.BLOSSOM_COLS) * _road.BLOSSOM_FRAME_SIZE, 0,
		_road.BLOSSOM_FRAME_SIZE, _road.BLOSSOM_FRAME_SIZE)

	for t in _road._trees:
		var p: Vector2 = t["pos"]
		var on_left: bool = p.x < _road.ROAD_LEFT
		if on_left  and _road.landscape_left  != _road.LANDSCAPE_GRASS:
			continue
		if not on_left and _road.landscape_right != _road.LANDSCAPE_GRASS:
			continue
		# Ground contact measured from sprite pixels:
		# spruce:  rows 7–118 of 256-src at 1.5x → pos.y − 15
		# oak:     rows 2–125 of 128-src at 2.0x → pos.y + 122
		# blossom: rows 5–123 of 128-src at 1.0x → pos.y + 59
		const GROUND_OFFSET := [-15.0, 122.0, 59.0]
		var ground_y: float = p.y + GROUND_OFFSET[t["type"]]
		items.append({"y": ground_y, "kind": 0, "data": t})

	# ── Elk ────────────────────────────────────────────────────────────────────
	for elk in _elk_mgr._elks:
		var elk_bottom: float = elk["pos"].y + _elk_mgr.ELK_SCALE * _elk_mgr.FRAME_H * 0.5
		items.append({"y": elk_bottom, "kind": 1, "data": elk})

	items.sort_custom(func(a, b) -> bool: return a["y"] < b["y"])

	for item in items:
		if item["kind"] == 0:
			_draw_tree(item["data"], spruce_src, oak_src, blossom_src)
		else:
			_draw_elk(item["data"])

	draw_set_transform(Vector2.ZERO)


func _draw_tree(t: Dictionary, spruce_src: Rect2, oak_src: Rect2, blossom_src: Rect2) -> void:
	var p: Vector2 = t["pos"]
	match t["type"]:
		1:
			if _road._oak_tex:
				draw_texture_rect_region(_road._oak_tex,
					Rect2(p.x - _road.OAK_HALF, p.y - _road.OAK_HALF, _road.OAK_HALF * 2, _road.OAK_HALF * 2),
					oak_src)
		2:
			if _road._blossom_tex:
				draw_texture_rect_region(_road._blossom_tex,
					Rect2(p.x - _road.BLOSSOM_HALF, p.y - _road.BLOSSOM_HALF,
						  _road.BLOSSOM_HALF * 2, _road.BLOSSOM_HALF * 2),
					blossom_src)
		_:
			if _road._tree_tex:
				draw_texture_rect_region(_road._tree_tex,
					Rect2(p.x - _road.TREE_HALF, p.y - _road.TREE_HALF, _road.TREE_HALF * 2, _road.TREE_HALF * 2),
					spruce_src)


func _draw_elk(elk: Dictionary) -> void:
	var hw: float  = _elk_mgr.FRAME_W * 0.5
	var hh: float  = _elk_mgr.FRAME_H * 0.5
	var state: int = elk["state"]

	if state == _elk_mgr.STATE_JUMP_RAISE or state == _elk_mgr.STATE_JUMP_OUT:
		draw_circle(Vector2(elk["land_x"], elk["pos"].y), _elk_mgr.SHADOW_RADIUS,
			Color(0.0, 0.0, 0.0, 0.30))

	var arc_y: float = 0.0
	if state == _elk_mgr.STATE_JUMP_OUT or state == _elk_mgr.STATE_JUMP_BACK:
		arc_y = -sin(elk["jump_t"] * PI) * _elk_mgr.JUMP_ARC_HEIGHT
	var draw_pos: Vector2 = elk["pos"] + Vector2(0.0, arc_y)

	var sx: float = _elk_mgr.ELK_SCALE if elk["right"] else -_elk_mgr.ELK_SCALE
	draw_set_transform(draw_pos, 0.0, Vector2(sx, _elk_mgr.ELK_SCALE))

	match state:
		_elk_mgr.STATE_STAND, _elk_mgr.STATE_EAT, _elk_mgr.STATE_JUMP_RAISE:
			draw_texture_rect_region(
				_elk_mgr._tex_base,
				Rect2(-hw, -hh, _elk_mgr.FRAME_W, _elk_mgr.FRAME_H),
				Rect2(elk["frame"] * _elk_mgr.FRAME_W, 0, _elk_mgr.FRAME_W, _elk_mgr.FRAME_H))
		_elk_mgr.STATE_JUMP_OUT, _elk_mgr.STATE_ON_ROAD, _elk_mgr.STATE_JUMP_BACK:
			var jf: int = mini(elk["jump_frame"], 3)
			draw_texture_rect_region(
				_elk_mgr._tex_jump,
				Rect2(-hw, -hh, _elk_mgr.FRAME_W, _elk_mgr.FRAME_H),
				Rect2(jf * _elk_mgr.FRAME_W, 0, _elk_mgr.FRAME_W, _elk_mgr.FRAME_H))

	draw_set_transform(Vector2.ZERO)
