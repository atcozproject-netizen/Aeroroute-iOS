extends Control
## Native Godot CanvasItem world map: detailed vector coastlines, smooth touch controls.

signal airport_tapped(code: String)
signal route_drafted(start_code: String, end_code: String)

const SEA_TOP = Color("345967")
const SEA_BOTTOM = Color("4d7e89")
const LAND_FILL = Color("f5f0df")
const LAND_EDGE = Color("cdd8c9")
const NODE_FREE = Color("234e5c")
const NODE_OWNED = Color("f1ae77")
const ROUTE_LINE = Color("efbb8a")
const ROUTE_GLOW = Color(1.0, 0.83, 0.64, 0.29)
const OWNED_HALO = Color(0.98, 0.75, 0.52, 0.21)
const LAND_TEXTURE: Texture2D = preload("res://data/world_land.png")

var game
var camera_lon: float = 13.0
var camera_lat: float = 52.0
var zoom: float = 4.4
var route_origin: String = ""
var pointer_start: Vector2 = Vector2.ZERO
var pointer_last: Vector2 = Vector2.ZERO
var pointer_down: bool = false
var pointer_from: String = ""
var pointer_moved: bool = false
var drag_threshold: float = 10.0
var temporary_line_end: Vector2 = Vector2.ZERO
var pointers: Dictionary = {}
var pinch_length: float = 0.0
var pinch_center: Vector2 = Vector2.ZERO
var pinch_active: bool = false
var touch_input_seen: bool = false
var touch_last_ms: int = -1000000
var plane_layer: Control
var land_bounds: Array = []
var land_lods: Array = []
var land_valid: Array = []
var map_airports: Array = []
var visible_pin_codes: Dictionary = {}
var map_revision: int = 0

# The iPhone must not process or label every airport at world scale.
# A static world-map LOD is computed only once, not on every pan frame.
const LOD_THRESHOLDS = [0.8, 0.55, 0.36, 0.12]
const MIN_ZOOM: float = 2.7
const MAX_ZOOM: float = 16.0
const PAN_SENSITIVITY: float = 0.70
const MAX_PAN_STEP_PX: float = 36.0


func configure(source_game) -> void:
	game = source_game
	map_airports = game.airports.duplicate()
	map_airports.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["rank"]) > int(b["rank"])
	)
	# Land texture is pre-rendered so no runtime coastline triangulation is needed.
	queue_redraw()

func simplify_ring(ring: Array, tolerance: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	if ring.is_empty():
		return result
	var prev := Vector2(float(ring[0][0]), float(ring[0][1]))
	result.append(prev)
	var min_sq: float = tolerance * tolerance
	for index in range(1, ring.size() - 1):
		var coord := Vector2(float(ring[index][0]), float(ring[index][1]))
		if prev.distance_squared_to(coord) >= min_sq:
			result.append(coord)
			prev = coord
	if ring.size() > 1:
		var end_coord := Vector2(float(ring[-1][0]), float(ring[-1][1]))
		if result[-1] != end_coord and end_coord != result[0]:
			result.append(end_coord)
	# Avoid duplicate end point on explicitly closed rings; ear clipping can fail.
	if result.size() > 2 and result[0].distance_squared_to(result[-1]) < 0.000001:
		result.remove_at(result.size() - 1)
	return result

func land_lod_index() -> int:
	if zoom < 2.7:
		return 0
	if zoom < 6.0:
		return 1
	if zoom < 11.5:
		return 2
	return 3

func airport_min_rank() -> int:
	if zoom < 1.55:
		return 7
	if zoom < 2.5:
		return 6
	if zoom < 4.2:
		return 5
	if zoom < 6.4:
		return 4
	if zoom < 9.0:
		return 3
	if zoom < 12.5:
		return 2
	return 1

func candidate_airports() -> Array:
	var candidates: Array = []
	var minimum_rank: int = airport_min_rank()
	for airport in map_airports:
		var code: String = str(airport["icao"])
		var owned: bool = game.owned.has(code)
		if not owned and int(airport["rank"]) < minimum_rank:
			continue
		var pos: Vector2 = project(float(airport["lon"]), float(airport["lat"]))
		if pos.x < -30.0 or pos.x > size.x + 30.0 or pos.y < -30.0 or pos.y > size.y + 30.0:
			continue
		candidates.append({"code": code, "position": pos, "airport": airport, "owned": owned})
	# Player-owned airports are always visible, even in dense metro areas.
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if bool(a["owned"]) != bool(b["owned"]):
			return bool(a["owned"])
		return int(a["airport"]["rank"]) > int(b["airport"]["rank"])
	)
	var result: Array = []
	var spacing: float = 28.0 if zoom < 6.5 else 23.0 if zoom < 11.0 else 15.0
	var spacing_sq: float = spacing * spacing
	for item in candidates:
		var collide: bool = false
		if not bool(item["owned"]):
			for chosen in result:
				if item["position"].distance_squared_to(chosen["position"]) < spacing_sq:
					collide = true
					break
		if not collide:
			result.append(item)
	return result

