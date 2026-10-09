extends "res://scripts/ui/night_scene.gd"
## Cenas finais em pixel art.
##
## kind escolhe a cena:
##   "takeoff"    a fuga dá certo: o jato decola ao amanhecer
##   "runway"     a PF bloqueia a pista e intercepta o avião
##   "arrest"     prisão em casa, ao amanhecer
##   "cartel"     queima de arquivo: o quarto, um carro lá fora, e a luz some
##   "congress"   posse em Brasília
## Estende a cena da noite para reaproveitar o quarto e a janela.

var kind: String = "arrest"

var _caption: Label
var _kicker: Label
var _caption_at: float = 3.0

const SUIT_COLORS: Dictionary = {
	"h": Color("#1B1718"), "s": Color("#C98D6C"), "d": Color("#A26E55"), "e": Color("#1B1718"),
	"j": Color("#1D2733"), "k": Color("#151D27"), "c": Color("#F25555"),
	"p": Color("#1D2733"), "q": Color("#151D27"), "b": Color("#0C1015")
}
const AGENT_COLORS: Dictionary = {
	"h": Color("#0C1015"), "s": Color("#B98267"), "d": Color("#95664F"), "e": Color("#0C1015"),
	"j": Color("#10161D"), "k": Color("#0A0E13"), "c": Color("#F2C94C"),
	"p": Color("#10161D"), "q": Color("#0A0E13"), "b": Color("#05070A")
}

func _init() -> void:
	ledger_enabled = false

func _ready() -> void:
	super._ready()
	var view: Vector2 = get_viewport_rect().size
	var texts: Dictionary = {
		"takeoff": ["PISTA CLANDESTINA / 05:48", "As rodas saíram do chão. Lá embaixo, o país ficou do tamanho de um mapa.", 4.3, 6.6],
		"runway": ["PISTA CLANDESTINA / 05:48", "Faróis na cabeceira. A pista estava bloqueada antes de o motor esquentar.", 3.7, 6.4],
		"arrest": ["06:00 / MANDADO DE PRISÃO", "Seis da manhã. Eles sempre chegam às seis da manhã.", 3.2, 6.2],
		"cartel": ["02:14", "O sinal caiu no meio da madrugada. Ninguém perguntou por você.", 3.7, 6.2],
		"congress": ["BRASÍLIA / DIA DA POSSE", "Vossa Excelência jurou cumprir a Constituição. A plateia aplaudiu de pé.", 1.4, 6.0]
	}
	var info: Array = texts.get(kind, texts["arrest"])
	_caption_at = float(info[2])
	duration = float(info[3]) if UI.motion else 2.4
	if not UI.motion:
		_caption_at = 0.0
	_kicker = UI.caps(str(info[0]), UI.CYAN, 13)
	_kicker.position = Vector2(60, view.y - 132.0)
	_kicker.modulate.a = 0.0
	_kicker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_kicker)
	_caption = UI.paragraph(str(info[1]), 24, UI.WHITE, minf(760.0, view.x - 120.0))
	_caption.add_theme_font_override("font", UI.font_display)
	_caption.position = Vector2(60, view.y - 108.0)
	_caption.modulate.a = 0.0
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_caption)
	var hint: Label = UI.caps("CLIQUE OU ESPAÇO PARA PULAR", Color(1, 1, 1, 0.35), 10)
	hint.position = Vector2(view.x - 250.0, view.y - 34.0)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)

func _process(delta: float) -> void:
	super._process(delta)
	var alpha: float = span(_caption_at, _caption_at + 0.5)
	if _caption != null:
		_caption.modulate.a = alpha
		_kicker.modulate.a = alpha

func _paint() -> void:
	if not UI.motion:
		return
	match kind:
		"takeoff": _paint_airstrip(true)
		"runway": _paint_airstrip(false)
		"cartel": _paint_cartel()
		"congress": _paint_congress()
		_: _paint_arrest()
	# Faixa escura atrás da legenda, para o texto ler bem sobre qualquer cena.
	var veil: float = span(_caption_at, _caption_at + 0.5) * 0.72
	for i: int in range(8):
		px(0, 100.0 + float(i) * 3.5, GRID_W, 4, Color(0.01, 0.02, 0.04, veil * float(i + 1) / 8.0))

