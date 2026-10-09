extends Control
## PixelCanvas — base das cenas em pixel art (troca de turno e finais).
##
## A cena é desenhada em uma grade de 228 x 128 "pixels grandes", ampliada
## para caber na janela. Tudo é desenhado por código em _draw(): retângulos na
## grade (px) e sprites descritos como texto (sprite), onde cada letra é uma
## cor da paleta. As cenas filhas sobrescrevem _paint() e usam `t` (segundos
## desde o início) para animar.

signal finished

const GRID_W: int = 228
const GRID_H: int = 128

## Algarismos 3 x 5 para relógios e placas.
const DIGITS: Dictionary = {
	"0": ["###", "#.#", "#.#", "#.#", "###"],
	"1": [".#.", "##.", ".#.", ".#.", "###"],
	"2": ["###", "..#", "###", "#..", "###"],
	"3": ["###", "..#", "###", "..#", "###"],
	"4": ["#.#", "#.#", "###", "..#", "..#"],
	"5": ["###", "#..", "###", "..#", "###"],
	"6": ["###", "#..", "###", "#.#", "###"],
	"7": ["###", "..#", "..#", ".#.", ".#."],
	"8": ["###", "#.#", "###", "#.#", "###"],
	"9": ["###", "#.#", "###", "..#", "###"],
	":": [".", "#", ".", "#", "."]
}

## Paleta do personagem.
const HERO_COLORS: Dictionary = {
	"h": Color("#1B1718"), "s": Color("#C98D6C"), "d": Color("#A26E55"), "e": Color("#1B1718"),
	"j": Color("#2F4D62"), "k": Color("#223948"), "c": Color("#63E7F4"),
	"p": Color("#1B2733"), "q": Color("#141D26"), "b": Color("#0C1015")
}
## Cabeça e tronco, de perfil, olhando para a direita (10 x 15).
const HERO_TOP: Array = [
	"...hhhh...",
	"..hhhhhh..",
	"..hhhhss..",
	"..hhssss..",
	"..hsssed..",
	"...sssss..",
	"...ssss...",
	"....sd....",
	"..jjjjjj..",
	".jjjjjjjj.",
	".jjkjjcjj.",
	".jjkjjjjj.",
	".jjkjjjjs.",
	".jjkjjjj..",
	"..jjjjjj.."
]
## Pernas em pé e em dois momentos do passo (10 x 9).
const HERO_LEGS: Array = [
	["..pppppp..", "..pppppp..", "..ppp.qqq.", "..ppp.qqq.", "..ppp.qqq.", "..ppp.qqq.", "..ppp.qqq.", "..bbb.bbb.", "..bbbbbbbb"],
	["..pppppp..", ".pppppppp.", ".ppp..qqq.", "ppp....qqq", "ppp....qqq", "pp......qq", "pp......qq", "bb......bb", "bbb....bbb"],
	["..pppppp..", "..pppppp..", "...ppqq...", "...ppqq...", "...ppqq...", "...ppqq...", "...ppqq...", "...bbbb...", "...bbbbb.."]
]
## De costas, sentado diante da mesa (10 x 14).
const HERO_BACK: Array = [
	"...hhhh...",
	"..hhhhhh..",
	"..hhhhhh..",
	"..hhhhhh..",
	"..hhhhhh..",
	"...hhhh...",
	"....dd....",
	"..jjjjjj..",
	".jjjjjjjj.",
	".jkjjjjkj.",
	".jkjjjjkj.",
	".jkjjjjkj.",
	".jjjjjjjj.",
	"..jjjjjj.."
]

var t: float = 0.0
var duration: float = 6.0
var playing: bool = true
var skippable: bool = true

var _unit: float = 6.0              # tamanho de um "pixel grande" na tela
var _origin: Vector2 = Vector2.ZERO
var _done: bool = false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 150
	theme = UI.theme
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Sem isto, o Espaço acionaria de novo o botão que abriu a cena em vez de pulá-la.
	get_viewport().gui_release_focus()

func _process(delta: float) -> void:
	if playing and not _done:
		t += delta
		if t >= duration:
			t = duration
			_finish()
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed:
		skip()

func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo:
		if key.keycode == KEY_SPACE or key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER or key.keycode == KEY_ESCAPE:
			skip()
		get_viewport().set_input_as_handled()

## Pula direto para o fim da cena.
func skip() -> void:
	if skippable and not _done:
		_finish()

func _finish() -> void:
	if _done:
		return
	_done = true
	var tw: Tween = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.28 if UI.motion else 0.0)
	tw.tween_callback(func() -> void: finished.emit())

