extends Control
## Aeroroute: responsive Godot airline game UI for iPhone portrait and landscape.

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
var cockpit_background: Control
var cockpit_top: VBoxContainer
var clock_dock: PanelContainer
var quote_card: PanelContainer
var quote_label: Label
var viewport_layout_mode: String = "portrait"
var hud: PanelContainer
var hud_balance: Label
var hud_routes: Label
var hud_passengers: Label
var brand_status: Label
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
var start_selection_label: Label
var start_begin_button: Button
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
var follow_button: Button

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	create_scene()
	resized.connect(_refresh_layout)
	call_deferred("_refresh_layout")
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
	v.add_child(label(title, 9, Color("b8d6d9")))
	var value: Label = label(initial, 17, Color("ffffff"), true)
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
	world_map.route_tapped.connect(_route_tapped)
	world_map.route_drafted.connect(_quick_create_route)
	world_map.route_preview_changed.connect(_update_route_quote)
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
	# Opaque, non-interactive header gives the brand and counters proper readability.
	var header: PanelContainer = add_styled_panel(Color(0.065, 0.19, 0.23, 0.96), 20)
	cockpit_background = header
	var header_style: StyleBoxFlat = header.get_theme_stylebox("panel") as StyleBoxFlat
	header_style.content_margin_left = 0
	header_style.content_margin_right = 0
	header_style.content_margin_top = 0
	header_style.content_margin_bottom = 0
	header_style.shadow_color = Color(0.04, 0.17, 0.20, 0.24)
	header_style.shadow_size = 10
	header_style.border_width_bottom = 2
	header_style.border_color = Color("e5b979")
	header.anchor_right = 1.0
	header.offset_left = 8.0
	header.offset_right = -8.0
	header.offset_top = 6.0
	header.offset_bottom = 119.0
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(header)
	var top: VBoxContainer = stack(6)
	cockpit_top = top
	top.anchor_right = 1.0
	top.offset_left = 19.0
	top.offset_right = -19.0
	top.offset_top = 14.0
	add_child(top)
	var brand_row: HBoxContainer = row(9)
	top.add_child(brand_row)
	var logo_box: PanelContainer = add_styled_panel(Color("255b69"), 12)
	var logo_style: StyleBoxFlat = logo_box.get_theme_stylebox("panel") as StyleBoxFlat
	logo_style.content_margin_left = 4
	logo_style.content_margin_right = 4
	logo_style.content_margin_top = 3
	logo_style.content_margin_bottom = 3
	logo_box.custom_minimum_size = Vector2(40, 40)
	brand_row.add_child(logo_box)
	var mark: Label = label("A", 21, Color("e7b88a"), true)
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	logo_box.add_child(mark)
	var brand_text: VBoxContainer = stack(0)
	brand_row.add_child(expanded(brand_text))
	brand_text.add_child(label("AEROROUTE", 17, Color("fff9e8"), true))
	brand_status = label("FLYGOPERATIVT", 9, Color("a8ccd0"))
	brand_status.autowrap_mode = TextServer.AUTOWRAP_OFF
	brand_status.clip_text = true
	brand_text.add_child(brand_status)
	var search_btn: Button = button("SÖK", false)
	search_btn.custom_minimum_size = Vector2(43, 40)
	search_btn.add_theme_font_size_override("font_size", 11)
	search_btn.tooltip_text = "Sök flygplats"
	brand_row.add_child(search_btn)
	search_btn.pressed.connect(show_search)
	var center_btn: Button = button("HEM", false)
	center_btn.custom_minimum_size = Vector2(43, 40)
	center_btn.add_theme_font_size_override("font_size", 11)
	center_btn.tooltip_text = "Visa huvudflygplatsen"
	brand_row.add_child(center_btn)
	center_btn.pressed.connect(func() -> void:
		world_map.reset_gesture()
		world_map.center_on(game.home)
	)
	hud = add_styled_panel(Color(0.19, 0.39, 0.43, 0.76), 11)
	var compact_style: StyleBoxFlat = hud.get_theme_stylebox("panel") as StyleBoxFlat
	compact_style.content_margin_left = 10
	compact_style.content_margin_right = 10
	compact_style.content_margin_top = 5
	compact_style.content_margin_bottom = 5
	top.add_child(hud)
	var stats: HBoxContainer = row(7)
	hud.add_child(stats)
	stats.add_child(build_stat("SALDO", "650 AC", "cash"))
	stats.add_child(build_stat("LINJER", "0", "routes"))
	stats.add_child(build_stat("PASSAGERARE", "0", "passengers"))

	nav_bar = add_styled_panel(Color(0.07, 0.19, 0.24, 0.96), 19)
	var nav_back: StyleBoxFlat = nav_bar.get_theme_stylebox("panel") as StyleBoxFlat
	nav_back.shadow_color = Color(0.02, 0.15, 0.22, 0.26)
	nav_back.shadow_size = 9
	var nav_style: StyleBoxFlat = nav_bar.get_theme_stylebox("panel") as StyleBoxFlat
	nav_style.content_margin_top = 5
	nav_style.content_margin_bottom = 5
	nav_style.content_margin_left = 8
	nav_style.content_margin_right = 8
	nav_bar.anchor_top = 1.0
	nav_bar.anchor_bottom = 1.0
	nav_bar.anchor_right = 1.0
	nav_bar.offset_top = -64.0
	nav_bar.offset_bottom = 0.0
	add_child(nav_bar)
	var nav: HBoxContainer = row(6)
	nav_bar.add_child(nav)
	for item in [{"id":"map","name":"KARTA"},{"id":"routes","name":"LINJER"},{"id":"fleet","name":"FLOTTA"},{"id":"company","name":"BOLAG"}]:
		var b: Button = button(str(item["name"]), false)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 42.0
		b.add_theme_font_size_override("font_size", 11)
		nav.add_child(b)
		var id: String = str(item["id"])
		b.pressed.connect(func() -> void: show_tab(id))
		tab_buttons[id] = b

	# Map controls remain accessible without pinch gestures and offer quick recentering.
	zoom_buttons = stack(6)
	zoom_buttons.anchor_left = 1.0
	zoom_buttons.anchor_right = 1.0
	zoom_buttons.offset_left = -61.0
	zoom_buttons.offset_right = -13.0
	zoom_buttons.offset_top = 149.0  # below compact cockpit HUD
	zoom_buttons.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(zoom_buttons)
	var zoom_in: Button = button("+", false)
	zoom_in.custom_minimum_size = Vector2(48, 48)
	zoom_in.add_theme_font_size_override("font_size", 23)
	zoom_buttons.add_child(zoom_in)
	zoom_in.pressed.connect(func() -> void: world_map.change_zoom(1.27))
	var zoom_out: Button = button("−", false)
	zoom_out.custom_minimum_size = Vector2(48, 48)
	zoom_out.add_theme_font_size_override("font_size", 23)
	zoom_buttons.add_child(zoom_out)
	zoom_out.pressed.connect(func() -> void: world_map.change_zoom(0.79))
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
	route_mode_button = button("DRA NY LINJE", true)
	var route_action_style: StyleBoxFlat = route_mode_button.get_theme_stylebox("normal") as StyleBoxFlat
	route_action_style.bg_color = Color("e7b574")
	route_mode_button.add_theme_color_override("font_color", Color("123441"))
	route_mode_button.add_theme_color_override("font_hover_color", Color("123441"))
	route_mode_button.toggle_mode = true
	route_mode_button.anchor_top = 1.0
	route_mode_button.anchor_bottom = 1.0
	route_mode_button.offset_top = -202.0
	route_mode_button.offset_bottom = -153.0
	route_mode_button.offset_left = 13.0
	route_mode_button.offset_right = 134.0
	route_mode_button.custom_minimum_size = Vector2(121.0, 49.0)
	add_child(route_mode_button)
	follow_button = button("✈ FÖLJ FLYG", false)
	follow_button.anchor_top = 1.0
	follow_button.anchor_bottom = 1.0
	follow_button.offset_top = -202.0
	follow_button.offset_bottom = -153.0
	follow_button.offset_left = 145.0
	follow_button.offset_right = 271.0
	follow_button.custom_minimum_size = Vector2(126.0, 49.0)
	follow_button.disabled = true
	add_child(follow_button)
	follow_button.pressed.connect(func() -> void:
		var ops: Dictionary = game.network_snapshot()
		var next_id: String = str(ops.get("next_route_id", ""))
		if world_map.follow_route_id != "" and next_id != world_map.follow_route_id:
			next_id = world_map.follow_route_id
		var active: bool = world_map.toggle_follow(next_id)
		follow_button.text = "✕ SLUTA FÖLJA" if active else "✈ FÖLJ FLYG"
	)
	route_mode_button.toggled.connect(func(active: bool) -> void:
		route_mode_button.text = "✓ VÄLJ 2 PLATSER" if active else "DRA NY LINJE"
		route_mode = active
		world_map.route_draw_enabled = active
		route_origin = ""
		world_map.route_origin = ""
		world_map.reset_gesture()
		update_map_status()
	)
	# FIR is enabled after the HUD and notification labels have been created.


	var bottom_controls: PanelContainer = add_styled_panel(Color(0.08, 0.23, 0.29, 0.96), 16)
	var dock_back: StyleBoxFlat = bottom_controls.get_theme_stylebox("panel") as StyleBoxFlat
	dock_back.shadow_color = Color(0.03, 0.15, 0.21, 0.24)
	dock_back.shadow_size = 7
	clock_dock = bottom_controls
	var dock_style: StyleBoxFlat = bottom_controls.get_theme_stylebox("panel") as StyleBoxFlat
	dock_style.content_margin_top = 6
	dock_style.content_margin_bottom = 6
	bottom_controls.anchor_left = 0.0
	bottom_controls.anchor_right = 1.0
	bottom_controls.anchor_top = 1.0
	bottom_controls.anchor_bottom = 1.0
	bottom_controls.offset_left = 12.0
	bottom_controls.offset_right = -12.0
	bottom_controls.offset_top = -130.0
	bottom_controls.offset_bottom = -70.0
	bottom_controls.name = "ClockDock"
	add_child(bottom_controls)
	var time_row: HBoxContainer = row(8)
	bottom_controls.add_child(time_row)
	var time_info: VBoxContainer = stack(3)
	time_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	time_row.add_child(time_info)
	time_info.add_child(label("FLYGTRAFIK", 10, Color("b8d4d6")))
	clock_label = label("INGA FLYG", 16, Color("fff8e7"), true)
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

	content_view = add_styled_panel(Color("edf5ef"), 20)
	var content_style: StyleBoxFlat = content_view.get_theme_stylebox("panel") as StyleBoxFlat
	content_style.shadow_color = Color(0.03, 0.13, 0.16, 0.23)
	content_style.shadow_size = 12
	content_view.anchor_right = 1.0
	content_view.anchor_bottom = 1.0
	content_view.offset_bottom = -64.0
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
	sheet.offset_bottom = -64.0
	sheet.visible = false
	add_child(sheet)
	sheet_scroll = ScrollContainer.new()
	sheet_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sheet_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sheet.add_child(sheet_scroll)
	sheet_body = stack(11)
	sheet_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sheet_scroll.add_child(sheet_body)

	# Cost preview is touch transparent, centered above route action controls.
	quote_card = add_styled_panel(Color("163d4b"), 13)
	quote_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quote_card.anchor_left = 0.5
	quote_card.anchor_right = 0.5
	quote_card.anchor_top = 1.0
	quote_card.anchor_bottom = 1.0
	quote_card.offset_left = -150.0
	quote_card.offset_right = 150.0
	quote_card.offset_top = -267.0
	quote_card.offset_bottom = -211.0
	quote_card.visible = false
	add_child(quote_card)
	quote_label = label("", 12, Color("fff6e6"), true)
	quote_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quote_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	quote_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quote_card.add_child(quote_label)
	active_toast = label("", 12, PAPER, true)
	active_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	active_toast.offset_left = -170
	active_toast.offset_right = 170
	active_toast.offset_top = -252
	active_toast.offset_bottom = -224
	active_toast.visible = false
	add_child(active_toast)
	map_status = label("", 11, Color("fbf2e3"), true)
	map_status.anchor_left = 0.0
	map_status.anchor_top = 1.0
	map_status.anchor_bottom = 1.0
	map_status.offset_left = 17.0
	map_status.offset_top = -229.0
	map_status.offset_bottom = -208.0
	map_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(map_status)
	fir_layer.set_mode(1)
	update_map_status()
	_refresh_layout()