# ---------------------------------------------------------
# Peças compartilhadas
# ---------------------------------------------------------

## Céu em faixas, do alto ao horizonte.
func _sky(top: Color, low: Color, height: float) -> void:
	var bands: int = 14
	for i: int in range(bands):
		var f: float = float(i) / float(bands - 1)
		px(0, height * float(i) / float(bands), GRID_W, height / float(bands) + 0.5, top.lerp(low, f * f))

## Viatura de perfil. lights alterna o giroflex.
func _police_car(x: float, ground: float, flip: bool, strobe: bool) -> void:
	var body: Color = Color("#0E151C")
	px(x, ground - 5.0, 20, 4, body)
	px(x + 4.0, ground - 8.0, 11, 3, body)
	px(x + 5.0, ground - 7.0, 4, 2, Color("#2A3A48"))
	px(x + 10.0, ground - 7.0, 4, 2, Color("#2A3A48"))
	px(x, ground - 4.0, 20, 1, Color("#F2C94C"))
	px(x + 3.0, ground - 2.0, 4, 2, Color("#05070A"))
	px(x + 13.0, ground - 2.0, 4, 2, Color("#05070A"))
	px(x + 8.0, ground - 9.0, 2, 1, Color("#F25555") if strobe else Color("#3A1518"))
	px(x + 10.0, ground - 9.0, 2, 1, Color("#3A6BFF") if not strobe else Color("#15203A"))
	var front: float = x - 1.0 if flip else x + 20.0
	px(front, ground - 4.0, 1, 1, Color("#FFF2C4"))

## Clarão alternado do giroflex sobre a cena inteira.
func _strobe_wash(strength: float) -> void:
	var red: bool = int(floor(t * 6.0)) % 2 == 0
	px(0, 0, GRID_W, GRID_H, Color(0.95, 0.2, 0.2, 0.10 * strength) if red else Color(0.2, 0.35, 1.0, 0.10 * strength))

# ---------------------------------------------------------
# Pista: decolagem ou interceptação
# ---------------------------------------------------------