func center_on(code: String) -> void:
	if game == null:
		return
	var a: Dictionary = game.airport(code)
	if a.is_empty():
		return
	camera_lon = float(a["lon"])
	camera_lat = clampf(float(a["lat"]), -72.0, 76.0)
	zoom = 9.0
	queue_redraw()

func whole_world() -> void:
	camera_lon = 12.0
	camera_lat = 38.0
	zoom = MIN_ZOOM
	queue_redraw()

func projection_scale() -> float:
	return size.x * zoom / 360.0

func project(lon: float, lat: float) -> Vector2:
	var dx: float = fposmod(lon - camera_lon + 180.0, 360.0) - 180.0
	return Vector2(size.x * 0.5 + dx * projection_scale(), size.y * 0.5 - (lat - camera_lat) * projection_scale() * 1.17)

func world_project_raw(lon: float, lat: float, shift: float = 0.0) -> Vector2:
	return Vector2(size.x * 0.5 + (lon - camera_lon + shift) * projection_scale(), size.y * 0.5 - (lat - camera_lat) * projection_scale() * 1.17)

func _draw() -> void:
	var gradient_sections: int = 12
	for i in range(gradient_sections):
		var t: float = float(i) / float(gradient_sections - 1)
		draw_rect(Rect2(0.0, size.y * t, size.x, size.y / float(gradient_sections) + 1.0), SEA_TOP.lerp(SEA_BOTTOM, t), true)
	if game == null:
		return
	var sc: float = projection_scale()
	# Play-oriented cartography: no Google-Earth-style coordinate grid.
	# A quiet navigation sheen gives depth without additional textures or draw-heavy shaders.
	var sheen: PackedVector2Array = PackedVector2Array()
	for step in range(13):
		var x: float = size.x * float(step) / 12.0
		sheen.append(Vector2(x, size.y * 0.72 + sin(x / maxf(size.x, 1.0) * TAU) * 23.0))
	draw_polyline(sheen, Color(1.0, 1.0, 1.0, 0.045), 1.0, true)

	# Draw each visible section of a pre-rendered land texture. With this
	# technique the full continents draw correctly regardless of winding,
	# self-intersections or antimeridian crossings in the source polygons.
	# Max three GPU draw calls, rather than hundreds of polygons per frame.
	draw_land_texture(sc)

	for r in game.routes:
		var arc: PackedVector2Array = route_points(str(r["from"]), str(r["to"]))
		if arc.size() >= 2:
			draw_polyline(arc, ROUTE_GLOW, 5.0, true)
			draw_polyline(arc, ROUTE_LINE, 1.9, true)

	# Level-of-detail + collision avoidance. No overlap jungle on iPhone.
	var placed_labels: Array[Rect2] = []
	visible_pin_codes.clear()
	for item in candidate_airports():
		var code: String = str(item["code"])
		visible_pin_codes[code] = true
		var p: Vector2 = item["position"]
		var owned: bool = bool(item["owned"])
		var rank: int = int(item["airport"]["rank"])
		var radius: float = (4.1 if zoom < 8.0 else 4.6) + (1.2 if owned else 0.0)
		if owned:
			draw_circle(p, radius + 6.0, OWNED_HALO)
		elif rank >= 7 and zoom >= 5.0:
			draw_circle(p, radius + 3.0, Color(1.0, 1.0, 1.0, 0.14))
		draw_circle(p, radius + 1.75, Color(1.0, 0.99, 0.94, .96))
		draw_circle(p, radius, NODE_OWNED if owned else NODE_FREE)
		if owned and zoom > 7.0:
			draw_circle(p, 1.5, Color("fff0cf"))
		var show_label: bool = owned or (zoom >= 4.0 and rank >= 7) or (zoom >= 7.5 and rank >= 5) or (zoom >= 11.0 and rank >= 3)
		if not show_label or p.y < 142.0 or p.y > size.y - 133.0:
			continue
		var tx: Vector2 = p + Vector2(8.0, -4.5)
		var label_bounds: Rect2 = Rect2(tx.x - 3.0, tx.y - 12.0, 40.0, 18.0)
		if label_bounds.end.x > size.x - 5.0:
			continue
		var can_draw: bool = true
		for previous in placed_labels:
			if previous.intersects(label_bounds):
				can_draw = false
				break
		if not can_draw:
			continue
		placed_labels.append(label_bounds)
		draw_string(ThemeDB.fallback_font, tx, code, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("213c48"))

	var origin: String = pointer_from if pointer_down and pointer_from != "" else route_origin
	if origin != "" and game.airports_by_code.has(origin):
		var start: Dictionary = game.airport(origin)
		var a_point: Vector2 = project(float(start["lon"]), float(start["lat"]))
		if pointer_down and pointer_moved:
			draw_line(a_point, temporary_line_end, Color(1.0, 0.94, 0.78, 0.19), 8.0, true)
			draw_line(a_point, temporary_line_end, Color("ffd09b"), 2.8, true)
			draw_circle(temporary_line_end, 6.0, Color("ffd09b"))
		elif route_origin != "":
			draw_arc(a_point, 14.0, 0.0, TAU, 30, Color("ffe6b6"), 2.7, true)
		draw_arc(a_point, 19.0, 0.0, TAU, 30, Color(1.0, 0.87, 0.62, 0.29), 3.0, true)