func _update_route_quote(quote: Dictionary) -> void:
	if quote_card == null:
		return
	if quote.is_empty() or not game.initialized or current_sheet != "" or active_tab != "map":
		quote_card.visible = false
		return
	quote_card.visible = true
	var destination: String = str(quote.get("to", ""))
	var price: float = float(quote.get("price", -1.0))
	var is_ok: bool = bool(quote.get("ok", false))
	var reason: String = str(quote.get("reason", ""))
	var style: StyleBoxFlat = quote_card.get_theme_stylebox("panel") as StyleBoxFlat
	style.bg_color = Color("1b6559") if is_ok else Color("713f49") if destination != "" else Color("204959")
	if destination == "":
		quote_label.text = "DRA TILL EN FLYGPLATS\nPriset visas innan du släpper"
	elif price < 0.0:
		quote_label.text = "%s → %s · EJ MÖJLIG\n%s" % [quote["from"], destination, reason]
	elif is_ok:
		quote_label.text = "%s → %s · %s\n✓ DU HAR RÅD · SALDO %s" % [quote["from"], destination, game.money(price), game.money(game.cash)]
	else:
		quote_label.text = "%s → %s · %s\n%s · SALDO %s" % [quote["from"], destination, game.money(price), reason, game.money(game.cash)]

