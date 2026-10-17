extends Control
## FIR boundaries for Aeroroute; NOT authoritative AIS navigation data.
signal fir_loaded(count: int)
signal fir_load_failed(message: String)
const FIR_URL: String = ""
const STROKE: Color = Color(0.66, 0.76, 0.82, 0.36)
const LABEL: Color = Color("294a56")
const LABEL_BG: Color = Color(0.96, 0.97, 0.96, 0.87)
const MAX_LABELS: int = 5
const MAX_DENSE_LABELS: int = 3
var world_map
var regions: Array = []
var loaded: bool = false
var loading: bool = false
var enabled: bool = false
var display_mode: int = 0 # 0 off, 1 subtle boundaries, 2 names with strict declutter
var http: HTTPRequest
var camera_signature: Vector4 = Vector4(-999, -999, -999, -999)
var viewport_height: float = -1.0

func configure(map_control: Control) -> void:
	world_map = map_control
	http = HTTPRequest.new()
	http.timeout = 25.0
	add_child(http)
	http.request_completed.connect(_received)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	visible = false

func set_mode(mode: int) -> void:
	display_mode = clampi(mode, 0, 2)
	enabled = display_mode != 0
	visible = enabled
	if enabled and not loaded and not loading:
		load_firs()
	set_process(enabled)
	queue_redraw()

func set_fir_visible(value: bool) -> void:
	set_mode(1 if value else 0)


func load_firs() -> void:
	loading = true
	if FileAccess.file_exists("res://data/fir_regions.json"):
		var file: FileAccess = FileAccess.open("res://data/fir_regions.json", FileAccess.READ)
		if file != null:
			parse_regions(file.get_as_text())
			return
	# The actual worldwide dataset is bundled by the GitHub build. Do not rely
	# on the former temporary PageShare URL (which can expire).
	loading = false
	fir_load_failed.emit("FIR-gränser saknas i spelpaketet.")

func _received(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	loading = false
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		fir_load_failed.emit("FIR-datan kunde inte laddas. Kontrollera internet.")
		return
	parse_regions(body.get_string_from_utf8())

func parse_regions(content: String) -> void:
	var data: Variant = JSON.parse_string(content)
	if typeof(data) != TYPE_DICTIONARY or not data.has("regions"):
		loading = false
		fir_load_failed.emit("FIR-filens format kunde inte läsas.")
		return
	regions.clear()
	for feature in data["regions"]:
		if not (feature is Dictionary) or not feature.has("rings"):
			continue
		var items: Array = []
		for ring in feature["rings"]:
			var points: PackedVector2Array = PackedVector2Array()
			for pt in ring:
				if pt is Array and pt.size() >= 2:
					points.append(Vector2(float(pt[0]), float(pt[1])))
			if points.size() >= 3:
				var left: float = 180.0
				var right: float = -180.0
				var south: float = 90.0
				var north: float = -90.0
				for point in points:
					left = minf(left, point.x)
					right = maxf(right, point.x)
					south = minf(south, point.y)
					north = maxf(north, point.y)
				items.append({"points": points, "left": left, "right": right, "south": south, "north": north})
		if not items.is_empty():
			regions.append({"code": str(feature.get("code", "")), "name": str(feature.get("name", "")), "rings": items, "lon": float(feature.get("lon", 0.0)), "lat": float(feature.get("lat", 0.0))})
	loaded = not regions.is_empty()
	loading = false
	if loaded:
		fir_loaded.emit(regions.size())
	else:
		fir_load_failed.emit("Inga FIR-gränser hittades.")
	queue_redraw()

func _process(_delta: float) -> void:
	if not enabled or not loaded or world_map == null:
		return
	var current: Vector4 = Vector4(world_map.camera_lon, world_map.camera_lat, world_map.zoom, world_map.size.x)
	if camera_signature.distance_to(current) > 0.0001 or absf(viewport_height - size.y) > 1.0:
		camera_signature = current
		viewport_height = size.y
		queue_redraw()

func _draw() -> void:
	if not enabled or not loaded or world_map == null:
		return
	var pscale: float = world_map.projection_scale()
	if pscale <= 0.0:
		return
	var labels: Array[Rect2] = []
	var budget: int = 0
	var label_budget: int = 0
	var label_limit: int = MAX_DENSE_LABELS if world_map.zoom < 10.0 else MAX_LABELS
	var min_lon: float = world_map.camera_lon - size.x * 0.5 / pscale
	var max_lon: float = world_map.camera_lon + size.x * 0.5 / pscale
	var min_lat: float = world_map.camera_lat - size.y * 0.5 / (pscale * 1.17)
	var max_lat: float = world_map.camera_lat + size.y * 0.5 / (pscale * 1.17)
	for region in regions:
		for segment in region["rings"]:
			if budget >= 25000:
				break
			if float(segment["north"]) < min_lat - 1.0 or float(segment["south"]) > max_lat + 1.0:
				continue
			var points: PackedVector2Array = segment["points"]
			for offset in [-360.0, 0.0, 360.0]:
				if float(segment["right"]) + offset < min_lon - 1.0 or float(segment["left"]) + offset > max_lon + 1.0:
					continue
				var poly: PackedVector2Array = PackedVector2Array()
				var last_lon: float = 10000.0
				for coord in points:
					if last_lon < 9000.0 and absf(coord.x - last_lon) > 180.0:
						if poly.size() >= 2:
							draw_polyline(poly, STROKE, 0.85, true)
						poly = PackedVector2Array()
					last_lon = coord.x
					poly.append(world_map.world_project_raw(coord.x, coord.y, offset))
				if poly.size() >= 2:
					draw_polyline(poly, STROKE, 0.85 if world_map.zoom < 8.0 else 1.05, true)
			budget += points.size()
		if display_mode != 2 or world_map.zoom < 7.5 or label_budget >= label_limit:
			continue
		var label_pos: Vector2 = world_map.project(float(region["lon"]), float(region["lat"]))
		if label_pos.x < 24.0 or label_pos.x > size.x - 55.0 or label_pos.y < 180.0 or label_pos.y > size.y - 158.0:
			continue
		var title: String = str(region["code"]) + " FIR"
		if world_map.zoom > 9.0:
			title = str(region["name"])
		var font: Font = ThemeDB.fallback_font
		var font_size: int = 12 if world_map.zoom > 6.0 else 11
		var text_width: float = minf(font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x, 158.0)
		var box: Rect2 = Rect2(label_pos - Vector2(7, 19), Vector2(text_width + 17.0, 23.0))
		var free: bool = true
		for prev in labels:
			if prev.intersects(box):
				free = false
				break
		if free:
			labels.append(box)
			label_budget += 1
			draw_rect(box, LABEL_BG)
			draw_string(font, label_pos + Vector2(1.0, -3.0), title, HORIZONTAL_ALIGNMENT_LEFT, 150.0, font_size, LABEL)