func draw_land_texture(sc: float) -> void:
	if LAND_TEXTURE == null:
		return
	var tex_size: Vector2 = LAND_TEXTURE.get_size()
	var world_w: float = 360.0 * sc
	var world_h: float = 180.0 * sc * 1.17
	var top: float = size.y * 0.5 - (90.0 - camera_lat) * sc * 1.17
	var visible_top: float = maxf(0.0, top)
	var visible_bottom: float = minf(size.y, top + world_h)
	if visible_bottom <= visible_top or world_w < 1.0:
		return
	var src_y: float = (visible_top - top) / world_h * tex_size.y
	var src_h: float = (visible_bottom - visible_top) / world_h * tex_size.y
	for wrap in [-360.0, 0.0, 360.0]:
		var left: float = size.x * 0.5 + (-180.0 + wrap - camera_lon) * sc
		var view_left: float = maxf(0.0, left)
		var view_right: float = minf(size.x, left + world_w)
		if view_right <= view_left:
			continue
		var src_x: float = (view_left - left) / world_w * tex_size.x
		var src_w: float = (view_right - view_left) / world_w * tex_size.x
		draw_texture_rect_region(LAND_TEXTURE, Rect2(view_left, visible_top, view_right-view_left, visible_bottom-visible_top), Rect2(src_x, src_y, src_w, src_h), Color("e1dfc9"), false, true)


