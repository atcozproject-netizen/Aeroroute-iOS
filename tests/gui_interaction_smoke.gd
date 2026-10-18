extends SceneTree
## Headless GUI regression test: actual mouse events must reach clickable Control nodes.
## iOS taps are mapped to GUI mouse events by pointing/emulate_mouse_from_touch=true.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("AEROROUTE GUI SMOKE: " + reason)
	quit(1)

func _click(at: Vector2) -> void:
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = at
	press.global_position = at
	root.push_input(press, true)
	var release: InputEventMouseButton = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = at
	release.global_position = at
	root.push_input(release, true)

func _run() -> void:
	if ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", false) != true:
		_fail("Touch-to-GUI-mouse emulation must be enabled on iOS.")
		return
	var scene_resource: PackedScene = load("res://scenes/Main.tscn")
	if scene_resource == null:
		_fail("Main scene missing")
		return
	var view: Control = scene_resource.instantiate()
	root.add_child(view)
	await process_frame
	await process_frame
	if view.start_overlay == null or view.start_search == null or not view.start_overlay.visible:
		_fail("New game overlay or search box missing")
		return
	# V0.9.6: actual ICAO coverage and high-resolution map assets must be
	# present in the SAME Godot PCK which iPhone Safari downloads.
	if view.game.airports.size() < 2200:
		_fail("Expanded real-airport dataset not loaded by Godot")
		return
	if str(view.game.airport("ESSA").get("iata", "")) != "ARN" or str(view.game.airport("ESSP").get("iata", "")) != "NRK":
		_fail("Expanding the airport catalog replaced canonical Swedish ICAO/IATA records")
		return
	var texture: Texture2D = load("res://data/world_land.png") as Texture2D
	if texture == null or texture.get_size() != Vector2(4096.0, 2048.0):
		_fail("4K coastline asset not present in game export")
		return
	var proposals: Array = view.game.recommended_destinations("OMDB", 4)
	if proposals.is_empty() or proposals.size() > 4:
		_fail("Nearby airport route suggestions unavailable")
		return
	for suggestion in proposals:
		if not view.game.airports_by_code.has(str(suggestion["code"])) or float(suggestion["cost"]) <= 0.0:
			_fail("Route suggestion has nonexistent airport or invalid opening cost")
			return

	# New game must begin with COUNTRY, then permit any airport as HUB.
	if view.start_country != "" or view.start_begin_button.visible:
		_fail("Onboarding must start with country selection, not an arbitrary hub")
		return
	if not view.game.can_start_at("ESSP"):
		_fail("Small regional airports like ESSP must be eligible as home hubs")
		return
	var unfeatured_hub: String = ""
	for airport in view.game.airports:
		var candidate_icao: String = str(airport["icao"])
		if not view.game.featured_codes.has(candidate_icao):
			unfeatured_hub = candidate_icao
			break
	if unfeatured_hub.is_empty() or not view.game.can_start_at(unfeatured_hub):
		_fail("Hubs are still restricted to curated international airports")
		return
	var search: LineEdit = view.start_search
	if search.get_global_rect().size.x < 20.0:
		_fail("Country search field has no usable geometry")
		return
	_click(search.get_global_rect().get_center())
	await process_frame
	if not search.has_focus():
		_fail("Country selection search cannot receive focus")
		return
	search.text = "UAE"
	search.text_changed.emit("UAE")
	await process_frame
	var options: VBoxContainer = view.start_choices
	if options.get_child_count() < 1:
		_fail("United Arab Emirates country search returned no results")
		return
	var country_button: Button = options.get_child(0) as Button
	_click(country_button.get_global_rect().get_center())
	await process_frame
	if view.start_country != "UAE" or not view.start_begin_button.visible:
		_fail("Country selection did not switch to airport stage")
		return
	search.text = "OMDB"
	search.text_changed.emit("OMDB")
	await process_frame
	if options.get_child_count() < 1:
		_fail("Airport search failed inside the selected country")
		return
	var first: Button = options.get_child(0) as Button
	if not first.text.contains("OMDB"):
		_fail("OMDB is not available after selecting UAE")
		return
	_click(first.get_global_rect().get_center())
	await process_frame
	if view.start_choice_code != "OMDB" or not first.button_pressed or view.start_begin_button.disabled:
		_fail("Airport selection did not select a valid HUB")
		return
	if view.start_overlay.find_children("*", "ScrollContainer", true, false).size() > 0:
		_fail("Start modal still contains buggy nested airport scrolling")
		return
	if view.start_choices.get_child_count() > 4:
		_fail("Start modal displays too many airport choices on iPhone")
		return
	# Rotate BEFORE starting company: welcome screen must display a true
	# two-column layout and remain inside the short landscape viewport.
	root.size = Vector2i(844,390)
	await process_frame
	await process_frame
	view._refresh_layout()
	if view.start_layout.columns != 2 or view.viewport_layout_mode != "landscape":
		_fail("Startup screen did not reflow into two landscape columns")
		return
	var start_rect: Rect2 = view.start_welcome.get_global_rect()
	if start_rect.position.y < -2.0 or start_rect.end.y > view.size.y + 2.0:
		_fail("Landscape welcome screen clipped vertically")
		return
	# Short browser viewport: Safari may shrink usable height after rotating.
	for narrow_size in [Vector2i(740, 320),Vector2i(667, 280)]:
		root.size = narrow_size
		await process_frame
		await process_frame
		view._refresh_layout()
		var short_rect: Rect2 = view.start_welcome.get_global_rect()
		if short_rect.position.y < -2.0 or short_rect.end.y > view.size.y + 2.0:
			_fail("Short landscape onboarding clipped at " + str(narrow_size))
			return
		if view.start_layout.columns != 2:
			_fail("Short landscape onboarding did not keep two-column layout")
			return
		# The browser-native LineEdit may have a taller intrinsic size.
		# Require the complete onboarding panel to be INSIDE the viewport
		# instead of assuming a fixed widget height across Safari themes.
	root.size = Vector2i(390,844)
	await process_frame
	await process_frame
	view._refresh_layout()
	if view.start_layout.columns != 1 or view.viewport_layout_mode != "portrait":
		_fail("Startup failed to return to single column in portrait")
		return
	var begin_button: Button = null
	for candidate in view.start_overlay.find_children("*", "Button", true, false):
		if candidate is Button and candidate.text.begins_with("STARTA FLYGBOLAG"):
			begin_button = candidate
			break
	if begin_button == null:
		_fail("Start company button missing")
		return
	_click(begin_button.get_global_rect().get_center())
	await process_frame
	if not view.game.initialized:
		_fail("Tapping start company button did not begin game")
		return
	if view.game.home != "OMDB" or view.start_overlay != null:
		_fail("Starting must use the visible selected ICAO and cleanly close onboarding")
		return
	if view.profit_layer == null:
		_fail("Profit effect layer missing")
		return
	# A map should NEVER draw every small-airport name at once, even zoomed in.
	# Zoom level controls detail; selection controls whether a full name appears.
	var map_for_labels: Control = view.world_map
	map_for_labels.focused_airport = ""
	map_for_labels.zoom = 36.0
	var pins_for_labels: Array = map_for_labels.candidate_airports()
	var labels_on_map: Array = map_for_labels.label_candidates(pins_for_labels)
	if labels_on_map.size() > 6 or map_for_labels.airport_label_budget() > 6:
		_fail("The iPhone map draws too many airport names at once")
		return
	for item in labels_on_map:
		if str(item["text"]).length() > 9:
			_fail("Unselected airport labels should use short ICAO codes")
			return
	map_for_labels.zoom = 9.0
	if map_for_labels.label_candidates(map_for_labels.candidate_airports()).size() > 4:
		_fail("Regional map is overcrowded with airport labels")
		return
	map_for_labels.zoom = 9.0

	# The game is now a free-form network simulation, not XP progression.
	if view.get("goal_bar") != null or view.get("level_effects") != null:
		_fail("Removed level progression UI is still present")
		return
	if view.game.level() != 8 or view.game.next_level_requirement() != -1:
		_fail("Legacy passenger unlock gates were not disabled")
		return
	if view.game.featured_codes.size() < 350 or view.game.featured_codes.size() > 1350:
		_fail("Curated commercial-airport network not loaded")
		return
	for essential in ["ESSA", "ESSP", "ESGJ", "OMDB", "WSSS", "EGLL", "KJFK"]:
		if not view.game.featured_codes.has(essential):
			_fail("Commercial airport filter dropped a relevant airport: " + essential)
			return
	var tile: Texture2D = load("res://data/map_tiles/09_01.png") as Texture2D
	if tile == null or tile.get_size() != Vector2(1280.0, 1280.0):
		_fail("High-resolution regional tiles missing in Godot PCK")
		return
	view.world_map.center_on("ESSA")
	view.world_map.zoom = 48.0
	view.world_map.queue_redraw()
	await process_frame
	if view.world_map.detailed_tile_draws < 1:
		_fail("The close-up map did not draw detail tiles")
		return

	view.game.landed.emit("TEST", 8, 37.50)
	await process_frame
	if not view.profit_layer.has_active_profit():
		_fail("Landing signal did not animate profit")
		return
	if not str(view.profit_layer.effects[0]["amount"]).contains("+37.5"):
		_fail("Profit animation does not show actual net")
		return
	view.game.landed.emit("TEST", 3, -8.50)
	await process_frame
	if view.profit_layer.effects.size() < 2 or not str(view.profit_layer.effects[1]["amount"]).contains("8.5"):
		_fail("Negative flight income did not animate")
		return
	if not view.fir_layer.loaded or not view.fir_layer.enabled or view.fir_layer.regions.size() < 200:
		_fail("FIR display is not loaded and enabled with worldwide regions")
		return
	if view.route_mode_button == null:
		_fail("Dedicated route mode toggle missing")
		return
	view.route_mode_button.button_pressed = true
	await process_frame
	if not view.route_mode:
		_fail("Route-mode button did not enable")
		return
	view._airport_tapped("OMDB")
	await process_frame
	if view.route_origin != "OMDB" or view.world_map.route_origin != "OMDB":
		_fail("First selected airport is not held as route origin")
		return
	view._airport_tapped("EGLL")
	await process_frame
	if view.current_sheet != "planner" or view.route_mode or view.route_origin != "":
		_fail("Two airport selections did not open route planner and clear gesture mode")
		return
	# FIR must start in a quiet, boundary-only mode and cycle through
	# boundaries+names -> off -> boundaries, rather than drawing a label jungle.
	if view.fir_layer.display_mode != 1:
		_fail("Default FIR display mode must be subtle boundaries without labels")
		return
	view.fir_button.pressed.emit()
	await process_frame
	if view.fir_layer.display_mode != 2:
		_fail("FIR+ mode was not enabled by the mode button")
		return
	view.fir_button.pressed.emit()
	await process_frame
	if view.fir_layer.display_mode != 0 or view.fir_layer.enabled:
		_fail("FIR button could not hide FIR overlay")
		return
	view.fir_button.pressed.emit()
	await process_frame
	if view.fir_layer.display_mode != 1:
		_fail("FIR button could not restore subtle borders")
		return

	# Pan is ALWAYS the default behavior, even when a finger begins
	# over an airport. Route creation must not happen incidentally.
	view.show_tab("map")
	view.world_map.center_on("OMDB")
	await process_frame
	var targets: Array = []
	for airport_item in view.world_map.candidate_airports():
		var point: Vector2 = airport_item["position"]
		if view.map_can_interact(point):
			targets.append(airport_item)
	var source_airport: Dictionary = {}
	var destination_airport: Dictionary = {}
	for a in targets:
		for b in targets:
			if a["code"] != b["code"] and a["position"].distance_to(b["position"]) >= 65.0 and not view.game.initial_plane(str(a["code"]), str(b["code"])).is_empty():
				source_airport = a
				destination_airport = b
				break
		if not source_airport.is_empty():
			break
	if source_airport.is_empty():
		_fail("Could not find two touchable airports for interaction regression")
		return
	var from_pos: Vector2 = source_airport["position"]
	var to_pos: Vector2 = destination_airport["position"]
	var original_lon: float = view.world_map.camera_lon
	var down: InputEventScreenTouch = InputEventScreenTouch.new()
	down.index = 0
	down.pressed = true
	down.position = from_pos
	root.push_input(down, true)
	var move_event: InputEventScreenDrag = InputEventScreenDrag.new()
	move_event.index = 0
	move_event.position = to_pos
	move_event.relative = to_pos - from_pos
	root.push_input(move_event, true)
	var up: InputEventScreenTouch = InputEventScreenTouch.new()
	up.index = 0
	up.pressed = false
	up.position = to_pos
	root.push_input(up, true)
	await process_frame
	if view.current_sheet == "planner" or absf(view.world_map.camera_lon - original_lon) < 0.005:
		_fail("Swipe starting on a marker must pan and never open a route")
		return
	if view.world_map.gesture_captured or not view.world_map.pointers.is_empty():
		_fail("Completed normal pan retained stale touch capture")
		return

	# The Fly Corp-like route gesture needs only a brief hold on the
	# airport marker; no modal or secondary route selection at all.
	view.game.cash = 12000.0
	view.world_map.center_on("OMDB")
	await process_frame
	from_pos = view.world_map.project(float(source_airport["airport"]["lon"]), float(source_airport["airport"]["lat"]))
	to_pos = view.world_map.project(float(destination_airport["airport"]["lon"]), float(destination_airport["airport"]["lat"]))
	down.position = from_pos
	root.push_input(down, true)
	view.world_map._process(0.14)
	view.world_map._process(0.14)
	if view.world_map.gesture_kind != "route":
		_fail("Long press did not arm deliberate route creation")
		return
	move_event.position = to_pos
	move_event.relative = to_pos - from_pos
	root.push_input(move_event, true)
	up.position = to_pos
	root.push_input(up, true)
	await process_frame
	var built_id: String = view.game.route_key(str(source_airport["code"]), str(destination_airport["code"]))
	if view.game.get_route(built_id).is_empty() or view.current_sheet != "":
		_fail("Direct drag should immediately open a route without a route picker")
		return
	var new_route: Dictionary = view.game.get_route(built_id)
	if new_route.get("plane", "") == "":
		_fail("Direct route was created without its automatic aircraft")
		return
	view.game.routes.erase(new_route)
	if view.world_map.gesture_captured or not view.world_map.pointers.is_empty():
		_fail("Finished long-press drag retained stale touch state")
		return

	# Two-finger gesture must never trigger route creation, and may
	# transition into single-finger map panning safely.
	view.show_tab("map")
	view.world_map.center_on("OMDB")
	await process_frame
	from_pos = view.world_map.project(float(source_airport["airport"]["lon"]), float(source_airport["airport"]["lat"]))
	var second_down: InputEventScreenTouch = InputEventScreenTouch.new()
	second_down.index = 1
	second_down.pressed = true
	second_down.position = from_pos + Vector2(24.0, 15.0)
	down.position = from_pos
	root.push_input(down, true)
	root.push_input(second_down, true)
	move_event.position = from_pos + Vector2(30.0, 19.0)
	move_event.relative = Vector2(30.0, 19.0)
	root.push_input(move_event, true)
	var second_up: InputEventScreenTouch = InputEventScreenTouch.new()
	second_up.index = 1
	second_up.pressed = false
	second_up.position = second_down.position
	root.push_input(second_up, true)
	up.position = move_event.position
	root.push_input(up, true)
	await process_frame
	if view.current_sheet == "planner" or view.world_map.gesture_captured or not view.world_map.pointers.is_empty():
		_fail("Pinch release triggered a route or left capture active")
		return
	# Close-zoom LOD: no minor airports in the overview; they emerge as
	# users zoom in, and name details are shown only at neighborhood scale.
	var map: Control = view.world_map
	var small_airport: Dictionary = view.game.airport("ESSP")
	map.focused_airport = ""
	map.camera_lon = float(small_airport["lon"])
	map.camera_lat = float(small_airport["lat"])
	map.zoom = 9.0
	await process_frame
	var visible_small: bool = false
	for candidate in map.candidate_airports():
		if candidate["code"] == "ESSP":
			visible_small = true
	if visible_small or map.airport_min_rank() <= 1:
		_fail("Minor airports must not clutter overview zoom")
		return
	map.zoom = 20.0
	# A selected minor airport must always be visible even when an
	# adjacent regional field wins automatic decluttering.
	map.focused_airport = "ESSP"
	await process_frame
	visible_small = false
	for candidate in map.candidate_airports():
		if candidate["code"] == "ESSP":
			visible_small = true
	if not visible_small or map.airport_min_rank() != 1:
		_fail("Minor airport does not appear at close zoom")
		return
	map.zoom = 42.0
	map.focused_airport = "ESSP"
	if not map.airport_label_text(small_airport).contains("Norrköping"):
		_fail("Close zoom does not reveal real small-airport name")
		return
	map.zoom = 9.0
	for iteration in range(10):
		map.change_zoom(1.27)
	if map.zoom < 60.0 or map.zoom > map.MAX_ZOOM:
		_fail("Zoom-in button does not reach the intended close-up range")
		return
	for iteration in range(12):
		map.change_zoom(0.79)
	if map.zoom >= 7.0:
		_fail("Zoom-out cannot return to regional view")
		return
	map.focused_airport = "ESSP"
	map.zoom = 9.0
	visible_small = false
	for candidate in map.candidate_airports():
		if candidate["code"] == "ESSP":
			visible_small = true
	if not visible_small:
		_fail("A searched small airport must remain focused at regional zoom")
		return
	# V1.0 must reflect actual economics rather than a tenfold forecasting bug.
	var model: Dictionary = view.game.initial_plane("ESSA", "ESSP")
	if model.is_empty():
		_fail("No short-haul aircraft available for realistic flight simulation")
		return
	var route_id: String = view.game.route_key("ESSA", "ESSP")
	var synthetic: Dictionary = {"id":route_id,"from":"ESSA","to":"ESSP",
		"plane":str(model["id"]),"fare":1.25,"progress":0.40,"direction":0}
	view.game.routes.append(synthetic)
	var forecast: Dictionary = view.game.projected(synthetic)
	if forecast.is_empty():
		_fail("Network forecast unavailable")
		return
	var forecast_passengers: float = minf(float(forecast["seats"]), maxf(0.0, float(forecast["demand"])))
	if absf(float(forecast["pax"]) - forecast_passengers) > 0.02:
		_fail("Forecast passenger count differs from actual flight passenger basis")
		return
	var report: Dictionary = view.game.network_snapshot()
	if int(report["routes"]) != 1 or int(report["next_seconds"]) <= 0 or str(report["next_airport"]) != "ESSP":
		_fail("Live operations snapshot did not identify the next arrival")
		return
	if absf(float(report["net"]) - float(forecast["net"])) > 0.02:
		_fail("Operations dashboard does not reflect actual projected route net")
		return
	view.world_map.animate_new_route(route_id)
	if view.world_map.reveal_progress >= 1.0 or view.world_map.reveal_route_id != route_id:
		_fail("New airline route did not start its reveal animation")
		return
	view.world_map._process(0.2)
	if view.world_map.reveal_progress <= 0.0:
		_fail("New airline route animation is not advancing")
		return
	if not view.flight_layer.has_method("draw_flight_trail") or not view.flight_layer.has_method("point_on_route"):
		_fail("Aircraft contrail animation missing")
		return
	view.show_tab("routes")
	await process_frame
	var operational_text: String = ""
	for candidate in view.content_body.find_children("*", "Label", true, false):
		if candidate is Label:
			operational_text += candidate.text + " "
	if not operational_text.contains("MINA LINJER") or operational_text.contains("FLYGOPERATIVT"):
		_fail("Routes screen must show playable lines instead of a verbose operations report")
		return
	var has_route_action: bool = false
	for route_control in view.content_body.find_children("*", "Button", true, false):
		if (route_control as Button).text.contains("ESSA") and (route_control as Button).text.contains("ESSP"):
			has_route_action = true
	if not has_route_action:
		_fail("Routes tab must allow direct selection of the player's active line")
		return
	# Cockpit V1.1: actual layout and both map-first actions must function,
	# including continuing to show the player's flying plane.
	view.show_tab("map")
	await process_frame
	var header_height: float = view.hud.get_global_rect().end.y
	if header_height >= 135.0:
		_fail("Cockpit dashboard still blocks too much of the map (end_y: %.1f)" % header_height)
		return
	if view.route_mode_button.get_parent() == view.zoom_buttons:
		_fail("Create-line game action is still buried among zoom controls")
		return
	if view.route_mode_button.get_global_rect().position.y < view.size.y - 220.0:
		_fail("Primary game action does not float near the flight dock")
		return
	if view.follow_button == null or view.follow_button.disabled:
		_fail("Flight-follow action not enabled with an active route")
		return
	var follow_id: String = view.game.route_key("ESSA", "ESSP")
	view.follow_button.pressed.emit()
	await process_frame
	if view.world_map.follow_route_id != follow_id:
		_fail("Follow flight button did not activate tracking")
		return
	view.world_map._process(0.10)
	var follow_report: Dictionary = view.game.network_snapshot()
	if str(follow_report.get("next_route_id", "")) != follow_id:
		_fail("Flight-follow route does not agree with live next-arrival report")
		return
	view.world_map.handle_press(Vector2(185, 305))
	if view.world_map.follow_route_id != "":
		_fail("Touching the map failed to stop automatic flight tracking")
		return
	view.world_map.reset_gesture()
	if view.route_mode_button.text != "DRA NY LINJE":
		_fail("Primary action failed to reset after leaving route mode")
		return
	_click(view.route_mode_button.get_global_rect().get_center())
	await process_frame
	if not view.route_mode or not view.world_map.route_draw_enabled:
		_fail("Touching floating route button does not enable route planning")
		return
	view.route_mode_button.button_pressed = false
	await process_frame
	if view.route_mode:
		_fail("Toggling route action off did not return to map navigation")
		return
	if view.game.routes.size() != 1:
		_fail("Cockpit redesign unexpectedly changed route model")
		return
	# V1.2: airport tap must show one-click terminal upgrade and the
	# correct aircraft picker for each connected line.
	view.game.owned["ESSA"] = true
	view.game.owned["ESSP"] = true
	view.game.cash = 9999.0
	view.game.terminals["ESSA"] = 1
	view.show_airport("ESSA")
	await process_frame
	if view.current_sheet != "airport":
		_fail("Tap on airport must open the simplified airport sheet")
		return
	var upgrade_action: Button = null
	var connected_action: Button = null
	for node in view.sheet_body.find_children("*", "Button", true, false):
		if node is Button:
			if node.text.contains("UPPGRADERA FLYGPLATS"):
				upgrade_action = node
			if node.text.contains("ESSA") and node.text.contains("ESSP"):
				connected_action = node
	if upgrade_action == null or connected_action == null:
		_fail("Airport sheet must display terminal upgrade and connected flight")
		return
	var expected_upgrade_price: float = view.game.terminal_upgrade_price("ESSA")
	var previous_cash: float = view.game.cash
	upgrade_action.pressed.emit()
	await process_frame
	if int(view.game.terminals["ESSA"]) != 2 or absf(previous_cash - view.game.cash - expected_upgrade_price) > 0.1:
		_fail("Airport terminal upgrade charged incorrectly or failed")
		return
	view.show_airport("ESSA")
	await process_frame
	for node in view.sheet_body.find_children("*", "Button", true, false):
		if node is Button and node.text.contains("ESSP"):
			node.pressed.emit()
			break
	await process_frame
	if view.current_sheet != "aircraft" or view.current_route != route_id:
		_fail("Airport's connected route did not open its aircraft picker")
		return
	var aircraft_actions: int = 0
	for node in view.sheet_body.find_children("*", "Button", true, false):
		if node is Button and node.text.contains("säten"):
			aircraft_actions += 1
	if aircraft_actions < 1 or aircraft_actions > 3:
		_fail("Aircraft picker should offer one to three relevant models, not the complete catalog")
		return
	# Multiple connected routes must not imply changing every plane at once.
	var second_model: Dictionary = view.game.initial_plane("ESSA", "ESGG")
	if second_model.is_empty():
		_fail("Missing alternate route aircraft for multi-route test")
		return
	var second_id: String = view.game.route_key("ESSA", "ESGG")
	view.game.routes.append({"id":second_id,"from":"ESSA","to":"ESGG",
		"plane":str(second_model["id"]),"fare":1.2,"progress":0.25,"direction":0})
	view.show_airport("ESSA")
	await process_frame
	if view.game.connected_routes("ESSA").size() != 2:
		_fail("Airport multi-route list does not show both linked flights")
		return
	var multi_route_buttons: int = 0
	for node in view.sheet_body.find_children("*", "Button", true, false):
		if node is Button and (node.text.contains("ESSP") or node.text.contains("ESGG")):
			multi_route_buttons += 1
	if multi_route_buttons != 2:
		_fail("Airport list must show exactly one action for each connected route")
		return
	# A normal map tap ON a line, far from any airport, must open aircraft
	# selection; a pan must never do so.
	view.show_tab("map")
	view.world_map.camera_lon = 16.3
	view.world_map.camera_lat = 59.1
	view.world_map.zoom = 36.0
	await process_frame
	var arc: PackedVector2Array = view.world_map.route_points("ESSA", "ESSP")
	var hit: Vector2 = Vector2(-1.0, -1.0)
	for possible in arc:
		if view.world_map.nearest_route(possible, 4.0) == route_id and view.world_map.nearest_airport(possible, 17.0) == "":
			hit = possible
			break
	if hit.x < 0.0:
		_fail("Route line offers no visible tap area away from airport markers")
		return
	view.world_map.handle_press(hit)
	view.world_map.handle_release(hit)
	await process_frame
	if view.current_sheet != "aircraft" or view.current_route != route_id:
		_fail("Touching drawn flight route did not open plane list")
		return
	var replacement: Dictionary = {}
	for p in view.game.catalog:
		if str(p["id"]) != str(synthetic["plane"]) and float(p["range"]) >= view.game.kilometers("ESSA","ESSP"):
			replacement = p
			break
	if replacement.is_empty():
		_fail("No compatible plane to test swap")
		return
	var cash_before_plane: float = view.game.cash
	var swap_cost: float = view.game.plane_change_price(route_id, str(replacement["id"]))
	var swap_error: String = view.game.change_plane(route_id, str(replacement["id"]))
	if swap_error != "" or str(synthetic["plane"]) != str(replacement["id"]):
		_fail("Changing selected plane did not update only requested route")
		return
	if str(view.game.get_route(second_id)["plane"]) != str(second_model["id"]) or absf(view.game.cash - (cash_before_plane - swap_cost)) > 0.1:
		_fail("Plane change affected another route or charged wrong amount")
		return
	# V1.4 live costs are previewed BEFORE the gesture is released.
	view.show_tab("map")
	view.game.cash = 5000.0
	var cost_quote: Dictionary = view.game.route_quote("ESSA", "ESMS")
	if not bool(cost_quote["ok"]) or float(cost_quote["price"]) <= 0.0:
		_fail("A real short-haul route should return a valid affordable quote")
		return
	if absf(float(cost_quote["price"]) - view.game.route_cost("ESSA", "ESMS")) > 0.01:
		_fail("Preview cost must match the actual route charge")
		return
	view._update_route_quote(cost_quote)
	await process_frame
	if not view.quote_card.visible or not view.quote_label.text.contains(view.game.money(float(cost_quote["price"]))):
		_fail("Route price HUD must show real price while dragging")
		return
	if view.quote_label.text.count("\n") != 1 or view.quote_label.text.contains("flygplats ") or view.quote_label.text.contains("PROGNOS"):
		_fail("Route HUD must stay compact and hide accounting detail during drag")
		return
	if not view.quote_label.text.contains("/ flyg"):
		_fail("Route preview must retain a useful one-line expected flight return")
		return
	view.game.cash = 0.0
	var poor_quote: Dictionary = view.game.route_quote("ESSA", "ESMS")
	view._update_route_quote(poor_quote)
	if bool(poor_quote["ok"]) or not view.quote_label.text.contains("Saknar"):
		_fail("Cannot-afford cost must appear before touch release")
		return
	# Invalid routes must have actionable feedback, not a fabricated cost.
	var too_long: Dictionary = view.game.route_quote("ESSA", "RJTT")
	if bool(too_long["ok"]) or str(too_long["reason"]) == "":
		_fail("Invalid route must carry a reason")
		return
	view._update_route_quote({})
	if view.quote_card.visible:
		_fail("Route cost tooltip must disappear when dragging ends")
		return
	view.game.cash = 9999.0
	view.world_map.camera_lon = float(view.game.airport("ESSA")["lon"])
	view.world_map.camera_lat = float(view.game.airport("ESSA")["lat"])
	view.world_map.zoom = 19.0
	await process_frame
	var from_point: Vector2 = view.world_map.project(float(view.game.airport("ESSA")["lon"]), float(view.game.airport("ESSA")["lat"]))
	var dest_point: Vector2 = view.world_map.project(float(view.game.airport("EKCH")["lon"]), float(view.game.airport("EKCH")["lat"]))
	view.world_map.handle_press(from_point)
	view.world_map._process(0.14)
	view.world_map._process(0.14)
	view.world_map.handle_motion(dest_point)
	await process_frame
	if not view.quote_card.visible or not view.quote_label.text.contains("ESSA → EKCH"):
		_fail("Moving finger from one airport to another did not preview its cost")
		return
	view.world_map.reset_gesture()
	await process_frame
	if view.quote_card.visible:
		_fail("Canceled drag left stale quote overlay")
		return

	# Both orientations use one real responsive map, not a rotated/scaled copy.
	root.size = Vector2i(844, 390)
	await process_frame
	await process_frame
	view._refresh_layout()
	if view.size.x <= view.size.y:
		_fail("Real Godot viewport remained in portrait proportions")
		return
	if view.viewport_layout_mode != "landscape" or view.clock_dock.anchor_top != 0.0:
		_fail("Landscape HUD did not move flight controls away from bottom map")
		return
	if view.nav_bar.anchor_right != 0.0 or view.sheet.anchor_left != 1.0:
		_fail("Landscape navigation/modal geometry invalid")
		return
	var wide: Rect2 = Rect2(Vector2.ZERO, view.size)
	for widget in [view.cockpit_background, view.clock_dock, view.nav_bar, view.route_mode_button, view.follow_button]:
		var bounds: Rect2 = widget.get_global_rect()
		if bounds.position.x < -1.0 or bounds.position.y < -1.0 or bounds.end.x > wide.end.x + 1.0 or bounds.end.y > wide.end.y + 1.0:
			_fail("Landscape gameplay control outside real screen: " + widget.name)
			return
	if view.cockpit_background.get_global_rect().intersects(view.clock_dock.get_global_rect()):
		_fail("Landscape header and flight dock overlap")
		return
	if view.route_mode_button.get_global_rect().intersects(view.nav_bar.get_global_rect()) or view.follow_button.get_global_rect().intersects(view.nav_bar.get_global_rect()):
		_fail("Landscape route actions overlap navigation")
		return
	if view.sheet.get_global_rect().intersects(view.nav_bar.get_global_rect()):
		_fail("Landscape route information panel overlaps the bottom navigation")
		return
	if view.zoom_buttons.columns != 4:
		_fail("Zoom/FIR map controls still use a tall portrait column in landscape")
		return
	for compact_size in [Vector2i(740, 320),Vector2i(667, 280)]:
		root.size = compact_size
		await process_frame
		await process_frame
		view._refresh_layout()
		var area: Rect2 = Rect2(Vector2.ZERO,view.size)
		for widget in [view.cockpit_background,view.clock_dock,view.nav_bar,view.zoom_buttons,view.route_mode_button,view.follow_button]:
			var bounds: Rect2 = widget.get_global_rect()
			if bounds.position.x < -1.0 or bounds.position.y < -1.0 or bounds.end.x > area.end.x + 1.0 or bounds.end.y > area.end.y + 1.0:
				_fail("Short landscape control outside screen: "+widget.name+" at "+str(compact_size))
				return
		view._update_route_quote(cost_quote)
		var tip: Rect2 = view.quote_card.get_global_rect()
		if not view.quote_card.visible or view.quote_label.text.count("\n") != 1:
			_fail("Landscape cost preview must use readable two-line compact presentation")
			return
		if tip.intersects(view.nav_bar.get_global_rect()) or tip.intersects(view.zoom_buttons.get_global_rect()) or tip.intersects(view.route_mode_button.get_global_rect()) or tip.intersects(view.follow_button.get_global_rect()):
			_fail("Landscape route cost preview obscures other game controls")
			return
		view._update_route_quote({})
	root.size = Vector2i(390, 844)
	await process_frame
	await process_frame
	view._refresh_layout()
	if view.viewport_layout_mode != "portrait" or view.clock_dock.anchor_top != 1.0:
		_fail("Portrait controls failed to restore")
		return
	view.refresh_hud()
	if view.clock_label.text.begins_with("DAG"):
		_fail("Internal event time must not appear as a visible day progression")
		return
	# Cost model: an affordable realistic starting flight, no double-charge for
	# an already opened market and a total equal to its billed components.
	view.game.cash = 650.0
	var quote_first: Dictionary = view.game.route_quote("WSSS","WMKK")
	if not bool(quote_first["ok"]):
		_fail("Starter cash does not allow a reasonable Singapore-KL route")
		return
	if not quote_first.has("estimated_net") or not quote_first.has("estimated_pax"):
		_fail("Route quote must explain expected profit and passenger demand")
		return
	var breakdown: Dictionary = view.game.route_cost_breakdown("WSSS","WMKK")
	var calculated: float = float(breakdown["aircraft"])+float(breakdown["airport"])+float(breakdown["route"])
	if absf(float(breakdown["total"]) - calculated) > 0.11 or absf(float(quote_first["price"]) - calculated) > 0.11:
		_fail("Three displayed route cost components do not add to billed quote")
		return
	var fee_once: float = view.game.airport_access_cost("WMKK")
	if fee_once <= 0.0:
		_fail("New airport is missing one-time market opening fee")
		return
	view.game.owned["WMKK"] = true
	if view.game.airport_access_cost("WMKK") != 0.0 or absf(view.game.route_cost("WSSS","WMKK") - float(quote_first["price"]) + fee_once) > 0.11:
		_fail("Reusing an already owned airport incorrectly charges its access fee")
		return
	view.game.owned.erase("WMKK")
	var cash_before_purchase: float = view.game.cash
	var new_route_error: String = view.game.create_route("WSSS","WMKK")
	if new_route_error != "" or absf(view.game.cash - (cash_before_purchase - float(quote_first["price"]))) > 0.11:
		_fail("Route charged a price different from preview")
		return
	if not view.game.owned.has("WMKK"):
		_fail("Purchased airport not recorded as an owned market")
		return
	# The player can compare demand, margins and aircraft options without
	# spending cash or silently changing a route during market analysis.
	var managed_id: String = view.game.route_key("WSSS", "WMKK")
	var managed_route: Dictionary = view.game.get_route(managed_id)
	var base_fare: float = float(managed_route["fare"])
	var base_cash: float = view.game.cash
	var base_forecast: Dictionary = view.game.projected(managed_route)
	var advice: Dictionary = view.game.fare_recommendation(managed_id)
	if advice.is_empty() or float(advice.get("fare", 0.0)) < 0.55 or float(advice.get("gain", -1.0)) < -0.001:
		_fail("Fare advisor failed to return a legal, non-worse modeled offer")
		return
	if float(advice["net"]) + 0.01 < float(base_forecast["net"]) or float(managed_route["fare"]) != base_fare or view.game.cash != base_cash:
		_fail("Fare advisor changed live economy or worsened flight forecast")
		return
	if not view.game.fare_recommendation("NO-ROUTE").is_empty():
		_fail("Fare advisor accepted an unknown route")
		return
	view.show_route(managed_id)
	var fare_sliders: Array[Node] = view.sheet.find_children("*", "HSlider", true, false)
	if fare_sliders.is_empty():
		_fail("Route sheet does not expose playable ticket price control")
		return
	var fare_slider: HSlider = fare_sliders[0] as HSlider
	fare_slider.value = minf(fare_slider.max_value, fare_slider.value + 0.5)
	if absf(float(managed_route["fare"]) - view.game.rounded(fare_slider.value)) > 0.001:
		_fail("Ticket price slider did not update the route")
		return
	var adjusted: Dictionary = view.game.projected(managed_route)
	var forecast_seen: bool = false
	for entry in view.sheet.find_children("*", "Label", true, false):
		var msg: String = str((entry as Label).text)
		if msg.contains("Prognos:") and msg.contains(view.game.money(float(adjusted["net"]))):
			forecast_seen = true
	if not forecast_seen:
		_fail("Ticket slider did not refresh live profit forecast on the visible screen")
		return
	view.show_plane_picker(managed_id)
	var compact_aircraft: int = 0
	for entry in view.sheet_body.find_children("*", "Button", true, false):
		if (entry as Button).text.contains("platser"):
			compact_aircraft += 1
	if compact_aircraft < 1 or compact_aircraft > 3:
		_fail("Aircraft picker must show only a few relevant purchase choices")
		return
	# iPhone UX: the user only sees aircraft they actually operate.
	view.show_tab("fleet")
	await process_frame
	var owned_aircraft_buttons: int = 0
	for entry in view.content_body.find_children("*", "Button", true, false):
		if (entry as Button).text.contains("→"):
			owned_aircraft_buttons += 1
	if owned_aircraft_buttons != view.game.routes.size():
		_fail("Fleet tab must show exactly the user's owned aircraft, not the catalog")
		return
	if view.content_body.find_children("*", "Label", true, false).size() > 10:
		_fail("Fleet is still overloaded with aircraft specification labels")
		return
	var away: InputEventMouseButton = InputEventMouseButton.new()
	away.button_index = MOUSE_BUTTON_LEFT
	away.pressed = true
	away.position = Vector2(330, 260)
	view._input(away)
	await process_frame
	if view.active_tab != "map" or view.content_view.visible:
		_fail("Tapping map above fleet panel must return immediately to map")
		return
	view.show_plane_picker(managed_id)
	await process_frame
	if not view.sheet.visible or not view.shade.visible:
		_fail("Airplane picker needs visible but non-blocking modal shell")
		return
	if view.shade.color.a > 0.20:
		_fail("Aircraft panel dims the whole game excessively")
		return
	for entry in view.sheet_body.find_children("*", "Button", true, false):
		var option: Button = entry as Button
		if option.disabled and option.text.contains("platser"):
			var readable: Color = option.get_theme_color("font_disabled_color")
			if readable.r > 0.45 and readable.g > 0.45 and readable.b > 0.45:
				_fail("Unavailable aircraft buttons still render near-white text on gray")
				return
	away.position = Vector2(330, 260)
	view._input(away)
	await process_frame
	if view.current_sheet != "" or view.sheet.visible or view.shade.visible or not view.map_gesture_active():
		_fail("Tapping the visible map did not close modal and release gestures")
		return
	# Repeat through the real viewport path for an iPhone touch (not just
	# a direct method call), and reject map drags leaking through the popup.
	view.show_plane_picker(managed_id)
	await process_frame
	var finger_down: InputEventScreenTouch = InputEventScreenTouch.new()
	finger_down.index = 0
	finger_down.pressed = true
	finger_down.position = Vector2(330, 260)
	root.push_input(finger_down, true)
	await process_frame
	if view.current_sheet != "" or view.sheet.visible:
		_fail("Actual screen touch outside the sheet did not close the panel")
		return
	var finger_up: InputEventScreenTouch = InputEventScreenTouch.new()
	finger_up.index = 0
	finger_up.pressed = false
	finger_up.position = finger_down.position
	root.push_input(finger_up, true)
	await process_frame
	if view.world_map.gesture_captured or not view.map_gesture_active():
		_fail("Outside-tap dismissal accidentally captured the map gesture")
		return
	print("AEROROUTE GUI SMOKE PASSED: compact pricing and fleet, outside-map dismissal, readable aircraft options, portrait/landscape")
	quit(0)
