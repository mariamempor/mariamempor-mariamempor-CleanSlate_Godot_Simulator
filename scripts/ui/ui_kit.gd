extends Node
## UI — kit de interface compartilhado (autoload).
##
## Paleta, fontes, tema e as "fábricas" de rótulos, painéis e botões que todas
## as telas usam, mais os helpers de animação. Nada aqui conhece regra de jogo:
## quem decide o que mostrar são as telas (main.gd, abas, popups).
##
## Regra de animação: a "entrada" (fade + deslize) acontece uma vez, quando o
## jogador chega a uma tela ou troca de aba. Quando a tela só é atualizada
## (um saldo mudou), nada entra de novo: os números contam até o valor novo.

const W = preload("res://scripts/ui/widgets.gd")

# ---------- paleta ----------
const CYAN: Color = Color("#63E7F4")
const CYAN_BRIGHT: Color = Color("#A9FBFF")
const CYAN_DARK: Color = Color("#1D3B49")
const BG: Color = Color("#061018")
const PANEL: Color = Color("#0E1923")
const WHITE: Color = Color("#E7F2F7")
const MUTED: Color = Color("#8399A9")
const DIM: Color = Color("#52646F")
const GREEN: Color = Color("#62E3A2")
const ORANGE: Color = Color("#FF9950")
const RED: Color = Color("#F25555")
const YELLOW: Color = Color("#F2C94C")
const VIOLET: Color = Color("#B79CFF")     # Dark Web / Monero
const INK_2: Color = Color("#BFD0DA")      # texto corrido
const LINE: Color = Color("#1F3440")       # bordas discretas
const SURFACE: Color = Color("#09131B")    # fundo de áreas internas
const TRACK: Color = Color("#14232D")      # trilho de barras

# ---------- layout ----------
const FONT_DIR: String = "res://assets/fonts/"
const SIDEBAR_W: float = 248.0
const GUTTER: float = 24.0
const PAD: float = 18.0
const GAP: float = 16.0
const HEADER_H: float = 56.0
const DOCK_W: float = 340.0
const DOCK_H: float = 58.0
const BODY_Y: float = 70.0

## Zonas de suspeita: [limite superior, nome].
const ZONES: Array = [[25.0, "Controlado"], [50.0, "Atenção"], [75.0, "Elevado"], [100.0, "Crítico"]]

var font_text: Font
var font_bold: Font
var font_display: Font
var font_mono: Font
var font_mono_md: Font
var theme: Theme

var motion: bool = true             # Configurações > Reduzir animações desliga
var animating: bool = true          # false enquanto uma tela é só atualizada
var suppress: bool = false          # true ao refazer a tela por causa de resize
## Último valor exibido de cada número: é de onde as contagens partem.
var shown: Dictionary = {}

func _ready() -> void:
	_setup_fonts()
	theme = _build_theme()

# =========================================================
# FONTES E TEMA
# =========================================================

func _setup_fonts() -> void:
	# As fontes ficam em res://assets/fonts/. Sem os arquivos, a interface cai
	# para a fonte padrão do Godot e uma monoespaçada do sistema.
	var sans: Font = _load_font("IBMPlexSans-Variable.ttf")
	if sans != null:
		font_text = _vary(sans, 400.0, 100.0)
		font_bold = _vary(sans, 600.0, 100.0)
		font_display = _vary(sans, 600.0, 84.0)
	else:
		font_text = ThemeDB.fallback_font
		var heavy: FontVariation = FontVariation.new()
		heavy.base_font = ThemeDB.fallback_font
		heavy.variation_embolden = 0.6
		font_bold = heavy
		font_display = heavy
	font_mono = _load_font("IBMPlexMono-Regular.ttf")
	if font_mono == null:
		var system_mono: SystemFont = SystemFont.new()
		system_mono.font_names = PackedStringArray(["Cascadia Mono", "Consolas", "DejaVu Sans Mono", "monospace"])
		font_mono = system_mono
	font_mono_md = _load_font("IBMPlexMono-Medium.ttf")
	if font_mono_md == null:
		font_mono_md = font_mono

func _load_font(file_name: String) -> Font:
	var path: String = FONT_DIR + file_name
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Font

## Variação de peso (wght) e largura (wdth) de uma fonte variável.
func _vary(base: Font, weight: float, width: float) -> FontVariation:
	var ts: TextServer = TextServerManager.get_primary_interface()
	var variation: FontVariation = FontVariation.new()
	variation.base_font = base
	variation.variation_opentype = {ts.name_to_tag("wght"): weight, ts.name_to_tag("wdth"): width}
	return variation