func _refresh_layout() -> void:
	_layout_for_size(size)

func _layout_for_size(view_size: Vector2) -> void:
	if cockpit_background == null or clock_dock == null or nav_bar == null:
		return
	var landscape: bool = view_size.x > view_size.y * 1.12
	viewport_layout_mode = "landscape" if landscape else "portrait"
	var cockpit_width: float = minf(420.0, view_size.x - 6.0) if landscape else view_size.x
	cockpit_background.anchor_right = 0.0 if landscape else 1.0
	cockpit_background.offset_left = 8.0
	cockpit_background.offset_right = cockpit_width - 8.0 if landscape else -8.0
	cockpit_background.offset_bottom = 118.0
	cockpit_top.anchor_right = 0.0 if landscape else 1.0
	cockpit_top.offset_left = 19.0
	cockpit_top.offset_right = cockpit_width - 19.0 if landscape else -19.0
	zoom_buttons.offset_top = 113.0 if landscape else 143.0
	zoom_buttons.offset_left = -52.0 if landscape else -61.0
	zoom_buttons.offset_right = -8.0 if landscape else -13.0
	nav_bar.anchor_left = 0.0
	nav_bar.anchor_right = 0.0 if landscape else 1.0
	nav_bar.offset_left = 8.0 if landscape else 10.0
	nav_bar.offset_right = minf(view_size.x * 0.62, 494.0) if landscape else -10.0
	nav_bar.offset_top = -64.0 if landscape else -68.0
	nav_bar.offset_bottom = -8.0
	if landscape:
		clock_dock.anchor_left = 1.0
		clock_dock.anchor_right = 1.0
		clock_dock.anchor_top = 0.0
		clock_dock.anchor_bottom = 0.0
		clock_dock.offset_left = -326.0
		clock_dock.offset_right = -12.0
		clock_dock.offset_top = 13.0
		clock_dock.offset_bottom = 74.0
	else:
		clock_dock.anchor_left = 0.0
		clock_dock.anchor_right = 1.0
		clock_dock.anchor_top = 1.0
		clock_dock.anchor_bottom = 1.0
		clock_dock.offset_left = 11.0
		clock_dock.offset_right = -11.0
		clock_dock.offset_top = -125.0
		clock_dock.offset_bottom = -65.0
	route_mode_button.offset_top = -128.0 if landscape else -196.0
	route_mode_button.offset_bottom = -76.0 if landscape else -147.0
	follow_button.offset_top = route_mode_button.offset_top
	follow_button.offset_bottom = route_mode_button.offset_bottom
	if quote_card != null:
		quote_card.anchor_top = 0.0 if landscape else 1.0
		quote_card.anchor_bottom = 0.0 if landscape else 1.0
		quote_card.offset_top = 91.0 if landscape else -260.0
		quote_card.offset_bottom = 151.0 if landscape else -204.0
	if sheet != null:
		if landscape:
			sheet.anchor_left = 1.0
			sheet.anchor_right = 1.0
			sheet.anchor_top = 0.0
			sheet.anchor_bottom = 1.0
			sheet.offset_left = -minf(466.0, view_size.x * 0.57)
			sheet.offset_right = -10.0
			sheet.offset_top = 80.0
			sheet.offset_bottom = -64.0
		else:
			sheet.anchor_left = 0.0
			sheet.anchor_right = 1.0
			sheet.anchor_top = 1.0
			sheet.anchor_bottom = 1.0
			sheet.offset_left = 0.0
			sheet.offset_right = 0.0
			sheet.offset_top = -minf(555.0, view_size.y * 0.73)
			sheet.offset_bottom = -62.0
	if content_view != null:
		if landscape:
			content_view.anchor_left = 1.0
			content_view.anchor_right = 1.0
			content_view.anchor_top = 0.0
			content_view.anchor_bottom = 1.0
			content_view.offset_left = -minf(view_size.x * 0.45, 474.0)
			content_view.offset_right = -9.0
			content_view.offset_top = 84.0
			content_view.offset_bottom = -9.0
		else:
			content_view.anchor_left = 0.0
			content_view.anchor_right = 1.0
			content_view.anchor_top = 1.0
			content_view.anchor_bottom = 1.0
			content_view.offset_left = 9.0
			content_view.offset_right = -9.0
			content_view.offset_top = -minf(view_size.y * 0.61, 550.0)
			content_view.offset_bottom = -76.0

