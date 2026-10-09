extends CanvasLayer
## PopupManager — notícias e decisões que interrompem o jogo.
##
## Um popup é descrito por um dicionário ("evento"):
##   style    "news", "official" ou "cartel" (muda as cores e o cabeçalho)
##   kicker   faixa do topo            source   linha pequena acima do título
##   title, body                       impact   efeito, em uma linha (opcional)
##   options  [{label, detail, enabled, danger, quiet, action}]
##            vazio = popup só de leitura, com um botão para fechar
## action é um Callable que aplica a escolha e devolve {ok, message}.
##
## Uso:  var mensagem: String = await PopupManager.show_event(evento)
##
## O layout é todo em containers: título e texto têm largura fixa e quebra de
## linha, e a altura do painel acompanha o conteúdo. Era a falta disso que
## fazia o texto vazar do popup de notícias.

signal closed(message: String)

const WIDTH: float = 760.0

var root_ui: Control
var _is_open: bool = false
var _dismissible: bool = false

func _ready() -> void:
	layer = 200
	root_ui = Control.new()
	root_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ui.theme = UI.theme
	root_ui.visible = false
	add_child(root_ui)

func is_open() -> bool:
	return _is_open

func clear_popup() -> void:
	for child: Node in root_ui.get_children():
		child.queue_free()
	root_ui.visible = false
	root_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _is_open:
		_is_open = false
		closed.emit("")

func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo or not _is_open:
		return
	# Popups de leitura fecham com Enter, Espaço ou Esc. Decisões exigem um clique.
	if _dismissible and (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER or key.keycode == KEY_SPACE or key.keycode == KEY_ESCAPE):
		_resolve("")
	get_viewport().set_input_as_handled()

## Mostra um evento e espera o jogador responder. Devolve a mensagem do resultado.
func show_event(event: Dictionary) -> String:
	if _is_open:
		clear_popup()
	_build(event)
	var message: String = await closed
	return message

func _resolve(message: String) -> void:
	if not _is_open:
		return
	_is_open = false
	for child: Node in root_ui.get_children():
		child.queue_free()
	root_ui.visible = false
	root_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	closed.emit(message)

