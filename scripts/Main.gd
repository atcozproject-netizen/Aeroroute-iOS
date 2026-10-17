extends Control
## Aeroroute: native Godot scene/UI and interactions. iPhone portrait, canvas_items stretch.

const StateScript = preload("res://scripts/GameState.gd")
const MapScript = preload("res://scripts/WorldMap.gd")
const FlightScript = preload("res://scripts/FlightLayer.gd")
const FirScript = preload("res://scripts/FirLayer.gd")
const ProfitScript = preload("res://scripts/ProfitEffects.gd")
const PAPER = Color("fffdf5")
const INK = Color("254853")
const MUTED = Color("7f9a9d")
const DARK = Color("294f5d")
const MINT = Color("edf4ef")
const GOLD = Color("e9b68e")

var game = StateScript.new()
var world_map
var flight_layer
var fir_layer
var fir_button: Button
var fir_mode: int = 1
var route_mode_button: Button
var route_mode: bool = false
var map_status: Label
var profit_layer: Control
var balance_tween: Tween
var toast_tween: Tween
var hud: PanelContainer
var hud_balance: Label
var hud_routes: Label
var hud_passengers: Label
var clock_label: Label
var play_button: Button
var nav_bar: PanelContainer
var tab_buttons: Dictionary = {}
var content_view: PanelContainer
var content_body: VBoxContainer
var shade: ColorRect
var sheet: PanelContainer
var sheet_scroll: ScrollContainer
var sheet_body: VBoxContainer
var start_overlay: ColorRect
var start_search: LineEdit
var start_choices: VBoxContainer
var start_choice_code: String = "ESSA"
var route_origin: String = ""
var active_tab: String = "map"
var current_sheet: String = ""
var current_code: String = ""
var current_route: String = ""
var active_toast: Label
var ui_seconds: float = 0.0
var flight_eta: Label
var search_line: LineEdit
var search_results: VBoxContainer
var zoom_buttons: VBoxContainer

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	create_scene()
	game.changed.connect(_on_game_changed)
	game.news.connect(_on_news)
	game.landed.connect(_on_landed)
	if game.load_game():
		world_map.center_on(game.home)
		show_tab("map")
	else:
		show_start()
	refresh_hud()

func add_styled_panel(color: Color, radius: int = 20) -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.corner_radius_top_left = radius
	s.corner_radius_top_right = radius
	s.corner_radius_bottom_left = radius
	s.corner_radius_bottom_right = radius
	s.content_margin_left = 15
	s.content_margin_right = 15
	s.content_margin_top = 13
	s.content_margin_bottom = 13
	s.shadow_color = Color(0.10, 0.19, 0.20, 0.09)
	s.shadow_size = 4
	p.add_theme_stylebox_override("panel", s)
	return p

