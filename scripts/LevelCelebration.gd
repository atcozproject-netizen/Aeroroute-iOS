extends Control
## Compact level-unlock celebration. Never captures map touches.
const DURATION: float = 2.15
var age: float = DURATION
var achieved_level: int = 1
var fraction: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)

func celebrate(level_number: int) -> void:
	achieved_level = level_number
	age = 0.0
	fraction = 0.0
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	age += delta
	fraction += delta
	if fraction < 0.041:
		return
	fraction = 0.0
	if age >= DURATION:
		set_process(false)
	queue_redraw()

func _draw() -> void:
	if age >= DURATION:
		return
	var t: float = clampf(age / DURATION, 0.0, 1.0)
	var fade: float = minf(1.0, age / 0.17) * (1.0 - smoothstep(0.75, 1.0, t))
	var center: Vector2 = Vector2(size.x * 0.5, size.y * 0.48 - 15.0 * t)
	var bg: Rect2 = Rect2(center - Vector2(134, 49), Vector2(268, 98))
	draw_rect(bg, Color(0.13, 0.30, 0.36, 0.91 * fade), true)
	draw_rect(bg, Color(0.94, 0.73, 0.47, fade), false, 2.0, true)
	var font: Font = ThemeDB.fallback_font
	var title: String = "NIVÅ %d UPPLÅST!" % achieved_level
	draw_string(font, center + Vector2(-98, -7), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color(1.0, 0.91, 0.73, fade))
	draw_string(font, center + Vector2(-98, 20), "NYA FLYGPLAN TILLGÄNGLIGA", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.94, 0.97, 0.96, fade))
	for i in range(12):
		var angle: float = TAU * float(i) / 12.0 + float(achieved_level) * 0.13
		var dist: float = 54.0 + 80.0 * t
		var particle: Vector2 = center + Vector2(cos(angle), sin(angle)) * dist
		draw_circle(particle, 2.0 + 1.2 * (1.0 - t), Color(1.0, 0.77, 0.48, fade * (1.0 - t)))
