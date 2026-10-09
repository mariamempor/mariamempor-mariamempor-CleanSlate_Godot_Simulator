extends Control

var t: float = 0.0
var glitch_timer: float = 0.0
var glitch_y: float = 0.0
var glitch_h: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	t += delta
	glitch_timer -= delta
	if glitch_timer <= 0.0:
		glitch_timer = 1.2 + fmod(t * 0.37, 1.8)
		glitch_y = fmod(t * 241.0, max(1.0, get_viewport_rect().size.y - 22.0))
		glitch_h = 2.0 + fmod(t * 13.0, 8.0)
	queue_redraw()

func _draw() -> void:
	var s: Vector2 = get_viewport_rect().size
	for y: int in range(0, int(s.y), 4):
		draw_rect(Rect2(0, y, s.x, 1), Color(0, 0, 0, 0.035))
	draw_rect(Rect2(0, 0, s.x, 18), Color(0, 0, 0, 0.06))
	draw_rect(Rect2(0, s.y - 18, s.x, 18), Color(0, 0, 0, 0.07))
	if fmod(t, 5.7) > 5.45:
		draw_rect(Rect2(0, glitch_y, s.x, glitch_h), Color(0.20, 0.92, 0.95, 0.035))
		draw_rect(Rect2(80, glitch_y + 2, min(320.0, s.x - 100.0), 1), Color(0.95, 0.25, 0.30, 0.08))
	draw_rect(Rect2(0, 0, 8, s.y), Color(0, 0, 0, 0.07))
	draw_rect(Rect2(s.x - 8, 0, 8, s.y), Color(0, 0, 0, 0.07))