func label(text: String, font_size: int = 14, color: Color = INK, strong: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if strong:
		l.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.20))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func button(text: String, filled: bool = true) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 43)
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_color_override("font_color", PAPER if filled else DARK)
	b.add_theme_color_override("font_hover_color", PAPER if filled else DARK)
	var normal := StyleBoxFlat.new()
	normal.bg_color = DARK if filled else Color("e7f0eb")
	normal.shadow_size = 2
	normal.shadow_color = Color(0.10, 0.19, 0.20, 0.08)
	normal.corner_radius_top_left = 12
	normal.corner_radius_top_right = 12
	normal.corner_radius_bottom_left = 12
	normal.corner_radius_bottom_right = 12
	normal.content_margin_left = 13
	normal.content_margin_right = 13
	b.add_theme_stylebox_override("normal", normal)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color("396d7b") if filled else Color("d8e7e2")
	b.add_theme_stylebox_override("hover", hover)
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = Color("1b3945") if filled else Color("ccdcd6")
	b.add_theme_stylebox_override("pressed", pressed)
	var disabled: StyleBoxFlat = normal.duplicate()
	disabled.bg_color = Color("bfcfcb")
	b.add_theme_stylebox_override("disabled", disabled)
	b.button_down.connect(func() -> void:
		b.pivot_offset = b.size * 0.5
		var feedback: Tween = create_tween()
		feedback.tween_property(b, "scale", Vector2(0.97, 0.97), 0.07)
	)
	b.button_up.connect(func() -> void:
		var feedback: Tween = create_tween()
		feedback.tween_property(b, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)
	return b

func line_break() -> HSeparator:
	var sep := HSeparator.new()
	sep.modulate = Color("b7d0cc")
	return sep

func stack(gap: int = 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", gap)
	return v

func row(gap: int = 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", gap)
	return h

func expanded(control: Control) -> Control:
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return control

func build_stat(title: String, initial: String, save_to: String) -> VBoxContainer:
	var v: VBoxContainer = stack(3)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(label(title, 10, MUTED))
	var value: Label = label(initial, 18, INK, true)
	v.add_child(value)
	match save_to:
		"cash": hud_balance = value
		"routes": hud_routes = value
		"passengers": hud_passengers = value
	return v

func create_scene() -> void:
	world_map = MapScript.new()
	world_map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	world_map.mouse_filter = Control.MOUSE_FILTER_STOP
	world_map.clip_contents = true
	add_child(world_map)
	world_map.configure(game)
	world_map.airport_tapped.connect(_airport_tapped)
	world_map.route_drafted.connect(_draft_route)
	fir_layer = FirScript.new()
	fir_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fir_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fir_layer)
	fir_layer.configure(world_map)
	fir_layer.fir_load_failed.connect(func(message: String) -> void:
		if fir_button != null:
			fir_button.button_pressed = false
		toast(message)
	)
	fir_layer.fir_loaded.connect(func(count: int) -> void:
		update_map_status()
		toast("FIR-gränser klara: %d" % count)
	)
	flight_layer = FlightScript.new()
	flight_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flight_layer.setup(game, world_map)
	add_child(flight_layer)
	profit_layer = ProfitScript.new()
	profit_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	profit_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(profit_layer)
	profit_layer.setup(game, world_map)

	var top: VBoxContainer = stack(10)
	top.anchor_right = 1.0
	top.offset_left = 16.0
	top.offset_right = -16.0
	top.offset_top = 15.0
	add_child(top)
	var brand_row: HBoxContainer = row(9)
	top.add_child(brand_row)
	var logo_box: PanelContainer = add_styled_panel(DARK, 11)
	logo_box.custom_minimum_size = Vector2(43, 43)
	brand_row.add_child(logo_box)
	var mark: Label = label("A", 21, Color("e7b88a"), true)
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	logo_box.add_child(mark)
	var brand_text: VBoxContainer = stack(0)
	brand_row.add_child(expanded(brand_text))
	brand_text.add_child(label("AEROROUTE", 18, INK, true))
	brand_text.add_child(label("AIRLINE EMPIRE", 10, Color("608892")))
	var search_btn: Button = button("SÖK", false)
	search_btn.custom_minimum_size = Vector2(53, 43)
	search_btn.tooltip_text = "Sök flygplats"
	brand_row.add_child(search_btn)
	search_btn.pressed.connect(show_search)
	var center_btn: Button = button("HEM", false)
	center_btn.custom_minimum_size = Vector2(53, 43)
	center_btn.tooltip_text = "Visa huvudflygplatsen"
	brand_row.add_child(center_btn)
	center_btn.pressed.connect(func() -> void:
		world_map.reset_gesture()
		world_map.center_on(game.home)
	)
	hud = add_styled_panel(Color("fffdf7"), 17)
	top.add_child(hud)
	var stats: HBoxContainer = row(7)
	hud.add_child(stats)
	stats.add_child(build_stat("SALDO", "650 AC", "cash"))
	stats.add_child(build_stat("LINJER", "0", "routes"))
	stats.add_child(build_stat("PASSAGERARE", "0", "passengers"))

	nav_bar = add_styled_panel(Color("fffdf8"), 0)
	nav_bar.anchor_top = 1.0
	nav_bar.anchor_bottom = 1.0
	nav_bar.anchor_right = 1.0
	nav_bar.offset_top = -82.0
	nav_bar.offset_bottom = 0.0
	add_child(nav_bar)
	var nav: HBoxContainer = row(6)
	nav_bar.add_child(nav)
	for item in [{"id":"map","name":"KARTA"},{"id":"routes","name":"LINJER"},{"id":"fleet","name":"FLOTTA"},{"id":"company","name":"BOLAG"}]:
		var b: Button = button(str(item["name"]), false)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 43.0
		nav.add_child(b)
		var id: String = str(item["id"])
		b.pressed.connect(func() -> void: show_tab(id))
		tab_buttons[id] = b

	# Map controls remain accessible without pinch gestures and offer quick recentering.
	zoom_buttons = stack(8)
	zoom_buttons.anchor_left = 1.0
	zoom_buttons.anchor_right = 1.0
	zoom_buttons.offset_left = -61.0
	zoom_buttons.offset_right = -13.0
	zoom_buttons.offset_top = 222.0  # Keep controls below the balance/status HUD
	zoom_buttons.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(zoom_buttons)
	var zoom_in: Button = button("+", false)
	zoom_in.custom_minimum_size = Vector2(48, 48)
	zoom_in.add_theme_font_size_override("font_size", 23)
	zoom_buttons.add_child(zoom_in)
	zoom_in.pressed.connect(func() -> void: world_map.change_zoom(1.12))
	var zoom_out: Button = button("−", false)
	zoom_out.custom_minimum_size = Vector2(48, 48)
	zoom_out.add_theme_font_size_override("font_size", 23)
	zoom_buttons.add_child(zoom_out)
	zoom_out.pressed.connect(func() -> void: world_map.change_zoom(0.89))
	var region_btn: Button = button("ÖVR", false)
	region_btn.custom_minimum_size = Vector2(48, 42)
	region_btn.add_theme_font_size_override("font_size", 11)
	zoom_buttons.add_child(region_btn)
	region_btn.pressed.connect(func() -> void: world_map.whole_world())
	fir_button = button("FIR", false)
	fir_button.custom_minimum_size = Vector2(48, 42)
	fir_button.tooltip_text = "Växla FIR: av / gränser / gränser och namn"
	zoom_buttons.add_child(fir_button)
	fir_button.pressed.connect(func() -> void:
		fir_mode = (fir_mode + 1) % 3
		fir_layer.set_mode(fir_mode)
		fir_button.text = "AV" if fir_mode == 0 else ("FIR" if fir_mode == 1 else "FIR+")
		update_map_status()
	)
	route_mode_button = button("LINJE", false)
	route_mode_button.toggle_mode = true
	route_mode_button.custom_minimum_size = Vector2(48, 44)
	zoom_buttons.add_child(route_mode_button)
	route_mode_button.toggled.connect(func(active: bool) -> void:
		route_mode = active
		world_map.route_draw_enabled = active
		route_origin = ""
		world_map.route_origin = ""
		world_map.reset_gesture()
		update_map_status()
	)
	# FIR is enabled after the HUD and notification labels have been created.


	var bottom_controls: PanelContainer = add_styled_panel(Color("fffcf4"), 16)
	bottom_controls.anchor_left = 0.0
	bottom_controls.anchor_right = 1.0
	bottom_controls.anchor_top = 1.0
	bottom_controls.anchor_bottom = 1.0
	bottom_controls.offset_left = 15.0
	bottom_controls.offset_right = -15.0
	bottom_controls.offset_top = -152.0
	bottom_controls.offset_bottom = -87.0
	bottom_controls.name = "ClockDock"
	add_child(bottom_controls)
	var time_row: HBoxContainer = row(8)
	bottom_controls.add_child(time_row)
	var time_info: VBoxContainer = stack(3)
	time_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	time_row.add_child(time_info)
	time_info.add_child(label("SPELTID", 10, MUTED))
	clock_label = label("DAG 01", 17, INK, true)
	time_info.add_child(clock_label)
	play_button = button("PAUS", false)
	play_button.custom_minimum_size.x = 78
	time_row.add_child(play_button)
	play_button.pressed.connect(_toggle_pause)
	var speed_button: Button = button("2x", true)
	speed_button.custom_minimum_size.x = 61
	time_row.add_child(speed_button)
	speed_button.pressed.connect(func() -> void:
		game.speed = 1.0 if game.speed > 1.0 else 2.0
		speed_button.text = "1x" if game.speed > 1.0 else "2x"
		game.save_game()
	)

	content_view = add_styled_panel(Color("f9f9f3"), 0)
	content_view.anchor_right = 1.0
	content_view.anchor_bottom = 1.0
	content_view.offset_bottom = -77.0
	content_view.visible = false
	add_child(content_view)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_view.add_child(scroll)
	content_body = stack(13)
	content_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content_body)

	shade = ColorRect.new()
	shade.color = Color(0.12, 0.27, 0.32, 0.49)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.visible = false
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	shade.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			close_sheet()
		if event is InputEventScreenTouch and not event.pressed:
			close_sheet()
	)

	sheet = add_styled_panel(Color("fffdf6"), 26)
	sheet.anchor_left = 0.0
	sheet.anchor_right = 1.0
	sheet.anchor_top = 1.0
	sheet.anchor_bottom = 1.0
	sheet.offset_top = -555.0
	sheet.offset_bottom = -77.0
	sheet.visible = false
	add_child(sheet)
	sheet_scroll = ScrollContainer.new()
	sheet_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sheet_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sheet.add_child(sheet_scroll)
	sheet_body = stack(11)
	sheet_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sheet_scroll.add_child(sheet_body)

	active_toast = label("", 12, PAPER, true)
	active_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	active_toast.offset_left = -170
	active_toast.offset_right = 170
	active_toast.offset_top = -196
	active_toast.offset_bottom = -166
	active_toast.visible = false
	add_child(active_toast)
	map_status = label("", 11, Color("fbf2e3"), true)
	map_status.anchor_left = 0.0
	map_status.anchor_top = 1.0
	map_status.anchor_bottom = 1.0
	map_status.offset_left = 17.0
	map_status.offset_top = -189.0
	map_status.offset_bottom = -169.0
	map_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(map_status)
	fir_layer.set_mode(1)
	update_map_status()

