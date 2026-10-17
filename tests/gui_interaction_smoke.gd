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

	var search: LineEdit = view.start_search
	if search.get_global_rect().size.x < 20.0:
		_fail("Search box has no usable geometry")
		return
	_click(search.get_global_rect().get_center())
	await process_frame
	if not search.has_focus():
		_fail("Clicking the search field did not focus it")
		return
	search.text = "OMDB"
	search.text_changed.emit("OMDB")
	await process_frame
	var options: VBoxContainer = view.start_choices
	if options.get_child_count() < 1:
		_fail("Searching for OMDB returned no airport")
		return
	var first: Button = options.get_child(0) as Button
	if first == null or not first.text.begins_with("OMDB"):
		_fail("OMDB airport selection missing after search")
		return
	_click(first.get_global_rect().get_center())
	await process_frame
	if view.start_choice_code != "OMDB":
		_fail("Tapping OMDB airport option did not select it")
		return
	var begin_button: Button = null
	for candidate in view.start_overlay.find_children("*", "Button", true, false):
		if candidate is Button and candidate.text == "STARTA NYTT FLYGBOLAG":
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
			if a["code"] != b["code"] and a["position"].distance_to(b["position"]) >= 65.0:
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

	# Long-press for 0.42 sec explicitly arms route dragging.
	view.world_map.center_on("OMDB")
	await process_frame
	from_pos = view.world_map.project(float(source_airport["airport"]["lon"]), float(source_airport["airport"]["lat"]))
	to_pos = view.world_map.project(float(destination_airport["airport"]["lon"]), float(destination_airport["airport"]["lat"]))
	down.position = from_pos
	root.push_input(down, true)
	view.world_map._process(0.24)
	view.world_map._process(0.24)
	if view.world_map.gesture_kind != "route":
		_fail("Long press did not arm deliberate route creation")
		return
	move_event.position = to_pos
	move_event.relative = to_pos - from_pos
	root.push_input(move_event, true)
	up.position = to_pos
	root.push_input(up, true)
	await process_frame
	if view.current_sheet != "planner":
		_fail("Long-press plus drag did not open route planner")
		return
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
	if not operational_text.contains("FLYGOPERATIVT") or not operational_text.contains("Nästa landning"):
		_fail("Live network briefing is missing from routes screen")
		return
		print("AEROROUTE GUI SMOKE PASSED: commercial airports, crisp coastline tiles, no progression, living economics, flight trails and ops briefing")
	quit(0)
