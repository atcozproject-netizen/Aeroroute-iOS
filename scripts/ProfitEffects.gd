extends Control
## Aeroroute: lightweight real earnings popup, updated only while active.
const GREEN = Color("24755e")
const RED = Color("ae6252")
const MAX_POPUPS: int = 8
const LIFETIME: float = 1.25
var game
var world_map
var effects: Array[Dictionary] = []
var accumulator: float = 0.0

func setup(model, map_control: Control) -> void:
	game = model
	world_map = map_control
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)

func show_landing(code: String, net: float, passengers: int) -> void:
	if effects.size() >= MAX_POPUPS:
		effects.pop_front()
	effects.append({"code": code, "amount": ("+" if net > 0.0 else "") + game.money(net),
		"net": net, "passengers": passengers, "age": 0.0})
	set_process(true)
	queue_redraw()

func has_active_profit() -> bool:
	return not effects.is_empty()

func _process(delta: float) -> void:
	accumulator += delta
	if accumulator < 0.033:
		return
	var dt: float = minf(accumulator, 0.09)
	accumulator = 0.0
	for idx in range(effects.size() - 1, -1, -1):
		effects[idx]["age"] = float(effects[idx]["age"]) + dt
		if float(effects[idx]["age"]) >= LIFETIME:
			effects.remove_at(idx)
	if effects.is_empty():
		set_process(false)
	queue_redraw()

func _draw() -> void:
	if game == null or world_map == null:
		return
	var font: Font = ThemeDB.fallback_font
	for effect in effects:
		var elapsed: float = float(effect["age"])
		var t: float = clampf(elapsed / LIFETIME, 0.0, 1.0)
		var code: String = str(effect["code"])
		var p: Vector2 = Vector2(size.x * 0.5, 177.0)
		if code != "" and game.airports_by_code.has(code):
			var airport: Dictionary = game.airport(code)
			p = world_map.project(float(airport["lon"]), float(airport["lat"]))
		var on_map: bool = p.x > 35.0 and p.x < size.x - 35.0 and p.y > 185.0 and p.y < size.y - 188.0
		if not on_map:
			p = Vector2(size.x * 0.5, 177.0)
		var origin: Vector2 = p
		p.y -= t * 36.0 + 10.0
		var alpha: float = minf(1.0, elapsed / 0.13) * (1.0 - smoothstep(0.67, 1.0, t))
		var color: Color = GREEN if float(effect["net"]) >= 0.0 else RED
		var amount: String = str(effect["amount"])
		var width: float = font.get_string_size(amount, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		var rect: Rect2 = Rect2(p.x - width * 0.5 - 12.0, p.y - 14.0, width + 24.0, 29.0)
		draw_rect(rect, Color(1.0, 0.994, 0.97, alpha * 0.94))
		draw_rect(rect, Color(color.r, color.g, color.b, alpha * 0.52), false, 1.0, true)
		draw_string(font, p + Vector2(-width * 0.5, 5.0), amount, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(color.r, color.g, color.b, alpha))
		if on_map and t < 0.7:
			draw_arc(origin, 5.0 + t * 20.0, 0.0, TAU, 20, Color(color.r, color.g, color.b, alpha * 0.60), 1.5, true)