func map_gesture_active() -> bool:
	return active_tab == "map" and game.initialized and not (
		(start_overlay != null and is_instance_valid(start_overlay) and start_overlay.visible)
		or shade.visible or sheet.visible
	)

func map_can_interact(pos: Vector2) -> bool:
	if not map_gesture_active():
		return false
	if pos.y < 184.0 or pos.y > size.y - 156.0:
		return false
	if pos.x > size.x - 88.0 and pos.y >= 207.0 and pos.y <= 543.0:
		return false
	return true

func clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func heading(eyebrow: String, title: String, sub: String = "") -> void:
	var head: HBoxContainer = row()
	sheet_body.add_child(head)
	var texts: VBoxContainer = stack(4)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(texts)
	texts.add_child(label(eyebrow.to_upper(), 10, MUTED))
	texts.add_child(label(title, 26, INK, true))
	if sub != "":
		texts.add_child(label(sub, 12, MUTED))
	var close: Button = button("STÄNG", false)
	close.custom_minimum_size = Vector2(53, 38)
	head.add_child(close)
	close.pressed.connect(close_sheet)

func open_sheet(sheet_type: String) -> void:
	world_map.reset_gesture()
	current_sheet = sheet_type
	shade.visible = true
	sheet.visible = true
	sheet_scroll.scroll_vertical = 0
	clear_children(sheet_body)

