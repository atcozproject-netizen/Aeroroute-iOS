extends Control
## Separate inexpensive 30-FPS overlay: routes/coasts are not rebuilt every animation frame.

var game
var map_view
var accumulator: float = 0.0

func setup(model, world_map) -> void:
	game = model
	map_view = world_map
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	if game == null or not visible or game.routes.is_empty():
		return
	accumulator += delta
	if accumulator >= 0.042:
		accumulator = 0.0
		queue_redraw()

func _draw() -> void:
	if game == null or map_view == null:
		return
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
		draw_airplane(pos, direction, route)

func draw_airplane(pos: Vector2, heading: Vector2, route: Dictionary) -> void:
	# Small crisp swept-wing silhouette, no bitmap/pixel upscaling.
	var geometry := PackedVector2Array([
		Vector2(11, 0), Vector2(3.5, -1.8), Vector2(-2.2, -8.5),
		Vector2(-4.5, -8.5), Vector2(-3.0, -1.9), Vector2(-9.0, -1.3),
		Vector2(-11.0, -4.0), Vector2(-12.4, -3.9), Vector2(-11.5, 0),
		Vector2(-12.4, 3.9), Vector2(-11.0, 4.0), Vector2(-9.0, 1.3),
		Vector2(-3.0, 1.9), Vector2(-4.5, 8.5), Vector2(-2.2, 8.5), Vector2(3.5, 1.8)
	])
	var outline: PackedVector2Array = PackedVector2Array()
	var body: PackedVector2Array = PackedVector2Array()
	var angle: float = heading.angle()
	for pt in geometry:
		body.append(pos + pt.rotated(angle) * 0.72)
		outline.append(pos + pt.rotated(angle) * 0.80)
	# Low-cost jet wake and navigation lights; no particle systems.
	var aft: Vector2 = pos - heading * 8.0
	draw_line(aft - heading * 8.0, aft, Color(1.0, 1.0, 1.0, 0.17), 2.0, true)
	draw_colored_polygon(outline, Color("fff9e9"))
	draw_colored_polygon(body, Color("285767"))
	draw_circle(pos + Vector2(-1.2, -6.0).rotated(angle) * 0.72, 1.35, Color("e68d7a"))
	draw_circle(pos + Vector2(-1.2, 6.0).rotated(angle) * 0.72, 1.35, Color("83c4ad"))
	if int(route.get("level", 1)) >= 4:
		draw_circle(aft, 1.4, Color(1.0, 0.81, 0.60, 0.75))
