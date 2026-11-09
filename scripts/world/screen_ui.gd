extends Control
## Conteúdo das telas do apartamento (monitores e TV), desenhado dentro de um
## SubViewport e aplicado como textura emissiva na tela 3D.
##
## kind:
##   "main"    patrimônio, meta do ato e gráfico do patrimônio
##   "ledger"  saldos e últimas operações
##   "market"  cotação da cripto e suspeita
##   "news"    TV: manchete e letreiro correndo
##   "dark"    notebook: terminal (fuga e invasão)
## Só se redesenha quando o jogo muda ou a cada meio segundo (relógio, letreiro).

var kind: String = "main"
var world                       # world_3d.gd (lê ui.history)
var _t: float = 0.0
var _ticker_x: float = 0.0
var _boot: float = 0.0          # animação de ligar a tela
var viewport: SubViewport       # a tela 3D só é re-renderizada quando pedimos
var _dirty: bool = true
var _tick: float = 0.0

const INK: Color = Color("#E9E2D3")
const AMBER: Color = Color("#E8A55A")
const BRASS: Color = Color("#C9A35B")
const TEAL: Color = Color("#5FC4B8")
const RED: Color = Color("#E5484D")
const MUTED: Color = Color("#7D8A93")
const BG: Color = Color("#07090B")
const LINE: Color = Color("#1E2730")

func _ready() -> void:
	GameManager.stats_changed.connect(_touch)

func _touch() -> void:
	_dirty = true

func boot() -> void:
	_boot = 0.0

func _process(delta: float) -> void:
	_t += delta
	_boot = minf(1.0, _boot + delta * 1.6)
	_tick += delta
	if kind == "news":
		_ticker_x -= delta * 70.0
	# Letreiro a ~12 quadros por segundo; o resto quando muda, ao ligar, ou a cada 1 s (relógio).
	var period: float = 0.083 if kind == "news" else (0.05 if _boot < 1.0 else 1.0)
	if _dirty or _tick >= period:
		_tick = 0.0
		_dirty = false
		queue_redraw()
		if viewport != null:
			viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func _draw() -> void:
	var s: Vector2 = size
	draw_rect(Rect2(Vector2.ZERO, s), BG)
	# Linhas de varredura discretas: a tela parece um equipamento, não um PNG.
	for y: int in range(0, int(s.y), 3):
		draw_line(Vector2(0, y), Vector2(s.x, y), Color(1, 1, 1, 0.018))
	match kind:
		"main":
			_draw_main(s)
		"ledger":
			_draw_ledger(s)
		"market":
			_draw_market(s)
		"news":
			_draw_news(s)
		"dark":
			_draw_dark(s)
	if _boot < 1.0:
		var band: float = s.y * 0.5 * (1.0 - _boot)
		draw_rect(Rect2(0, 0, s.x, band), Color.BLACK)
		draw_rect(Rect2(0, s.y - band, s.x, band), Color.BLACK)

func _font(mono: bool = true) -> Font:
	var f: Font = UI.font_mono if mono else UI.font_bold
	return f if f != null else ThemeDB.fallback_font