func close_sheet() -> void:
	current_sheet = ""
	shade.visible = false
	sheet.visible = false
	flight_eta = null
	world_map.route_origin = ""
	world_map.queue_redraw()

func info_tile(title: String, value: String) -> PanelContainer:
	var panel: PanelContainer = add_styled_panel(MINT, 13)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v: VBoxContainer = stack(5)
	panel.add_child(v)
	v.add_child(label(title.to_upper(), 9, MUTED))
	v.add_child(label(value, 15, INK, true))
	return panel

func update_map_status() -> void:
	if map_status == null:
		return
	if route_mode:
		map_status.text = "LINJE: välj startflygplats" if route_origin == "" else ("FRÅN %s → välj destination" % route_origin)
	elif fir_mode == 2:
		map_status.text = "FIR • GRÄNSER + NAMN"
	elif fir_mode == 1:
		map_status.text = "FIR • DISKRETA GRÄNSER"
	else:
		map_status.text = "KARTA • FLYTTA MED FINGRET"
	map_status.visible = active_tab == "map" and game.initialized

func _airport_tapped(code: String) -> void:
	if not game.initialized:
		return
	if route_mode and route_origin == "":
		route_origin = code
		world_map.route_origin = code
		update_map_status()
		world_map.queue_redraw()
		return
	if route_origin != "" and code != route_origin:
		_draft_route(route_origin, code)
	elif route_mode and route_origin == code:
		route_origin = ""
		world_map.route_origin = ""
		update_map_status()
		world_map.queue_redraw()
	else:
		show_airport(code)

func _draft_route(from: String, to: String) -> void:
	world_map.route_draw_enabled = false
	route_mode = false
	if route_mode_button != null:
		route_mode_button.set_pressed_no_signal(false)
	route_origin = ""
	world_map.route_origin = ""
	world_map.queue_redraw()
	update_map_status()
	if from == to:
		return
	var id: String = game.route_key(from, to)
	if not game.get_route(id).is_empty():
		show_route(id)
	else:
		show_planner(from, to)

func show_airport(code: String) -> void:
	var a: Dictionary = game.airport(code)
	if a.is_empty():
		return
	current_code = code
	open_sheet("airport")
	heading("FLYGPLATS", code, str(a["name"]) + " · " + str(a["country"]))
	var tiles: HBoxContainer = row(7)
	sheet_body.add_child(tiles)
	tiles.add_child(info_tile("EFTERFRÅGAN", "Nivå %d" % int(a["rank"])))
	tiles.add_child(info_tile("LINJER", str(game.gates_used(code))))
	tiles.add_child(info_tile("TERMINAL", str(game.terminals.get(code, 1))))
	var new_line: Button = button("+ NY FLYGLINJE")
	sheet_body.add_child(new_line)
	new_line.pressed.connect(func() -> void:
		close_sheet()
		route_origin = code
		world_map.route_origin = code
		route_mode = true
		world_map.route_draw_enabled = true
		if route_mode_button != null:
			route_mode_button.set_pressed_no_signal(true)
		world_map.queue_redraw()
		update_map_status()
		toast("Välj en destinationsflygplats")
	)
	if game.owned.has(code):
		var upgrade: Button = button("UPPGRADERA TERMINAL", false)
		sheet_body.add_child(upgrade)
		upgrade.pressed.connect(func() -> void:
			var msg: String = game.upgrade_terminal(code)
			if msg != "":
				toast(msg)
			else:
				show_airport(code)
		)
	for r in game.routes:
		if str(r["from"]) == code or str(r["to"]) == code:
			var rt: Button = button("%s - %s" % [r["from"], r["to"]], false)
			sheet_body.add_child(rt)
			var id: String = str(r["id"])
			rt.pressed.connect(func() -> void: show_route(id))

