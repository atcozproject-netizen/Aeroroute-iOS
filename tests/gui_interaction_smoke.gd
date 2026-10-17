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
	# Finger-drag regression: use the same InputEventScreenTouch / InputEventScreenDrag
	# events the iPhone sends to Godot, between actual visible airport markers.
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
		_fail("Could not find two separated, tappable airports for touch drag")
		return
	var from_pos: Vector2 = source_airport["position"]
	var to_pos: Vector2 = destination_airport["position"]
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
	if view.current_sheet != "planner":
		_fail("Dragging between two actual airports did not open route planner")
		return
	if view.world_map.gesture_captured or not view.world_map.pointers.is_empty():
		_fail("A completed drag left the iPhone gesture captured")
		return
	print("AEROROUTE GUI SMOKE PASSED: FIR, two-tap planning, native touch drag and clean release")
	quit(0)
