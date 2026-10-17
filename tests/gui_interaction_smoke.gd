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
	print("AEROROUTE GUI SMOKE PASSED: touch input, search, positive and negative landing animation")
	quit(0)