func _build_theme() -> Theme:
	# Um Theme estiliza de uma vez os controles nativos (SpinBox, slider,
	# tooltip, barra de rolagem). Telas e popups aplicam com `theme = UI.theme`.
	var t: Theme = Theme.new()
	t.default_font = font_text
	t.default_font_size = 14

	var tip: StyleBoxFlat = flat(Color("#0B1820"), CYAN_DARK, 6)
	tip.set_content_margin_all(10.0)
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", WHITE)
	t.set_font_size("font_size", "TooltipLabel", 12)

	var field: StyleBoxFlat = flat(SURFACE, Color("#2B3A47"), 6)
	field.content_margin_left = 12.0
	field.content_margin_right = 12.0
	field.content_margin_top = 8.0
	field.content_margin_bottom = 8.0
	var field_focus: StyleBoxFlat = field.duplicate() as StyleBoxFlat
	field_focus.border_color = CYAN
	t.set_stylebox("normal", "LineEdit", field)
	t.set_stylebox("read_only", "LineEdit", field)
	t.set_stylebox("focus", "LineEdit", field_focus)
	t.set_font("font", "LineEdit", font_mono_md)
	t.set_font_size("font_size", "LineEdit", 17)
	t.set_color("font_color", "LineEdit", WHITE)
	t.set_color("font_uneditable_color", "LineEdit", MUTED)
	t.set_color("caret_color", "LineEdit", CYAN_BRIGHT)
	t.set_color("selection_color", "LineEdit", Color(CYAN, 0.30))

	var slider_track: StyleBoxFlat = flat(TRACK, Color.TRANSPARENT, 3, 0)
	slider_track.content_margin_top = 3.0
	slider_track.content_margin_bottom = 3.0
	var slider_fill: StyleBoxFlat = slider_track.duplicate() as StyleBoxFlat
	slider_fill.bg_color = CYAN
	t.set_stylebox("slider", "HSlider", slider_track)
	t.set_stylebox("grabber_area", "HSlider", slider_fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", slider_fill)

	var scroll_track: StyleBoxFlat = flat(Color.TRANSPARENT, Color.TRANSPARENT, 3, 0)
	scroll_track.content_margin_left = 3.0
	scroll_track.content_margin_right = 3.0
	t.set_stylebox("scroll", "VScrollBar", scroll_track)
	t.set_stylebox("grabber", "VScrollBar", flat(Color("#2B3A47"), Color.TRANSPARENT, 3, 0))
	t.set_stylebox("grabber_highlight", "VScrollBar", flat(Color("#4D687B"), Color.TRANSPARENT, 3, 0))
	t.set_stylebox("grabber_pressed", "VScrollBar", flat(CYAN, Color.TRANSPARENT, 3, 0))
	return t

# =========================================================
# FORMATAÇÃO E ZONAS
# =========================================================

func money(v: float) -> String:
	return GameManager.format_money(v)

## Número com vírgula decimal, como se escreve em português.
func num(v: float, decimals: int = 1) -> String:
	return (("%." + str(decimals) + "f") % v).replace(".", ",")

## Número sem a casa decimal quando ela é zero: 4 em vez de 4,0.
func num_short(v: float) -> String:
	return num(v).trim_suffix(",0")

func pct(v: float) -> String:
	return num(v) + "%"

## Percentual sem casa decimal quando ela é zero: 12% em vez de 12,0%.
func pct_short(v: float) -> String:
	return num(v).trim_suffix(",0") + "%"

## Número com sinal explícito: +4,5 ou -3,0.
func signed(v: float, decimals: int = 1) -> String:
	return ("+" if v >= 0.0 else "-") + num(absf(v), decimals)

## Dinheiro abreviado para espaços apertados: R$ 850 mil, R$ 1,2 mi.
func short_money(v: float) -> String:
	var a: float = absf(v)
	var prefix: String = "-" if v < 0.0 else ""
	if a >= 1000000.0:
		var millions: float = a / 1000000.0
		var text: String = ("%.1f" % millions).replace(".", ",") if millions < 100.0 else "%d" % int(round(millions))
		return "%sR$ %s mi" % [prefix, text.trim_suffix(",0")]
	if a >= 1000.0:
		return "%sR$ %d mil" % [prefix, int(round(a / 1000.0))]
	return "%sR$ %d" % [prefix, int(round(a))]

## Só o número abreviado, sem R$ (rótulos de gráfico).
func short_number(v: float) -> String:
	if v >= 1000000.0:
		return ("%.1fM" % (v / 1000000.0)).replace(".0M", "M").replace(".", ",")
	if v >= 1000.0:
		return "%dk" % int(round(v / 1000.0))
	return str(int(v))

func zone_index(suspicion: float) -> int:
	for i: int in range(ZONES.size()):
		if suspicion < float(ZONES[i][0]):
			return i
	return ZONES.size() - 1

func zone_color(index: int) -> Color:
	return [GREEN, YELLOW, ORANGE, RED][clampi(index, 0, 3)]

func zone_colors() -> Array:
	return [GREEN, YELLOW, ORANGE, RED]

func zone_name(suspicion: float) -> String:
	return str(ZONES[zone_index(suspicion)][1])

func risk_color(suspicion: float) -> Color:
	return zone_color(zone_index(suspicion))

# =========================================================
# TEXTO
# =========================================================

## Largura real de um rótulo de uma linha. Fora da árvore, get_minimum_size()
## ainda mede com a fonte padrão (16 px) e devolve um valor maior que o real;
## aqui a conta é feita direto na fonte e no tamanho que o rótulo vai usar.
func text_width(node: Label) -> float:
	var font: Font = node.get_theme_font("font")
	var font_size: int = node.get_theme_font_size("font_size")
	return font.get_string_size(node.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

func label(text: String, font_size: int, color: Color = WHITE) -> Label:
	var node: Label = Label.new()
	node.text = text
	node.add_theme_font_override("font", font_text)
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	return node

## Título em IBM Plex Sans semibold.
func bold(text: String, font_size: int, color: Color = WHITE) -> Label:
	var node: Label = label(text, font_size, color)
	node.add_theme_font_override("font", font_bold)
	return node

## Título de tela, na versão condensada da fonte.
func display(text: String, font_size: int, color: Color = WHITE) -> Label:
	var node: Label = label(text, font_size, color)
	node.add_theme_font_override("font", font_display)
	return node

## Números: monoespaçada, para os dígitos não "dançarem" nas contagens.
func mono(text: String, font_size: int, color: Color = WHITE) -> Label:
	var node: Label = label(text, font_size, color)
	node.add_theme_font_override("font", font_mono_md)
	return node

## Rótulo pequeno em maiúsculas.
func caps(text: String, color: Color = MUTED, font_size: int = 10) -> Label:
	var node: Label = label(text, font_size, color)
	node.add_theme_font_override("font", font_mono)
	return node

## Texto corrido com quebra de linha em uma largura fixa.
## A quebra é ligada ANTES de definir o tamanho: um Label sem quebra cresce até
## a largura do texto inteiro, e era isso que fazia texto vazar dos popups.
func paragraph(text: String, font_size: int, color: Color, width: float) -> Label:
	var node: Label = label(text, font_size, color)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.custom_minimum_size.x = width
	node.size.x = width
	return node

## Altura real de um texto com quebra de linha em uma largura (mesmo motivo de
## text_width).
func text_height(node: Label, width: float) -> float:
	var font: Font = node.get_theme_font("font")
	var font_size: int = node.get_theme_font_size("font_size")
	return font.get_multiline_string_size(node.text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size).y

## Rótulo de uma linha dentro de uma caixa: o texto que não cabe é cortado com
## reticências em vez de vazar. O corte é ligado antes do tamanho, pelo mesmo
## motivo da quebra de linha em paragraph().
func clip(node: Label, pos: Vector2, box: Vector2) -> Label:
	node.clip_text = true
	node.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	node.position = pos
	node.size = box
	return node

## Coloca um nó em uma posição e devolve o próprio nó (encadeia com add_child).
func at(node: Control, pos: Vector2) -> Control:
	node.position = pos
	return node

## Rótulo alinhado à direita dentro de uma largura.
func right(node: Label, pos: Vector2, width: float) -> Label:
	node.position = pos
	node.size = Vector2(width, node.get_minimum_size().y)
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return node

# =========================================================
# PAINÉIS
# =========================================================

func flat(bg: Color, border: Color, radius: int = 8, border_width: int = 1) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	return box

func style_panel(node: Panel, bg: Color = PANEL, border: Color = LINE, radius: int = 8) -> void:
	var box: StyleBoxFlat = flat(bg, border, radius)
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.30)
	box.shadow_size = 10
	box.shadow_offset = Vector2(0, 4)
	node.add_theme_stylebox_override("panel", box)

func panel(host: Control, pos: Vector2, panel_size: Vector2, bg: Color = PANEL, border: Color = LINE) -> Panel:
	var node: Panel = Panel.new()
	node.position = pos
	node.size = panel_size
	style_panel(node, bg, border)
	host.add_child(node)
	return node

## Painel com título e, opcionalmente, uma linha de apoio. O conteúdo começa em y = 56.
func card(host: Control, rect: Rect2, title: String = "", hint: String = "") -> Panel:
	var node: Panel = panel(host, rect.position, rect.size)
	if title != "":
		node.add_child(at(bold(title, 14, WHITE), Vector2(PAD, 14)))
	if hint != "":
		var hint_label: Label = label(hint, 12, MUTED)
		clip(hint_label, Vector2(PAD, 34), Vector2(rect.size.x - PAD * 2.0, 18))
		node.add_child(hint_label)
	return node

## Bloco "rótulo + valor" para usar dentro de containers.
## O Label do valor fica em tile.get_meta("value_label").
func tile(title: String, value: String, color: Color, tip: String = "", value_size: int = 20) -> PanelContainer:
	var node: PanelContainer = PanelContainer.new()
	var box: StyleBoxFlat = flat(SURFACE, LINE, 6)
	box.set_content_margin_all(12.0)
	node.add_theme_stylebox_override("panel", box)
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.tooltip_text = tip
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(col)
	col.add_child(caps(title, MUTED))
	var value_label: Label = mono(value, value_size, color)
	col.add_child(value_label)
	node.set_meta("value_label", value_label)
	return node

func chip(text: String, color: Color) -> PanelContainer:
	var node: PanelContainer = PanelContainer.new()
	var box: StyleBoxFlat = flat(Color(color, 0.12), Color(color, 0.45), 4)
	box.content_margin_left = 7.0
	box.content_margin_right = 7.0
	box.content_margin_top = 2.0
	box.content_margin_bottom = 2.0
	node.add_theme_stylebox_override("panel", box)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(caps(text, color, 9))
	return node

## Linha "chave ......... valor" com divisória, em posição absoluta.
func kv_row(host: Control, y: float, width: float, key: String, value: String, value_color: Color = WHITE, x: float = PAD) -> void:
	host.add_child(at(label(key, 13, MUTED), Vector2(x, y)))
	host.add_child(right(mono(value, 13, value_color), Vector2(x, y), width - x * 2.0))
	var sep: ColorRect = ColorRect.new()
	sep.position = Vector2(x, y + 28.0)
	sep.size = Vector2(width - x * 2.0, 1)
	sep.color = Color("#1A2B36")
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(sep)

## Linha "chave ... valor" para usar dentro de um VBoxContainer.
func kv_line(key: String, value: String, value_color: Color = WHITE) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	var key_label: Label = label(key, 13, INK_2)
	key_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(key_label)
	var value_label: Label = mono(value, 14, value_color)
	row.add_child(value_label)
	row.set_meta("value_label", value_label)
	return row

## Item numerado (sequência) para listas explicativas.
func list_item(marker: String, text: String, width: float, marker_color: Color = CYAN) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var badge: Label = mono(marker, 13, marker_color)
	badge.custom_minimum_size = Vector2(24, 0)
	badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(badge)
	row.add_child(paragraph(text, 14, INK_2, width - 36.0))
	return row

## Termo + definição.
func term_item(term: String, definition: String, width: float) -> VBoxContainer:
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.add_child(bold(term, 14, WHITE))
	col.add_child(paragraph(definition, 14, INK_2, width))
	return col

func spacer(height: float = 0.0, expand: bool = false) -> Control:
	var node: Control = Control.new()
	node.custom_minimum_size.y = height
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if expand:
		node.size_flags_vertical = Control.SIZE_EXPAND_FILL
		node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node

func rule(host: Control, pos: Vector2, length: float, color: Color = LINE, vertical: bool = false) -> ColorRect:
	var node: ColorRect = ColorRect.new()
	node.position = pos
	node.size = Vector2(1, length) if vertical else Vector2(length, 1)
	node.color = color
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(node)
	return node

func icon(icon_name: String) -> Texture2D:
	var path: String = "res://assets/icons/%s.svg" % icon_name
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

func icon_rect(icon_name: String, pos: Vector2, icon_size: float, tint: Color = Color.WHITE) -> TextureRect:
	var texture: Texture2D = icon(icon_name)
	if texture == null:
		return null
	var rect: TextureRect = TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.position = pos
	rect.size = Vector2(icon_size, icon_size)
	rect.modulate = tint
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect

# =========================================================
# BOTÕES
# =========================================================

## kind: "primary", "secondary", "danger", "nav" ou "nav_active".
func style_button(node: Button, kind: String) -> void:
	var normal: StyleBoxFlat = flat(Color("#14212C"), Color("#2B3A47"), 6)
	var hover: StyleBoxFlat = flat(Color("#1A2D3A"), Color("#4D687B"), 6)
	var pressed: StyleBoxFlat = flat(Color("#101A23"), Color("#4D687B"), 6)
	match kind:
		"primary":
			normal = flat(Color("#103D49"), CYAN, 6)
			hover = flat(Color("#176172"), CYAN_BRIGHT, 6)
			pressed = flat(Color("#0C323C"), CYAN, 6)
		"danger":
			normal = flat(Color("#3A1518"), RED, 6)
			hover = flat(Color("#55191E"), Color("#FF8A8A"), 6)
			pressed = flat(Color("#2B1013"), RED, 6)
		"nav":
			normal = flat(Color.TRANSPARENT, Color.TRANSPARENT, 6)
			hover = flat(Color("#12202B"), Color.TRANSPARENT, 6)
			pressed = flat(Color("#0C1720"), Color.TRANSPARENT, 6)
		"nav_active":
			normal = flat(Color("#0F2B36"), CYAN, 6, 0)
			normal.border_width_left = 3
			hover = normal
			pressed = normal
	var disabled: StyleBoxFlat = flat(Color("#0D161E"), Color("#1A2732"), 6)
	var focus: StyleBoxFlat = flat(Color.TRANSPARENT, CYAN_BRIGHT, 6)
	for box: StyleBoxFlat in [normal, hover, pressed, disabled]:
		box.content_margin_left = 14.0
		box.content_margin_right = 14.0
	node.add_theme_stylebox_override("normal", normal)
	node.add_theme_stylebox_override("hover", hover)
	node.add_theme_stylebox_override("pressed", pressed)
	node.add_theme_stylebox_override("disabled", disabled)
	node.add_theme_stylebox_override("focus", focus)
	node.add_theme_font_override("font", font_bold)
	node.add_theme_font_size_override("font_size", 13)
	node.add_theme_color_override("font_color", WHITE if kind != "nav" else INK_2)
	node.add_theme_color_override("font_hover_color", CYAN_BRIGHT if kind != "danger" else WHITE)
	node.add_theme_color_override("font_pressed_color", WHITE)
	node.add_theme_color_override("font_focus_color", WHITE)
	node.add_theme_color_override("font_disabled_color", DIM)
	node.add_theme_color_override("icon_disabled_color", Color(1, 1, 1, 0.3))
	node.add_theme_constant_override("h_separation", 10)
	node.add_theme_constant_override("icon_max_width", 18)

func button(text: String, callback: Callable, min_size: Vector2 = Vector2(0, 44), accent: bool = false, icon_name: String = "") -> Button:
	var node: Button = Button.new()
	node.text = text
	node.custom_minimum_size = min_size
	node.pressed.connect(func() -> void:
		AudioManager.play_click()
		callback.call()
	)
	node.mouse_entered.connect(func() -> void:
		if not node.disabled:
			AudioManager.play_hover()
	)
	# Resposta ao clique: o botão "afunda" um pouco enquanto está pressionado.
	node.button_down.connect(func() -> void: press(node, true))
	node.button_up.connect(func() -> void: press(node, false))
	style_button(node, "primary" if accent else "secondary")
	if icon_name != "":
		var texture: Texture2D = icon(icon_name)
		if texture != null:
			node.icon = texture
			node.alignment = HORIZONTAL_ALIGNMENT_LEFT
	return node

## Botão em posição absoluta dentro de um painel.
func button_at(host: Control, pos: Vector2, btn_size: Vector2, text: String, callback: Callable, accent: bool = false, icon_name: String = "") -> Button:
	var node: Button = button(text, callback, btn_size, accent, icon_name)
	node.position = pos
	node.size = btn_size
	host.add_child(node)
	return node

## Desliga um botão e explica o motivo no tooltip.
func disable(node: Button, reason: String) -> void:
	node.disabled = true
	node.tooltip_text = reason
	node.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN

## Interruptor liga/desliga: um botão que mostra o estado por extenso.
func toggle(initial: bool, on_change: Callable) -> Button:
	var node: Button = Button.new()
	node.toggle_mode = true
	node.button_pressed = initial
	node.custom_minimum_size = Vector2(120, 36)
	var refresh: Callable = func() -> void:
		node.text = "LIGADO" if node.button_pressed else "DESLIGADO"
		style_button(node, "primary" if node.button_pressed else "secondary")
	node.toggled.connect(func(pressed: bool) -> void:
		AudioManager.play_click()
		refresh.call()
		on_change.call(pressed)
	)
	refresh.call()
	return node

# =========================================================
# ANIMAÇÕES
# =========================================================

func can_anim() -> bool:
	return motion and animating and not suppress

## Entrada de um nó em posição absoluta. "order" atrasa em cascata.
func enter(node: Control, order: int = 0, offset: Vector2 = Vector2(0, 14)) -> void:
	if node == null or not can_anim():
		return
	var target: Vector2 = node.position
	var delay: float = 0.04 * float(order)
	node.modulate.a = 0.0
	node.position = target + offset
	var tw: Tween = node.create_tween().set_parallel(true)
	tw.tween_property(node, "modulate:a", 1.0, 0.22).set_delay(delay)
	tw.tween_property(node, "position", target, 0.34).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## Entrada só com fade, para filhos de containers (o container manda na posição).
func fade(node: CanvasItem, order: int = 0) -> void:
	if node == null or not can_anim():
		return
	node.modulate.a = 0.0
	node.create_tween().tween_property(node, "modulate:a", 1.0, 0.24).set_delay(0.04 * float(order))

## Anima um número do último valor exibido até o atual. "key" identifica o número.
func count(node: Label, key: String, value: float, fmt: Callable) -> void:
	var from: float = float(shown.get(key, 0.0))
	shown[key] = value
	if not motion or suppress or is_equal_approx(from, value):
		node.text = str(fmt.call(value))
		return
	node.text = str(fmt.call(from))
	var tw: Tween = node.create_tween()
	tw.tween_method(func(v: float) -> void: node.text = str(fmt.call(v)), from, value, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## Anima a propriedade "progress" ou "value" de um componente desenhado.
func tween_prop(node: Node, property: String, from: float, to: float, duration: float = 0.7, delay: float = 0.0) -> void:
	if not motion or suppress or is_equal_approx(from, to):
		node.set(property, to)
		return
	node.set(property, from)
	node.create_tween().tween_property(node, property, to, duration).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func press(node: Button, down: bool) -> void:
	if not motion or not is_instance_valid(node) or node.disabled:
		return
	node.pivot_offset = node.size * 0.5
	node.create_tween().tween_property(node, "scale", Vector2.ONE * (0.97 if down else 1.0), 0.08)

## Pisca devagar (pontos de status, cursores, alertas).
func pulse(node: CanvasItem, low: float = 0.35, period: float = 1.4) -> void:
	if not motion:
		return
	var tw: Tween = node.create_tween().set_loops()
	tw.tween_property(node, "modulate:a", low, period * 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(node, "modulate:a", 1.0, period * 0.5).set_trans(Tween.TRANS_SINE)

## Barra de progresso. Com "key", parte do último valor exibido (para números
## que mudam durante o jogo). Sem "key", cresce do zero na entrada da tela.
func bar(host: Control, pos: Vector2, width: float, ratio: float, color: Color, key: String = "", height: float = 8.0) -> void:
	var radius: int = int(height * 0.5)
	var track: Panel = Panel.new()
	track.position = pos
	track.size = Vector2(width, height)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	track.add_theme_stylebox_override("panel", flat(TRACK, Color.TRANSPARENT, radius, 0))
	host.add_child(track)
	var fill: ColorRect = ColorRect.new()
	fill.color = color
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(fill)
	var target: float = width * clampf(ratio, 0.0, 1.0)
	var from: float = target
	if key != "":
		from = width * clampf(float(shown.get(key, 0.0)), 0.0, 1.0)
		shown[key] = ratio
	elif can_anim():
		from = 0.0
	fill.size = Vector2(from, height)
	if motion and not suppress and not is_equal_approx(from, target):
		fill.create_tween().tween_property(fill, "size:x", target, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		fill.size.x = target

func sparkline(host: Control, pos: Vector2, spark_size: Vector2, values: Array, color: Color = CYAN) -> void:
	var spark: W.Spark = W.Spark.new()
	spark.position = pos
	spark.size = spark_size
	spark.values = values
	spark.line_color = color
	host.add_child(spark)
	if can_anim():
		tween_prop(spark, "progress", 0.0, 1.0, 0.8, 0.15)
