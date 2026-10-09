extends "res://scripts/ui/pixel_canvas.gd"
## Troca de turno: uma noite inteira em poucos segundos.
##
## Uma cena contínua, sem cortes: o operador desliga o PC, apaga a luminária,
## atravessa o quarto e deita. A noite passa em time-lapse na janela (lua,
## estrelas, luzes dos prédios se apagando, relógio correndo), amanhece, ele
## levanta, volta para a mesa e o PC inicializa. Enquanto isso, o painel à
## esquerda mostra o fechamento do dia, linha por linha.
##
## Linha do tempo (segundos):
##   0.0  trabalhando        0.5  desliga o PC       1.15 apaga a luminária
##   1.2  anda até a cama    2.4  deita              2.6  a noite passa
##   4.8  amanhece, acorda   5.1  anda até a mesa    6.2  senta, PC liga
##   6.9  clarão do monitor  7.2  fim

const B = preload("res://scripts/data/balance.gd")

const FLOOR: float = 92.0           # linha em que a parede encontra o piso
const GROUND: float = 106.0         # linha dos pés
const DESK_X: float = 180.0         # coluna do personagem na mesa
const BED_X: float = 56.0           # coluna do personagem ao lado da cama
const WINDOW_X: float = 92.0        # borda esquerda do vidro da janela
const MONITOR_Y: float = 48.0       # alto da moldura do monitor
const SEAT_HEAD: float = 75.0       # alto da cabeça do personagem sentado

var report: Dictionary = {}
## As cenas de final reaproveitam o quarto, mas sem o painel de fechamento.
var ledger_enabled: bool = true
var _lines: Array = []              # rótulos do fechamento, na ordem em que aparecem
var _title: Label
var _day_title: Label

func _ready() -> void:
	super._ready()
	if not ledger_enabled:
		return
	duration = 7.2 if UI.motion else 2.2
	_build_ledger()

# ---------------------------------------------------------
# Fechamento do dia (texto por cima da cena)
# ---------------------------------------------------------

func _build_ledger() -> void:
	var view: Vector2 = get_viewport_rect().size
	var width: float = 400.0
	var panel: PanelContainer = PanelContainer.new()
	var box: StyleBoxFlat = UI.flat(Color(0.024, 0.055, 0.082, 0.90), UI.LINE, 8)
	box.set_content_margin_all(20.0)
	panel.add_theme_stylebox_override("panel", box)
	panel.custom_minimum_size.x = width
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 9)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(col)

	col.add_child(UI.caps("ATO %d  /  FECHAMENTO" % int(report.get("act", 1)), UI.CYAN, 11))
	_title = UI.display("DIA %02d" % int(report.get("day", 1)), 34, UI.WHITE)
	col.add_child(_title)
	col.add_child(UI.spacer(2))

	var rows: Array = []
	var operations: int = int(report.get("operations", 0))
	rows.append([("Processado em 1 operação" if operations == 1 else "Processado em %d operações" % operations) if operations > 0 else "Nenhuma operação hoje", UI.money(float(report.get("processed", 0.0))), UI.ORANGE if operations > 0 else UI.MUTED])
	rows.append(["Entrou no saldo limpo", "+ " + UI.money(float(report.get("clean", 0.0))), UI.GREEN])
	if float(report.get("wages", 0.0)) > 0.0:
		rows.append(["Folha dos laranjas", "- " + UI.money(float(report["wages"])), UI.WHITE])
	if absf(float(report.get("yield", 0.0))) >= 1.0:
		var gain: float = float(report["yield"])
		rows.append(["Rendimento dos fundos", ("+ " if gain >= 0.0 else "- ") + UI.money(absf(gain)), UI.GREEN if gain >= 0.0 else UI.RED])
	if float(report.get("remessa", 0.0)) > 0.0:
		rows.append(["Remessa desta noite", "+ " + UI.money(float(report["remessa"])), UI.ORANGE])
	var before: float = float(report.get("suspicion_day", 0.0))
	var after: float = float(report.get("suspicion_end", 0.0))
	rows.append(["Suspeita", "%s  >  %s" % [UI.pct(before), UI.pct(after)], UI.risk_color(after)])
	var goal: float = maxf(float(report.get("goal", 1.0)), 1.0)
	rows.append(["Patrimônio", "%s  (%d%%)" % [UI.short_money(float(report.get("net_worth", 0.0))), int(clampf(float(report.get("net_worth", 0.0)) / goal, 0.0, 1.0) * 100.0)], UI.CYAN])
	for row_v: Variant in rows:
		var row: Array = row_v as Array
		var line: HBoxContainer = UI.kv_line(str(row[0]), str(row[1]), row[2])
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(line)
		_lines.append(line)

	# Avisos: o que deu errado na noite e o que espera uma decisão.
	var warnings: Array[String] = []
	if bool(report.get("pile", false)):
		warnings.append("Dinheiro sujo parado chamou atenção: suspeita +%d." % int(B.PILE_PENALTY))
	if int(report.get("unpaid", 0)) > 0:
		warnings.append("%d laranja(s) ficaram sem pagamento." % int(report["unpaid"]))
	if not Campaign.events.is_empty():
		warnings.append("%d assunto(s) esperando a sua decisão." % Campaign.events.size())
	for warning: String in warnings:
		var label: Label = UI.paragraph(warning, 13, UI.ORANGE, width - 40.0)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(label)
		_lines.append(label)
	panel.position = Vector2(48, 44) if UI.motion else Vector2((view.x - width) * 0.5, 150)

	# Título do novo dia, no alto à direita, quando amanhece.
	_day_title = UI.display("", 46, UI.WHITE)
	_day_title.size = Vector2(320, 60)
	_day_title.position = Vector2(view.x - 368.0, 40)
	_day_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_day_title.modulate.a = 0.0
	_day_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if Campaign.ending == "" and not Campaign.escape_active:
		_day_title.text = "ATO %d  /  DIA %02d" % [int(report.get("next_act", 1)), int(report.get("next_day", 1))]
	add_child(_day_title)

	var hint: Label = UI.caps("CLIQUE OU ESPAÇO PARA PULAR", Color(1, 1, 1, 0.35), 10)
	hint.position = Vector2(view.x - 250.0, view.y - 34.0)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)
	_update_ledger()

