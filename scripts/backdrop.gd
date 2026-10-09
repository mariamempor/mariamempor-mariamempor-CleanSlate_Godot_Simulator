extends Control
## Fundo das telas.
##
## "menu": a cidade à noite, em pixel art, no mesmo estilo da troca de turno
## (céu em faixas, estrelas, lua e prédios com janelas acesas).
## "dashboard": fundo liso com uma grade discreta, para não disputar atenção
## com os painéis. "plain": a mesma grade, sem a moldura do dashboard.

const UNIT: float = 6.0             # tamanho do "pixel grande", igual ao das cenas
const SIDEBAR_W: float = 248.0

var mode: String = "menu"
var pulse: float = 0.0

func set_mode(new_mode: String) -> void:
	mode = new_mode
	queue_redraw()

func _process(delta: float) -> void:
	pulse += delta
	queue_redraw()

func _draw() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	if mode == "menu":
		_draw_menu(viewport_size)
	else:
		_draw_dashboard(viewport_size, mode == "dashboard")

## Número pseudoaleatório fixo para um índice: a cidade é sempre a mesma.
func _noise(index: int, salt: int = 0) -> float:
	var n: int = (index * 73856093) ^ (salt * 19349663) ^ 0x5bd1e995
	n = (n ^ (n >> 13)) * 1274126177
	return float(absi(n) % 10007) / 10007.0

func _draw_menu(view: Vector2) -> void:
	# Céu: do azul quase preto, no alto, a um azul mais claro no horizonte.
	var top: Color = Color("#040A18")
	var low: Color = Color("#12233F")
	var bands: int = 18
	for i: int in range(bands):
		var f: float = float(i) / float(bands - 1)
		draw_rect(Rect2(0, view.y * float(i) / float(bands), view.x, view.y / float(bands) + 1.0), top.lerp(low, f * f))
	# Estrelas piscando devagar.
	for i: int in range(90):
		var sx: float = floorf(_noise(i, 1) * view.x / UNIT) * UNIT
		var sy: float = floorf(_noise(i, 2) * view.y * 0.62 / UNIT) * UNIT
		var twinkle: float = 0.45 + 0.55 * sin(pulse * (0.6 + _noise(i, 3) * 1.8) + float(i))
		draw_rect(Rect2(sx, sy, UNIT * 0.5, UNIT * 0.5), Color(0.86, 0.93, 1.0, 0.55 * twinkle))
	# Lua.
	var moon: Vector2 = Vector2(floorf(view.x * 0.56 / UNIT) * UNIT, UNIT * 12.0)
	draw_rect(Rect2(moon + Vector2(UNIT, 0), Vector2(UNIT * 4.0, UNIT * 6.0)), Color("#E6EBDD"))
	draw_rect(Rect2(moon + Vector2(0, UNIT), Vector2(UNIT * 6.0, UNIT * 4.0)), Color("#E6EBDD"))
	draw_rect(Rect2(moon + Vector2(UNIT * 3.0, UNIT * 2.0), Vector2(UNIT, UNIT)), Color("#C3C9BC"))
	draw_rect(Rect2(moon + Vector2(UNIT * 1.0, UNIT * 3.0), Vector2(UNIT, UNIT)), Color("#C3C9BC"))

	# Duas fileiras de prédios: uma distante, mais clara, e uma próxima, mais escura.
	_skyline(view, 11, view.y * 0.34, Color("#0E1C33"), 0.10, 0.5)
	_skyline(view, 23, view.y * 0.24, Color("#070F1D"), 0.30, 1.0)
	draw_rect(Rect2(0, view.y - UNIT * 3.0, view.x, UNIT * 3.0), Color("#04080F"))

## Uma fileira de prédios ao longo da base da tela.
func _skyline(view: Vector2, salt: int, max_height: float, color: Color, lit: float, glow: float) -> void:
	var x: float = -UNIT * 2.0
	var index: int = 0
	while x < view.x:
		var w: float = floorf(5.0 + _noise(index, salt) * 9.0) * UNIT
		var h: float = floorf((0.35 + _noise(index, salt + 1) * 0.65) * max_height / UNIT) * UNIT
		var top: float = view.y - h
		draw_rect(Rect2(x, top, w, h), color)
		# Janelas: uma parte fica acesa; algumas apagam e acendem de vez em quando.
		var cols: int = int(w / UNIT)
		var rows: int = int(h / UNIT)
		for row: int in range(2, rows - 1, 2):
			for col: int in range(1, cols - 1, 2):
				var id: int = index * 977 + row * 31 + col
				if _noise(id, salt + 2) > lit:
					continue
				var blink: bool = _noise(id, salt + 3) < 0.12 and sin(pulse * 0.4 + float(id)) < -0.6
				if blink:
					continue
				var warm: bool = _noise(id, salt + 4) < 0.72
				draw_rect(Rect2(x + float(col) * UNIT, top + float(row) * UNIT, UNIT, UNIT), Color(0.95, 0.79, 0.30, 0.85 * glow) if warm else Color(0.39, 0.91, 0.96, 0.85 * glow))
		# Antena com luz vermelha nos prédios mais altos da fileira da frente.
		if glow >= 1.0 and h > max_height * 0.82:
			draw_rect(Rect2(x + floorf(float(cols) * 0.5) * UNIT, top - UNIT * 4.0, UNIT, UNIT * 4.0), color)
			if int(floor(pulse * 1.2 + float(index))) % 2 == 0:
				draw_rect(Rect2(x + floorf(float(cols) * 0.5) * UNIT, top - UNIT * 5.0, UNIT, UNIT), Color("#F25555"))
		x += w + floorf(_noise(index, salt + 5) * 2.0) * UNIT
		index += 1

## framed = true desenha a moldura do dashboard (grade a partir do menu lateral
## e a linha sob o topo). As outras telas usam só a grade ("plain").
func _draw_dashboard(view: Vector2, framed: bool) -> void:
	draw_rect(Rect2(Vector2.ZERO, view), Color("#061018"))
	var left: float = SIDEBAR_W if framed else 0.0
	for x: int in range(int(left), int(view.x), 34):
		draw_line(Vector2(x, 0), Vector2(x, view.y), Color(0.12, 0.25, 0.30, 0.07), 1.0)
	for y: int in range(14, int(view.y), 34):
		draw_line(Vector2(left, y), Vector2(view.x, y), Color(0.12, 0.25, 0.30, 0.055), 1.0)
	if framed:
		# Linha sob o topo, pulsando de leve.
		var glow: float = 0.14 + 0.05 * sin(pulse * 1.8)
		draw_rect(Rect2(SIDEBAR_W, 81, view.x - SIDEBAR_W, 1), Color(0.35, 0.91, 0.96, glow))