func map_gesture_active() -> bool:
	return active_tab == "map" and game.initialized and not (
		(start_overlay != null and is_instance_valid(start_overlay) and start_overlay.visible)
		or shade.visible or sheet.visible
	)

func map_can_interact(pos: Vector2) -> bool:
	if not map_gesture_active():
		return false
	# Respect ACTUAL UI geometry in either orientation, rather than
	# rejecting wide horizontal strips of playable map by hardcoded Y.
	for control in [cockpit_background, nav_bar, clock_dock, zoom_buttons, route_mode_button, follow_button]:
		if control != null and control.visible and control.get_global_rect().has_point(pos):
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
	if quote_card != null:
		quote_card.visible = false
	current_sheet = sheet_type
	shade.visible = true
	sheet.visible = true
	sheet_scroll.scroll_vertical = 0
	clear_children(sheet_body)

func close_sheet() -> void:
	current_sheet = ""
	world_map.focused_route_id = ""
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
	# The top HUD communicates FIR state through its button; the map status
	# is reserved for purposeful route building, never persistent cartographic text.
	map_status.visible = active_tab == "map" and game.initialized and route_mode

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
		world_map.focused_airport = code
		world_map.queue_redraw()
		show_airport(code)

func _route_tapped(route_id: String) -> void:
	if not game.initialized or route_mode:
		return
	if game.get_route(route_id).is_empty():
		return
	show_plane_picker(route_id)