func _process(delta: float) -> void:
	super._process(delta)
	_update_ledger()

func _update_ledger() -> void:
	if not ledger_enabled:
		return
	# As linhas aparecem uma a uma enquanto a noite passa.
	var start: float = 1.3 if UI.motion else 0.0
	var step: float = 0.32 if UI.motion else 0.0
	for i: int in range(_lines.size()):
		var node: Control = _lines[i]
		node.modulate.a = clampf((t - start - float(i) * step) / 0.25, 0.0, 1.0) if UI.motion else 1.0
	if _day_title != null:
		_day_title.modulate.a = span(5.0, 5.5) if UI.motion else 0.0

# ---------------------------------------------------------
# Cena
# ---------------------------------------------------------

func _paint() -> void:
	if not UI.motion:
		return
	# night: 0 no começo da noite, 1 ao amanhecer.
	var night: float = span(2.6, 4.8)
	var dawn: float = smoothstep(0.70, 1.0, night)
	var lamp_on: bool = t < 1.15
	var dark: float = 0.0
	if not lamp_on:
		dark = lerpf(0.40, 0.62, span(1.15, 2.8)) * (1.0 - dawn)

	_room(lamp_on, dawn)
	_desk(lamp_on)
	_bed()
	_hero_in_room()
	# Escuridão da noite por cima do quarto. O que emite luz é redesenhado depois.
	px(0, 0, GRID_W, GRID_H, Color(0.01, 0.03, 0.09, dark))
	if dawn > 0.0 and dawn < 1.0:
		px(0, 0, GRID_W, GRID_H, Color(0.95, 0.55, 0.30, 0.10 * sin(dawn * PI)))
	_window(night, dawn)
	_light_beam(night, dawn, dark)
	_clock(night)
	_monitor()
	_sleep_marks()
	# Clarão do monitor no fim: a tela "engole" a cena e vira o dashboard.
	var flash: float = span(6.85, 7.15)
	if flash > 0.0:
		px(0, 0, GRID_W, GRID_H, Color(0.62, 0.95, 1.0, flash * 0.9))

