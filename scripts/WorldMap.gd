extends Control
## Native Godot CanvasItem world map: detailed vector coastlines, smooth touch controls.

signal airport_tapped(code: String)
signal route_tapped(route_id: String)
signal route_drafted(start_code: String, end_code: String)

const SEA_TOP = Color("72b8c7")
const SEA_BOTTOM = Color("72b8c7")
const LAND_FILL = Color("f1e6d1")
const LAND_EDGE = Color("e4d7ba")
const NODE_FREE = Color("265b70")
const NODE_OWNED = Color("f2b777")
const ROUTE_LINE = Color("de986d")
const ROUTE_POSITIVE = Color("469787")
const ROUTE_NEGATIVE = Color("cd8275")
const ROUTE_NEUTRAL = Color("d5a777")
const ROUTE_GLOW = Color(1.0, 0.83, 0.64, 0.29)
const OWNED_HALO = Color(0.98, 0.75, 0.52, 0.21)
const LAND_TEXTURE: Texture2D = preload("res://data/world_land.png")
const DETAIL_TILE_DEGREES: float = 20.0
const DETAIL_BEGIN_ZOOM: float = 20.0
const MAX_ACTIVE_TILES: int = 10

var game
var camera_lon: float = 13.0
var camera_lat: float = 52.0
var zoom: float = 4.4
var focused_airport: String = ""
var focused_route_id: String = ""
var route_origin: String = ""
var pointer_start: Vector2 = Vector2.ZERO
var pointer_last: Vector2 = Vector2.ZERO
var pointer_down: bool = false
var pointer_from: String = ""
var pointer_moved: bool = false
var drag_threshold: float = 11.0
var route_draw_enabled: bool = false
var gesture_kind: String = "idle"
var hold_elapsed: float = 0.0
const HOLD_TO_ROUTE_SECONDS: float = 0.42

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
var detail_tile_cache: Dictionary = {}
var detail_tile_recent: Array[String] = []
var detailed_tile_draws: int = 0
var reveal_route_id: String = ""
var reveal_progress: float = 1.0
var reveal_accumulator: float = 0.0
var follow_route_id: String = ""
var follow_accumulator: float = 0.0
const REVEAL_SECONDS: float = 0.88

# The iPhone must not process or label every airport at world scale.
# A static world-map LOD is computed only once, not on every pan frame.
const LOD_THRESHOLDS = [0.8, 0.55, 0.36, 0.12]
const MIN_ZOOM: float = 2.7
const MAX_ZOOM: float = 64.0
const PAN_SENSITIVITY: float = 0.70
const MAX_PAN_STEP_PX: float = 36.0


func configure(source_game) -> void:
	game = source_game
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
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
	# Smooth LOD: local airfields (rank 1) appear only at neighborhood zoom.
	if zoom < 4.2:
		return 5
	if zoom < 6.4:
		return 4
	if zoom < 10.0:
		return 3
	if zoom < 18.0:
		return 2
	return 1

func airport_label_text(airport: Dictionary) -> String:
	var code: String = str(airport.get("icao", ""))
	# A map is not a table: unselected airports always display a short code.
	# Detailed names remain available in the airport info panel.
	if code == focused_airport and zoom >= 29.0:
		var name_text: String = str(airport.get("name", code)).strip_edges()
		if name_text.length() > 20:
			name_text = name_text.substr(0, 19).strip_edges() + "…"
		return code + " · " + name_text
	return code

func airport_label_budget() -> int:
	if zoom < 6.0:
		return 3
	if zoom < 15.0:
		return 4
	if zoom < 35.0:
		return 5
	return 6

func airport_label_priority(item: Dictionary) -> int:
	var code: String = str(item["code"])
	if bool(item["focused"]):
		return 500
	if bool(item["owned"]):
		return 400
	for r in game.routes:
		if str(r["from"]) == code or str(r["to"]) == code:
			return 300
	return int(item["airport"]["rank"]) * 10