func route_points(a_code: String, b_code: String) -> PackedVector2Array:
	var a: Dictionary = game.airport(a_code)
	var b: Dictionary = game.airport(b_code)
	var result := PackedVector2Array()
	if a.is_empty() or b.is_empty():
		return result
	var aa: Vector2 = project(float(a["lon"]), float(a["lat"]))
	var bb: Vector2 = project(float(b["lon"]), float(b["lat"]))
	var span: Vector2 = bb - aa
	var amount: float = clampf(span.length() * 0.085, 7.0, 36.0)
	var control: Vector2 = (aa + bb) / 2.0 + Vector2(-span.y, span.x).normalized() * amount
	for i in range(25):
		var t: float = float(i) / 24.0
		result.append(aa * pow(1.0 - t, 2) + 2.0 * (1.0 - t) * t * control + bb * t * t)
	return result

func nearest_airport(pos: Vector2, radius: float = 31.0) -> String:
	if game == null:
		return ""
	var nearest: String = ""
	var best: float = radius
	for item in candidate_airports():
		var dist: float = item["position"].distance_to(pos)
		if dist < best:
			nearest = str(item["code"])
			best = dist
	return nearest

func change_zoom(factor: float, around: Vector2 = Vector2.ZERO) -> void:
	var pivot: Vector2 = around if around != Vector2.ZERO else size * 0.5
	var before: float = projection_scale()
	var target_lon: float = camera_lon + (pivot.x - size.x * 0.5) / before
	var target_lat: float = camera_lat - (pivot.y - size.y * 0.5) / (before * 1.17)
	zoom = clampf(zoom * clampf(factor, 0.88, 1.12), MIN_ZOOM, MAX_ZOOM)
	var after: float = projection_scale()
	camera_lon = fposmod(target_lon - (pivot.x - size.x * 0.5) / after + 180.0, 360.0) - 180.0
	camera_lat = clampf(target_lat + (pivot.y - size.y * 0.5) / (after * 1.17), -50.0, 74.0)
	queue_redraw()

func pan(delta_pixels: Vector2) -> void:
	# Use a bounded, damped step: one anomalous Safari touch event must not move the map across oceans.
	var safe_step: Vector2 = delta_pixels.limit_length(MAX_PAN_STEP_PX) * PAN_SENSITIVITY
	camera_lon = fposmod(camera_lon - safe_step.x / projection_scale() + 180.0, 360.0) - 180.0
	camera_lat = clampf(camera_lat + safe_step.y / (projection_scale() * 1.17), -50.0, 74.0)
	queue_redraw()

func handle_press(pos: Vector2) -> void:
	pointer_down = true
	pointer_start = pos
	pointer_last = pos
	pointer_from = nearest_airport(pos, 32.0)
	pointer_moved = false
	temporary_line_end = pos

func handle_motion(pos: Vector2) -> void:
	if not pointer_down:
		return
	if pointer_start.distance_to(pos) > drag_threshold:
		pointer_moved = true
	if pointer_moved and pointer_from == "" and route_origin == "":
		pan(pos - pointer_last)
	else:
		temporary_line_end = pos
		queue_redraw()
	pointer_last = pos

func handle_release(pos: Vector2) -> void:
	if not pointer_down:
		return
	pointer_down = false
	var destination: String = nearest_airport(pos, 33.0)
	if pointer_from != "" and pointer_moved:
		if destination != "" and destination != pointer_from:
			route_drafted.emit(pointer_from, destination)
		else:
			# Preserve the source; user can tap the target instead of precisely dropping on a tiny point.
			airport_tapped.emit(pointer_from)
	elif route_origin != "" and destination != "" and destination != route_origin:
		route_drafted.emit(route_origin, destination)
	elif not pointer_moved and destination != "":
		airport_tapped.emit(destination)
	pointer_from = ""
	queue_redraw()