func _room(lamp_on: bool, dawn: float) -> void:
	var wall: Color = Color("#1B2A38").lerp(Color("#2A3D4E"), dawn * 0.7)
	px(0, 0, GRID_W, FLOOR, wall)
	# Faixa mais escura no alto e rodapé.
	px(0, 0, GRID_W, 6, wall.darkened(0.25))
	px(0, FLOOR - 3.0, GRID_W, 3, Color("#111A22"))
	# Piso de tábuas.
	px(0, FLOOR, GRID_W, GRID_H - FLOOR, Color("#2A211D"))
	for i: int in range(6):
		px(0, FLOOR + 5.0 + float(i) * 6.0, GRID_W, 1, Color("#221A17"))
	for i: int in range(24):
		px(float(i) * 19.0 + float((i * 7) % 11), FLOOR + float((i % 6)) * 6.0, 1, 5, Color("#221A17"))
	# Tapete.
	px(98, 111, 54, 9, Color("#1D3540"))
	px(100, 112, 50, 7, Color("#234452"))
	px(104, 115, 42, 1, Color("#2F5B6B"))
	# Planta no canto.
	px(216, 96, 8, 10, Color("#5A4338"))
	px(215, 95, 10, 2, Color("#6B5044"))
	for leaf: Array in [[217, 84, 2, 12], [220, 80, 2, 16], [214, 88, 2, 8], [223, 86, 2, 10], [218, 78, 2, 4]]:
		px(leaf[0], leaf[1], leaf[2], leaf[3], Color("#2F6B4F"))
	# Luz quente da luminária na parede, enquanto está acesa.
	if lamp_on:
		poly([Vector2(156, 72), Vector2(161, 72), Vector2(176, 92), Vector2(140, 92)], Color(1.0, 0.78, 0.45, 0.10))

func _bed() -> void:
	# Cabeceira, estrado, colchão, travesseiro e cobertor.
	px(9, 74, 5, 32, Color("#22303B"))
	px(14, 97, 58, 6, Color("#2B3A47"))
	px(15, 103, 3, 3, Color("#1A242D"))
	px(67, 103, 3, 3, Color("#1A242D"))
	px(14, 90, 58, 7, Color("#C9D0D4"))
	px(16, 86, 13, 5, Color("#E6EBED"))
	px(16, 90, 13, 1, Color("#B5BDC2"))
	px(30, 88, 42, 9, Color("#6A3F51"))
	px(30, 88, 42, 2, Color("#7E4C61"))
	px(70, 90, 2, 12, Color("#5A3445"))

func _desk(lamp_on: bool) -> void:
	# Criado-mudo (o relógio é desenhado depois, por cima da escuridão).
	px(74, 93, 22, 13, Color("#3A2B25"))
	px(73, 92, 24, 2, Color("#4A372F"))
	px(77, 98, 16, 1, Color("#2B201B"))
	px(84, 100, 2, 1, Color("#7A6252"))
	# Gabinete do PC, embaixo da mesa.
	px(198, 91, 9, 15, Color("#11171C"))
	px(200, 94, 1, 1, Color("#62E3A2") if t < 0.9 or t > 6.25 else Color("#1E2A30"))
	# Mesa.
	px(150, 84, 64, 3, Color("#4A372F"))
	px(150, 87, 64, 1, Color("#3A2B25"))
	px(152, 88, 3, 18, Color("#2B201B"))
	px(209, 88, 3, 18, Color("#2B201B"))
	# Pé do monitor (a tela é desenhada depois, por cima da escuridão).
	px(184, 74, 4, 8, Color("#1A2228"))
	px(179, 82, 14, 2, Color("#1A2228"))
	# Teclado e caneca.
	px(177, 84, 18, 1, Color("#39434C"))
	px(205, 79, 4, 5, Color("#C9D0D4"))
	px(209, 80, 1, 3, Color("#C9D0D4"))
	# Luminária de mesa.
	px(155, 82, 6, 2, Color("#51443A"))
	px(157, 74, 1, 8, Color("#51443A"))
	px(154, 70, 9, 3, Color("#B68A5D"))
	px(156, 73, 5, 1, Color("#FFE2A8") if lamp_on else Color("#3A3028"))
	# Cadeira (de costas para a câmera).
	px(176, 98, 18, 2, Color("#18222B"))
	px(184, 100, 2, 4, Color("#10171D"))
	px(178, 104, 14, 2, Color("#10171D"))