func show_planner(from: String, to: String) -> void:
	open_sheet("planner")
	heading("NY FLYGLINJE", from + " → " + to, str(game.airport(from)["name"]) + " – " + str(game.airport(to)["name"]))
	var stats: HBoxContainer = row(8)
	sheet_body.add_child(stats)
	stats.add_child(info_tile("DISTANS", game.distance_label(from, to)))
	stats.add_child(info_tile("EFTERFRÅGAN", str(game.demand_market(from, to)["label"])))
	var plane: Dictionary = game.initial_plane(from, to)
	var selected: Dictionary = plane if not plane.is_empty() else game.minimum_plane(from, to)
	if not selected.is_empty():
		sheet_body.add_child(label(str(selected["name"]), 15, INK, true))
		sheet_body.add_child(label("%d platser  ·  %d km räckvidd" % [int(selected["seats"]), int(selected["range"])], 12, MUTED))
	var cost: float = game.route_cost(from, to)
	var total: HBoxContainer = row()
	sheet_body.add_child(total)
	total.add_child(expanded(label("KOSTNAD", 12, MUTED)))
	total.add_child(label(game.money(cost) if cost >= 0.0 else "LÅST", 21, DARK, true))
	if plane.is_empty():
		sheet_body.add_child(label("Flygplansnivå %d krävs för den här distansen." % int(selected.get("level", 8)), 12, MUTED))
	var controls: HBoxContainer = row()
	sheet_body.add_child(controls)
	var cancel: Button = button("Avbryt", false)
	controls.add_child(expanded(cancel))
	cancel.pressed.connect(close_sheet)
	var confirm: Button = button("ÖPPNA LINJE")
	controls.add_child(expanded(confirm))
	confirm.disabled = plane.is_empty() or cost > game.cash or not game.gates_available(from) or not game.gates_available(to)
	confirm.pressed.connect(func() -> void:
		var result: String = game.create_route(from, to)
		if result != "":
			toast(result)
		else:
			world_map.queue_redraw()
			show_route(game.route_key(from, to))
			toast("Flyglinjen är öppnad!")
	)

func show_route(id: String) -> void:
	var r: Dictionary = game.get_route(id)
	if r.is_empty():
		close_sheet()
		return
	var projection: Dictionary = game.projected(r)
	current_route = id
	open_sheet("route")
	heading("DIN FLYGLINJE", str(r["from"]) + " ↔ " + str(r["to"]), game.distance_label(str(r["from"]), str(r["to"])))
	var cols: HBoxContainer = row(6)
	sheet_body.add_child(cols)
	cols.add_child(info_tile("INTÄKTER / FLYG", game.money(float(projection["revenue"]))))
	cols.add_child(info_tile("KOSTNADER / FLYG", game.money(float(projection["cost"]))))
	cols.add_child(info_tile("NETTO / FLYG", game.money(float(projection["net"]))))
	var p: Dictionary = game.catalog_by_id.get(str(r["plane"]), {})
	sheet_body.add_child(label(str(p.get("name", "Flygplan")), 16, INK, true))
	sheet_body.add_child(label("%d platser  ·  %d%% beläggning" % [int(projection["seats"]), int(projection["load"])], 12, MUTED))
	flight_eta = label("Nästa landning: %d sek" % int(ceil((1.0 - float(r["progress"])) * game.flight_duration(r) / game.speed)), 12, Color("548b87"))
	sheet_body.add_child(flight_eta)
	sheet_body.add_child(line_break())
	sheet_body.add_child(label("BILJETTPRIS", 11, MUTED))
	var ticket_row: HBoxContainer = row()
	sheet_body.add_child(ticket_row)
	var fare_value: Label = label(game.money(float(r["fare"])), 15, INK, true)
	var slider := HSlider.new()
	slider.min_value = 0.55
	slider.max_value = maxf(2.5, (0.85 + float(projection["distance"]) * 0.00028) * 2.1)
	slider.step = 0.05
	slider.value = float(r["fare"])
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ticket_row.add_child(slider)
	ticket_row.add_child(fare_value)
	slider.value_changed.connect(func(value: float) -> void:
		r["fare"] = game.rounded(value)
		fare_value.text = game.money(float(r["fare"]))
		game.save_game()
	)
	var upgrades: Array = game.available_upgrades(r)
	if not upgrades.is_empty():
		sheet_body.add_child(label("UPPGRADERA FLYGPLAN", 11, MUTED, true))
		for model in upgrades:
			var upgrade_cost: float = maxf(0.0, game.rounded(float(model["price"]) - float(p["price"]) * 0.55))
			var entry: Button = button("%s · %d platser · %s" % [model["name"], int(model["seats"]), game.money(upgrade_cost)], false)
			entry.disabled = game.cash < upgrade_cost
			sheet_body.add_child(entry)
			var new_id: String = str(model["id"])
			entry.pressed.connect(func() -> void:
				var result: String = game.upgrade_plane(id, new_id)
				if result == "":
					show_route(id)
				else:
					toast(result)
			)