func _quick_create_route(from: String, to: String) -> void:
	# Fly Corp-like: draw between two airports and the route opens immediately
	# with an automatically selected suitable plane. No menu selection required.
	if not game.initialized:
		return
	if from == to:
		return
	var id: String = game.route_key(from, to)
	if not game.get_route(id).is_empty():
		show_plane_picker(id)
		return
	var error: String = game.create_route(from, to)
	if error != "":
		toast(error)
		return
	world_map.animate_new_route(id)
	toast("Ny linje: %s ↔ %s" % [from, to])

func _draft_route(from: String, to: String) -> void:
	world_map.route_draw_enabled = false
	route_mode = false
	if route_mode_button != null:
		route_mode_button.set_pressed_no_signal(false)
		route_mode_button.text = "DRA NY LINJE"
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
	var airport: Dictionary = game.airport(code)
	if airport.is_empty():
		return
	current_code = code
	world_map.focused_airport = code
	world_map.focused_route_id = ""
	world_map.queue_redraw()
	open_sheet("airport")
	heading("FLYGPLATS", code, str(airport["name"]) + " · " + str(airport["country"]))
	var connected: Array = game.connected_routes(code)
	var is_owned: bool = game.owned.has(code)
	if is_owned:
		var terminal_level: int = int(game.terminals.get(code, 1))
		var capacity: int = 2 + terminal_level * 2
		sheet_body.add_child(label("%d/%d flyglinjer anslutna  ·  Terminal %d" % [connected.size(), capacity, terminal_level], 13, MUTED))
		var upgrade_cost: float = game.terminal_upgrade_price(code)
		var upgrade_text: String = "✓ MAXIMAL KAPACITET" if upgrade_cost < 0.0 else "⬆ UPPGRADERA FLYGPLATS  ·  %s" % game.money(upgrade_cost)
		var upgrade: Button = button(upgrade_text, true)
		upgrade.disabled = upgrade_cost < 0.0 or game.cash < upgrade_cost
		sheet_body.add_child(upgrade)
		upgrade.pressed.connect(func() -> void:
			var error: String = game.upgrade_terminal(code)
			if error != "":
				toast(error)
			else:
				show_airport(code)
				toast("Terminalen är uppgraderad")
		)
	else:
		sheet_body.add_child(label(game.airport_market_class(code), 13, MUTED))
	if not connected.is_empty():
		sheet_body.add_child(line_break())
		sheet_body.add_child(label("VÄLJ EN LINJE FÖR ATT BYTA FLYGPLAN" if connected.size() > 1 else "FLYGPLAN PÅ DIN LINJE", 12, MUTED, true))
		for r in connected:
			var id: String = str(r["id"])
			var destination: String = str(r["to"]) if str(r["from"]) == code else str(r["from"])
			var model: Dictionary = game.catalog_by_id.get(str(r["plane"]), {})
			var title: String = "%s  ↔  %s" % [code, destination]
			var route_button: Button = button("%s   ›   %s" % [title, str(model.get("name", "Flygplan"))], false)
			route_button.custom_minimum_size.y = 52.0
			sheet_body.add_child(route_button)
			route_button.pressed.connect(func() -> void: show_plane_picker(id))
	else:
		sheet_body.add_child(label("Inga anslutna linjer ännu.", 13, MUTED))
	if connected.is_empty():
		sheet_body.add_child(label("Håll på flygplatsen och dra till nästa flygplats på kartan.", 12, MUTED))

