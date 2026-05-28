extends CanvasLayer

const VP_W := 1920.0
const VP_H := 1080.0
const PANEL_W := 500.0
const PANEL_H := 640.0

const RESOLUTIONS := ["1280x720", "1920x1080", "2560x1440", "3840x2160"]

var _widgets: Dictionary = {}
var _cfg := ConfigFile.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_ESCAPE:
		if visible:
			_on_cancel()
		else:
			_open()
		get_viewport().set_input_as_handled()


# ── Open / close ───────────────────────────────────────────────────────────────

func _open() -> void:
	_cfg.load("res://config.cfg")
	_load_values()
	visible = true
	get_tree().paused = true


func _on_ok() -> void:
	_save_values()
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_cancel() -> void:
	visible = false
	get_tree().paused = false


# ── Config I/O ─────────────────────────────────────────────────────────────────

func _load_values() -> void:
	var saved_res: String = str(_cfg.get_value("display", "resolution", "1280x720"))
	var res_idx := RESOLUTIONS.find(saved_res)
	_widgets["resolution"].selected = max(res_idx, 0)
	_widgets["dn_enabled"].button_pressed  = bool(_cfg.get_value("day_night", "enabled",    false))
	_set_slider(_widgets["dn_start"],       float(_cfg.get_value("day_night", "start_time", 10.0)))
	_widgets["rain_enabled"].button_pressed = bool(_cfg.get_value("rain",      "enabled",    true))
	_set_slider(_widgets["rain_drops"],     float(_cfg.get_value("rain",      "drop_count", 300)))
	_widgets["elk_enabled"].button_pressed  = bool(_cfg.get_value("elk",       "enabled",    true))
	_set_slider(_widgets["elk_spawn"],      float(_cfg.get_value("elk",       "spawn_chance", 0.8)))
	_set_slider(_widgets["elk_jump"],       float(_cfg.get_value("elk",       "jump_chance",  0.9)))
	_widgets["shore_left"].selected  = int(_cfg.get_value("landscape", "left",  0))
	_widgets["shore_right"].selected = int(_cfg.get_value("landscape", "right", 0))


func _save_values() -> void:
	_cfg.set_value("display",   "resolution",   RESOLUTIONS[_widgets["resolution"].selected])
	_cfg.set_value("day_night", "enabled",      _widgets["dn_enabled"].button_pressed)
	_cfg.set_value("day_night", "start_time",   _widgets["dn_start"].value)
	_cfg.set_value("rain",      "enabled",      _widgets["rain_enabled"].button_pressed)
	_cfg.set_value("rain",      "drop_count",   int(_widgets["rain_drops"].value))
	_cfg.set_value("elk",       "enabled",      _widgets["elk_enabled"].button_pressed)
	_cfg.set_value("elk",       "spawn_chance", _widgets["elk_spawn"].value)
	_cfg.set_value("elk",       "jump_chance",  _widgets["elk_jump"].value)
	_cfg.set_value("landscape", "left",         _widgets["shore_left"].selected)
	_cfg.set_value("landscape", "right",        _widgets["shore_right"].selected)
	_cfg.save("res://config.cfg")


# ── UI builder ─────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	# Darkening overlay
	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.55)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	# Centered panel
	var panel := PanelContainer.new()
	panel.position = Vector2((VP_W - PANEL_W) * 0.5, (VP_H - PANEL_H) * 0.5)
	panel.size = Vector2(PANEL_W, PANEL_H)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 24)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	vbox.add_child(title)

	vbox.add_child(_make_separator())

	# ── Display ──
	_add_section_label(vbox, "Display")
	_widgets["resolution"] = _add_option_button(vbox, "Resolution", RESOLUTIONS)

	vbox.add_child(_make_separator())

	# ── Day / Night ──
	_add_section_label(vbox, "Day / Night Cycle")
	_widgets["dn_enabled"] = _add_checkbox(vbox, "Enabled")
	_widgets["dn_start"]   = _add_slider(vbox, "Start time", 0.0, 59.0, 1.0,
										  func(v): return "%.0f s  (%s)" % [v, _dn_phase(v)])

	vbox.add_child(_make_separator())

	# ── Rain ──
	_add_section_label(vbox, "Rain")
	_widgets["rain_enabled"] = _add_checkbox(vbox, "Enabled")
	_widgets["rain_drops"]   = _add_slider(vbox, "Drop count", 50, 800, 50,
										   func(v): return "%d" % int(v))

	vbox.add_child(_make_separator())

	# ── Elk ──
	_add_section_label(vbox, "Elk")
	_widgets["elk_enabled"] = _add_checkbox(vbox, "Enabled")
	_widgets["elk_spawn"]   = _add_slider(vbox, "Spawn chance", 0.0, 1.0, 0.05,
										  func(v): return "%d%%" % int(v * 100))
	_widgets["elk_jump"]    = _add_slider(vbox, "Jump chance",  0.0, 1.0, 0.05,
										  func(v): return "%d%%" % int(v * 100))

	vbox.add_child(_make_separator())

	# ── Landscape ──
	_add_section_label(vbox, "Landscape")
	_widgets["shore_left"]  = _add_option_button(vbox, "Left shore",  ["Grass", "Seashore"])
	_widgets["shore_right"] = _add_option_button(vbox, "Right shore", ["Grass", "Seashore"])

	vbox.add_child(_make_separator())

	# Note
	var note := Label.new()
	note.text = "OK saves settings and restarts the game."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	note.add_theme_font_size_override("font_size", 13)
	vbox.add_child(note)

	# Spacer
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# Buttons
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 20)
	vbox.add_child(btn_row)

	var ok_btn := Button.new()
	ok_btn.text = "OK"
	ok_btn.custom_minimum_size = Vector2(110, 38)
	ok_btn.pressed.connect(_on_ok)
	btn_row.add_child(ok_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(110, 38)
	cancel_btn.pressed.connect(_on_cancel)
	btn_row.add_child(cancel_btn)


# ── Widget helpers ─────────────────────────────────────────────────────────────

func _make_separator() -> HSeparator:
	return HSeparator.new()


func _add_section_label(parent: Control, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.75, 0.3))
	parent.add_child(lbl)


func _add_checkbox(parent: Control, text: String) -> CheckBox:
	var cb := CheckBox.new()
	cb.text = text
	parent.add_child(cb)
	return cb


func _add_slider(parent: Control, label: String,
				  min_v: float, max_v: float, step: float,
				  fmt_fn: Callable) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label
	lbl.custom_minimum_size = Vector2(110, 0)
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)

	var val_lbl := Label.new()
	val_lbl.custom_minimum_size = Vector2(80, 0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val_lbl)

	slider.set_meta("val_lbl", val_lbl)
	slider.set_meta("fmt_fn",  fmt_fn)
	slider.value_changed.connect(func(v: float) -> void:
		val_lbl.text = fmt_fn.call(v)
	)

	return slider


func _add_option_button(parent: Control, label: String, options: Array) -> OptionButton:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label
	lbl.custom_minimum_size = Vector2(110, 0)
	row.add_child(lbl)

	var btn := OptionButton.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for opt in options:
		btn.add_item(opt)
	row.add_child(btn)

	return btn


func _set_slider(slider: HSlider, value: float) -> void:
	slider.value = value
	var lbl: Label   = slider.get_meta("val_lbl")
	var fn: Callable = slider.get_meta("fmt_fn")
	lbl.text = fn.call(value)


func _dn_phase(t: float) -> String:
	if t < 20.0: return "day"
	if t < 30.0: return "dusk"
	if t < 50.0: return "night"
	return "dawn"