func _paint_airstrip(success: bool) -> void:
	var ground: float = 104.0
	# Na fuga bem-sucedida, o céu amanhece enquanto o avião some.
	var dawn: float = span(3.6, 6.2) if success else 0.0
	_sky(Color("#050B1C").lerp(Color("#3A4E8C"), dawn), Color("#0E1B38").lerp(Color("#F09A5C"), dawn), 86.0)
	for i: int in range(40):
		var twinkle: float = 0.5 + 0.5 * sin(t * (1.5 + noise(i, 3) * 3.0) + float(i))
		px(floorf(noise(i, 1) * 227.0), floorf(noise(i, 2) * 60.0), 1, 1, Color(0.9, 0.95, 1.0, (1.0 - dawn) * twinkle))
	# Serra no horizonte e as luzes de uma cidade distante.
	for i: int in range(24):
		var hill: float = 6.0 + noise(i, 5) * 9.0
		px(float(i) * 10.0 - 4.0, 86.0 - hill, 12, hill, Color("#070D18").lerp(Color("#2A3350"), dawn))
	for i: int in range(30):
		if noise(i, 6) < 0.6:
			px(floorf(60.0 + noise(i, 7) * 160.0), 84.0 + floorf(noise(i, 8) * 2.0), 1, 1, Color(0.95, 0.80, 0.40, 0.8 * (1.0 - dawn)))
	# Pátio, pista e balizamento.
	px(0, 86, GRID_W, GRID_H - 86, Color("#0D1218"))
	px(0, 96, GRID_W, 18, Color("#161D25"))
	for i: int in range(20):
		px(float(i) * 14.0 - 6.0, 105, 8, 1, Color("#3A4652"))
	for i: int in range(24):
		var on: bool = (i + int(floor(t * 3.0))) % 3 != 0
		px(float(i) * 10.0 + 2.0, 95, 1, 1, Color("#63E7F4") if on else Color("#1D3B49"))
		px(float(i) * 10.0 + 6.0, 114, 1, 1, Color("#F2C94C") if on else Color("#4A3D1A"))
	# Hangar com a porta entreaberta.
	px(0, 58, 38, 38, Color("#0A1017"))
	px(0, 56, 40, 3, Color("#141C25"))
	px(22, 70, 12, 26, Color("#1E2A33"))
	px(24, 72, 8, 24, Color(1.0, 0.85, 0.55, 0.20))

	# Posição do jato ao longo da cena.
	var jet_x: float = 92.0
	var jet_y: float = ground
	var airborne: bool = false
	if success:
		var run: float = span(2.6, 4.4)
		jet_x = 92.0 + 190.0 * run * run
		var lift: float = clampf((run - 0.55) / 0.45, 0.0, 1.0)
		jet_y = ground - 46.0 * lift * lift
		airborne = lift > 0.0
	else:
		jet_x = 92.0 + 30.0 * span(2.6, 3.5, true)
	if jet_x < 240.0:
		_jet(jet_x, jet_y, t > 2.0, airborne, t < 1.9)

	# O operador atravessa o pátio com a maleta e embarca.
	if t < 1.6:
		var hx: float = lerpf(30.0, jet_x + 22.0, span(0.0, 1.6))
		hero_walk(hx, ground + 2.0, false)
		px(hx + 9.0, ground - 9.0, 4, 3, Color("#3A2B25"))
		px(hx + 10.0, ground - 10.0, 2, 1, Color("#3A2B25"))

	if success:
		# Rastro de calor do motor na corrida de decolagem.
		if t > 2.2 and jet_x < 230.0:
			for i: int in range(5):
				px(jet_x - 6.0 - float(i) * 4.0 - fmod(t * 30.0, 4.0), jet_y - 12.0 + noise(i + int(t * 20.0), 2), 3, 1, Color(1.0, 0.7, 0.35, 0.35 - float(i) * 0.06))
		return

	# Interceptação: as viaturas entram pela direita e fecham a pista.
	var arrive: float = span(2.8, 3.7, true)
	if arrive > 0.0:
		var strobe: bool = int(floor(t * 6.0)) % 2 == 0
		_police_car(lerpf(240.0, 166.0, arrive), ground + 2.0, true, strobe)
		_police_car(lerpf(260.0, 190.0, arrive), ground + 6.0, true, not strobe)
		_police_car(lerpf(-40.0, 40.0, arrive), ground + 6.0, false, strobe)
	if t > 3.7:
		_strobe_wash(1.0)
		# Agentes cercando a escada do avião.
		var close_in: float = span(3.8, 4.8, true)
		hero_stand(lerpf(164.0, jet_x + 34.0, close_in), ground + 2.0, 0, true, AGENT_COLORS)
		hero_stand(lerpf(52.0, jet_x + 8.0, close_in), ground + 4.0, 0, false, AGENT_COLORS)
		# Holofote sobre a porta.
		poly([Vector2(200, 0), Vector2(214, 0), Vector2(jet_x + 40.0, ground), Vector2(jet_x + 14.0, ground)], Color(1.0, 1.0, 0.9, 0.07))