func show_plane_picker(route_id: String) -> void:
	var route: Dictionary = game.get_route(route_id)
	if route.is_empty():
		close_sheet()
		return
	current_route = route_id
	world_map.focused_route_id = route_id
	world_map.queue_redraw()
	open_sheet("aircraft")
	heading("FLYGPLAN PÅ LINJEN", str(route["from"]) + " ↔ " + str(route["to"]), game.distance_label(str(route["from"]), str(route["to"])))
	var current: Dictionary = game.catalog_by_id.get(str(route["plane"]), {})
	var current_name: String = str(current.get("name", "Flygplan"))
	sheet_body.add_child(label("NUVARANDE  ·  " + current_name, 15, INK, true))
	var projected: Dictionary = game.projected(route)
	if not projected.is_empty():
		sheet_body.add_child(label("%d platser  ·  %d%% beläggning  ·  %s netto/flyg" % [int(projected["seats"]), int(projected["load"]), game.money(float(projected["net"]))], 12, MUTED))
	sheet_body.add_child(line_break())
	sheet_body.add_child(label("VÄLJ FLYGPLAN", 12, MUTED, true))
	var km: float = game.kilometers(str(route["from"]), str(route["to"]))
	for model in game.catalog:
		var id: String = str(model["id"])
		var existing: bool = id == str(route["plane"])
		var valid_range: bool = float(model["range"]) >= km
		var price: float = game.plane_change_price(route_id, id)
		var affordable: bool = price <= game.cash
		var money_label: String = "ANVÄNDS" if existing else "FÖR KORT RÄCKVIDD" if not valid_range else ("FÅ " + game.money(-price)) if price < 0.0 else ("BETALA " + game.money(price))
		var text_value: String = "%s  ·  %d säten  ·  %s" % [str(model["name"]), int(model["seats"]), money_label]
		var option: Button = button(text_value, existing)
		option.custom_minimum_size.y = 47.0
		option.disabled = existing or not valid_range or not affordable
		sheet_body.add_child(option)
		option.pressed.connect(func() -> void:
			var result: String = game.change_plane(route_id, id)
			if result != "":
				toast(result)
			else:
				show_plane_picker(route_id)
				toast("Flygplanet har bytts")
		)
	sheet_body.add_child(line_break())
	var details: Button = button("BILJETTPRIS & LINJEDETALJER", false)
	sheet_body.add_child(details)
	details.pressed.connect(func() -> void: show_route(route_id))

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
			world_map.animate_new_route(game.route_key(from, to))
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
	var choose_aircraft: Button = button("BYT FLYGPLAN  ·  VISA ALLA MODELLER")
	sheet_body.add_child(choose_aircraft)
	choose_aircraft.pressed.connect(func() -> void: show_plane_picker(id))

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
		if not game.is_featured(str(a["icao"])):
			continue
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
	# The living flight map remains active behind partial operations panels.
	flight_layer.visible = true
	get_node("ClockDock").visible = tab == "map"
	zoom_buttons.visible = tab == "map"
	route_mode_button.visible = tab == "map"
	follow_button.visible = tab == "map"
	if tab == "map":
		follow_button.disabled = game.routes.is_empty()
	if tab != "map":
		world_map.route_draw_enabled = false
		world_map.toggle_follow("")
		follow_button.text = "✈ FÖLJ FLYG"
		route_mode = false
		route_origin = ""
		world_map.route_origin = ""
		if route_mode_button != null:
			route_mode_button.set_pressed_no_signal(false)
			route_mode_button.text = "DRA NY LINJE"
	update_map_status()
	for key in tab_buttons:
		var nav_button: Button = tab_buttons[key]
		nav_button.modulate = Color.WHITE
		var active: bool = key == tab
		var nav_style := StyleBoxFlat.new()
		nav_style.bg_color = Color("e8b877") if active else Color(0.14, 0.33, 0.39, 0.85)
		nav_style.corner_radius_top_left = 12
		nav_style.corner_radius_top_right = 12
		nav_style.corner_radius_bottom_left = 12
		nav_style.corner_radius_bottom_right = 12
		nav_style.content_margin_left = 4
		nav_style.content_margin_right = 4
		nav_button.add_theme_stylebox_override("normal", nav_style)
		nav_button.add_theme_color_override("font_color", Color("173d49") if active else Color("deeff0"))
	if tab != "map":
		build_tab()