func show_search() -> void:
	if not game.initialized:
		return
	open_sheet("search")
	heading("VÄRLDEN", "Hitta flygplats", "Sök ICAO, IATA eller stad")
	search_line = LineEdit.new()
	search_line.placeholder_text = "ESSA, Arlanda, London…"
	search_line.custom_minimum_size.y = 45
	sheet_body.add_child(search_line)
	search_results = stack(4)
	sheet_body.add_child(search_results)
	search_line.text_changed.connect(_search_updated)
	_search_updated("")

func _search_updated(query: String) -> void:
	if search_results == null:
		return
	clear_children(search_results)
	var matches: Array = []
	for a in game.airports:
		var field: String = "%s %s %s %s" % [a["icao"], a["iata"], a["name"], a["country"]]
		if query.strip_edges() == "" or field.to_lower().contains(query.to_lower()):
			matches.append(a)
	matches.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["rank"]) > int(b["rank"]))
	for i in range(mini(18, matches.size())):
		var a: Dictionary = matches[i]
		var code: String = str(a["icao"])
		var item: Button = button("%s   %s" % [code, str(a["name"])], false)
		search_results.add_child(item)
		item.pressed.connect(func() -> void:
			search_line.release_focus()
			close_sheet()
			show_tab("map")
			world_map.center_on(code)
			if route_origin != "" and route_origin != code:
				_draft_route(route_origin, code)
			else:
				show_airport(code)
		)

func _clear_content() -> void:
	clear_children(content_body)

func show_tab(tab: String) -> void:
	world_map.reset_gesture()
	if not game.initialized:
		return
	active_tab = tab
	close_sheet()
	content_view.visible = tab != "map"
	flight_layer.visible = tab == "map"
	get_node("ClockDock").visible = tab == "map"
	zoom_buttons.visible = tab == "map"
	if tab != "map":
		world_map.route_draw_enabled = false
		route_mode = false
		route_origin = ""
		world_map.route_origin = ""
		if route_mode_button != null:
			route_mode_button.set_pressed_no_signal(false)
	update_map_status()
	for key in tab_buttons:
		var nav_button: Button = tab_buttons[key]
		nav_button.modulate = Color.WHITE
		var active: bool = key == tab
		var nav_style := StyleBoxFlat.new()
		nav_style.bg_color = Color("d8eae3") if active else Color("f5f7f2")
		nav_style.corner_radius_top_left = 12
		nav_style.corner_radius_top_right = 12
		nav_style.corner_radius_bottom_left = 12
		nav_style.corner_radius_bottom_right = 12
		nav_style.content_margin_left = 4
		nav_style.content_margin_right = 4
		nav_button.add_theme_stylebox_override("normal", nav_style)
		nav_button.add_theme_color_override("font_color", DARK if active else Color("77939a"))
	if tab != "map":
		build_tab()