func label_candidates(pins: Array) -> Array:
	# Sorting and collision checks happen only when the map redraws.
	var eligible: Array = []
	for item in pins:
		var rank: int = int(item["airport"]["rank"])
		var important: bool = bool(item["focused"]) or bool(item["owned"])
		var threshold: bool = (zoom >= 5.0 and rank >= 7) or (zoom >= 12.0 and rank >= 5) or (zoom >= 23.0 and rank >= 3) or zoom >= 45.0
		if important or threshold:
			eligible.append(item)
	eligible.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return airport_label_priority(a) > airport_label_priority(b)
	)
	var picked: Array = []
	var rects: Array[Rect2] = []
	var limit: int = airport_label_budget()
	for item in eligible:
		if picked.size() >= limit:
			break
		var p: Vector2 = item["position"]
		if p.y < 174.0 or p.y > size.y - 170.0:
			continue
		var value: String = airport_label_text(item["airport"])
		var label_size: int = 11
		var tx: Vector2 = p + Vector2(10.0, -4.0)
		var w: float = ThemeDB.fallback_font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size).x
		var rect: Rect2 = Rect2(tx.x - 3.0, tx.y - 13.0, w + 9.0, 20.0)
		if rect.position.x < 9.0 or rect.end.x > size.x - 12.0:
			continue
		# Keep space for the zoom/FIR/route controls on the right.
		if rect.end.x > size.x - 76.0 and rect.position.y < 545.0:
			continue
		var collides: bool = false
		for prev in rects:
			if rect.grow(10.0).intersects(prev.grow(10.0)):
				collides = true
				break
		if collides:
			continue
		rects.append(rect)
		picked.append({"text":value, "pos":tx, "rect":rect, "focused":bool(item["focused"]), "owned":bool(item["owned"])})
	return picked

func candidate_airports() -> Array:
	if game == null:
		return []
	var candidates: Array = []
	var minimum_rank: int = airport_min_rank()
	var sc: float = maxf(projection_scale(), 0.001)
	var max_d_lon: float = size.x * 0.5 / sc + 3.0
	var max_d_lat: float = size.y * 0.5 / (sc * 1.17) + 3.0
	# Geographic culling BEFORE projecting all 2661 records avoids work
	# during iPhone pinch/pan at city zoom.
	for airport in map_airports:
		var code: String = str(airport["icao"])
		var owned: bool = game.owned.has(code)
		var focused: bool = code == focused_airport
		if not owned and not focused and not game.is_featured(code):
			continue
		if not owned and not focused and int(airport["rank"]) < minimum_rank:
			continue
		var lat: float = float(airport["lat"])
		if absf(lat - camera_lat) > max_d_lat:
			continue
		var lon: float = float(airport["lon"])
		var diff_lon: float = fposmod(lon - camera_lon + 180.0, 360.0) - 180.0
		if absf(diff_lon) > max_d_lon:
			continue
		var pos: Vector2 = project(lon, lat)
		if pos.x < -30.0 or pos.x > size.x + 30.0 or pos.y < -30.0 or pos.y > size.y + 30.0:
			continue
		candidates.append({"code":code, "position":pos, "airport":airport, "owned":owned, "focused":focused})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if bool(a["focused"]) != bool(b["focused"]):
			return bool(a["focused"])
		if bool(a["owned"]) != bool(b["owned"]):
			return bool(a["owned"])
		return int(a["airport"]["rank"]) > int(b["airport"]["rank"])
	)
	var result: Array = []
	var spacing: float = 28.0 if zoom < 6.5 else 23.0 if zoom < 12.0 else 17.0 if zoom < 22.0 else 12.0 if zoom < 42.0 else 8.0
	var spacing_sq: float = spacing * spacing
	for item in candidates:
		var collide: bool = false
		if not bool(item["owned"]) and not bool(item["focused"]):
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
	focused_airport = code
	zoom = 9.0
	queue_redraw()

func whole_world() -> void:
	camera_lon = 12.0
	camera_lat = 38.0
	focused_airport = ""
	zoom = MIN_ZOOM
	queue_redraw()

func projection_scale() -> float:
	return size.x * zoom / 360.0

func project(lon: float, lat: float) -> Vector2:
	var dx: float = fposmod(lon - camera_lon + 180.0, 360.0) - 180.0
	return Vector2(size.x * 0.5 + dx * projection_scale(), size.y * 0.5 - (lat - camera_lat) * projection_scale() * 1.17)

func world_project_raw(lon: float, lat: float, shift: float = 0.0) -> Vector2:
	return Vector2(size.x * 0.5 + (lon - camera_lon + shift) * projection_scale(), size.y * 0.5 - (lat - camera_lat) * projection_scale() * 1.17)

