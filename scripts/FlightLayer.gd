extends Control
## Separate inexpensive 30-FPS overlay: routes/coasts are not rebuilt every animation frame.

var game
var map_view
var accumulator: float = 0.0
var ambient_time: float = 0.0

func setup(model, world_map) -> void:
	game = model
	map_view = world_map
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	if game == null or not visible or game.routes.is_empty():
		return
	accumulator += delta
	ambient_time += delta
	if accumulator >= 0.042:
		accumulator = 0.0
		queue_redraw()

func _draw() -> void:
	if game == null or map_view == null:
		return
	# Active hubs breathe gently while planes fly. This is decorative only
	# and does not create input targets or additional route labels.
	var active_codes: Dictionary = {}
	for r in game.routes:
		active_codes[str(r["from"])] = true
		active_codes[str(r["to"])] = true
	var pulse: float = 0.5 + 0.5 * sin(ambient_time * 2.25)
	for code in active_codes:
		var airport: Dictionary = game.airport(str(code))
		if airport.is_empty():
			continue
		var hub_pos: Vector2 = map_view.project(float(airport["lon"]), float(airport["lat"]))
		if hub_pos.x < 10.0 or hub_pos.x > size.x - 10.0 or hub_pos.y < 177.0 or hub_pos.y > size.y - 170.0:
			continue
		draw_arc(hub_pos, 8.0 + 3.0 * pulse, 0.0, TAU, 24, Color(0.98, 0.75, 0.48, 0.12 + 0.16 * pulse), 1.4, true)
	# Active market events appear as temporary, gentle halos over their airports.
	for event in game.route_events:
		if int(event.get("ends", 0)) <= game.day:
			continue
		var point: Dictionary = game.airport(str(event.get("airport", "")))
		if point.is_empty():
			continue
		var event_pos: Vector2 = map_view.project(float(point["lon"]), float(point["lat"]))
		if event_pos.x < 0.0 or event_pos.x > size.x or event_pos.y < 168.0 or event_pos.y > size.y - 170.0:
			continue
		draw_arc(event_pos, 11.0 + pulse * 7.0, 0.0, TAU, 28, Color(0.99, 0.68, 0.35, 0.14 + pulse * 0.15), 2.1, true)
	for route in game.routes:
		var arc: PackedVector2Array = map_view.route_points(str(route["from"]), str(route["to"]))
		if arc.size() < 2:
			continue
		var t: float = clampf(float(route.get("progress", 0.0)), 0.0, 1.0)
		if int(route.get("direction", 0)) == 1:
			t = 1.0 - t
		var idx: int = clampi(int(t * float(arc.size() - 1)), 0, arc.size() - 2)
		var blend: float = t * (arc.size() - 1) - float(idx)
		var pos: Vector2 = arc[idx].lerp(arc[idx + 1], blend)
		var direction: Vector2 = (arc[idx + 1] - arc[idx]).normalized()
		if int(route.get("direction", 0)) == 1:
			direction = -direction
		if pos.x < -15.0 or pos.x > size.x + 15.0 or pos.y < -15.0 or pos.y > size.y + 15.0:
			continue
		draw_flight_trail(arc, t, 1 if int(route.get("direction", 0)) == 0 else -1)
		draw_airplane(pos, direction, route)

func point_on_route(arc: PackedVector2Array, fraction: float) -> Vector2:
	var t: float = clampf(fraction, 0.0, 1.0)
	var idx: int = clampi(int(t * float(arc.size() - 1)), 0, arc.size() - 2)
	var blend: float = t * float(arc.size() - 1) - float(idx)
	return arc[idx].lerp(arc[idx + 1], blend)