func build_tab() -> void:
	_clear_content()
	match active_tab:
		"routes":
			content_body.add_child(label("DINA FLYGLINJER", 24, INK, true))
			content_body.add_child(label("%d linjer · %d flygplatser" % [game.routes.size(), game.owned.size()], 13, MUTED))
			for r in game.routes:
				var projection: Dictionary = game.projected(r)
				var b: Button = button("%s - %s   %s / flyg" % [r["from"], r["to"], game.money(float(projection["net"]))], false)
				content_body.add_child(b)
				var id: String = str(r["id"])
				b.pressed.connect(func() -> void: show_route(id))
			if game.routes.is_empty():
				content_body.add_child(label("Dra mellan två flygplatser på kartan för att öppna din första linje.", 15, MUTED))
			var map_btn: Button = button("+ NY LINJE PÅ KARTAN")
			content_body.add_child(map_btn)
			map_btn.pressed.connect(func() -> void: show_tab("map"))
		"fleet":
			content_body.add_child(label("FLYGPLANSFLOTTAN", 24, INK, true))
			content_body.add_child(label("NIVÅ %d / 8  ·  %d plan" % [game.level(), game.routes.size()], 13, MUTED))
			for r in game.routes:
				var plane: Dictionary = game.catalog_by_id.get(str(r["plane"]), {})
				var b: Button = button("%s  ·  %s - %s" % [plane.get("name", ""), r["from"], r["to"]], false)
				content_body.add_child(b)
				var id: String = str(r["id"])
				b.pressed.connect(func() -> void: show_route(id))
			content_body.add_child(line_break())
			content_body.add_child(label("FLYGPLANSNIVÅER", 12, MUTED, true))
			for p in game.catalog:
				content_body.add_child(label("%s  %s  ·  %d platser" % ["KLAR" if int(p["level"]) <= game.level() else "LÅST", p["name"], int(p["seats"])], 13, INK if int(p["level"]) <= game.level() else MUTED))
			if game.next_level_requirement() > 0:
				content_body.add_child(label("Nästa nivå vid %d transporterade passagerare." % game.next_level_requirement(), 12, MUTED))
		"company":
			content_body.add_child(label("DITT FLYGBOLAG", 24, INK, true))
			content_body.add_child(label(game.company_name, 19, INK, true))
			content_body.add_child(label("Huvudkontor %s" % game.home, 12, MUTED))
			var summary: HBoxContainer = row()
			content_body.add_child(summary)
			summary.add_child(info_tile("SALDO", game.money(game.cash)))
			summary.add_child(info_tile("FLYGNINGAR", str(game.total_flights)))
			content_body.add_child(info_tile("PASSAGERARE", str(game.total_passengers)))
			content_body.add_child(line_break())
			var company_name_edit := LineEdit.new()
			company_name_edit.text = game.company_name
			company_name_edit.max_length = 28
			company_name_edit.custom_minimum_size.y = 45
			content_body.add_child(company_name_edit)
			var rename: Button = button("SPARA FLYGBOLAGSNAMN")
			content_body.add_child(rename)
			rename.pressed.connect(func() -> void:
				if company_name_edit.text.strip_edges().length() >= 3:
					game.company_name = company_name_edit.text.strip_edges()
					game.save_game()
					toast("Namnet är sparat")
			)
			var reset_btn: Button = button("BÖRJA OM MED NYTT BOLAG", false)
			content_body.add_child(reset_btn)
			reset_btn.pressed.connect(func() -> void:
				var dialog := ConfirmationDialog.new()
				dialog.title = "Börja om?"
				dialog.dialog_text = "Den nuvarande sparfilen skrivs över. Vill du starta om?"
				add_child(dialog)
				dialog.confirmed.connect(func() -> void:
					game.begin(game.home)
					show_tab("map")
					dialog.queue_free()
				)
				dialog.canceled.connect(func() -> void: dialog.queue_free())
				dialog.popup_centered()
			)
			content_body.add_child(label("LEDNINGSBESLUT", 12, MUTED, true))
			for kind in ["marketing", "service", "staffing"]:
				var title: String = {"marketing":"Marknadsföring", "service":"Service", "staffing":"Personal"}[kind]
				var line: HBoxContainer = row()
				content_body.add_child(line)
				line.add_child(expanded(label(title, 13, INK)))
				var minus: Button = button("−", false)
				line.add_child(minus)
				var value: Label = label(str(game.get(kind)), 13, INK)
				line.add_child(value)
				var plus: Button = button("+", false)
				line.add_child(plus)
				minus.pressed.connect(func() -> void: _change_setting(kind, -1))
				plus.pressed.connect(func() -> void: _change_setting(kind, 1))

func _change_setting(name: String, delta: int) -> void:
	game.set(name, clampi(int(game.get(name)) + delta, 0, 5))
	game.save_game()
	build_tab()

func _toggle_pause() -> void:
	game.paused = not game.paused
	play_button.text = "SPELA" if game.paused else "PAUS"
	game.save_game()

func refresh_hud() -> void:
	if not game.initialized:
		return
	hud_balance.text = game.money(game.cash)
	hud_routes.text = str(game.routes.size())
	hud_passengers.text = str(game.total_passengers)
	clock_label.text = "DAG %02d" % game.day
	play_button.text = "SPELA" if game.paused else "PAUS"
	if current_sheet == "route" and flight_eta != null:
		var r: Dictionary = game.get_route(current_route)
		if not r.is_empty():
			flight_eta.text = "Nästa landning: %d sek" % ceili((1.0 - float(r["progress"])) * game.flight_duration(r) / game.speed)

func _on_game_changed() -> void:
	refresh_hud()
	world_map.queue_redraw()