func build_tab() -> void:
	_clear_content()
	match active_tab:
		"routes":
			content_body.add_child(label("DINA FLYGLINJER", 24, INK, true))
			content_body.add_child(label("%d flygningar  ·  Senaste resultat: %s" % [game.total_flights, game.money(game.last_profit)], 12, MUTED))
			content_body.add_child(label("%d linjer · %d flygplatser" % [game.routes.size(), game.owned.size()], 13, MUTED))
			var report: Dictionary = game.network_snapshot()
			var situation: PanelContainer = add_styled_panel(Color("e5f1eb"), 14)
			content_body.add_child(situation)
			var situation_text: VBoxContainer = stack(4)
			situation.add_child(situation_text)
			situation_text.add_child(label("LIVE · FLYGOPERATIVT", 11, Color("56837c"), true))
			if int(report["routes"]) > 0:
				situation_text.add_child(label("%s netto per flygomgång" % game.money(float(report["net"])), 18, INK, true))
				situation_text.add_child(label("%d%% förväntad beläggning · %d olönsamma linjer" % [int(report["load"]), int(report["loss_routes"])], 12, MUTED))
				situation_text.add_child(label("Nästa landning: %s om %d sek" % [str(report["next_airport"]), int(report["next_seconds"])], 12, MUTED))
			else:
				situation_text.add_child(label("Ditt nätverk väntar på första flygningen", 13, INK))
			# Player-visible operating opportunities, not XP quests.
			for active_event in game.route_events:
				if int(active_event.get("ends", 0)) <= game.day:
					continue
				var event_airport: String = str(active_event.get("airport", ""))
				var event_title: String = str(active_event.get("title", "Trafikökning"))
				var extra_demand: int = roundi((float(active_event.get("multiplier", 1.0)) - 1.0) * 100.0)
				var days_left: int = int(active_event["ends"]) - game.day
				var event_card: Button = button("★ %s · %s  +%d%%  (%d dagar)" % [event_title, event_airport, extra_demand, days_left], false)
				content_body.add_child(event_card)
				event_card.pressed.connect(func() -> void: show_airport(event_airport))
			for r in game.routes:
				var projection: Dictionary = game.projected(r)
				var net: float = float(projection["net"])
				var icon_text: String = "↑" if net > 0.0 else "↓" if net < 0.0 else "•"
				var b: Button = button("%s %s → %s  %s" % [icon_text, r["from"], r["to"], game.money(net)], false)
				content_body.add_child(b)
				var id: String = str(r["id"])
				b.pressed.connect(func() -> void: show_route(id))
			if game.routes.is_empty():
				content_body.add_child(label("Tryck LINJE på kartan, välj två flygplatser och starta ditt nätverk.", 15, MUTED))
			content_body.add_child(line_break())
			content_body.add_child(label("RUTTRADAR · NÄSTA MÖJLIGHETER", 11, MUTED, true))
			for idea in game.recommended_destinations(game.home, 3):
				var choice_code: String = str(idea["code"])
				var opening_cost: float = float(idea["cost"])
				var suggestion: Button = button("%s · %d km · %s" % [choice_code, roundi(float(idea["km"])), game.money(opening_cost)], false)
				content_body.add_child(suggestion)
				suggestion.pressed.connect(func() -> void: show_planner(game.home, choice_code))
			var map_btn: Button = button("+ NY LINJE PÅ KARTAN")
			content_body.add_child(map_btn)
			map_btn.pressed.connect(func() -> void: show_tab("map"))
		"fleet":
			content_body.add_child(label("FLYGPLANSFLOTTAN", 24, INK, true))
			content_body.add_child(label("%d aktiva flygplan  ·  Fritt modellval efter räckvidd och ekonomi" % game.routes.size(), 13, MUTED))
			for r in game.routes:
				var plane: Dictionary = game.catalog_by_id.get(str(r["plane"]), {})
				var b: Button = button("%s  ·  %s - %s" % [plane.get("name", ""), r["from"], r["to"]], false)
				content_body.add_child(b)
				var id: String = str(r["id"])
				b.pressed.connect(func() -> void: show_route(id))
			content_body.add_child(line_break())
			content_body.add_child(label("TILLGÄNGLIGA FLYGPLAN", 12, MUTED, true))
			for p in game.catalog:
				content_body.add_child(label("%s  ·  %d platser  ·  %d km" % [p["name"], int(p["seats"]), roundi(float(p["range"]))], 13, INK))
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
	var ops: Dictionary = game.network_snapshot()
	if follow_button != null:
		follow_button.disabled = int(ops["routes"]) == 0
	if brand_status != null:
		if int(ops["routes"]) > 0:
			brand_status.text = "✈ %s  ·  %d S" % [str(ops["next_airport"]), int(ops["next_seconds"])]
		else:
			brand_status.text = "BYGG DITT FLYGNÄT"
	hud_balance.text = game.money(game.cash)
	hud_routes.text = str(game.routes.size())
	hud_passengers.text = str(game.total_passengers)
	clock_label.text = "NÄSTA %s · %d S" % [str(ops["next_airport"]), int(ops["next_seconds"])] if int(ops["routes"]) > 0 else "BYGG FÖRSTA LINJEN"
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
	# Entirely fixed-height startup controls. The former nested scroll list
	# could lose labels or swallow touch while scrolling in iPhone Safari.
	start_overlay = ColorRect.new()
	start_overlay.color = Color("153e4b")
	start_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	start_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(start_overlay)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	start_overlay.add_child(center)
	var welcome: PanelContainer = add_styled_panel(Color("fffaf0"), 23)
	welcome.custom_minimum_size = Vector2(minf(maxf(size.x - 26.0, 282.0), 376.0), 0.0)
	center.add_child(welcome)
	var box: VBoxContainer = stack(10)
	welcome.add_child(box)
	var wordmark: Label = label("A E R O R O U T E", 20, DARK, true)
	box.add_child(wordmark)
	box.add_child(label("Bygg ditt flygbolag", 20, INK, true))
	box.add_child(label("Välj en startflygplats. Sedan kan du dra linjer direkt mellan flygplatser på kartan.", 13, MUTED))
	box.add_child(line_break())
	box.add_child(label("HUVUDFLYGPLATS", 11, MUTED, true))
	start_search = LineEdit.new()
	start_search.placeholder_text = "Sök ICAO, IATA eller stad"
	start_search.custom_minimum_size.y = 48.0
	start_search.clear_button_enabled = true
	box.add_child(start_search)
	start_choices = stack(5)
	box.add_child(start_choices)
	start_selection_label = label("", 13, Color("2b705e"), true)
	start_selection_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	start_selection_label.clip_text = true
	box.add_child(start_selection_label)
	start_search.text_changed.connect(_update_start_choices)
	_update_start_choices("")
	start_begin_button = button("STARTA FLYGBOLAG  →")
	start_begin_button.custom_minimum_size.y = 53.0
	box.add_child(start_begin_button)
	start_begin_button.pressed.connect(func() -> void:
		if not game.can_start_at(start_choice_code):
			start_selection_label.text = "Välj en giltig startflygplats"
			return
		start_search.release_focus()
		game.begin(start_choice_code)
		update_map_status()
		start_overlay.queue_free()
		start_overlay = null
		world_map.center_on(game.home)
		show_tab("map")
		toast("Håll på en flygplats och dra till nästa för en linje")
	)