func draw_flight_trail(arc: PackedVector2Array, progress: float, travel_sign: int) -> void:
	# Seven short interpolation samples, independent of airport label density.
	# The tail follows the actual plane and never redraws the static coastline.
	if arc.size() < 2:
		return
	var tail: PackedVector2Array = PackedVector2Array()
	for j in range(7, -1, -1):
		var sample_t: float = clampf(progress - float(travel_sign) * 0.006 * float(j), 0.0, 1.0)
		tail.append(point_on_route(arc, sample_t))
	if tail.size() > 1:
		draw_polyline(tail, Color(1.0, 0.97, 0.87, 0.13), 4.0, true)
		draw_polyline(tail, Color(1.0, 0.96, 0.87, 0.42), 1.25, true)

func draw_airplane(pos: Vector2, heading: Vector2, route: Dictionary) -> void:
	# The actual aircraft model determines its silhouette.
	# Small aircraft are prop planes, large aircraft have a swept-wing jet shape.
	var model: Dictionary = game.catalog_by_id.get(str(route.get("plane", "")), {})
	var is_prop: bool = int(model.get("level", 1)) <= 2
	var angle: float = heading.angle()
	var size_factor: float = 1.19 if is_prop else 1.24
	var geometry: PackedVector2Array
	if is_prop:
		geometry = PackedVector2Array([
			Vector2(10.2, 0),Vector2(3.0, -1.0),Vector2(-0.6, -10.4),
			Vector2(-2.5, -10.4),Vector2(-2.4, -2.0),Vector2(-8.8, -1.0),
			Vector2(-10.2, -4.1),Vector2(-11.4, -4.1),Vector2(-10.8, 0),
			Vector2(-11.4, 4.1),Vector2(-10.2, 4.1),Vector2(-8.8, 1.0),
			Vector2(-2.4, 2.0),Vector2(-2.5, 10.4),Vector2(-0.6, 10.4),
			Vector2(3.0, 1.0)])
	else:
		geometry = PackedVector2Array([
			Vector2(13.0,0.0),Vector2(4.0,-1.6),Vector2(-2.6,-10.3),
			Vector2(-4.7,-10.3),Vector2(-3.2,-2.4),Vector2(-9.3,-1.2),
			Vector2(-10.3,-4.2),Vector2(-11.9,-4.1),Vector2(-11.5,0),
			Vector2(-11.9,4.1),Vector2(-10.3,4.2),Vector2(-9.3,1.2),
			Vector2(-3.2,2.4),Vector2(-4.7,10.3),Vector2(-2.6,10.3),
			Vector2(4.0,1.6)])
	var outer: PackedVector2Array = PackedVector2Array()
	var fill: PackedVector2Array = PackedVector2Array()
	for pt in geometry:
		fill.append(pos + pt.rotated(angle) * size_factor)
		outer.append(pos + pt.rotated(angle) * (size_factor + 0.065))
	# Aviation-style halo, subtly scaled so it stays crisp when zooming.
	draw_circle(pos, 20.0 if not is_prop else 18.0, Color(1.0, 0.96, 0.78, 0.13))
	draw_colored_polygon(outer, Color(1.0, 0.99, 0.93, 0.96))
	draw_colored_polygon(fill, Color("244e5c"))
	var wing_extent: float = 10.4 if is_prop else 10.3
	var wing_left: Vector2 = pos + Vector2(-1.0, -wing_extent).rotated(angle) * size_factor
	var wing_right: Vector2 = pos + Vector2(-1.0, wing_extent).rotated(angle) * size_factor
	draw_circle(wing_left, 1.9, Color("ec8878"))
	draw_circle(wing_right, 1.9, Color("8dd2b4"))
	if is_prop:
		# Rotating two-blade propeller is visible up close but uses no sprites.
		var tip: Vector2 = pos + heading * (9.3 * size_factor)
		var prop_axis: Vector2 = Vector2(-sin(angle), cos(angle))
		var speed_wobble: float = sin(ambient_time * 32.0)
		draw_line(tip + prop_axis * (2.0 + speed_wobble), tip - prop_axis * (2.0 + speed_wobble), Color(1.0, 1.0, 1.0, 0.72), 1.2, true)
	else:
		var aft: Vector2 = pos - heading * (9.0 * size_factor)
		draw_circle(aft, 1.6, Color(1.0, 0.78, 0.52, 0.72))