func _on_landed(route_id: String, count: int, net: float) -> void:
	var route: Dictionary = game.get_route(route_id)
	var airport_code: String = ""
	if active_tab == "map" and current_sheet.is_empty() and not route.is_empty():
		airport_code = str(route["to"]) if int(route.get("direction", 1)) == 1 else str(route["from"])
	profit_layer.show_landing(airport_code, net, count)
	pulse_balance(net)
	if current_sheet == "route" and current_route == route_id:
		show_route(route_id)
	if active_tab == "routes" or active_tab == "company":
		build_tab()

func pulse_balance(net: float) -> void:
	if hud_balance == null:
		return
	if balance_tween != null and balance_tween.is_running():
		balance_tween.kill()
	hud_balance.scale = Vector2.ONE
	hud_balance.modulate = Color.WHITE
	hud_balance.pivot_offset = hud_balance.size * 0.5
	balance_tween = create_tween()
	balance_tween.tween_property(hud_balance, "modulate", Color("258368") if net >= 0.0 else Color("ae6450"), 0.14)
	balance_tween.parallel().tween_property(hud_balance, "scale", Vector2(1.08, 1.08), 0.14)
	balance_tween.chain().tween_property(hud_balance, "modulate", Color.WHITE, 0.27)
	balance_tween.parallel().tween_property(hud_balance, "scale", Vector2.ONE, 0.27).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_news(title: String, info: String) -> void:
	toast(title + ": " + info)

func _process(delta: float) -> void:
	game.advance(delta)
	ui_seconds += delta
	if ui_seconds > 0.5:
		ui_seconds = 0.0
		refresh_hud()

func toast(message: String) -> void:
	if toast_tween != null and toast_tween.is_running():
		toast_tween.kill()
	active_toast.text = message
	active_toast.visible = true
	active_toast.modulate.a = 1.0
	toast_tween = create_tween()
	toast_tween.tween_interval(2.1)
	toast_tween.tween_property(active_toast, "modulate:a", 0.0, 0.30)
	toast_tween.tween_callback(func() -> void: active_toast.visible = false)

func show_start() -> void:
	start_overlay = ColorRect.new()
	start_overlay.color = Color("d1e8e4")
	start_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	start_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(start_overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	start_overlay.add_child(center)
	var welcome: PanelContainer = add_styled_panel(Color("fffdf6"), 28)
	welcome.custom_minimum_size = Vector2(340, 480)
	center.add_child(welcome)
	var container: VBoxContainer = stack(12)
	welcome.add_child(container)
	container.add_child(label("A E R O R O U T E", 20, DARK, true))
	container.add_child(label("Ditt flygbolag. Din värld.", 22, INK, true))
	container.add_child(label("Bygg ett globalt flygnät, en linje i taget. Börja utan flygplan och rutter.", 13, MUTED))
	container.add_child(line_break())
	container.add_child(label("VÄLJ HUVUDFLYGPLATS", 11, MUTED, true))
	start_search = LineEdit.new()
	start_search.placeholder_text = "Sök stad eller ICAO-kod"
	start_search.custom_minimum_size.y = 45
	container.add_child(start_search)
	var airport_scroll := ScrollContainer.new()
	airport_scroll.custom_minimum_size.y = 170
	airport_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_child(airport_scroll)
	start_choices = stack(4)
	start_choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	airport_scroll.add_child(start_choices)
	start_search.text_changed.connect(_update_start_choices)
	_update_start_choices("")
	var begin_btn: Button = button("STARTA NYTT FLYGBOLAG")
	container.add_child(begin_btn)
	begin_btn.pressed.connect(func() -> void:
		if not game.can_start_at(start_choice_code):
			toast("Välj en flygplats med en möjlig startlinje inom 1100 km")
			return
		game.begin(start_choice_code)
		update_map_status()
		start_overlay.queue_free()
		start_overlay = null
		world_map.center_on(game.home)
		show_tab("map")
	)

func _update_start_choices(search_text: String) -> void:
	clear_children(start_choices)
	var options: Array = []
	var q: String = search_text.to_lower().strip_edges()
	if q.is_empty():
		for code in ["ESSA", "EGLL", "KJFK", "EKCH", "OMDB", "WSSS"]:
			if game.airports_by_code.has(code):
				options.append(game.airport(code))
	else:
		for a in game.airports:
			if (str(a["icao"]) + " " + str(a["iata"]) + " " + str(a["name"])).to_lower().contains(q):
				options.append(a)
	options.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["rank"]) > int(b["rank"]))
	for i in range(mini(8, options.size())):
		var a: Dictionary = options[i]
		var code: String = str(a["icao"])
		var b: Button = button("%s · %s" % [code, a["name"]], false)
		start_choices.add_child(b)
		b.pressed.connect(func() -> void:
			start_choice_code = code
			start_search.release_focus()
			toast("Startflygplats: " + code)
		)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and game != null:
		game.save_game()