var gesture_captured: bool = false
var last_touch_event_ms: int = 0
var touch_was_pinch: bool = false

func reset_gesture() -> void:
	pointers.clear()
	touch_was_pinch = false
	pointer_down = false
	pointer_from = ""
	pointer_moved = false
	pinch_active = false
	pinch_length = 0.0
	gesture_captured = false
	queue_redraw()

func _process(_delta: float) -> void:
	if gesture_captured and Time.get_ticks_msec() - last_touch_event_ms > 8500:
		reset_gesture()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		reset_gesture()

func _can_capture_touch(pos: Vector2) -> bool:
	if game == null or not game.initialized:
		return false
	var node: Node = get_parent()
	if node != null and node.has_method("map_can_interact"):
		return bool(node.map_can_interact(pos))
	return true

func _input(event: InputEvent) -> void:
	if not (event is InputEventScreenTouch or event is InputEventScreenDrag):
		return
	if gesture_captured:
		var owner_node: Node = get_parent()
		if owner_node != null and owner_node.has_method("map_gesture_active"):
			if not bool(owner_node.map_gesture_active()):
				reset_gesture()
				return
	touch_input_seen = true
	touch_last_ms = Time.get_ticks_msec()
	last_touch_event_ms = touch_last_ms
	if event is InputEventScreenTouch:
		if event.pressed:
			if gesture_captured and pointers.has(event.index):
				reset_gesture()
			if not gesture_captured:
				if not _can_capture_touch(event.position):
					return
				reset_gesture()
				gesture_captured = true
			if pointers.size() > 0 and not _can_capture_touch(event.position):
				return
			pointers[event.index] = event.position
			if pointers.size() == 1:
				handle_press(event.position)
			else:
				pinch_active = true
				touch_was_pinch = true
				pointer_down = false
				pointer_from = ""
				var positions: Array = pointers.values()
				pinch_length = positions[0].distance_to(positions[1])
				pinch_center = (positions[0] + positions[1]) * 0.5
		else:
			if not gesture_captured or not pointers.has(event.index):
				return
			var last_finger: bool = pointers.size() == 1
			pointers.erase(event.index)
			if last_finger and not pinch_active and not touch_was_pinch:
				handle_release(event.position)
			if pointers.is_empty():
				reset_gesture()
			elif pointers.size() == 1:
				pinch_active = false
				pinch_length = 0.0
				var remaining: Vector2 = pointers.values()[0]
				handle_press(remaining)
				pointer_from = ""
				pointer_moved = true
	else:
		if not gesture_captured or not pointers.has(event.index):
			return
		pointers[event.index] = event.position
		if pointers.size() >= 2:
			var positions: Array = pointers.values()
			var center: Vector2 = (positions[0] + positions[1]) * 0.5
			var length_now: float = positions[0].distance_to(positions[1])
			if pinch_active and pinch_length > 10.0 and length_now > 10.0:
				pan(center - pinch_center)
				change_zoom(length_now / pinch_length, center)
			pinch_active = true
			touch_was_pinch = true
			pinch_length = length_now
			pinch_center = center
		else:
			handle_motion(event.position)
	get_viewport().set_input_as_handled()

func _gui_input(event: InputEvent) -> void:
	# Touch was processed by _input, and must never be handled again here.
	if event is InputEventMouseButton:
		if touch_input_seen and Time.get_ticks_msec() - touch_last_ms < 1900:
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				handle_press(event.position)
			else:
				handle_release(event.position)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			change_zoom(1.12, event.position)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			change_zoom(0.89, event.position)
	elif event is InputEventMouseMotion and pointer_down:
		if touch_input_seen and Time.get_ticks_msec() - touch_last_ms < 1900:
			return
		handle_motion(event.position)