func _draw() -> void:
	# Arredonda para o inteiro mais próximo: em 1366 x 768 dá 6, e a grade cobre a tela.
	_unit = maxf(1.0, roundf(minf(size.x / float(GRID_W), size.y / float(GRID_H))))
	_origin = ((size - Vector2(GRID_W, GRID_H) * _unit) * 0.5).floor()
	draw_rect(Rect2(Vector2.ZERO, size), Color("#04070A"))
	_paint()
	# Barras laterais, se a janela for mais larga que a grade.
	if _origin.x > 0.0:
		draw_rect(Rect2(0, 0, _origin.x, size.y), Color("#04070A"))
		draw_rect(Rect2(size.x - _origin.x, 0, _origin.x + 1.0, size.y), Color("#04070A"))

## As cenas filhas desenham aqui.
func _paint() -> void:
	pass

# ---------- primitivas ----------

## Retângulo na grade.
func px(x: float, y: float, w: float, h: float, color: Color) -> void:
	if color.a <= 0.0 or w <= 0.0 or h <= 0.0:
		return
	draw_rect(Rect2(_origin + Vector2(x, y) * _unit, Vector2(w, h) * _unit), color)

## Converte um ponto da grade para a tela (para polígonos de luz).
func at_grid(x: float, y: float) -> Vector2:
	return _origin + Vector2(x, y) * _unit

## Polígono na grade (feixes de luz, telhados).
func poly(points: Array, color: Color) -> void:
	var screen: PackedVector2Array = PackedVector2Array()
	for point_v: Variant in points:
		var point: Vector2 = point_v
		screen.append(at_grid(point.x, point.y))
	draw_colored_polygon(screen, color)

## Desenha um sprite descrito em linhas de texto. Cada letra é uma cor da paleta;
## ponto é transparente. flip espelha na horizontal.
func sprite(rows: Array, x: float, y: float, palette: Dictionary, flip: bool = false, alpha: float = 1.0) -> void:
	for row_index: int in range(rows.size()):
		var row: String = rows[row_index]
		var width: int = row.length()
		for col: int in range(width):
			var key: String = row[col]
			if key == "." or not palette.has(key):
				continue
			var color: Color = palette[key]
			var gx: float = x + float(width - 1 - col if flip else col)
			px(gx, y + float(row_index), 1, 1, Color(color, color.a * alpha))

## Texto de algarismos 3 x 5 (relógios).
func digits(text: String, x: float, y: float, color: Color) -> void:
	var cursor: float = x
	for i: int in range(text.length()):
		var glyph: Array = DIGITS.get(text[i], [])
		var width: int = 0
		for row_index: int in range(glyph.size()):
			var row: String = glyph[row_index]
			width = row.length()
			for col: int in range(width):
				if row[col] == "#":
					px(cursor + float(col), y + float(row_index), 1, 1, color)
		cursor += float(width) + 1.0

## Cor ao longo de uma lista de marcos [[posição 0..1, cor], ...].
func ramp(keys: Array, f: float) -> Color:
	var first: Array = keys[0]
	if f <= float(first[0]):
		return first[1]
	for i: int in range(1, keys.size()):
		var a: Array = keys[i - 1]
		var b: Array = keys[i]
		if f <= float(b[0]):
			var width: float = maxf(float(b[0]) - float(a[0]), 0.0001)
			return (a[1] as Color).lerp(b[1], (f - float(a[0])) / width)
	return (keys[keys.size() - 1] as Array)[1]

## Progresso 0..1 de um trecho da linha do tempo, com suavização.
func span(from: float, to: float, ease_out: bool = false) -> float:
	var f: float = clampf((t - from) / maxf(to - from, 0.0001), 0.0, 1.0)
	return 1.0 - pow(1.0 - f, 2.0) if ease_out else f

## Número pseudoaleatório fixo para um índice (estrelas, janelas): sempre o mesmo
## a cada quadro, para a cena não "ferver".
func noise(index: int, salt: int = 0) -> float:
	var n: int = (index * 73856093) ^ (salt * 19349663) ^ 0x5bd1e995
	n = (n ^ (n >> 13)) * 1274126177
	return float(absi(n) % 10007) / 10007.0

# ---------- personagem ----------

## Personagem em pé ou andando. x é a coluna da esquerda; feet é a linha do chão.
## step: 0 parado; 1 e 2 alternam no passo.
func hero_stand(x: float, feet: float, step: int = 0, flip: bool = false, palette: Dictionary = HERO_COLORS) -> void:
	sprite(HERO_TOP, x, feet - 24.0, palette, flip)
	sprite(HERO_LEGS[step], x, feet - 9.0, palette, flip)

func hero_walk(x: float, feet: float, flip: bool = false, palette: Dictionary = HERO_COLORS) -> void:
	# Dois quadros de passo alternando; o corpo sobe 1 pixel no meio do passo.
	var phase: int = int(floor(t * 7.0)) % 2
	hero_stand(x, feet - float(phase), 1 if phase == 0 else 2, flip, palette)

## Personagem de costas, sentado. top é a linha do alto da cabeça.
func hero_back(x: float, top: float, palette: Dictionary = HERO_COLORS) -> void:
	sprite(HERO_BACK, x, top, palette)