func toggle_follow(route_id: String) -> bool:
	if route_id == "" or game.get_route(route_id).is_empty():
		follow_route_id = ""
	else:
		follow_route_id = "" if follow_route_id == route_id else route_id
	follow_accumulator = 0.0
	queue_redraw()
	return follow_route_id != ""

func center_on_followed_aircraft() -> void:
	if follow_route_id == "":
		return
	var route: Dictionary = game.get_route(follow_route_id)
	if route.is_empty():
		follow_route_id = ""
		return
	var a: Dictionary = game.airport(str(route["from"]))
	var b: Dictionary = game.airport(str(route["to"]))
	if a.is_empty() or b.is_empty():
		follow_route_id = ""
		return
	var t: float = clampf(float(route.get("progress", 0.0)), 0.0, 1.0)
	if int(route.get("direction", 0)) == 1:
		t = 1.0 - t
	var start_lon: float = float(a["lon"])
	var lon_delta: float = fposmod(float(b["lon"]) - start_lon + 180.0, 360.0) - 180.0
	camera_lon = fposmod(start_lon + lon_delta * t + 180.0, 360.0) - 180.0
	camera_lat = lerpf(float(a["lat"]), float(b["lat"]), t)
	zoom = maxf(zoom, 10.0)
	queue_redraw()

func animate_new_route(route_id: String) -> void:
	reveal_route_id = route_id
	reveal_progress = 0.0
	reveal_accumulator = 0.0
	queue_redraw()

func route_visual_color(route: Dictionary) -> Color:
	var estimate: Dictionary = game.projected(route)
	if estimate.is_empty():
		return ROUTE_NEUTRAL
	var net: float = float(estimate["net"])
	if net < -1.0:
		return ROUTE_NEGATIVE
	if net > 1.0:
		return ROUTE_POSITIVE
	return ROUTE_NEUTRAL