func _text(pos: Vector2, text: String, size_px: int, color: Color, mono: bool = true, width: float = -1.0, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string(_font(mono), pos, text, align, width, size_px, color)

func _header(s: Vector2, title: String, color: Color) -> void:
	_text(Vector2(18, 30), title, 16, color)
	_text(Vector2(0, 30), GameManager.format_time(GameManager.current_time_minutes), 16, MUTED, true, s.x - 18.0, HORIZONTAL_ALIGNMENT_RIGHT)
	draw_line(Vector2(18, 42), Vector2(s.x - 18, 42), LINE, 1.0)

func _series(key: String) -> Array:
	if world == null or world.ui == null:
		return []
	var h: Variant = world.ui.get("history")
	if typeof(h) != TYPE_DICTIONARY:
		return []
	return (h as Dictionary).get(key, []) as Array

func _chart(rect: Rect2, values: Array, color: Color, fill: bool = true) -> void:
	draw_rect(rect, Color(1, 1, 1, 0.02))
	for i: int in range(1, 4):
		var gy: float = rect.position.y + rect.size.y * float(i) / 4.0
		draw_line(Vector2(rect.position.x, gy), Vector2(rect.end.x, gy), Color(1, 1, 1, 0.04), 1.0)
	if values.size() < 2:
		_text(rect.position + Vector2(10, rect.size.y * 0.5), "aguardando dados", 14, MUTED)
		return
	var lo: float = INF
	var hi: float = -INF
	for v: Variant in values:
		lo = minf(lo, float(v))
		hi = maxf(hi, float(v))
	if hi - lo < 1.0:
		hi = lo + 1.0
	var pts: PackedVector2Array = []
	var shown: float = clampf(_boot * 1.4, 0.0, 1.0)
	var count: int = maxi(2, int(ceil(float(values.size()) * shown)))
	for i: int in range(count):
		var x: float = rect.position.x + rect.size.x * float(i) / float(values.size() - 1)
		var y: float = rect.end.y - rect.size.y * (float(values[i]) - lo) / (hi - lo) * 0.9 - rect.size.y * 0.05
		pts.append(Vector2(x, y))
	if fill:
		var poly: PackedVector2Array = pts.duplicate()
		poly.append(Vector2(pts[pts.size() - 1].x, rect.end.y))
		poly.append(Vector2(pts[0].x, rect.end.y))
		draw_colored_polygon(poly, Color(color, 0.12))
	draw_polyline(pts, color, 2.0, true)
	draw_circle(pts[pts.size() - 1], 4.0, color)

func _bar(rect: Rect2, ratio: float, color: Color) -> void:
	draw_rect(rect, Color(1, 1, 1, 0.06))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(ratio, 0.0, 1.0), rect.size.y)), color)

func _draw_main(s: Vector2) -> void:
	_header(s, "PATRIMÔNIO  ·  ATO %d" % Campaign.act, BRASS)
	_text(Vector2(18, 98), UI.money(GameManager.net_worth()), 44, INK, false)
	var ratio: float = Campaign.progress()
	_text(Vector2(18, 130), "META DO ATO  %d%%" % int(ratio * 100.0), 15, AMBER)
	_bar(Rect2(18, 140, s.x - 36, 6), ratio, AMBER)
	_chart(Rect2(18, 162, s.x - 36, s.y - 180), _series("worth"), AMBER)

func _draw_ledger(s: Vector2) -> void:
	_header(s, "LIVRO-CAIXA", TEAL)
	_text(Vector2(18, 74), "SUJO", 13, MUTED)
	_text(Vector2(18, 100), UI.short_money(GameManager.dirty_money), 26, AMBER)
	_text(Vector2(s.x * 0.5, 74), "LIMPO", 13, MUTED)
	_text(Vector2(s.x * 0.5, 100), UI.short_money(GameManager.clean_money), 26, TEAL)
	var y: float = 136.0
	for i: int in range(mini(6, GameManager.transactions.size())):
		var tx: Dictionary = GameManager.transactions[i]
		var line: String = "%s  %s" % [str(tx.get("time", "")), str(tx.get("company", ""))]
		_text(Vector2(18, y), line, 13, INK.darkened(0.15), true, s.x * 0.62)
		_text(Vector2(0, y), "+" + UI.short_money(float(tx.get("clean", 0.0))), 13, TEAL, true, s.x - 18.0, HORIZONTAL_ALIGNMENT_RIGHT)
		y += 22.0
	if GameManager.transactions.is_empty():
		_text(Vector2(18, y), "Nenhuma operação hoje.", 14, MUTED)