func _build(event: Dictionary) -> void:
	for child: Node in root_ui.get_children():
		child.queue_free()
	var style: String = str(event.get("style", "official"))
	var options: Array = event.get("options", [])
	_dismissible = options.is_empty()
	_is_open = true
	get_viewport().gui_release_focus()
	root_ui.visible = true
	root_ui.mouse_filter = Control.MOUSE_FILTER_STOP
	if style == "news":
		AudioManager.play_warning()
	else:
		AudioManager.play_transition()

	# Cores por tipo: notícia (vermelho de plantão), ofício (cinza de repartição),
	# cartel (preto e vermelho escuro).
	var border: Color = UI.RED
	var band: Color = Color("#8C2027")
	var band_ink: Color = Color.WHITE
	if style == "official":
		border = Color("#B9C4CB")
		band = Color("#26343E")
		band_ink = Color("#E4E9ED")
	elif style == "cartel":
		border = Color("#7A1F24")
		band = Color("#1A0C0E")
		band_ink = UI.RED

	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.70)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_ui.add_child(shade)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_ui.add_child(center)

	var holder: PanelContainer = PanelContainer.new()
	holder.custom_minimum_size.x = WIDTH
	var box: StyleBoxFlat = UI.flat(Color("#0C141E"), border, 8)
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	box.shadow_size = 24
	holder.add_theme_stylebox_override("panel", box)
	center.add_child(holder)
	var frame: VBoxContainer = VBoxContainer.new()
	frame.add_theme_constant_override("separation", 0)
	holder.add_child(frame)

	# Faixa do topo.
	var band_box: PanelContainer = PanelContainer.new()
	var band_style: StyleBoxFlat = UI.flat(band, Color.TRANSPARENT, 0, 0)
	band_style.corner_radius_top_left = 7
	band_style.corner_radius_top_right = 7
	band_style.content_margin_left = 22.0
	band_style.content_margin_right = 22.0
	band_style.content_margin_top = 11.0
	band_style.content_margin_bottom = 11.0
	band_box.add_theme_stylebox_override("panel", band_style)
	frame.add_child(band_box)
	band_box.add_child(UI.caps(str(event.get("kicker", "")), band_ink, 13))

	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["margin_left", "margin_right"]:
		margin.add_theme_constant_override(side, 26)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 24)
	frame.add_child(margin)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	margin.add_child(col)
	var inner: float = WIDTH - 52.0

	if str(event.get("source", "")) != "":
		col.add_child(UI.caps(str(event["source"]), UI.MUTED, 11))
	var title: Label = UI.paragraph(str(event.get("title", "")), 28, UI.WHITE, inner)
	title.add_theme_font_override("font", UI.font_display)
	col.add_child(title)

	# Notícia: "foto" à esquerda e texto à direita. Os outros: só o texto.
	if style == "news":
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 22)
		col.add_child(row)
		var photo: PanelContainer = PanelContainer.new()
		photo.custom_minimum_size = Vector2(180, 132)
		photo.add_theme_stylebox_override("panel", UI.flat(UI.SURFACE, Color("#314655"), 6))
		photo.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(photo)
		var wire: Label = UI.display("NEWS\nWIRE", 26, UI.CYAN)
		wire.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		wire.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		photo.add_child(wire)
		var text_col: VBoxContainer = VBoxContainer.new()
		text_col.add_theme_constant_override("separation", 12)
		row.add_child(text_col)
		text_col.add_child(UI.paragraph(str(event.get("body", "")), 16, UI.INK_2, inner - 202.0))
		if str(event.get("impact", "")) != "":
			text_col.add_child(_impact(str(event["impact"]), inner - 202.0))
	else:
		col.add_child(UI.paragraph(str(event.get("body", "")), 16, UI.INK_2, inner))
		if str(event.get("impact", "")) != "":
			col.add_child(_impact(str(event["impact"]), inner))

	var rule: ColorRect = ColorRect.new()
	rule.custom_minimum_size = Vector2(inner, 1)
	rule.color = Color("#263846")
	col.add_child(rule)

	if options.is_empty():
		var close: Button = UI.button("FECHAR" if style == "news" else "ENTENDI", func() -> void: _resolve(""), Vector2(170, 44), true)
		close.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		col.add_child(close)
	else:
		col.add_child(UI.caps("SUAS OPÇÕES", UI.MUTED, 11))
		for option_v: Variant in options:
			col.add_child(_option_row(option_v as Dictionary, inner))

	if UI.motion:
		shade.modulate.a = 0.0
		holder.modulate.a = 0.0
		center.position.y = 20.0
		var tw: Tween = root_ui.create_tween().set_parallel(true)
		tw.tween_property(shade, "modulate:a", 1.0, 0.18)
		tw.tween_property(holder, "modulate:a", 1.0, 0.2)
		tw.tween_property(center, "position:y", 0.0, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _impact(text: String, width: float) -> Label:
	return UI.paragraph("EFEITO: " + text.to_upper(), 12, UI.ORANGE, width)

## Uma opção de decisão: botão à esquerda, consequência escrita à direita.
func _option_row(option: Dictionary, width: float) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var enabled: bool = bool(option.get("enabled", true))
	var danger: bool = bool(option.get("danger", false))
	var quiet: bool = bool(option.get("quiet", false))
	var action: Callable = option.get("action", Callable())
	var button: Button = UI.button(str(option.get("label", "OPÇÃO")), func() -> void:
		var message: String = ""
		if action.is_valid():
			var result: Variant = action.call()
			if typeof(result) == TYPE_DICTIONARY:
				message = str((result as Dictionary).get("message", ""))
		AudioManager.play_confirm()
		_resolve(message)
	, Vector2(270, 46), not danger and not quiet)
	if danger:
		UI.style_button(button, "danger")
	if not enabled:
		UI.disable(button, "Você não tem o que esta opção exige.")
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(button)
	var detail: Label = UI.paragraph(str(option.get("detail", "")), 13, UI.INK_2 if enabled else UI.DIM, width - 286.0)
	detail.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(detail)
	return row