## Jato executivo de perfil, com o nariz para a direita. y é a linha do chão.
func _jet(x: float, y: float, engines: bool, airborne: bool, door_open: bool) -> void:
	var body: Color = Color("#D5DCE1")
	var shade: Color = Color("#A9B3BA")
	var top: float = y - 15.0
	# Cauda e estabilizador.
	px(x, top - 7.0, 4, 8, body)
	px(x - 2.0, top - 8.0, 8, 2, shade)
	# Fuselagem e nariz afilado.
	px(x, top, 44, 7, body)
	px(x + 44.0, top + 1.0, 4, 5, body)
	px(x + 48.0, top + 2.0, 3, 3, body)
	px(x, top + 5.0, 46, 2, shade)
	# Janelas da cabine e da cabine de comando.
	for i: int in range(6):
		px(x + 12.0 + float(i) * 5.0, top + 2.0, 2, 2, Color("#17222C"))
	px(x + 43.0, top + 1.0, 3, 2, Color("#17222C"))
	# Motor traseiro e asa.
	px(x + 3.0, top - 2.0, 10, 3, Color("#6A747C"))
	if engines:
		px(x + 1.0, top - 1.0, 2, 1, Color("#FFB45A"))
		px(x - 1.0 - fmod(t * 20.0, 2.0), top - 1.0, 2, 1, Color(1.0, 0.75, 0.4, 0.6))
	px(x + 16.0, top + 7.0, 16, 2, Color("#7F8A92"))
	# Trem de pouso (recolhe no ar) e escada (só com a porta aberta).
	if not airborne:
		px(x + 12.0, top + 9.0, 1, 4, Color("#3A4652"))
		px(x + 11.0, top + 13.0, 3, 2, Color("#05070A"))
		px(x + 40.0, top + 7.0, 1, 6, Color("#3A4652"))
		px(x + 39.0, top + 13.0, 3, 2, Color("#05070A"))
	if door_open:
		px(x + 33.0, top + 1.0, 4, 6, Color("#17222C"))
		for i: int in range(4):
			px(x + 30.0 - float(i) * 2.0, top + 8.0 + float(i) * 2.0, 4, 1, Color("#8C979F"))
	# Luz de navegação piscando.
	if int(floor(t * 2.5)) % 2 == 0:
		px(x + 2.0, top - 8.0, 1, 1, Color("#F25555"))

# ---------------------------------------------------------
# Prisão em casa
# ---------------------------------------------------------

func _paint_arrest() -> void:
	var ground: float = 100.0
	_sky(Color("#16203F"), Color("#C9795A"), 100.0)
	# Prédios vizinhos e o prédio do operador.
	px(0, 40, 50, 60, Color("#0C1420"))
	px(178, 30, 50, 70, Color("#0C1420"))
	px(54, 14, 120, 86, Color("#131D2A"))
	px(54, 12, 120, 3, Color("#1C2937"))
	for floor_index: int in range(6):
		for column: int in range(9):
			var wx: float = 62.0 + float(column) * 12.0
			var wy: float = 20.0 + float(floor_index) * 13.0
			var mine: bool = floor_index == 2 and column == 5
			var lit: bool = mine or noise(floor_index * 9 + column, 11) < 0.12
			px(wx, wy, 7, 8, Color("#F2C94C") if lit else Color("#0A111A"))
			if mine and t > 1.4:
				# A silhueta dele na janela, olhando para a rua.
				px(wx + 2.0, wy + 2.0, 3, 6, Color("#1B1718"))
	px(104, 82, 14, 18, Color("#0A111A"))
	px(105, 83, 12, 17, Color(1.0, 0.85, 0.55, 0.25 if t > 1.6 else 0.05))
	# Rua.
	px(0, ground, GRID_W, GRID_H - ground, Color("#0D1218"))
	px(0, ground, GRID_W, 2, Color("#1A222B"))
	for i: int in range(12):
		px(float(i) * 22.0, 112, 10, 1, Color("#2A3440"))

	var arrive: float = span(0.2, 1.4, true)
	var strobe: bool = int(floor(t * 6.0)) % 2 == 0
	_police_car(lerpf(-30.0, 62.0, arrive), ground + 8.0, false, strobe)
	_police_car(lerpf(250.0, 136.0, arrive), ground + 8.0, true, not strobe)
	# Agentes entram; depois saem com ele entre os dois.
	if t > 1.4 and t < 2.4:
		var enter: float = span(1.4, 2.4)
		hero_walk(lerpf(84.0, 106.0, enter), ground + 4.0, false, AGENT_COLORS)
		hero_walk(lerpf(130.0, 108.0, enter), ground + 4.0, true, AGENT_COLORS)
	if t > 3.0:
		var leave: float = span(3.0, 4.6)
		var hx: float = lerpf(106.0, 142.0, leave)
		hero_walk(hx - 9.0, ground + 4.0, false, AGENT_COLORS)
		hero_walk(hx, ground + 4.0, false)
		hero_walk(hx + 9.0, ground + 4.0, false, AGENT_COLORS)
	if t > 1.2:
		_strobe_wash(0.9)
	# Grades descendo: o fim da cena.
	var bars: float = span(4.7, 5.3, true)
	if bars > 0.0:
		for i: int in range(13):
			px(6.0 + float(i) * 18.0, -GRID_H + GRID_H * bars, 5, GRID_H, Color("#090C10"))
			px(7.0 + float(i) * 18.0, -GRID_H + GRID_H * bars, 1, GRID_H, Color("#27313B"))
		px(0, 38.0 * bars - 6.0, GRID_W, 5, Color("#090C10"))
		px(0, GRID_H - 44.0 * bars + 4.0, GRID_W, 5, Color("#090C10"))

