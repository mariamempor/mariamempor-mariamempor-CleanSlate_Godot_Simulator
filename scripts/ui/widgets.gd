extends RefCounted
## Componentes desenhados à mão.
##
## Cada classe é um Control que se desenha em _draw(). A propriedade "progress"
## (0..1), quando existe, serve à animação de entrada: um Tween muda o valor e
## o setter chama queue_redraw().
##
## Uso:  const W = preload("res://scripts/ui/widgets.gd")
##       var spark := W.Spark.new()

## Linha de tendência compacta. Com menos de 2 pontos, mostra só uma linha-base.
class Spark extends Control:
	var values: Array = []
	var line_color: Color = Color.WHITE
	var progress: float = 1.0:
		set(v):
			progress = v
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var n: int = values.size()
		if n < 2:
			var mid: float = size.y * 0.5
			draw_dashed_line(Vector2(0.0, mid), Vector2(size.x, mid), Color(line_color, 0.35), 1.0, 4.0)
			return
		var lo: float = float(values[0])
		var hi: float = lo
		for v: Variant in values:
			lo = minf(lo, float(v))
			hi = maxf(hi, float(v))
		var pts: PackedVector2Array = PackedVector2Array()
		for i: int in range(n):
			var t: float = 0.5
			if not is_equal_approx(hi, lo):
				t = (float(values[i]) - lo) / (hi - lo)
			pts.append(Vector2(size.x * float(i) / float(n - 1), size.y - 3.0 - t * (size.y - 6.0)))
		var shown: PackedVector2Array = _cut(pts, progress)
		if shown.size() < 2:
			return
		var last: Vector2 = shown[shown.size() - 1]
		if last.x - shown[0].x > 4.0:
			var area: PackedVector2Array = shown.duplicate()
			area.append(Vector2(last.x, size.y))
			area.append(Vector2(shown[0].x, size.y))
			draw_colored_polygon(area, Color(line_color, 0.10))
		draw_polyline(shown, line_color, 2.0, true)
		draw_circle(last, 3.0, line_color)

	## Devolve só o trecho inicial da linha, proporcional a ratio (0..1).
	static func _cut(pts: PackedVector2Array, ratio: float) -> PackedVector2Array:
		var out: PackedVector2Array = PackedVector2Array()
		if pts.size() < 2:
			return out
		var pos: float = clampf(ratio, 0.0, 1.0) * float(pts.size() - 1)
		var whole: int = int(floor(pos))
		for i: int in range(whole + 1):
			out.append(pts[i])
		if whole < pts.size() - 1:
			out.append(pts[whole].lerp(pts[whole + 1], pos - float(whole)))
		return out