func _draw() -> void:
	# Smooth premium strategy-board palette. No stripes, grids or video-sized shaders.
	draw_rect(Rect2(Vector2.ZERO,size), SEA_TOP, true)
	if game == null:
		return
	var sc: float = projection_scale()

	# Draw each visible section of a pre-rendered land texture. With this
	# technique the full continents draw correctly regardless of winding,
	# self-intersections or antimeridian crossings in the source polygons.
	# Max three GPU draw calls, rather than hundreds of polygons per frame.
	draw_land_texture(sc)
	if zoom >= DETAIL_BEGIN_ZOOM:
		draw_detail_tiles(sc)

	for r in game.routes:
		var arc: PackedVector2Array = route_points(str(r["from"]), str(r["to"]))
		if arc.size() < 2:
			continue
		var color: Color = route_visual_color(r)
		if str(r["id"]) == reveal_route_id and reveal_progress < 1.0:
			var steps: int = clampi(ceili(float(arc.size()) * reveal_progress), 2, arc.size())
			arc = arc.slice(0, steps)
		var selected: bool = str(r["id"]) == focused_route_id
		var halo: Color = Color(color.r, color.g, color.b, 0.31 if selected else 0.18)
		draw_polyline(arc, halo, 9.0 if selected else 4.4, true)
		draw_polyline(arc, Color("ffd499") if selected else color, 3.5 if selected else 2.0, true)
		if str(r["id"]) == reveal_route_id and reveal_progress < 1.0:
			draw_circle(arc[arc.size() - 1], 4.7, Color(1.0, 0.94, 0.76, 0.89))

	# Render every appropriate airport marker, but VERY FEW labels.
	# Tap any dot for the full airport name, country and route actions.
	var pins: Array = candidate_airports()
	visible_pin_codes.clear()
	for item in pins:
		var code: String = str(item["code"])
		visible_pin_codes[code] = true
		var p: Vector2 = item["position"]
		var owned: bool = bool(item["owned"])
		var rank: int = int(item["airport"]["rank"])
		var focused: bool = bool(item["focused"])
		var radius: float = (3.2 if zoom < 8.0 else 3.8 if zoom < 24.0 else 4.1) + (1.0 if owned or focused else 0.0)
		if owned or focused:
			draw_circle(p, radius + 6.0, OWNED_HALO)
		elif rank >= 7 and zoom >= 5.0:
			draw_circle(p, radius + 3.0, Color(1.0, 1.0, 1.0, 0.14))
		draw_circle(p, radius + 1.55, Color(0.995, 0.995, 0.98, .96))
		draw_circle(p, radius, NODE_OWNED if owned else NODE_FREE)
		if owned and zoom > 7.0:
			draw_circle(p, 1.5, Color("fff0cf"))
	for item in label_candidates(pins):
		var tx: Vector2 = item["pos"]
		if bool(item["focused"]):
			draw_rect(item["rect"].grow(2.0), Color(0.97, 0.98, 0.95, 0.94))
		draw_string(ThemeDB.fallback_font, tx, str(item["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("315764"))

	var origin: String = pointer_from if pointer_down and gesture_kind == "route" and pointer_from != "" else route_origin
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
		draw_texture_rect_region(LAND_TEXTURE, Rect2(view_left, visible_top, view_right-view_left, visible_bottom-visible_top), Rect2(src_x, src_y, src_w, src_h), Color.WHITE, false, true)


func tile_resource_path(x: int, y: int) -> String:
	return "res://data/map_tiles/%02d_%02d.png" % [posmod(x, 18), y]

func cached_detail_tile(x: int, y: int) -> Texture2D:
	var path: String = tile_resource_path(x, y)
	if detail_tile_cache.has(path):
		detail_tile_recent.erase(path)
		detail_tile_recent.append(path)
		return detail_tile_cache[path]
	# Ignore the global cache so tiles that leave view can actually be evicted.
	var texture: Texture2D = ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
	if texture == null:
		return null
	detail_tile_cache[path] = texture
	detail_tile_recent.append(path)
	while detail_tile_recent.size() > MAX_ACTIVE_TILES:
		var remove_path: String = detail_tile_recent.pop_front()
		detail_tile_cache.erase(remove_path)
	return texture

func draw_detail_tiles(sc: float) -> void:
	# Natural Earth 10m land rendered to 20-degree tiles at build time.
	# At max zoom this has approximately one source pixel per screen pixel.
	var half_lon: float = size.x * 0.5 / maxf(sc, 0.01)
	var half_lat: float = size.y * 0.5 / maxf(sc * 1.17, 0.01)
	var left_index: int = floori((camera_lon - half_lon + 180.0) / DETAIL_TILE_DEGREES)
	var right_index: int = floori((camera_lon + half_lon + 180.0) / DETAIL_TILE_DEGREES)
	var first_y: int = clampi(floori((90.0 - camera_lat - half_lat) / DETAIL_TILE_DEGREES), 0, 8)
	var last_y: int = clampi(floori((90.0 - camera_lat + half_lat) / DETAIL_TILE_DEGREES), 0, 8)
	detailed_tile_draws = 0
	for y in range(first_y, last_y + 1):
		var north: float = 90.0 - float(y) * DETAIL_TILE_DEGREES
		for ix in range(left_index, right_index + 1):
			# ix may be outside [-180,+180]; keep its world-wrap position.
			var texture: Texture2D = cached_detail_tile(ix, y)
			if texture == null:
				continue
			var lon_left: float = -180.0 + float(ix) * DETAIL_TILE_DEGREES
			var pos: Vector2 = world_project_raw(lon_left, north)
			var draw_size: Vector2 = Vector2(DETAIL_TILE_DEGREES * sc, DETAIL_TILE_DEGREES * sc * 1.17)
			draw_texture_rect(texture, Rect2(pos, draw_size), false, Color.WHITE)
			detailed_tile_draws += 1

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

func nearest_route(pos: Vector2, radius: float = 17.0) -> String:
	# Geometry-based line picking. Runs only on release, not while panning.
	if game == null or game.routes.is_empty():
		return ""
	var best_id: String = ""
	var best_dist_squared: float = radius * radius
	for route in game.routes:
		var arc: PackedVector2Array = route_points(str(route["from"]), str(route["to"]))
		for i in range(1, arc.size()):
			var a: Vector2 = arc[i - 1]
			var b: Vector2 = arc[i]
			var segment: Vector2 = b - a
			var length_squared: float = segment.length_squared()
			if length_squared < 0.01:
				continue
			var t: float = clampf((pos - a).dot(segment) / length_squared, 0.0, 1.0)
			var dist_squared: float = pos.distance_squared_to(a + segment * t)
			if dist_squared < best_dist_squared:
				best_dist_squared = dist_squared
				best_id = str(route["id"])
	return best_id

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
	zoom = clampf(zoom * clampf(factor, 0.76, 1.32), MIN_ZOOM, MAX_ZOOM)
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
	follow_route_id = ""
	pointer_down = true
	pointer_start = pos
	pointer_last = pos
	pointer_from = nearest_airport(pos, 30.0)
	pointer_moved = false
	temporary_line_end = pos
	hold_elapsed = 0.0
	gesture_kind = "pending"

func handle_motion(pos: Vector2) -> void:
	if not pointer_down:
		return
	if gesture_kind == "pending" and pointer_start.distance_to(pos) > drag_threshold:
		pointer_moved = true
		if route_draw_enabled and pointer_from != "":
			gesture_kind = "route"
		else:
			# Every ordinary swipe pans, even when it begins on a marker.
			gesture_kind = "pan"
	if gesture_kind == "pan":
		pan(pos - pointer_last)
	elif gesture_kind == "route":
		temporary_line_end = pos
		queue_redraw()
	pointer_last = pos

func handle_release(pos: Vector2) -> void:
	if not pointer_down:
		return
	var origin_code: String = pointer_from
	var was_route: bool = gesture_kind == "route"
	var was_tap: bool = gesture_kind == "pending"
	pointer_down = false
	pointer_from = ""
	gesture_kind = "idle"
	hold_elapsed = 0.0
	if was_route:
		var target: String = nearest_airport(pos, 33.0)
		if target != "" and origin_code != "" and target != origin_code:
			route_drafted.emit(origin_code, target)
	elif was_tap:
		# Airport dot wins close to the marker. Else the visible route line
		# takes precedence, with a comfortable 17px hit corridor on iPhone.
		var selected: String = nearest_airport(pos, 17.0)
		if selected != "":
			airport_tapped.emit(selected)
		elif not route_draw_enabled:
			var route_id: String = nearest_route(pos)
			if route_id != "":
				route_tapped.emit(route_id)
			else:
				selected = nearest_airport(pos, 29.0)
				if selected != "":
					airport_tapped.emit(selected)
		else:
			selected = nearest_airport(pos, 30.0)
			if selected != "":
				airport_tapped.emit(selected)
	# Panning and canceled routes never open a route planner.
	queue_redraw()

var gesture_captured: bool = false
var last_touch_event_ms: int = 0
var touch_was_pinch: bool = false

func reset_gesture() -> void:
	pointers.clear()
	gesture_kind = "idle"
	hold_elapsed = 0.0
	touch_was_pinch = false
	pointer_down = false
	pointer_from = ""
	pointer_moved = false
	pinch_active = false
	pinch_length = 0.0
	gesture_captured = false
	queue_redraw()

func _process(delta: float) -> void:
	if follow_route_id != "" and game != null and game.initialized:
		follow_accumulator += delta
		if follow_accumulator >= 0.065:
			follow_accumulator = 0.0
			center_on_followed_aircraft()
	if reveal_progress < 1.0:
		reveal_accumulator += delta
		if reveal_accumulator >= 1.0 / 30.0:
			reveal_progress = minf(1.0, reveal_progress + reveal_accumulator / REVEAL_SECONDS)
			reveal_accumulator = 0.0
			if reveal_progress >= 1.0:
				reveal_route_id = ""
			queue_redraw()
	if gesture_captured and Time.get_ticks_msec() - last_touch_event_ms > 8500:
		reset_gesture()
		return
	if pointer_down and gesture_kind == "pending" and pointer_from != "" and not route_draw_enabled and not touch_was_pinch:
		hold_elapsed += minf(delta, 0.25)
		if hold_elapsed >= HOLD_TO_ROUTE_SECONDS:
			gesture_kind = "route"
			queue_redraw()

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
				gesture_kind = "pinch"
				hold_elapsed = 0.0
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
				gesture_kind = "pan"
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
				change_zoom(clampf(length_now / pinch_length, 0.88, 1.12), center)
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
			change_zoom(1.22, event.position)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			change_zoom(0.82, event.position)
	elif event is InputEventMouseMotion and pointer_down:
		if touch_input_seen and Time.get_ticks_msec() - touch_last_ms < 1900:
			return
		handle_motion(event.position)