# ---------------------------------------------------------
# Queima de arquivo
# ---------------------------------------------------------

func _paint_cartel() -> void:
	# O quarto de sempre, de madrugada. Um carro para lá fora. A luz some.
	var lights: bool = t < 3.2
	var flicker: bool = t > 2.5 and int(floor(t * 14.0)) % 3 == 0
	var lamp: bool = lights and not flicker
	_room(lamp, 0.0)
	_desk(lamp)
	_bed()
	hero_back(DESK_X, SEAT_HEAD)
	px(178, 87, 14, 11, Color("#18222B"))
	px(0, 0, GRID_W, GRID_H, Color(0.01, 0.03, 0.09, 0.30 if lamp else 0.62))
	_window(0.35, 0.0)
	# Faróis varrendo a parede pelo vidro: dois fachos que cruzam o quarto.
	if t > 1.3 and t < 2.9:
		var sweep: float = span(1.3, 2.9)
		var bx: float = lerpf(-40.0, 190.0, sweep)
		poly([Vector2(bx, 18), Vector2(bx + 16.0, 18), Vector2(bx + 46.0, 92), Vector2(bx + 22.0, 92)], Color(1.0, 0.95, 0.8, 0.13))
		poly([Vector2(bx + 22.0, 18), Vector2(bx + 38.0, 18), Vector2(bx + 70.0, 92), Vector2(bx + 46.0, 92)], Color(1.0, 0.95, 0.8, 0.10))
	px(75, 84, 20, 8, Color("#0A0D10"))
	digits("02:14", 76, 85, Color("#FF5A4A"))
	# Monitor: painel normal, depois o aviso, depois chuvisco.
	var sx: float = 170.0
	var sy: float = MONITOR_Y + 2.0
	px(168, MONITOR_Y, 36, 26, Color("#0B0F13"))
	if t < 2.0:
		_screen_dashboard(sx, sy, 32, 22, 1.0)
	else:
		px(sx, sy, 32, 22, Color("#1A0608"))
		if int(floor(t * 5.0)) % 2 == 0:
			px(sx + 14.0, sy + 5.0, 4, 8, Color("#F25555"))
			px(sx + 14.0, sy + 15.0, 4, 3, Color("#F25555"))
		for i: int in range(24):
			px(sx + floorf(noise(i + int(t * 30.0), 1) * 31.0), sy + floorf(noise(i + int(t * 30.0), 2) * 21.0), 1, 1, Color(1, 1, 1, 0.25))
	# Corte seco para o preto.
	if not lights:
		px(0, 0, GRID_W, GRID_H, Color("#000000"))

# ---------------------------------------------------------
# Posse em Brasília
# ---------------------------------------------------------