func _hero_in_room() -> void:
	var seated_evening: bool = t < 1.0
	var seated_morning: bool = t >= 6.2
	if seated_evening or seated_morning:
		# De costas, digitando: os ombros balançam um pixel.
		var typing: bool = seated_evening and t < 0.5 or seated_morning and t > 6.5
		var bob: float = 1.0 if typing and int(floor(t * 9.0)) % 2 == 0 else 0.0
		hero_back(DESK_X, SEAT_HEAD)
		# Mãos no teclado: alternam de lado enquanto ele digita.
		px(DESK_X - 2.0 + bob, 83, 2, 1, HERO_COLORS["s"])
		px(DESK_X + 10.0 - bob, 83, 2, 1, HERO_COLORS["s"])
		# Encosto da cadeira por cima do tronco.
		px(178, 87, 14, 11, Color("#18222B"))
		px(179, 88, 12, 1, Color("#243240"))
		return
	if t < 1.2:
		hero_stand(DESK_X, GROUND, 0, true)
	elif t < 2.4:
		hero_walk(lerpf(DESK_X, BED_X, span(1.2, 2.4)), GROUND, true)
	elif t < 4.9:
		# Dormindo: cabeça no travesseiro e o cobertor subindo e descendo com a respiração.
		var breath: float = 1.0 if int(floor(t * 1.6)) % 2 == 0 else 0.0
		px(19, 84, 6, 2, HERO_COLORS["h"])
		px(19, 86, 6, 3, HERO_COLORS["s"])
		px(18, 85, 1, 3, HERO_COLORS["h"])
		px(30, 87.0 - breath, 30, 2.0 + breath, Color("#7E4C61"))
		px(30, 89, 42, 8, Color("#6A3F51"))
	elif t < 5.1:
		hero_stand(BED_X, GROUND, 0, false)
	else:
		hero_walk(lerpf(BED_X, DESK_X, span(5.1, 6.2)), GROUND, false)

## Janela: céu em faixas, estrelas, lua, sol e a cidade com as luzes se apagando.
func _window(night: float, dawn: float) -> void:
	var x0: float = WINDOW_X
	var y0: float = 18.0
	var w: float = 60.0
	var h: float = 46.0
	var sky_top: Array = [[0.0, Color("#050B1C")], [0.60, Color("#050B1C")], [0.80, Color("#2A2250")], [0.92, Color("#6A5A9E")], [1.0, Color("#6FB4E0")]]
	var sky_low: Array = [[0.0, Color("#0C1832")], [0.60, Color("#0E1B38")], [0.80, Color("#7A3F5E")], [0.92, Color("#F09A5C")], [1.0, Color("#C4E6F4")]]
	var top: Color = ramp(sky_top, night)
	var low: Color = ramp(sky_low, night)
	var bands: int = 12
	for i: int in range(bands):
		var f: float = float(i) / float(bands - 1)
		px(x0, y0 + h * float(i) / float(bands), w, h / float(bands) + 0.5, top.lerp(low, f * f))
	# Estrelas: somem com a aurora e piscam de leve.
	var star_alpha: float = 1.0 - smoothstep(0.62, 0.86, night)
	for i: int in range(26):
		var sx: float = x0 + floorf(noise(i, 1) * (w - 1.0))
		var sy: float = y0 + floorf(noise(i, 2) * (h * 0.62))
		var twinkle: float = 0.55 + 0.45 * sin(t * (2.0 + noise(i, 3) * 4.0) + float(i))
		px(sx, sy, 1, 1, Color(0.90, 0.95, 1.0, star_alpha * twinkle))
	# Lua: cruza a janela em arco.
	var moon_f: float = clampf(night / 0.78, 0.0, 1.0)
	var moon_alpha: float = 1.0 - smoothstep(0.66, 0.84, night)
	if moon_alpha > 0.0:
		var mx: float = floorf(x0 + 4.0 + moon_f * (w - 14.0))
		var my: float = floorf(y0 + 15.0 - sin(moon_f * PI) * 9.0)
		px(mx + 1.0, my, 3, 5, Color(0.93, 0.95, 0.88, moon_alpha))
		px(mx, my + 1.0, 5, 3, Color(0.93, 0.95, 0.88, moon_alpha))
		px(mx + 3.0, my + 1.0, 1, 1, Color(0.75, 0.78, 0.74, moon_alpha))
	# Sol nascendo atrás dos prédios.
	if night > 0.82:
		var rise: float = smoothstep(0.82, 1.0, night)
		var sun_y: float = floorf(y0 + h - 6.0 - rise * 12.0)
		px(x0 + 37.0, sun_y - 1.0, 9, 9, Color(1.0, 0.80, 0.45, 0.25 * rise))
		px(x0 + 39.0, sun_y, 5, 7, Color(1.0, 0.90, 0.62, rise))
		px(x0 + 38.0, sun_y + 1.0, 7, 5, Color(1.0, 0.90, 0.62, rise))
	# Cidade: silhuetas e janelas acesas. As luzes vão se apagando madrugada adentro.
	var building: Color = Color("#081220").lerp(Color("#3F5670"), dawn)
	var lit: float = lerpf(0.62, 0.10, smoothstep(0.0, 0.55, night)) * (1.0 - smoothstep(0.80, 0.95, night))
	var skyline: Array = [[0, 9, 20], [9, 6, 29], [15, 10, 16], [25, 7, 34], [32, 9, 24], [41, 7, 31], [48, 12, 18]]
	for b: int in range(skyline.size()):
		var bx: float = x0 + float(skyline[b][0])
		var bw: float = float(skyline[b][1])
		var bh: float = float(skyline[b][2])
		px(bx, y0 + h - bh, bw, bh, building if b % 2 == 0 else building.lightened(0.06))
		for wy: int in range(2, int(bh) - 1, 3):
			for wx: int in range(1, int(bw) - 1, 2):
				if noise(b * 131 + wy * 17 + wx, 7) < lit:
					var warm: bool = noise(b * 31 + wy + wx, 9) < 0.7
					px(bx + float(wx), y0 + h - bh + float(wy), 1, 1, Color("#F2C94C") if warm else Color("#63E7F4"))
	# Antena com luz vermelha piscando no prédio mais alto.
	px(x0 + 28.0, y0 + h - 38.0, 1, 4, building)
	if int(floor(t * 2.0)) % 2 == 0 and dawn < 0.8:
		px(x0 + 28.0, y0 + h - 39.0, 1, 1, Color("#F25555"))
	# Moldura, travessas e peitoril.
	var frame: Color = Color("#2C3D4A")
	px(x0 - 2.0, y0 - 2.0, w + 4.0, 2, frame)
	px(x0 - 2.0, y0 + h, w + 4.0, 2, frame)
	px(x0 - 2.0, y0 - 2.0, 2, h + 4.0, frame)
	px(x0 + w, y0 - 2.0, 2, h + 4.0, frame)
	px(x0 + w * 0.5 - 1.0, y0, 2, h, frame)
	px(x0, y0 + h * 0.5 - 1.0, w, 1, frame)
	px(x0 - 4.0, y0 + h + 2.0, w + 8.0, 2, Color("#3A4E5E"))