func _draw_market(s: Vector2) -> void:
	_header(s, "MERCADO  ·  CRIPTO", TEAL)
	_text(Vector2(18, 92), UI.money(Portfolio.crypto_price), 30, INK, false)
	_chart(Rect2(18, 108, s.x - 36, s.y * 0.42), Portfolio.price_history, TEAL, false)
	var susp: float = GameManager.suspicion
	var y: float = 118.0 + s.y * 0.42 + 26.0
	_text(Vector2(18, y), "SUSPEITA  %d%%" % int(round(susp)), 15, RED if susp >= 60.0 else MUTED)
	_bar(Rect2(18, y + 10, s.x - 36, 6), susp / 100.0, RED if susp >= 60.0 else AMBER)

func _draw_news(s: Vector2) -> void:
	var red: Color = Color("#B3262B")
	draw_rect(Rect2(0, 0, s.x, 40), Color("#121518"))
	draw_rect(Rect2(0, 0, 150, 40), red)
	_text(Vector2(14, 28), "PLANTÃO", 20, Color.WHITE, false)
	_text(Vector2(166, 28), "CANAL 7  ·  AO VIVO", 15, MUTED)
	var tag: String = "SEM NOTÍCIAS"
	var title: String = "A cidade dorme. Por enquanto."
	if not GameManager.news_log.is_empty():
		var n: Dictionary = GameManager.news_log[0]
		tag = str(n.get("tag", "")).to_upper()
		title = str(n.get("title", ""))
	_text(Vector2(24, 100), tag, 16, AMBER)
	_wrap(Vector2(24, 140), title, 34, INK, s.x - 48.0, 3)
	# Letreiro correndo com as manchetes anteriores.
	draw_rect(Rect2(0, s.y - 46, s.x, 46), red.darkened(0.35))
	var parts: PackedStringArray = []
	for i: int in range(1, mini(6, GameManager.news_log.size())):
		parts.append(str((GameManager.news_log[i] as Dictionary).get("title", "")).to_upper())
	if parts.is_empty():
		parts.append("BOLSA FECHA ESTÁVEL  ·  TRÂNSITO INTENSO NA MARGINAL  ·  CHUVA À NOITE")
	var ticker: String = "   ●   ".join(parts) + "   ●   "
	var w: float = _font().get_string_size(ticker, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	if _ticker_x < -w:
		_ticker_x += w
	_text(Vector2(_ticker_x, s.y - 16), ticker + ticker, 18, Color.WHITE)

func _wrap(pos: Vector2, text: String, size_px: int, color: Color, width: float, max_lines: int) -> void:
	var words: PackedStringArray = text.split(" ")
	var line: String = ""
	var y: float = pos.y
	var lines: int = 0
	for word: String in words:
		var probe: String = word if line == "" else line + " " + word
		if _font(false).get_string_size(probe, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x > width and line != "":
			_text(Vector2(pos.x, y), line, size_px, color, false)
			y += size_px * 1.2
			lines += 1
			line = word
			if lines >= max_lines:
				return
		else:
			line = probe
	if line != "":
		_text(Vector2(pos.x, y), line, size_px, color, false)

func _draw_dark(s: Vector2) -> void:
	var green: Color = Color("#7CE38B")
	var violet: Color = Color("#B79CFF")
	if Campaign.escape_active:
		_text(Vector2(16, 30), "> tor://mercado ... conectado", 15, violet)
		_text(Vector2(16, 60), "> monero: %s" % UI.short_money(Portfolio.monero), 15, green)
		_text(Vector2(16, 88), "> horas restantes: %d" % int(round(Campaign.escape_hours)), 15, green)
	else:
		var lines: Array = ["> ssh relay-04.onion", "> trace --clean", "> logs: 1.204 linhas", "> aguardando operador_"]
		for i: int in range(lines.size()):
			_text(Vector2(16, 30 + i * 28), str(lines[i]), 15, green if i < 3 else green.darkened(0.3 * float(int(_t * 2.0) % 2)))