func _update_start_choices(search_text: String) -> void:
	clear_children(start_choices)
	var options: Array = []
	var q: String = search_text.to_lower().strip_edges()
	if q.is_empty():
		for code in ["ESSA", "EGLL", "WSSS", "OMDB"]:
			if game.airports_by_code.has(code) and game.can_start_at(code):
				options.append(game.airport(code))
	else:
		for airport in game.airports:
			var code: String = str(airport["icao"])
			if not game.is_featured(code):
				continue
			var searchable: String = "%s %s %s %s" % [code, airport["iata"], airport["name"], airport["country"]]
			if searchable.to_lower().contains(q) and game.can_start_at(code):
				options.append(airport)
		options.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var prefix_a: bool = str(a["icao"]).to_lower().begins_with(q) or str(a["iata"]).to_lower().begins_with(q)
			var prefix_b: bool = str(b["icao"]).to_lower().begins_with(q) or str(b["iata"]).to_lower().begins_with(q)
			if prefix_a != prefix_b:
				return prefix_a
			return int(a["rank"]) > int(b["rank"])
		)
	for i in range(mini(4, options.size())):
		var airport: Dictionary = options[i]
		var code: String = str(airport["icao"])
		var fullname: String = str(airport["name"])
		var choice: Button = button("", false)
		choice.toggle_mode = true
		choice.custom_minimum_size.y = 47.0
		choice.add_theme_font_size_override("font_size", 12)
		start_choices.add_child(choice)
		choice.set_meta("airport_code", code)
		choice.pressed.connect(func() -> void:
			start_choice_code = code
			start_search.release_focus()
			_update_start_selected_visual()
		)
	_update_start_selected_visual()

func _update_start_selected_visual() -> void:
	if start_selection_label == null:
		return
	for node in start_choices.get_children():
		if not (node is Button):
			continue
		var airport_button: Button = node as Button
		var code: String = str(airport_button.get_meta("airport_code", ""))
		var airport: Dictionary = game.airport(code)
		var name_short: String = str(airport.get("name", code))
		if name_short.length() > 29:
			name_short = name_short.substr(0, 28).strip_edges() + "…"
		var selected: bool = code == start_choice_code
		airport_button.text = ("✓  " if selected else "     ") + code + " · " + name_short
		airport_button.set_pressed_no_signal(selected)
		airport_button.add_theme_color_override("font_color", Color("fffdf6") if selected else DARK)
		var background: StyleBoxFlat = StyleBoxFlat.new()
		background.bg_color = Color("397569") if selected else Color("e5efea")
		background.set_corner_radius_all(10)
		background.content_margin_left = 11
		background.content_margin_right = 11
		airport_button.add_theme_stylebox_override("normal", background)
		airport_button.add_theme_stylebox_override("pressed", background)
		airport_button.add_theme_stylebox_override("hover", background)
	var selected_airport: Dictionary = game.airport(start_choice_code)
	if selected_airport.is_empty():
		start_selection_label.text = "Välj en flygplats"
	else:
		start_selection_label.text = "VALD: %s · %s" % [start_choice_code, str(selected_airport["name"])]

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and game != null:
		game.save_game()