## Luz que entra pela janela: luar azulado de noite, sol quente de manhã.
func _light_beam(night: float, dawn: float, dark: float) -> void:
	var moon: float = dark * (1.0 - dawn) * 0.22
	if moon > 0.01:
		poly([Vector2(WINDOW_X, 66), Vector2(WINDOW_X + 60.0, 66), Vector2(WINDOW_X + 40.0, 128), Vector2(WINDOW_X - 36.0, 128)], Color(0.55, 0.70, 1.0, moon))
	if dawn > 0.0:
		var reach: float = lerpf(96.0, 128.0, dawn)
		poly([Vector2(WINDOW_X, 66), Vector2(WINDOW_X + 60.0, 66), Vector2(WINDOW_X + 28.0, reach), Vector2(WINDOW_X - 52.0, reach)], Color(1.0, 0.82, 0.52, 0.16 * dawn * (1.0 - span(6.4, 7.0) * 0.5)))
	if night >= 1.0:
		poly([Vector2(WINDOW_X, 66), Vector2(WINDOW_X + 60.0, 66), Vector2(WINDOW_X + 28.0, 128), Vector2(WINDOW_X - 52.0, 128)], Color(1.0, 0.86, 0.60, 0.05))

## Relógio do criado-mudo: corre durante a noite e pisca quando o alarme toca.
func _clock(night: float) -> void:
	px(75, 84, 20, 8, Color("#0A0D10"))
	px(75, 91, 20, 1, Color("#1B2228"))
	var minutes: int = int(23 * 60 + 10 + night * float(7 * 60 + 50)) % (24 * 60)
	@warning_ignore("integer_division")
	var text: String = "%02d:%02d" % [minutes / 60, minutes % 60]
	var alarm: bool = t >= 4.8 and t < 5.3
	if alarm and int(floor(t * 8.0)) % 2 == 0:
		return
	digits(text, 76, 85, Color("#FF5A4A"))