func _paint_congress() -> void:
	_sky(Color("#3F8FD0"), Color("#CFEAF7"), 92.0)
	# Nuvens.
	for cloud: Array in [[18, 14, 26], [150, 22, 34], [92, 8, 18]]:
		var drift: float = fmod(float(cloud[0]) + t * 1.5, 250.0) - 12.0
		px(drift, cloud[1], cloud[2], 3, Color(1, 1, 1, 0.75))
		px(drift + 4.0, float(cloud[1]) - 2.0, float(cloud[2]) - 9.0, 2, Color(1, 1, 1, 0.75))
	var white: Color = Color("#EEF2F4")
	var shade: Color = Color("#C5CDD3")
	# Plataforma, as duas torres e a passarela entre elas.
	px(34, 84, 160, 8, white)
	px(34, 90, 160, 2, shade)
	px(106, 26, 7, 60, white)
	px(116, 26, 7, 60, white)
	px(112, 26, 1, 60, shade)
	px(122, 26, 1, 60, shade)
	px(113, 52, 3, 4, white)
	for i: int in range(14):
		px(107, 29.0 + float(i) * 4.0, 5, 1, Color("#8FA3B3"))
		px(117, 29.0 + float(i) * 4.0, 5, 1, Color("#8FA3B3"))
	# Cúpula (Senado) à esquerda e cuia invertida (Câmara) à direita.
	var dome: Array = [[60, 82, 34], [63, 79, 28], [67, 76, 20], [72, 74, 10]]
	for row: Array in dome:
		px(row[0], row[1], row[2], 3, white)
	var bowl: Array = [[136, 72, 44], [139, 75, 38], [143, 78, 30], [148, 81, 20]]
	for row: Array in bowl:
		px(row[0], row[1], row[2], 3, white)
	px(136, 72, 44, 1, shade)
	# Gramado e espelho d'água.
	px(0, 92, GRID_W, 36, Color("#3E8A52"))
	px(0, 92, GRID_W, 2, Color("#2F6E41"))
	px(46, 96, 136, 5, Color("#4FA5D8"))
	px(46, 96, 136, 1, Color("#8FD0F0"))

	# Púlpito, microfones e o novo deputado acenando.
	hero_stand(108, 116, 0, false, SUIT_COLORS)
	var wave: float = 1.0 if int(floor(t * 4.0)) % 2 == 0 else 0.0
	px(117, 98.0 - wave, 2, 5, SUIT_COLORS["j"])
	px(117, 96.0 - wave, 2, 2, SUIT_COLORS["s"])
	px(102, 106, 24, 14, Color("#3A2B25"))
	px(101, 105, 26, 2, Color("#4A372F"))
	px(110, 110, 8, 5, Color("#F2C94C"))
	px(106, 101, 1, 4, Color("#11171C"))
	px(121, 101, 1, 4, Color("#11171C"))
	# Plateia: cabeças e braços erguidos.
	for i: int in range(38):
		var cx: float = float(i) * 6.0 + noise(i, 4) * 3.0
		var up: float = 2.0 if int(floor(t * 3.0 + noise(i, 5) * 4.0)) % 3 == 0 else 0.0
		var top: float = floorf(119.0 - noise(i, 6) * 3.0)
		px(cx + 1.0, top, 3, 3, Color("#16202B"))
		px(cx, top + 3.0, 5, 9, Color("#16202B"))
		if up > 0.0:
			px(cx + 5.0, top - 2.0, 1, 6, Color("#16202B"))
	# Confete.
	var colors: Array = [Color("#62E3A2"), Color("#F2C94C"), Color("#63E7F4"), Color("#FFFFFF"), Color("#FF9950")]
	for i: int in range(70):
		var fall: float = fmod(noise(i, 1) * 140.0 + t * (22.0 + noise(i, 2) * 26.0), 132.0)
		var sway: float = sin(t * 3.0 + float(i)) * 2.0
		px(floorf(noise(i, 3) * 227.0 + sway), floorf(fall) - 4.0, 1, 2 if i % 3 == 0 else 1, colors[i % colors.size()])