## Barras por dia (volume processado). As barras crescem em sequência.
class BarChart extends Control:
	var values: Array = []
	var labels: Array = []
	var texts: Array = []
	var bar_color: Color = Color.WHITE
	var grid_color: Color = Color(1, 1, 1, 0.1)
	var text_color: Color = Color.WHITE
	var label_color: Color = Color.GRAY
	var font: Font
	var highlight: int = -1
	var progress: float = 1.0:
		set(v):
			progress = v
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var n: int = values.size()
		if n == 0 or font == null:
			return
		var top: float = 20.0
		var base: float = size.y - 22.0
		for g: int in range(4):
			var gy: float = top + (base - top) * float(g) / 3.0
			draw_line(Vector2(0.0, gy), Vector2(size.x, gy), grid_color, 1.0)
		var hi: float = 0.0
		for v: Variant in values:
			hi = maxf(hi, float(v))
		var slot: float = size.x / float(n)
		var bar_w: float = minf(slot * 0.56, 44.0)
		for i: int in range(n):
			# Cada barra começa um pouco depois da anterior.
			var local: float = clampf(progress * 1.6 - 0.6 * float(i) / float(n), 0.0, 1.0)
			local = 1.0 - pow(1.0 - local, 3.0)
			var value: float = float(values[i])
			var cx: float = slot * (float(i) + 0.5)
			var h: float = 0.0
			if hi > 0.0:
				h = (base - top) * (value / hi) * local
			var color: Color = bar_color if i == highlight else Color(bar_color, 0.55)
			if value > 0.0:
				draw_rect(Rect2(cx - bar_w * 0.5, base - h, bar_w, maxf(h, 2.0)), color)
				var txt: String = str(texts[i])
				var tw: float = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
				draw_string(font, Vector2(cx - tw * 0.5, base - h - 6.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(text_color, local))
			else:
				draw_rect(Rect2(cx - bar_w * 0.5, base - 2.0, bar_w, 2.0), grid_color)
			var lab: String = str(labels[i])
			var lw: float = font.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
			draw_string(font, Vector2(cx - lw * 0.5, size.y - 4.0), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, text_color if i == highlight else label_color)


## Medidor de suspeita em 4 segmentos (as zonas), usado no topo da tela.
## limit marca onde a campanha acaba neste ato; warn marca o nível de mandado.
class RiskMeter extends Control:
	var zone_colors: Array = []
	var track: Color = Color(1, 1, 1, 0.1)
	var marker: Color = Color.WHITE
	var danger: Color = Color.RED
	var limit: float = 100.0
	var warn: float = 0.0
	var value: float = 0.0:
		set(v):
			value = v
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _x_of(v: float) -> float:
		var gap: float = 3.0
		var seg: float = (size.x - gap * 3.0) / 4.0
		var idx: int = mini(3, int(floor(v / 25.0)))
		return float(idx) * (seg + gap) + seg * ((v - float(idx) * 25.0) / 25.0)

	func _draw() -> void:
		var gap: float = 3.0
		var seg: float = (size.x - gap * 3.0) / 4.0
		var h: float = 6.0
		var y: float = (size.y - h) * 0.5
		var v: float = clampf(value, 0.0, 100.0)
		for i: int in range(4):
			var x: float = float(i) * (seg + gap)
			draw_rect(Rect2(x, y, seg, h), track)
			var fill: float = clampf((v - float(i) * 25.0) / 25.0, 0.0, 1.0)
			if fill > 0.0:
				draw_rect(Rect2(x, y, seg * fill, h), zone_colors[i])
		# Faixa proibida: do limite do ato até o fim da régua.
		if limit < 100.0:
			var lx: float = _x_of(limit)
			draw_rect(Rect2(lx, y - 2.0, size.x - lx, h + 4.0), Color(danger, 0.30))
			draw_rect(Rect2(lx - 1.0, y - 5.0, 2.0, h + 10.0), danger)
		if warn > 0.0:
			var wx: float = _x_of(warn)
			draw_rect(Rect2(wx - 1.0, y + h + 2.0, 2.0, 4.0), danger)
		var mx: float = _x_of(v)
		draw_rect(Rect2(mx - 1.0, y - 5.0, 2.0, h + 10.0), marker)


## Arco de suspeita da aba Risco.
class Gauge extends Control:
	var zone_colors: Array = []
	var track: Color = Color(1, 1, 1, 0.1)
	var danger: Color = Color.RED
	var limit: float = 100.0    # onde a campanha acaba neste ato
	var value: float = 0.0:
		set(v):
			value = v
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var center: Vector2 = Vector2(size.x * 0.5, size.y - 6.0)
		var radius: float = minf(size.x * 0.5 - 12.0, size.y - 20.0)
		var gap: float = 0.03
		var v: float = clampf(value, 0.0, 100.0)
		for i: int in range(4):
			var a0: float = PI + PI * float(i) / 4.0 + gap
			var a1: float = PI + PI * float(i + 1) / 4.0 - gap
			draw_arc(center, radius, a0, a1, 24, track, 12.0, true)
			var fill: float = clampf((v - float(i) * 25.0) / 25.0, 0.0, 1.0)
			if fill > 0.0:
				draw_arc(center, radius, a0, lerpf(a0, a1, fill), 24, zone_colors[i], 12.0, true)
		if limit < 100.0:
			draw_arc(center, radius + 11.0, PI + PI * limit / 100.0, TAU, 16, danger, 3.0, true)
		var angle: float = PI + PI * v / 100.0
		var tip: Vector2 = center + Vector2(cos(angle), sin(angle)) * (radius + 12.0)
		var tail: Vector2 = center + Vector2(cos(angle), sin(angle)) * (radius - 12.0)
		draw_line(tail, tip, Color.WHITE, 2.0, true)


## Ligações do diagrama de cripto, com pontos que percorrem o caminho.
class FlowLinks extends Control:
	var segments: Array = []
	var line_color: Color = Color.WHITE
	var moving: bool = true
	var _t: float = 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		if moving:
			_t += delta
			queue_redraw()

	func _draw() -> void:
		for seg_v: Variant in segments:
			var seg: Array = seg_v as Array
			var a: Vector2 = seg[0]
			var b: Vector2 = seg[1]
			draw_line(a, b, Color(line_color, 0.30), 2.0)
			draw_line(b + Vector2(-7, -5), b, Color(line_color, 0.8), 2.0, true)
			draw_line(b + Vector2(-7, 5), b, Color(line_color, 0.8), 2.0, true)
			for k: int in range(3):
				var f: float = fmod(_t * 0.45 + float(k) / 3.0, 1.0)
				draw_circle(a.lerp(b, f), 2.5, Color(line_color, sin(f * PI)))


## Miniatura da tela do jogo com uma área em destaque. O manual usa para
## mostrar ONDE fica cada coisa.
class ScreenMap extends Control:
	var focus: String = "all"   # "all", "center", "top" ou "footer"
	var nav_index: int = -1     # item do menu lateral em destaque (-1 = nenhum)
	var nav_count: int = 8
	var line: Color = Color.GRAY
	var fill: Color = Color.BLACK
	var accent: Color = Color.WHITE

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _area(rect: Rect2, lit: bool) -> void:
		draw_rect(rect, Color(accent, 0.14) if lit else fill)
		draw_rect(rect, accent if lit else line, false, 1.0)

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		var rail_w: float = floorf(w * 0.20)
		var x: float = rail_w + 6.0
		var strip: float = floorf(h * 0.15)
		var everything: bool = focus == "all"
		_area(Rect2(0, 0, rail_w, h), everything)
		_area(Rect2(x, 0, w - x, strip), everything or focus == "top")
		_area(Rect2(x, strip + 6.0, w - x, h - strip * 2.0 - 12.0), everything or focus == "center")
		_area(Rect2(x, h - strip, w - x, strip), everything or focus == "footer")
		for i: int in range(nav_count):
			var lit: bool = i == nav_index
			draw_rect(Rect2(5, h * 0.20 + float(i) * h * 0.078, rail_w - 10.0, 4), accent if lit else line)
		# medidor de suspeita no topo e botão de finalizar turno no rodapé
		draw_rect(Rect2(x + (w - x) * 0.42, strip * 0.5 - 1.0, (w - x) * 0.30, 3), accent if focus == "top" else line)
		draw_rect(Rect2(w - (w - x) * 0.26 - 5.0, h - strip + 5.0, (w - x) * 0.26, strip - 10.0), accent if focus == "footer" else line)