## Monitor: painel ligado, desligamento em linha (como um tubo antigo), tela
## preta e inicialização de manhã.
func _monitor() -> void:
	var x0: float = 168.0
	var y0: float = MONITOR_Y
	px(x0, y0, 36, 26, Color("#0B0F13"))
	var sx: float = x0 + 2.0
	var sy: float = y0 + 2.0
	var sw: float = 32.0
	var sh: float = 22.0
	px(sx, sy, sw, sh, Color("#020305"))
	if t < 0.5:
		_screen_dashboard(sx, sy, sw, sh, 1.0)
		px(x0 - 6.0, y0 - 5.0, 48, 36, Color(0.39, 0.91, 0.96, 0.05))
	elif t < 1.0:
		# Desligando: a imagem achata até virar uma linha e a linha encolhe até um ponto.
		var f: float = span(0.5, 1.0)
		if f < 0.55:
			var squeeze: float = 1.0 - f / 0.55
			var hh: float = maxf(1.0, floorf(sh * squeeze))
			px(sx, sy + (sh - hh) * 0.5, sw, hh, Color(0.75, 0.97, 1.0, 0.9))
		else:
			var shrink: float = 1.0 - (f - 0.55) / 0.45
			var ww: float = maxf(1.0, floorf(sw * shrink))
			px(sx + (sw - ww) * 0.5, sy + sh * 0.5, ww, 1, Color(0.85, 1.0, 1.0, 0.95))
	elif t >= 6.25:
		# Ligando: linhas de inicialização, depois o painel.
		var boot: float = span(6.25, 6.85)
		px(sx, sy, sw, sh, Color("#06141B"))
		if boot < 0.7:
			var shown: int = int(boot / 0.7 * 7.0) + 1
			for i: int in range(mini(shown, 7)):
				px(sx + 2.0, sy + 2.0 + float(i) * 3.0, 8.0 + noise(i, 4) * 18.0, 1, Color("#63E7F4") if i % 3 != 2 else Color("#62E3A2"))
			if int(floor(t * 10.0)) % 2 == 0:
				px(sx + 2.0, sy + 2.0 + float(mini(shown, 7)) * 3.0, 2, 1, Color("#A9FBFF"))
		else:
			_screen_dashboard(sx, sy, sw, sh, (boot - 0.7) / 0.3)
		px(x0 - 6.0, y0 - 5.0, 48, 36, Color(0.39, 0.91, 0.96, 0.06))

## Miniatura do dashboard na tela do monitor.
func _screen_dashboard(sx: float, sy: float, sw: float, sh: float, alpha: float) -> void:
	px(sx, sy, sw, sh, Color(0.03, 0.10, 0.14, alpha))
	px(sx, sy, 7, sh, Color(0.05, 0.15, 0.20, alpha))
	for i: int in range(5):
		px(sx + 1.0, sy + 2.0 + float(i) * 3.0, 5, 1, Color(0.39, 0.91, 0.96, alpha * (1.0 if i == 0 else 0.45)))
	px(sx + 9.0, sy + 2.0, 21, 1, Color(0.91, 0.95, 0.97, alpha * 0.8))
	var bars: Array = [5, 9, 7, 12, 10]
	for i: int in range(bars.size()):
		px(sx + 9.0 + float(i) * 4.0, sy + sh - 3.0 - float(bars[i]), 3, float(bars[i]), Color(0.39, 0.91, 0.96, alpha * (1.0 if i == 4 else 0.55)))
	px(sx + 9.0, sy + sh - 2.0, 21, 1, Color(0.38, 0.89, 0.64, alpha))

## "z z z" subindo da cama durante o sono e vapor na caneca de manhã.
func _sleep_marks() -> void:
	if t > 2.9 and t < 4.6:
		for i: int in range(3):
			var f: float = fmod(t * 0.55 + float(i) / 3.0, 1.0)
			var alpha: float = sin(f * PI) * 0.75
			var zx: float = floorf(27.0 + f * 9.0 + float(i) * 2.0)
			var zy: float = floorf(80.0 - f * 14.0)
			var color: Color = Color(0.80, 0.90, 1.0, alpha)
			px(zx, zy, 3, 1, color)
			px(zx + 1.0, zy + 1.0, 1, 1, color)
			px(zx, zy + 2.0, 3, 1, color)
	if t > 6.2:
		for i: int in range(3):
			var f: float = fmod(t * 0.8 + float(i) * 0.33, 1.0)
			px(206.0 + sin(f * 6.0 + float(i)) * 1.0, floorf(78.0 - f * 7.0), 1, 1, Color(0.9, 0.95, 1.0, (1.0 - f) * 0.6))
