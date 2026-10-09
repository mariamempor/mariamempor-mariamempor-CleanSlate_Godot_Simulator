extends Control
## CLEAN SLATE — casca da interface.
##
## Este script monta as telas "de fora" (menu, manual, passagem de ato, fim de
## campanha) e a moldura do dashboard (menu lateral, topo, rodapé). O conteúdo
## de cada aba mora em scripts/ui/tabs/, e os componentes compartilhados em
## scripts/ui/ui_kit.gd (autoload UI).
##
## O que as abas usam daqui: switch_tab, refresh, toast, result_toast,
## open_modal, close_modal, modal_header, amount_modal, confirm_modal, show_help.

const B = preload("res://scripts/data/balance.gd")
const T = preload("res://scripts/data/texts.gd")
const W = preload("res://scripts/ui/widgets.gd")

const TAB_SCRIPTS: Dictionary = {
	"overview": preload("res://scripts/ui/tabs/tab_overview.gd"),
	"companies": preload("res://scripts/ui/tabs/tab_companies.gd"),
	"staff": preload("res://scripts/ui/tabs/tab_staff.gd"),
	"lifestyle": preload("res://scripts/ui/tabs/tab_lifestyle.gd"),
	"wallet": preload("res://scripts/ui/tabs/tab_wallet.gd"),
	"transactions": preload("res://scripts/ui/tabs/tab_transactions.gd"),
	"news": preload("res://scripts/ui/tabs/tab_news.gd"),
	"risk": preload("res://scripts/ui/tabs/tab_risk.gd"),
	"darkweb": preload("res://scripts/ui/tabs/tab_darkweb.gd")
}

var backdrop: Control
var main_layer: Control
var modal_layer: Control
var toast_layer: Control
var crt_overlay: Control
var content: Control                # a aba aberta
var current_tab: String = "overview"
var tutorial_step: int = 0
var clock_label: Label
## Chamado quando o jogador aperta Enter com um modal aberto.
var modal_accept: Callable = Callable()
## Um ponto por dia para as linhas de tendência (vale para a sessão).
var history: Dictionary = {"dirty": [], "clean": [], "worth": [], "suspicion": []}

var _screen: String = ""            # menu, tutorial, dashboard, act, escape, settings, credits, end
var _toasts: Array = []
var _modal: Control
var _dock_time: Label
var _built_size: Vector2 = Vector2.ZERO
var _relayout_queued: bool = false
var _flow_busy: bool = false        # troca de turno, popups ou final em andamento

func _ready() -> void:
	theme = UI.theme
	_setup_backdrop()
	_setup_root()
	GameManager.stats_changed.connect(_on_stats_changed)
	Campaign.ending_reached.connect(_on_ending_reached)
	get_viewport().size_changed.connect(_on_viewport_resized)
	show_menu()
	AudioManager.play_ambient()

func _process(_delta: float) -> void:
	if GameManager.state != GameManager.GameState.WORK:
		return
	var time_text: String = GameManager.format_time(GameManager.current_time_minutes)
	if is_instance_valid(clock_label):
		clock_label.text = time_text
	if is_instance_valid(_dock_time) and not Campaign.escape_active:
		_dock_time.text = time_text

func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo or _flow_busy or PopupManager.is_open():
		return
	if _modal != null and is_instance_valid(_modal):
		if key.keycode == KEY_ESCAPE:
			close_modal()
			accept_event()
		elif (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER) and modal_accept.is_valid():
			var accept: Callable = modal_accept
			accept.call()
			accept_event()
		return
	match _screen:
		"dashboard":
			var tabs: Array = visible_tabs()
			var index: int = key.keycode - KEY_1
			if index >= 0 and index < tabs.size():
				switch_tab(str(tabs[index]))
				accept_event()
			elif key.keycode == KEY_F1:
				show_help(current_tab)
				accept_event()
		"tutorial":
			if key.keycode == KEY_RIGHT and tutorial_step < T.MANUAL.size() - 1:
				show_tutorial(tutorial_step + 1)
			elif key.keycode == KEY_LEFT and tutorial_step > 0:
				show_tutorial(tutorial_step - 1)
			elif key.keycode == KEY_ESCAPE:
				show_menu()
		"settings", "credits":
			if key.keycode == KEY_ESCAPE:
				show_menu()

# =========================================================
# CAMADAS E TROCA DE TELA
# =========================================================

func _setup_backdrop() -> void:
	backdrop = Control.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.set_script(load("res://scripts/backdrop.gd") as Script)
	add_child(backdrop)
	move_child(backdrop, 0)

func _setup_root() -> void:
	# Três camadas: a tela (refeita a cada troca), os modais e os avisos.
	# Os avisos ficam fora da main_layer para sobreviver quando a tela é refeita.
	main_layer = _layer(Control.MOUSE_FILTER_PASS)
	modal_layer = _layer(Control.MOUSE_FILTER_IGNORE)
	toast_layer = _layer(Control.MOUSE_FILTER_IGNORE)
	toast_layer.z_index = 180
	crt_overlay = Control.new()
	crt_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	crt_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crt_overlay.z_index = 190
	crt_overlay.set_script(load("res://scripts/crt_overlay.gd") as Script)
	add_child(crt_overlay)

func _layer(filter: Control.MouseFilter) -> Control:
	var layer: Control = Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = filter
	add_child(layer)
	return layer

func _clear_root() -> void:
	for child: Node in main_layer.get_children():
		child.queue_free()
	for child: Node in modal_layer.get_children():
		child.queue_free()
	_modal = null
	modal_accept = Callable()
	clock_label = null
	_dock_time = null
	content = null

## Passo comum a toda troca de tela.
func _begin_screen(screen: String, backdrop_mode: String) -> void:
	_clear_root()
	_screen = screen
	_built_size = get_viewport_rect().size
	if backdrop.has_method("set_mode"):
		backdrop.call("set_mode", backdrop_mode)
	crt_overlay.visible = true

## Tamanho usado no layout. O piso evita que a tela "desmonte" em janelas pequenas.
func vp() -> Vector2:
	var s: Vector2 = get_viewport_rect().size
	return Vector2(maxf(s.x, 1180.0), maxf(s.y, 680.0))

func _on_viewport_resized() -> void:
	if _relayout_queued or _screen == "":
		return
	_relayout_queued = true
	await get_tree().create_timer(0.15).timeout
	_relayout_queued = false
	if get_viewport_rect().size.is_equal_approx(_built_size) or _flow_busy or PopupManager.is_open():
		return
	if _modal != null and is_instance_valid(_modal):
		return
	UI.suppress = true
	match _screen:
		"menu": show_menu()
		"tutorial": show_tutorial(tutorial_step)
		"dashboard": show_dashboard(current_tab, false)
		"settings": show_settings()
		"credits": show_credits()
		"act": show_act_intro()
		"escape": show_escape_intro()
		"end": show_end_screen()
	UI.suppress = false

# =========================================================
# AVISOS (TOASTS) E MODAIS
# =========================================================

func toast(message: String, color: Color = UI.CYAN) -> void:
	if message == "":
		return
	var card: PanelContainer = PanelContainer.new()
	var box: StyleBoxFlat = UI.flat(Color("#0B1820"), Color(color, 0.55), 6)
	box.border_width_left = 3
	box.content_margin_left = 14.0
	box.content_margin_right = 16.0
	box.content_margin_top = 10.0
	box.content_margin_bottom = 10.0
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.4)
	box.shadow_size = 10
	card.add_theme_stylebox_override("panel", box)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(UI.label(message, 13, UI.WHITE))
	toast_layer.add_child(card)

	# No dashboard, o aviso aparece sobre a faixa "Próximo passo", no rodapé, para
	# não cobrir números nem botões. Nas outras telas, fica no canto superior direito.
	var card_size: Vector2 = card.get_combined_minimum_size()
	card.size = card_size
	var view: Vector2 = vp()
	var bottom: bool = _screen == "dashboard"
	var target: Vector2 = Vector2(view.x - card_size.x - UI.GUTTER, 28.0)
	var from: Vector2 = target + Vector2(36, 0)
	var push: float = card_size.y + 8.0
	if bottom:
		target = Vector2(UI.SIDEBAR_W + UI.GUTTER + 10.0, view.y - UI.DOCK_H - 14.0 + (UI.DOCK_H - card_size.y) * 0.5)
		from = target + Vector2(0, 24)
		push = -push
	for other_v: Variant in _toasts:
		var other: Control = other_v as Control
		if is_instance_valid(other):
			other.create_tween().tween_property(other, "position:y", other.position.y + push, 0.2)
	_toasts.push_front(card)
	card.position = from if UI.motion else target
	var tw: Tween = card.create_tween()
	if UI.motion:
		card.modulate.a = 0.0
		tw.set_parallel(true)
		tw.tween_property(card, "modulate:a", 1.0, 0.18)
		tw.tween_property(card, "position", target, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.set_parallel(false)
	tw.tween_interval(3.0)
	tw.tween_property(card, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func() -> void:
		_toasts.erase(card)
		card.queue_free()
	)

func clear_toasts() -> void:
	for card_v: Variant in _toasts:
		var card: Control = card_v as Control
		if is_instance_valid(card):
			card.queue_free()
	_toasts.clear()

## Mostra o resultado de uma ação do jogo: {ok, message}.
func result_toast(result: Dictionary) -> void:
	var ok: bool = bool(result.get("ok", false))
	if ok:
		AudioManager.play_confirm()
	else:
		AudioManager.play_warning()
	toast(str(result.get("message", "")), UI.GREEN if ok else UI.RED)

## Abre um modal centralizado e devolve a coluna onde o conteúdo deve entrar.
## Esc ou clique fora fecham. Enter chama modal_accept, se definido.
func open_modal(width: float, border: Color = UI.CYAN) -> VBoxContainer:
	close_modal(true)
	# Tira o foco do botão que abriu o modal. Sem isso, Enter apertaria de novo
	# o botão que ficou por baixo, em vez de confirmar o modal.
	get_viewport().gui_release_focus()
	var root: Control = Control.new()
	root.name = "Modal"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.z_index = 120
	modal_layer.add_child(root)

	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.0, 0.02, 0.04, 0.74)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.gui_input.connect(func(event: InputEvent) -> void:
		var click: InputEventMouseButton = event as InputEventMouseButton
		if click != null and click.pressed:
			close_modal()
	)
	root.add_child(shade)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var holder: PanelContainer = PanelContainer.new()
	holder.custom_minimum_size.x = width
	holder.mouse_filter = Control.MOUSE_FILTER_STOP
	var box: StyleBoxFlat = UI.flat(Color("#0C151E"), border, 10)
	box.set_content_margin_all(26.0)
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	box.shadow_size = 24
	holder.add_theme_stylebox_override("panel", box)
	center.add_child(holder)

	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	holder.add_child(col)

	_modal = root
	if UI.motion:
		shade.modulate.a = 0.0
		holder.modulate.a = 0.0
		center.position.y = 18.0
		var tw: Tween = root.create_tween().set_parallel(true)
		tw.tween_property(shade, "modulate:a", 1.0, 0.16)
		tw.tween_property(holder, "modulate:a", 1.0, 0.18)
		tw.tween_property(center, "position:y", 0.0, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return col

func close_modal(instant: bool = false) -> void:
	modal_accept = Callable()
	var root: Control = _modal
	_modal = null
	if root == null or not is_instance_valid(root):
		return
	if instant or not UI.motion:
		root.queue_free()
		return
	var tw: Tween = root.create_tween()
	tw.tween_property(root, "modulate:a", 0.0, 0.12)
	tw.tween_callback(root.queue_free)

func modal_open() -> bool:
	return _modal != null and is_instance_valid(_modal)

## Cabeçalho padrão de modal: rótulo, título e botão de fechar.
func modal_header(col: VBoxContainer, kicker: String, title: String, kicker_color: Color = UI.CYAN) -> void:
	var head: HBoxContainer = HBoxContainer.new()
	col.add_child(head)
	var titles: VBoxContainer = VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 2)
	head.add_child(titles)
	titles.add_child(UI.caps(kicker, kicker_color))
	titles.add_child(UI.display(title, 28, UI.WHITE))
	var close: Button = UI.button("FECHAR", func() -> void: close_modal(), Vector2(92, 34))
	close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close.tooltip_text = "Esc"
	head.add_child(close)

## Modal de confirmação simples.
## cfg: kicker, title, text, confirm, cancel (opcional), danger (opcional), on_confirm.
func confirm_modal(cfg: Dictionary) -> void:
	var danger: bool = bool(cfg.get("danger", false))
	var width: float = 460.0
	var col: VBoxContainer = open_modal(width + 52.0, UI.RED if danger else UI.CYAN)
	modal_header(col, str(cfg.get("kicker", "")), str(cfg.get("title", "")), UI.RED if danger else UI.CYAN)
	col.add_child(UI.paragraph(str(cfg.get("text", "")), 14, UI.INK_2, width))
	var on_confirm: Callable = cfg["on_confirm"]
	var run: Callable = func() -> void:
		close_modal(true)
		on_confirm.call()
	var footer: HBoxContainer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	col.add_child(footer)
	var confirm: Button = UI.button(str(cfg.get("confirm", "CONFIRMAR")), run, Vector2(210, 46), true)
	if danger:
		UI.style_button(confirm, "danger")
	footer.add_child(confirm)
	footer.add_child(UI.button(str(cfg.get("cancel", "CANCELAR")), func() -> void: close_modal(), Vector2(140, 46)))
	modal_accept = run

## Modal de "quanto?": campo de valor, atalhos de 25%, 50% e Máx e uma prévia
## que se atualiza enquanto o jogador mexe no valor.
## cfg:
##   kicker, title, text        cabeçalho e explicação
##   tiles                      [[rótulo, valor, cor, dica]] (opcional)
##   max, value, step, minimum  limites do campo
##   blocked                    se não for "", desliga o campo e mostra o motivo
##   preview                    Callable(valor) -> [[rótulo, texto, cor]]
##   note                       linha de apoio abaixo da prévia
##   confirm, icon              texto e ícone do botão
##   on_confirm                 Callable(valor) -> {ok, message}
func amount_modal(cfg: Dictionary) -> void:
	var width: float = 620.0
	var limit: float = float(cfg.get("max", 0.0))
	var minimum: float = float(cfg.get("minimum", B.MIN_OPERATION))
	var step: float = float(cfg.get("step", 1000.0))
	var blocked: String = str(cfg.get("blocked", ""))
	if blocked == "" and limit < minimum:
		blocked = "Não há valor disponível para esta operação."
	var enabled: bool = blocked == ""

	var col: VBoxContainer = open_modal(width + 52.0)
	modal_header(col, str(cfg.get("kicker", "")), str(cfg.get("title", "")))
	if str(cfg.get("text", "")) != "":
		col.add_child(UI.paragraph(str(cfg["text"]), 14, UI.INK_2, width))
	var tiles: Array = cfg.get("tiles", [])
	if not tiles.is_empty():
		var tile_row: HBoxContainer = HBoxContainer.new()
		tile_row.add_theme_constant_override("separation", 10)
		col.add_child(tile_row)
		for tile_v: Variant in tiles:
			var tile: Array = tile_v as Array
			tile_row.add_child(UI.tile(str(tile[0]), str(tile[1]), tile[2], str(tile[3]) if tile.size() > 3 else ""))

	col.add_child(UI.caps(str(cfg.get("field", "VALOR")), UI.MUTED))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	var input: SpinBox = SpinBox.new()
	input.custom_minimum_size = Vector2(250, 46)
	input.min_value = minimum
	input.max_value = maxf(limit, minimum)
	input.step = step
	input.prefix = "R$"
	input.value = clampf(float(cfg.get("value", limit)), minimum, maxf(limit, minimum))
	input.editable = enabled
	input.select_all_on_focus = true
	row.add_child(input)
	for quick_v: Variant in [["25%", 0.25], ["50%", 0.5], ["MÁX", 1.0]]:
		var quick: Array = quick_v as Array
		var share: float = float(quick[1])
		var quick_button: Button = UI.button(str(quick[0]), func() -> void:
			input.value = maxf(minimum, floorf(limit * share / step) * step if share < 1.0 else limit)
		, Vector2(66, 46))
		quick_button.disabled = not enabled
		quick_button.tooltip_text = "%s do limite de %s" % [str(quick[0]), UI.money(limit)]
		row.add_child(quick_button)

	# Prévia: mostra o resultado antes de o jogador se comprometer.
	var preview: Callable = cfg.get("preview", Callable())
	if preview.is_valid():
		var holder: PanelContainer = PanelContainer.new()
		var box: StyleBoxFlat = UI.flat(UI.SURFACE, UI.LINE, 6)
		box.set_content_margin_all(14.0)
		holder.add_theme_stylebox_override("panel", box)
		col.add_child(holder)
		var lines: VBoxContainer = VBoxContainer.new()
		lines.add_theme_constant_override("separation", 8)
		holder.add_child(lines)
		var value_labels: Array = []
		for line_v: Variant in preview.call(input.value) as Array:
			var line: Array = line_v as Array
			var kv: HBoxContainer = UI.kv_line(str(line[0]), str(line[1]), line[2])
			lines.add_child(kv)
			value_labels.append(kv.get_meta("value_label"))
		input.value_changed.connect(func(v: float) -> void:
			var updated: Array = preview.call(v) as Array
			for i: int in range(mini(updated.size(), value_labels.size())):
				var target: Label = value_labels[i]
				target.text = str(updated[i][1])
				target.add_theme_color_override("font_color", updated[i][2])
		)

	var note: String = blocked if not enabled else str(cfg.get("note", ""))
	if note != "":
		col.add_child(UI.paragraph(note, 12, UI.MUTED if enabled else UI.ORANGE, width))

	var on_confirm: Callable = cfg["on_confirm"]
	var run: Callable = func() -> void:
		if not enabled:
			return
		var amount: float = input.value
		close_modal(true)
		result_toast(on_confirm.call(amount))
	var footer: HBoxContainer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	col.add_child(footer)
	var execute: Button = UI.button(str(cfg.get("confirm", "CONFIRMAR")), run, Vector2(235, 48), true, str(cfg.get("icon", "")))
	execute.disabled = not enabled
	footer.add_child(execute)
	footer.add_child(UI.button("CANCELAR", func() -> void: close_modal(), Vector2(130, 48), false, "back"))
	footer.add_child(UI.spacer(0, true))
	var keys: Label = UI.caps("ENTER CONFIRMA / ESC CANCELA", UI.DIM)
	keys.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(keys)

	modal_accept = run
	var line_edit: LineEdit = input.get_line_edit()
	line_edit.text_submitted.connect(func(_text: String) -> void: run.call())
	line_edit.gui_input.connect(func(event: InputEvent) -> void:
		var key: InputEventKey = event as InputEventKey
		if key != null and key.pressed and key.keycode == KEY_ESCAPE:
			close_modal()
	)
	if enabled:
		line_edit.grab_focus.call_deferred()

## Modal de ajuda de uma aba: o que cada número significa e o que clicar.
func show_help(tab: String) -> void:
	if not T.HELP.has(tab):
		return
	var info: Dictionary = T.HELP[tab]
	var width: float = 620.0
	var col: VBoxContainer = open_modal(width + 52.0)
	modal_header(col, "COMO FUNCIONA", str(info["title"]))
	col.add_child(UI.paragraph(T.fill(str(info["lead"])), 15, UI.INK_2, width))
	var terms: Array = info["terms"]
	if not terms.is_empty():
		col.add_child(UI.caps("O QUE CADA COISA SIGNIFICA", UI.MUTED))
		for term_v: Variant in terms:
			var term: Array = term_v as Array
			col.add_child(UI.term_item(str(term[0]), T.fill(str(term[1])), width))
	var how: Array = info["how"]
	if not how.is_empty():
		col.add_child(UI.caps("O QUE FAZER", UI.MUTED))
		for i: int in range(how.size()):
			col.add_child(UI.list_item(str(i + 1), T.fill(str(how[i])), width))
	var done: Button = UI.button("ENTENDI", func() -> void: close_modal(), Vector2(150, 44), true)
	done.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(done)
	modal_accept = func() -> void: close_modal()

# =========================================================
# MENU
# =========================================================

func show_menu() -> void:
	_begin_screen("menu", "menu")
	UI.animating = true
	var view: Vector2 = vp()

	var badge: Label = UI.display("CLEAN SLATE", 64, UI.CYAN_BRIGHT)
	badge.position = Vector2(60, 38)
	main_layer.add_child(badge)
	var cursor: Label = UI.display("_", 64, UI.CYAN)
	cursor.position = Vector2(66.0 + UI.text_width(badge), 38)
	main_layer.add_child(cursor)
	UI.pulse(cursor, 0.0, 1.0)
	if UI.can_anim():
		# O título é "digitado": visible_ratio revela o texto da esquerda para a direita.
		badge.visible_ratio = 0.0
		badge.create_tween().tween_property(badge, "visible_ratio", 1.0, 0.5)

	var sub: Label = UI.caps("SIMULADOR DE LAVAGEM DE DINHEIRO", UI.ORANGE, 15)
	sub.position = Vector2(62, 124)
	main_layer.add_child(sub)
	UI.enter(sub, 3, Vector2(-14, 0))
	UI.rule(main_layer, Vector2(60, 156), 420.0, Color("#294856"))
	var dot: ColorRect = ColorRect.new()
	dot.position = Vector2(62, 173)
	dot.size = Vector2(7, 7)
	dot.color = UI.GREEN
	main_layer.add_child(dot)
	UI.pulse(dot)
	main_layer.add_child(UI.at(UI.caps("ESTAÇÃO SEGURA / REDE LOCAL", UI.GREEN, 11), Vector2(78, 168)))

	var entries: Array = []
	if GameManager.has_save():
		entries.append(["CONTINUAR", _load_and_open, true, "play"])
		entries.append(["NOVA CAMPANHA", _confirm_new_game, false, "next"])
	else:
		entries.append(["NOVA CAMPANHA", _start_new_game, true, "play"])
	entries.append(["MANUAL DO CONSULTOR", func() -> void: show_tutorial(0), false, "manual"])
	entries.append(["CONFIGURAÇÕES", show_settings, false, "settings"])
	entries.append(["CRÉDITOS", show_credits, false, "credits"])
	entries.append(["SAIR", func() -> void: get_tree().quit(), false, "exit"])
	for i: int in range(entries.size()):
		var entry: Array = entries[i]
		var button: Button = UI.button_at(main_layer, Vector2(60, 214.0 + float(i) * 58.0), Vector2(350, 48), str(entry[0]), entry[1], bool(entry[2]), str(entry[3]))
		UI.enter(button, i + 4, Vector2(-18, 0))

	# Resumo de como o jogo funciona, para quem abre o menu pela primeira vez.
	var brief_w: float = 470.0
	var brief: Panel = UI.panel(main_layer, Vector2(view.x - 60.0 - brief_w, 214), Vector2(brief_w, 300), Color(UI.PANEL, 0.94))
	UI.enter(brief, 8)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 24)
	brief.add_child(margin)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	box.add_child(UI.bold("Como funciona", 18, UI.WHITE))
	var rules: Array[String] = [
		"Toda noite chega uma remessa de dinheiro sujo. Você tem um prazo para transformá-la em patrimônio.",
		"Empresas de fachada lavam o dinheiro. Laranjas aumentam a capacidade. Bens dão prestígio.",
		"Tudo isso gera suspeita. São três atos, cada um com uma ameaça maior, e cinco finais possíveis."
	]
	for i: int in range(rules.size()):
		box.add_child(UI.list_item(str(i + 1), rules[i], brief_w - 48.0))
	box.add_child(UI.spacer(0, true))
	var read: Button = UI.button("LER O MANUAL", func() -> void: show_tutorial(0), Vector2(190, 40), false, "manual")
	read.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.add_child(read)

	# Finais já vistos: o que dá vontade de jogar de novo.
	var gallery: Panel = UI.panel(main_layer, Vector2(view.x - 60.0 - brief_w, 530), Vector2(brief_w, 96), Color(UI.PANEL, 0.94))
	UI.enter(gallery, 9)
	gallery.add_child(UI.at(UI.caps("FINAIS DESCOBERTOS  %d / %d" % [Campaign.unlocked_endings.size(), B.ENDING_ORDER.size()], UI.MUTED), Vector2(24, 14)))
	_endings_row(gallery, Vector2(24, 38), brief_w - 48.0)

	# Versão no alto, à direita: no rodapé o texto se perdia nas janelas dos prédios.
	main_layer.add_child(UI.right(UI.caps("V2.0.0 / BUILD ACADÊMICA  /  GODOT 4.7", UI.MUTED, 11), Vector2(60, 46), view.x - 120.0))

## Uma fileira com os cinco finais: nome para os vistos, "?" para os outros.
func _endings_row(host: Control, pos: Vector2, width: float) -> void:
	var gap: float = 8.0
	var count: int = B.ENDING_ORDER.size()
	var cell_w: float = (width - gap * float(count - 1)) / float(count)
	for i: int in range(count):
		var ending_id: String = str(B.ENDING_ORDER[i])
		var info: Dictionary = B.ENDINGS[ending_id]
		var seen: bool = Campaign.unlocked_endings.has(ending_id)
		var color: Color = (UI.GREEN if bool(info["win"]) else UI.RED) if seen else UI.DIM
		var cell: Panel = UI.panel(host, pos + Vector2(float(i) * (cell_w + gap), 0), Vector2(cell_w, 42), Color(color, 0.10) if seen else UI.SURFACE, Color(color, 0.6) if seen else UI.LINE)
		cell.tooltip_text = "%s: %s" % [str(info["kind"]), str(info["title"])] if seen else "Final ainda não descoberto."
		# Nas células estreitas (menu) entra o nome curto; o completo fica na dica.
		var caption: String = str(info["title"] if cell_w >= 170.0 else info["short"]).to_upper()
		var text: Label = UI.caps(caption if seen else "?", color, 9)
		# A quebra de linha vem antes do tamanho: do contrário o Label cresce para
		# caber o texto em uma linha só e vaza da célula.
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.clip_text = true
		text.position = Vector2(4, 4)
		text.size = Vector2(cell_w - 8.0, 34)
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(text)

func _confirm_new_game() -> void:
	confirm_modal({
		"kicker": "NOVA CAMPANHA", "title": "Apagar a campanha salva?",
		"text": "Existe uma campanha em andamento. Começar outra substitui o save quando você salvar de novo.",
		"confirm": "COMEÇAR DO ZERO", "danger": true, "on_confirm": _start_new_game
	})

func _start_new_game() -> void:
	GameManager.new_game()
	_reset_session()
	show_tutorial(0)

func _load_and_open() -> void:
	if GameManager.load_game():
		_reset_session()
		show_dashboard("darkweb" if Campaign.escape_active else "overview")
		toast("Campanha carregada.", UI.GREEN)
	else:
		toast("Não foi possível carregar o save.", UI.RED)

func _reset_session() -> void:
	for key: String in history:
		(history[key] as Array).clear()
	UI.shown.clear()
	_snapshot()

## Guarda um ponto por dia para as linhas de tendência.
func _snapshot() -> void:
	var now: Dictionary = {"dirty": GameManager.dirty_money, "clean": GameManager.clean_money, "worth": GameManager.net_worth(), "suspicion": GameManager.suspicion}
	for key: String in now:
		var series: Array = history[key]
		series.append(float(now[key]))
		if series.size() > 14:
			series.pop_front()

# =========================================================
# MANUAL
# =========================================================

func show_tutorial(step: int) -> void:
	var arriving: bool = _screen != "tutorial"
	_begin_screen("tutorial", "plain")
	tutorial_step = clampi(step, 0, T.MANUAL.size() - 1)
	var view: Vector2 = vp()
	var page: Dictionary = T.MANUAL[tutorial_step]
	var last: bool = tutorial_step == T.MANUAL.size() - 1
	var playing: bool = GameManager.state == GameManager.GameState.TUTORIAL

	# Ao trocar de página, só o conteúdo da direita entra de novo.
	UI.animating = arriving
	var top: Label = UI.display("MANUAL DO CONSULTOR", 34, UI.WHITE)
	top.position = Vector2(72, 34)
	main_layer.add_child(top)
	UI.enter(top, 0, Vector2(-12, 0))
	var hint: Label = UI.label("Oito páginas curtas. Dá para ler em três minutos.", 14, UI.MUTED)
	hint.position = Vector2(74, 80)
	main_layer.add_child(hint)
	UI.enter(hint, 1, Vector2(-12, 0))

	var panel_size: Vector2 = Vector2(view.x - 144.0, view.y - 122.0 - 96.0)
	var panel: Panel = UI.panel(main_layer, Vector2(72, 122), panel_size, UI.PANEL, Color("#28414D"))
	UI.enter(panel, 2)
	var rail_w: float = 250.0
	for i: int in range(T.MANUAL.size()):
		var index: int = i
		var entry: Button = UI.button_at(panel, Vector2(14, 16.0 + float(i) * 46.0), Vector2(rail_w - 28.0, 40), "%02d   %s" % [i + 1, str(T.MANUAL[i]["nav"])], func() -> void: show_tutorial(index))
		UI.style_button(entry, "nav_active" if i == tutorial_step else "nav")
		entry.alignment = HORIZONTAL_ALIGNMENT_LEFT
	UI.rule(panel, Vector2(rail_w, 0), panel_size.y, UI.LINE, true)

	UI.animating = true
	var metric_w: float = 270.0
	var text_w: float = panel_size.x - rail_w - 36.0 - 36.0 - metric_w - 28.0
	var box: VBoxContainer = VBoxContainer.new()
	box.position = Vector2(rail_w + 36.0, 30)
	box.size = Vector2(text_w, panel_size.y - 60.0)
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	UI.enter(box, 0, Vector2(16, 0))
	box.add_child(UI.caps("PÁGINA %02d DE %02d" % [tutorial_step + 1, T.MANUAL.size()], UI.CYAN))
	box.add_child(UI.display(str(page["title"]), 34, UI.WHITE))
	box.add_child(UI.paragraph(T.fill(str(page["body"])), 16, UI.INK_2, text_w))
	box.add_child(UI.spacer(8))
	var points: Array = page["points"]
	for i: int in range(points.size()):
		box.add_child(UI.list_item(str(i + 1), T.fill(str(points[i])), text_w))

	# Miniatura da tela mostrando onde fica o assunto da página.
	var map_info: Array = page["map"]
	var screen_map: W.ScreenMap = W.ScreenMap.new()
	screen_map.position = Vector2(panel_size.x - 36.0 - metric_w, 30)
	screen_map.size = Vector2(metric_w, 158)
	screen_map.focus = str(map_info[0])
	screen_map.nav_index = int(map_info[1])
	screen_map.line = Color("#2B3F4C")
	screen_map.fill = UI.SURFACE
	screen_map.accent = UI.CYAN
	panel.add_child(screen_map)
	UI.enter(screen_map, 2, Vector2(16, 0))
	var map_note: Label = UI.paragraph(str(page["map_note"]), 12, UI.MUTED, metric_w)
	map_note.position = Vector2(panel_size.x - 36.0 - metric_w, 198)
	panel.add_child(map_note)
	UI.enter(map_note, 2, Vector2(16, 0))

	# Navegação
	var bar_y: float = view.y - 76.0
	var back: Button = UI.button_at(main_layer, Vector2(72, bar_y), Vector2(150, 46), "ANTERIOR", func() -> void: show_tutorial(tutorial_step - 1), false, "back")
	back.disabled = tutorial_step == 0
	if not last:
		UI.button_at(main_layer, Vector2(234, bar_y), Vector2(170, 46), "PRÓXIMO", func() -> void: show_tutorial(tutorial_step + 1), true, "next")
	elif playing:
		UI.button_at(main_layer, Vector2(234, bar_y), Vector2(220, 46), "INICIAR OPERAÇÃO", _begin_campaign, true, "play")
	for i: int in range(T.MANUAL.size()):
		var pip: ColorRect = ColorRect.new()
		pip.position = Vector2(480.0 + float(i) * 24.0, bar_y + 21.0)
		pip.size = Vector2(18, 3)
		pip.color = UI.CYAN if i == tutorial_step else (Color(UI.CYAN, 0.4) if i < tutorial_step else UI.TRACK)
		main_layer.add_child(pip)
	main_layer.add_child(UI.at(UI.caps("SETAS DO TECLADO TAMBÉM NAVEGAM", UI.DIM), Vector2(480.0 + float(T.MANUAL.size()) * 24.0 + 12.0, bar_y + 16.0)))
	if playing:
		UI.button_at(main_layer, Vector2(view.x - 72.0 - 210.0, bar_y), Vector2(210, 46), "PULAR O MANUAL", _begin_campaign, false, "next")
	else:
		UI.button_at(main_layer, Vector2(view.x - 72.0 - 190.0, bar_y), Vector2(190, 46), "VOLTAR AO MENU", show_menu, false, "exit")

func _begin_campaign() -> void:
	GameManager.begin_work()
	show_act_intro()

# =========================================================
# PASSAGEM DE ATO E INÍCIO DA FUGA
# =========================================================

## Cartão de abertura de um ato: meta, prazo, ameaça, o que muda e onde o ato
## fica na campanha.
func show_act_intro() -> void:
	_begin_screen("act", "plain")
	UI.animating = true
	Campaign.pending_screen = ""
	var view: Vector2 = vp()
	var data: Dictionary = Campaign.data()
	var width: float = minf(980.0, view.x - 144.0)
	var x: float = (view.x - width) * 0.5

	var kicker: Label = UI.caps("ATO %d DE %d" % [Campaign.act, B.ACTS.size()], UI.CYAN, 14)
	kicker.position = Vector2(x, 50)
	main_layer.add_child(kicker)
	UI.enter(kicker, 0, Vector2(-14, 0))
	var title: Label = UI.display(str(data["name"]), 54, UI.WHITE)
	title.position = Vector2(x - 2.0, 68)
	main_layer.add_child(title)
	if UI.can_anim():
		title.visible_ratio = 0.0
		title.create_tween().tween_property(title, "visible_ratio", 1.0, 0.7)
	var focus: Label = UI.label(str(data["focus"]), 18, UI.INK_2)
	focus.position = Vector2(x, 140)
	main_layer.add_child(focus)
	UI.enter(focus, 6, Vector2(-14, 0))

	var tiles: HBoxContainer = HBoxContainer.new()
	tiles.position = Vector2(x, 186)
	tiles.size = Vector2(width, 84)
	tiles.add_theme_constant_override("separation", 12)
	main_layer.add_child(tiles)
	UI.enter(tiles, 9)
	tiles.add_child(UI.tile("META DE PATRIMÔNIO", UI.money(float(data["goal"])), UI.GREEN, "Saldo limpo + empresas + bens + carteira.", 24))
	tiles.add_child(UI.tile("PRAZO", "%d dias" % int(data["days"]), UI.WHITE, "", 24))
	tiles.add_child(UI.tile("REMESSA POR NOITE", UI.money(float(data["remessa"])), UI.ORANGE, "Dinheiro sujo que o cliente entrega.", 24))
	tiles.add_child(UI.tile("LIMITE DE SUSPEITA", "%d%%" % int(float(data["limit"])), UI.RED, "", 24))

	var panel_h: float = 206.0
	var panel: Panel = UI.panel(main_layer, Vector2(x, 286), Vector2(width, panel_h), UI.PANEL, Color("#28414D"))
	UI.enter(panel, 12)
	var half: float = (width - UI.PAD * 3.0) * 0.5
	panel.add_child(UI.at(UI.caps("A AMEAÇA: " + str(data["threat"]).to_upper(), UI.RED, 11), Vector2(UI.PAD, 18)))
	panel.add_child(UI.at(UI.paragraph(str(data["threat_text"]), 15, UI.INK_2, half), Vector2(UI.PAD, 42)))
	if float(data["bonus"]) > 0.0:
		panel.add_child(UI.at(UI.caps("ADIANTAMENTO DO CLIENTE", UI.GREEN, 11), Vector2(UI.PAD, 116)))
		panel.add_child(UI.at(UI.mono("+ " + UI.money(float(data["bonus"])), 22, UI.GREEN), Vector2(UI.PAD, 134)))
		panel.add_child(UI.at(UI.label("Já está no seu saldo limpo.", 12, UI.MUTED), Vector2(UI.PAD, 166)))
	var list: VBoxContainer = VBoxContainer.new()
	list.position = Vector2(UI.PAD * 2.0 + half, 18)
	list.size = Vector2(half, 10)
	list.add_theme_constant_override("separation", 7)
	panel.add_child(list)
	list.add_child(UI.caps("O QUE MUDA NESTE ATO", UI.MUTED, 11))
	for unlock_v: Variant in data["unlocks"] as Array:
		list.add_child(UI.list_item("+", str(unlock_v), half))

	# Trilha da campanha: os três atos e a fuga, com o ato atual em destaque.
	var road_y: float = 286.0 + panel_h + 14.0
	var stops: Array = []
	for i: int in range(B.ACTS.size()):
		var act_data: Dictionary = B.ACTS[i]
		stops.append(["ATO %d" % (i + 1), str(act_data["name"]), "%s em %d dias" % [UI.short_money(float(act_data["goal"])), int(act_data["days"])], signi(i + 1 - Campaign.act)])
	stops.append(["DEPOIS", "Operação Fuga", "%d horas para sumir" % int(B.ESCAPE_HOURS), 1])
	var gap: float = 10.0
	var stop_w: float = (width - gap * float(stops.size() - 1)) / float(stops.size())
	for i: int in range(stops.size()):
		var stop: Array = stops[i]
		var state: int = int(stop[3])
		var color: Color = UI.CYAN if state == 0 else (UI.GREEN if state < 0 else UI.DIM)
		var cell: Panel = UI.panel(main_layer, Vector2(x + float(i) * (stop_w + gap), road_y), Vector2(stop_w, 66), Color(color, 0.10) if state == 0 else UI.SURFACE, color if state == 0 else UI.LINE)
		UI.enter(cell, 14 + i)
		cell.add_child(UI.at(UI.caps(str(stop[0]) + ("  /  CONCLUÍDO" if state < 0 else ("  /  AGORA" if state == 0 else "")), color), Vector2(12, 9)))
		var stop_name: Label = UI.bold(str(stop[1]), 13, UI.WHITE if state <= 0 else UI.MUTED)
		UI.clip(stop_name, Vector2(12, 25), Vector2(stop_w - 24.0, 18))
		cell.add_child(stop_name)
		cell.add_child(UI.at(UI.caps(str(stop[2]).to_upper(), UI.MUTED, 9), Vector2(12, 46)))

	var go: Button = UI.button_at(main_layer, Vector2(x, road_y + 66.0 + 16.0), Vector2(240, 50), "COMEÇAR O ATO %d" % Campaign.act, func() -> void: show_dashboard("overview"), true, "play")
	UI.enter(go, 18)

## Cartão de abertura da Operação Fuga.
func show_escape_intro() -> void:
	_begin_screen("escape", "menu")
	UI.animating = true
	Campaign.pending_screen = ""
	var view: Vector2 = vp()
	var width: float = minf(900.0, view.x - 144.0)
	var x: float = (view.x - width) * 0.5
	var by_warrant: bool = Campaign.escape_reason == "mandado"

	var kicker: Label = UI.caps("MANDADO DE PRISÃO PREVENTIVA EXPEDIDO" if by_warrant else "META FINAL BATIDA", UI.RED if by_warrant else UI.GREEN, 14)
	kicker.position = Vector2(x, 80)
	main_layer.add_child(kicker)
	UI.pulse(kicker, 0.4, 1.0)
	var title: Label = UI.display("OPERAÇÃO FUGA", 64, UI.VIOLET)
	title.position = Vector2(x - 2.0, 100)
	main_layer.add_child(title)
	if UI.can_anim():
		title.visible_ratio = 0.0
		title.create_tween().tween_property(title, "visible_ratio", 1.0, 0.5)
	var lead_text: String = "A Polícia Federal tem um mandado no seu nome. Não há mais atos nem prazos: há %d horas para sumir." % int(B.ESCAPE_HOURS)
	if not by_warrant:
		lead_text = "Você bateu a meta do Ato 3. O cliente considera o serviço encerrado, e gente que sabe demais não se aposenta: some. Você tem %d horas." % int(B.ESCAPE_HOURS)
	var lead: Label = UI.paragraph(lead_text, 17, UI.INK_2, width)
	lead.position = Vector2(x, 184)
	main_layer.add_child(lead)
	UI.enter(lead, 5)

	var panel: Panel = UI.panel(main_layer, Vector2(x, 262), Vector2(width, 206), UI.PANEL, Color(UI.VIOLET, 0.5))
	UI.enter(panel, 8)
	var list: VBoxContainer = VBoxContainer.new()
	list.position = Vector2(UI.PAD + 4.0, 20)
	list.size = Vector2(width - UI.PAD * 2.0 - 8.0, 10)
	list.add_theme_constant_override("separation", 10)
	panel.add_child(list)
	list.add_child(UI.caps("O QUE FAZER, NESTA ORDEM", UI.MUTED, 11))
	var steps: Array[String] = [
		"Compre um passaporte e contrate um avião. Sem os dois, não há fuga.",
		"Liquide empresas, bens e carteira. Tudo vira saldo limpo, com deságio.",
		"Converta o saldo limpo em Monero. Só ele embarca com você.",
		"Decole. Cada hora a mais aumenta o que você leva e a chance de ser interceptado."
	]
	for i: int in range(steps.size()):
		list.add_child(UI.list_item(str(i + 1), steps[i], width - UI.PAD * 2.0 - 8.0, UI.VIOLET))
	list.add_child(UI.paragraph("A cada 24 horas de fuga, a suspeita sobe %d pontos. As empresas param de lavar e o cliente não manda mais remessas." % int(B.ESCAPE_DAILY_SUSPICION), 13, UI.MUTED, width - UI.PAD * 2.0 - 8.0))

	var go: Button = UI.button_at(main_layer, Vector2(x, 490), Vector2(260, 50), "ABRIR A DARK WEB", func() -> void: show_dashboard("darkweb"), true, "darkweb")
	UI.enter(go, 12)

# =========================================================
# DASHBOARD: MOLDURA
# =========================================================

## Abas visíveis agora (na fuga, só as que fazem sentido).
func visible_tabs() -> Array:
	if Campaign.escape_active:
		return T.ESCAPE_TABS.duplicate()
	var out: Array = []
	for entry_v: Variant in T.TABS:
		var tab_id: String = str((entry_v as Array)[1])
		if tab_id != "darkweb":
			out.append(tab_id)
	return out

## animate = false atualiza a tela sem repetir a animação de entrada.
func show_dashboard(tab: String = "overview", animate: bool = true) -> void:
	if not visible_tabs().has(tab):
		tab = str(visible_tabs()[0])
	var arriving: bool = _screen != "dashboard"
	var tab_changed: bool = arriving or tab != current_tab
	_begin_screen("dashboard", "dashboard")
	current_tab = tab
	if tab == "news":
		Campaign.fresh_news = 0
	var view: Vector2 = vp()

	UI.animating = animate and arriving
	_build_sidebar()
	_build_header()
	_build_advisor()
	_build_dock()

	content = (TAB_SCRIPTS[tab] as GDScript).new()
	content.position = Vector2(UI.SIDEBAR_W + UI.GUTTER, 16.0 + UI.HEADER_H + 20.0)
	content.size = Vector2(view.x - UI.SIDEBAR_W - UI.GUTTER * 2.0, view.y - content.position.y - UI.DOCK_H - 30.0)
	content.mouse_filter = Control.MOUSE_FILTER_PASS
	content.set("app", self)
	main_layer.add_child(content)
	UI.animating = animate and tab_changed
	content.call("build")
	UI.animating = true

func switch_tab(tab: String) -> void:
	show_dashboard(tab)

## Refaz a aba atual sem animação de entrada (depois de uma ação).
func refresh() -> void:
	if _screen == "dashboard":
		show_dashboard(current_tab, false)

func _nav_badge(tab_id: String) -> Array:
	match tab_id:
		"staff":
			var delating: int = Staff.delating().size()
			if delating > 0:
				return [str(delating), UI.RED]
		"news":
			if Campaign.fresh_news > 0:
				return [str(Campaign.fresh_news), UI.ORANGE]
		"lifestyle":
			if Lifestyle.excess() > 0.0:
				return ["!", UI.ORANGE]
		"risk":
			if GameManager.wiretap_days > 0:
				return ["!", UI.RED]
	return []

func _build_sidebar() -> void:
	var view: Vector2 = vp()
	var rail: Panel = Panel.new()
	rail.position = Vector2.ZERO
	rail.size = Vector2(UI.SIDEBAR_W, view.y)
	var rail_box: StyleBoxFlat = UI.flat(Color(0.031, 0.071, 0.098, 0.94), UI.LINE, 0, 0)
	rail_box.border_width_right = 1
	rail.add_theme_stylebox_override("panel", rail_box)
	main_layer.add_child(rail)
	UI.enter(rail, 0, Vector2(-24, 0))

	var sidebar: VBoxContainer = VBoxContainer.new()
	sidebar.position = Vector2(16, 20)
	sidebar.size = Vector2(UI.SIDEBAR_W - 32.0, view.y - 40.0)
	sidebar.add_theme_constant_override("separation", 4)
	rail.add_child(sidebar)
	sidebar.add_child(UI.display("CLEAN SLATE", 28, UI.CYAN_BRIGHT))
	sidebar.add_child(UI.caps("CONTROL CONSOLE / BUILD 2.0", UI.MUTED))
	sidebar.add_child(UI.spacer(14))

	var tabs: Array = visible_tabs()
	for i: int in range(tabs.size()):
		var tab_id: String = str(tabs[i])
		var active: bool = current_tab == tab_id
		var icon_name: String = tab_id
		for entry_v: Variant in T.TABS:
			if str((entry_v as Array)[1]) == tab_id:
				icon_name = str((entry_v as Array)[2])
		var button: Button = UI.button(T.tab_label(tab_id), switch_tab.bind(tab_id), Vector2(0, 40), false, icon_name)
		UI.style_button(button, "nav_active" if active else "nav")
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var hotkey: Label = UI.caps(str(i + 1), UI.CYAN if active else UI.DIM, 11)
		hotkey.position = Vector2(UI.SIDEBAR_W - 32.0 - 20.0, 12)
		button.add_child(hotkey)
		var badge: Array = _nav_badge(tab_id)
		if not badge.is_empty():
			var chip: PanelContainer = UI.chip(str(badge[0]), badge[1])
			chip.position = Vector2(UI.SIDEBAR_W - 32.0 - 56.0, 10)
			button.add_child(chip)
			UI.pulse(chip, 0.45, 1.1)
		sidebar.add_child(button)

	sidebar.add_child(UI.spacer(0, true))
	var save: Button = UI.button("SALVAR JOGO", func() -> void:
		if GameManager.save_game():
			toast("Jogo salvo.", UI.GREEN)
		else:
			toast("Não foi possível salvar agora.", UI.RED)
	, Vector2(0, 40), false, "save")
	sidebar.add_child(save)
	sidebar.add_child(UI.button("MENU PRINCIPAL", show_menu, Vector2(0, 40), false, "exit"))

## Bloco de largura fixa do topo, com filhos em posição absoluta.
func _block(width: float) -> Control:
	var block: Control = Control.new()
	block.custom_minimum_size = Vector2(width, UI.HEADER_H)
	return block

func _build_header() -> void:
	var view: Vector2 = vp()
	var header: HBoxContainer = HBoxContainer.new()
	header.position = Vector2(UI.SIDEBAR_W + UI.GUTTER, 16)
	header.size = Vector2(view.x - UI.SIDEBAR_W - UI.GUTTER * 2.0, UI.HEADER_H)
	header.add_theme_constant_override("separation", 26)
	main_layer.add_child(header)
	UI.enter(header, 1, Vector2(0, -12))
	var escaping: bool = Campaign.escape_active

	# 1. Ato, dia e horário (na fuga: horas restantes).
	var day_w: float = 214.0
	var day_block: Control = _block(day_w)
	header.add_child(day_block)
	if escaping:
		day_block.tooltip_text = "Horas até a Polícia Federal chegar. Cada ação da fuga gasta tempo."
		day_block.add_child(UI.caps("OPERAÇÃO FUGA", UI.VIOLET))
		clock_label = null
		var hours: Label = UI.mono("", 24, UI.WHITE)
		hours.position = Vector2(0, 12)
		day_block.add_child(hours)
		UI.count(hours, "h_hours", Campaign.escape_hours, func(v: float) -> String: return "%d h restantes" % int(round(v)))
		UI.bar(day_block, Vector2(0, 50), day_w, Campaign.escape_hours / B.ESCAPE_HOURS, UI.VIOLET, "bar_h_hours", 4.0)
	else:
		var total: int = maxi(GameManager.total_days, 1)
		var day: int = GameManager.current_day
		day_block.tooltip_text = "Ato %d, dia %d de %d. %s" % [Campaign.act, day, total, "Prazo prorrogado: não haverá outra chance." if Campaign.extension_used else "Faltam %d dias para o prazo." % Campaign.days_left()]
		var late: bool = Campaign.days_left() <= 5
		day_block.add_child(UI.caps("ATO %d  /  DIA %02d DE %02d" % [Campaign.act, day, total], UI.ORANGE if late else UI.MUTED))
		clock_label = UI.mono(GameManager.format_time(GameManager.current_time_minutes), 24, UI.WHITE)
		clock_label.position = Vector2(0, 12)
		day_block.add_child(clock_label)
		UI.bar(day_block, Vector2(0, 50), day_w, float(day) / float(total), UI.ORANGE if late else UI.CYAN, "bar_h_day", 4.0)

	header.add_child(UI.spacer(0, true))

	# 2. Caixa: os dois saldos que decidem o que dá para fazer agora.
	var cash_w: float = 186.0
	var cash_block: Control = _block(cash_w)
	cash_block.tooltip_text = "Saldo sujo: o que falta lavar. Saldo limpo: o que você pode gastar."
	header.add_child(cash_block)
	cash_block.add_child(UI.caps("SUJO", UI.MUTED))
	var dirty_value: Label = UI.right(UI.mono("", 15, UI.ORANGE), Vector2(0, -3), cash_w)
	cash_block.add_child(dirty_value)
	UI.count(dirty_value, "h_dirty", GameManager.dirty_money, UI.money)
	cash_block.add_child(UI.at(UI.caps("LIMPO", UI.MUTED), Vector2(0, 26)))
	var clean_value: Label = UI.right(UI.mono("", 15, UI.GREEN), Vector2(0, 23), cash_w)
	cash_block.add_child(clean_value)
	UI.count(clean_value, "h_clean", GameManager.clean_money, UI.money)
	UI.rule(cash_block, Vector2(0, 52), cash_w, UI.LINE)

	# 3. Suspeita: é a condição de derrota, então fica à vista em todas as abas.
	var suspicion: float = GameManager.suspicion
	var zone: int = UI.zone_index(suspicion)
	var risk_w: float = 330.0
	var risk_block: Control = _block(risk_w)
	var risk_tip: String = "Se a suspeita chegar a %d%%, a campanha acaba." % int(Campaign.limit())
	if Campaign.act >= 2 and not Campaign.mandado:
		risk_tip += " Acima de %d%% por %d noites: mandado de prisão." % [int(B.MANDADO_LEVEL), B.MANDADO_DAYS]
	risk_block.tooltip_text = risk_tip + " Clique para abrir Risco."
	risk_block.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	risk_block.gui_input.connect(func(event: InputEvent) -> void:
		var click: InputEventMouseButton = event as InputEventMouseButton
		if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			switch_tab("risk")
	)
	header.add_child(risk_block)
	risk_block.add_child(UI.caps("SUSPEITA", UI.MUTED))
	var status_text: String = UI.zone_name(suspicion).to_upper()
	var status_color: Color = UI.zone_color(zone)
	if Campaign.mandado:
		status_text = "MANDADO EXPEDIDO"
		status_color = UI.RED
	elif Campaign.mandado_streak > 0:
		status_text = "MANDADO EM %d NOITE(S)" % (B.MANDADO_DAYS - Campaign.mandado_streak)
		status_color = UI.RED
	elif GameManager.wiretap_days > 0:
		status_text = "GRAMPO ATIVO"
		status_color = UI.RED
	risk_block.add_child(UI.right(UI.caps(status_text, status_color), Vector2.ZERO, risk_w))
	var risk_value: Label = UI.mono("", 24, UI.zone_color(zone))
	risk_value.position = Vector2(0, 12)
	risk_block.add_child(risk_value)
	var meter: W.RiskMeter = W.RiskMeter.new()
	meter.position = Vector2(104, 20)
	meter.size = Vector2(risk_w - 104.0, 24)
	meter.zone_colors = UI.zone_colors()
	meter.track = UI.TRACK
	meter.marker = UI.WHITE
	meter.danger = UI.RED
	meter.limit = Campaign.limit()
	meter.warn = B.MANDADO_LEVEL if Campaign.act >= 2 and not Campaign.mandado else 0.0
	risk_block.add_child(meter)
	UI.tween_prop(meter, "value", float(UI.shown.get("h_meter", 0.0)), suspicion, 0.7)
	UI.shown["h_meter"] = suspicion
	UI.count(risk_value, "h_susp", suspicion, UI.pct)

	# 4. Patrimônio e meta do ato (na fuga: o Monero já convertido).
	var worth_w: float = 214.0
	var worth_block: Control = _block(worth_w)
	header.add_child(worth_block)
	if escaping:
		worth_block.tooltip_text = "Só o Monero sai do país com você."
		worth_block.add_child(UI.caps("MONERO", UI.MUTED))
		worth_block.add_child(UI.right(UI.caps("%d%% DE INTERCEPTAÇÃO" % int(round(Campaign.interception_chance())), UI.RED), Vector2.ZERO, worth_w))
		var monero_value: Label = UI.mono("", 20, UI.VIOLET)
		monero_value.position = Vector2(0, 15)
		worth_block.add_child(monero_value)
		UI.count(monero_value, "h_monero", Portfolio.monero, UI.money)
		UI.bar(worth_block, Vector2(0, 50), worth_w, Portfolio.monero / maxf(Campaign.escape_start_worth, 1.0), UI.VIOLET, "bar_h_monero", 4.0)
	else:
		var ratio: float = Campaign.progress()
		var reached: bool = Campaign.goal_reached()
		worth_block.tooltip_text = "Patrimônio = saldo limpo + empresas + bens + carteira. Meta do ato: %s." % UI.money(Campaign.goal())
		worth_block.add_child(UI.caps("PATRIMÔNIO", UI.MUTED))
		worth_block.add_child(UI.right(UI.caps("META BATIDA" if reached else "%d%% DA META" % int(ratio * 100.0), UI.GREEN if reached else UI.MUTED), Vector2.ZERO, worth_w))
		var worth_value: Label = UI.mono("", 20, UI.GREEN)
		worth_value.position = Vector2(0, 15)
		worth_block.add_child(worth_value)
		UI.count(worth_value, "h_worth", GameManager.net_worth(), UI.money)
		UI.bar(worth_block, Vector2(0, 50), worth_w, ratio, UI.GREEN, "bar_h_goal", 4.0)

## O que sugerir ao jogador agora. Devolve {text, tab, color}.
func next_step() -> Dictionary:
	var suspicion: float = GameManager.suspicion
	if Campaign.escape_active:
		if Campaign.passport == "" or Campaign.jet == "":
			return {"text": "Garanta o passaporte e o avião antes de qualquer outra coisa.", "tab": "darkweb", "color": UI.VIOLET}
		if GameManager.clean_money >= 1000.0:
			return {"text": "Converta o saldo limpo em Monero: só ele embarca.", "tab": "darkweb", "color": UI.VIOLET}
		return {"text": "Liquide o que ainda vale a pena ou decole agora.", "tab": "darkweb", "color": UI.VIOLET}
	if not Staff.delating().is_empty():
		return {"text": "Um laranja está negociando delação. Intervenha antes que o acordo feche.", "tab": "staff", "color": UI.RED}
	if suspicion >= Campaign.limit() - 15.0:
		return {"text": "Suspeita perto do limite do ato. Reduza o risco antes de operar de novo.", "tab": "risk", "color": UI.RED}
	if Campaign.goal_reached():
		return {"text": "Meta do ato batida. Finalize o turno para avançar.", "tab": "", "color": UI.GREEN}
	var has_dirty: bool = GameManager.dirty_money >= B.MIN_OPERATION
	var room: float = 0.0
	for company_id: String in GameManager.owned_ids():
		room += GameManager.remaining_capacity(company_id)
	if has_dirty and room >= B.MIN_OPERATION and GameManager.operations_today() == 0:
		return {"text": "Processe saldo sujo em uma empresa para começar o turno.", "tab": "companies", "color": UI.CYAN}
	if suspicion >= B.STAFF_STRESS_LEVEL and not Staff.roster.is_empty():
		return {"text": "Suspeita acima de %d%%: os laranjas estão se estressando. Vale reduzir o risco." % int(B.STAFF_STRESS_LEVEL), "tab": "risk", "color": UI.ORANGE}
	for company_id: String in B.COMPANY_ORDER:
		if GameManager.company_status(company_id) == "sale" and float(GameManager.companies[company_id]["price"]) <= GameManager.clean_money:
			return {"text": "%s está à venda e cabe no seu saldo." % str(GameManager.companies[company_id]["name"]), "tab": "companies", "color": UI.CYAN}
	Staff.ensure_candidates()
	var free_slots: int = 0
	for company_id: String in GameManager.owned_ids():
		free_slots += Staff.slots_free(company_id)
	if free_slots > 0:
		for candidate_v: Variant in Staff.candidates:
			if Staff.hire_fee(candidate_v) <= GameManager.clean_money:
				return {"text": "Há vaga para laranja: mais capacidade com o mesmo risco.", "tab": "staff", "color": UI.CYAN}
	if Lifestyle.excess() > 0.0:
		return {"text": "Sua ostentação passa da renda declarada. A malha fina pode chegar a qualquer noite.", "tab": "lifestyle", "color": UI.ORANGE}
	if has_dirty and room >= B.MIN_OPERATION:
		return {"text": "Ainda há capacidade hoje. Continue operando ou finalize o turno.", "tab": "companies", "color": UI.CYAN}
	return {"text": "Nada mais a processar hoje. Finalize o turno.", "tab": "", "color": UI.GREEN}

## Faixa "Próximo passo" no rodapé: diz o que fazer agora e leva até lá.
func _build_advisor() -> void:
	var view: Vector2 = vp()
	var step: Dictionary = next_step()
	var color: Color = step["color"]
	var target: String = str(step["tab"])
	var x: float = UI.SIDEBAR_W + UI.GUTTER
	var width: float = view.x - x - UI.GUTTER - UI.DOCK_W - 12.0
	var panel: Panel = UI.panel(main_layer, Vector2(x, view.y - UI.DOCK_H - 14.0), Vector2(width, UI.DOCK_H), UI.SURFACE)
	UI.enter(panel, 3, Vector2(0, 12))
	var dot: ColorRect = ColorRect.new()
	dot.position = Vector2(UI.PAD, 13)
	dot.size = Vector2(7, 7)
	dot.color = color
	panel.add_child(dot)
	UI.pulse(dot)
	panel.add_child(UI.at(UI.caps("PRÓXIMO PASSO", color), Vector2(UI.PAD + 14.0, 9)))
	var has_button: bool = target != "" and target != current_tab
	var text: Label = UI.label(str(step["text"]), 14, UI.WHITE)
	UI.clip(text, Vector2(UI.PAD, 28), Vector2(width - UI.PAD * 2.0 - (180.0 if has_button else 0.0), 20))
	panel.add_child(text)
	if has_button:
		UI.button_at(panel, Vector2(width - 180.0, 10), Vector2(170, 38), "ABRIR %s" % T.tab_label(target), func() -> void: switch_tab(target), false, target)

func _build_dock() -> void:
	var view: Vector2 = vp()
	var escaping: bool = Campaign.escape_active
	var dock: Panel = Panel.new()
	dock.name = "EndTurnDock"
	dock.position = Vector2(view.x - UI.DOCK_W - UI.GUTTER, view.y - UI.DOCK_H - 14.0)
	dock.size = Vector2(UI.DOCK_W, UI.DOCK_H)
	dock.z_index = 50
	UI.style_panel(dock, Color("#0B151D"), Color(UI.VIOLET, 0.6) if escaping else Color("#295567"), 8)
	main_layer.add_child(dock)
	UI.enter(dock, 4, Vector2(0, 12))
	if escaping:
		dock.add_child(UI.at(UI.caps("INTERCEPTAÇÃO", UI.MUTED), Vector2(16, 10)))
		_dock_time = UI.mono("%d%%" % int(round(Campaign.interception_chance())), 18, UI.RED)
		_dock_time.position = Vector2(16, 25)
		dock.add_child(_dock_time)
		var fly: Button = UI.button_at(dock, Vector2(UI.DOCK_W - 194.0, 8), Vector2(186, 42), "DECOLAR", request_takeoff, true, "escape")
		if not Campaign.ready_to_fly():
			UI.disable(fly, "Faltam o passaporte e o avião.")
		return
	dock.add_child(UI.at(UI.caps("TURNO %02d" % GameManager.current_day, UI.MUTED), Vector2(16, 10)))
	_dock_time = UI.mono(GameManager.format_time(GameManager.current_time_minutes), 18, UI.WHITE)
	_dock_time.position = Vector2(16, 25)
	dock.add_child(_dock_time)
	var action: Button = UI.button_at(dock, Vector2(UI.DOCK_W - 194.0, 8), Vector2(186, 42), "FINALIZAR TURNO", request_end_turn, true, "endturn")
	action.tooltip_text = "Encerra o dia: folha dos laranjas, queda da suspeita e nova remessa."

# =========================================================
# TROCA DE TURNO, EVENTOS E FINAIS
# =========================================================

## Pede confirmação só quando há sinal de engano: dia sem nenhuma operação,
## com saldo sujo e capacidade sobrando. Nos outros casos, finaliza direto.
func request_end_turn() -> void:
	if _flow_busy or GameManager.state != GameManager.GameState.WORK:
		return
	var room: float = 0.0
	for company_id: String in GameManager.owned_ids():
		room += GameManager.remaining_capacity(company_id)
	if GameManager.operations_today() > 0 or GameManager.dirty_money < B.MIN_OPERATION or room < B.MIN_OPERATION:
		end_turn()
		return
	confirm_modal({
		"kicker": "TURNO %02d" % GameManager.current_day, "title": "Finalizar sem operar?",
		"text": "Você não processou nada hoje e ainda tem %s de saldo sujo. O prazo do ato continua correndo." % UI.money(GameManager.dirty_money),
		"confirm": "FINALIZAR TURNO", "cancel": "VOLTAR", "on_confirm": end_turn
	})

func end_turn() -> void:
	if _flow_busy or GameManager.state != GameManager.GameState.WORK:
		return
	_flow_busy = true
	close_modal(true)
	clear_toasts()
	AudioManager.play_transition()
	var report: Dictionary = GameManager.end_day()
	_snapshot()
	await TurnManager.play_transition(self, report)
	GameManager.begin_day()
	await _after_flow()

func request_takeoff() -> void:
	if _flow_busy or not Campaign.ready_to_fly():
		return
	confirm_modal({
		"kicker": "OPERAÇÃO FUGA", "title": "Decolar agora?",
		"text": "Você embarca com %s em Monero. A chance de a Polícia Federal interceptar o avião é de %d%%. O saldo limpo que não foi convertido fica para trás." % [UI.money(Portfolio.monero), int(round(Campaign.interception_chance()))],
		"confirm": "DECOLAR", "cancel": "AINDA NÃO", "on_confirm": func() -> void: Campaign.takeoff()
	})

## Mostra, um por um, os popups criados durante a noite ou por uma ação.
func _run_events() -> void:
	var guard: int = 0
	while Campaign.ending == "" and not Campaign.events.is_empty() and guard < 12:
		guard += 1
		for event_v: Variant in Campaign.take_events():
			var message: String = await PopupManager.show_event(event_v)
			if message != "":
				toast(message, UI.CYAN)
			if Campaign.ending != "":
				return

## Depois da noite (ou de uma ação que mexe na campanha): popups pendentes,
## depois final, passagem de ato, início da fuga ou o dashboard.
func _after_flow() -> void:
	_flow_busy = true
	await _run_events()
	if Campaign.ending != "":
		await _play_ending()
	elif Campaign.pending_screen == "act":
		show_act_intro()
	elif Campaign.pending_screen == "escape":
		show_escape_intro()
	elif GameManager.state == GameManager.GameState.WORK:
		# Zera _screen para o novo dia abrir com a animação de entrada completa.
		_screen = ""
		show_dashboard(current_tab)
	_flow_busy = false

func _on_stats_changed() -> void:
	if GameManager.state == GameManager.GameState.WORK and _screen == "dashboard" and not _flow_busy:
		show_dashboard(current_tab, false)

## Final disparado no meio do dia (suspeita no limite, decolagem, imunidade).
func _on_ending_reached(_ending_id: String) -> void:
	if _flow_busy:
		return
	_play_ending.call_deferred()

func _play_ending() -> void:
	_flow_busy = true
	PopupManager.clear_popup()
	close_modal(true)
	clear_toasts()
	await TurnManager.play_ending(self, Campaign.ending)
	show_end_screen()
	_flow_busy = false

## Tela de fim de campanha.
func show_end_screen() -> void:
	_begin_screen("end", "menu")
	UI.animating = true
	var view: Vector2 = vp()
	var info: Dictionary = B.ENDINGS.get(Campaign.ending, B.ENDINGS["preso"])
	var won: bool = bool(info["win"])
	var accent: Color = UI.GREEN if won else UI.RED
	var width: float = minf(980.0, view.x - 144.0)
	var x: float = 72.0

	var kind: Label = UI.caps(str(info["kind"]).to_upper(), accent, 13)
	kind.position = Vector2(x, 46)
	main_layer.add_child(kind)
	var title: Label = UI.display(str(info["title"]).to_upper(), 52, accent)
	title.position = Vector2(x - 2.0, 64)
	main_layer.add_child(title)
	UI.enter(title, 0, Vector2(-16, 0))

	var panel: Panel = UI.panel(main_layer, Vector2(x, 146), Vector2(width, 330), Color("#0B121A"), accent)
	UI.enter(panel, 2)
	var story: Label = UI.paragraph(str(info["text"]), 17, UI.WHITE, width - 56.0)
	story.position = Vector2(28, 24)
	panel.add_child(story)
	var reason: Label = UI.paragraph(Campaign.ending_reason, 14, UI.MUTED, width - 56.0)
	reason.position = Vector2(28, 78)
	panel.add_child(reason)

	var tiles: HBoxContainer = HBoxContainer.new()
	tiles.position = Vector2(28, 142)
	tiles.size = Vector2(width - 56.0, 84)
	tiles.add_theme_constant_override("separation", 12)
	panel.add_child(tiles)
	var escaped: bool = Campaign.ending == "rei" or Campaign.ending == "foragido"
	var main_tile: PanelContainer = UI.tile("MONERO LEVADO" if escaped else "PATRIMÔNIO FINAL", "", UI.VIOLET if escaped else UI.GREEN, "", 24)
	tiles.add_child(main_tile)
	UI.shown.erase("end_main")
	UI.count(main_tile.get_meta("value_label") as Label, "end_main", Portfolio.monero if escaped else GameManager.net_worth(), UI.money)
	tiles.add_child(UI.tile("ATO ALCANÇADO", "%d de %d" % [Campaign.act, B.ACTS.size()], UI.WHITE, "", 24))
	tiles.add_child(UI.tile("DIAS DE CAMPANHA", str(GameManager.day_total), UI.WHITE, "", 24))
	tiles.add_child(UI.tile("TOTAL LAVADO", UI.short_money(GameManager.total_processed), UI.CYAN, "", 24))

	var note: String = "Metas batidas: %d de %d." % [Campaign.goals_hit, B.ACTS.size()]
	if escaped and Campaign.escape_start_worth > 0.0:
		note += " Você levou %d%% do patrimônio que tinha ao iniciar a fuga." % int(round(Portfolio.monero / Campaign.escape_start_worth * 100.0))
	if not Campaign.escape_result.is_empty() and bool(Campaign.escape_result.get("flew", false)):
		note += " A chance de interceptação na decolagem era de %d%%." % int(round(float(Campaign.escape_result.get("chance", 0.0))))
	panel.add_child(UI.at(UI.label(note, 14, UI.MUTED), Vector2(28, 246)))
	UI.button_at(panel, Vector2(28, 276), Vector2(220, 42), "NOVA CAMPANHA", _start_new_game, true, "play")
	UI.button_at(panel, Vector2(260, 276), Vector2(190, 42), "VOLTAR AO MENU", show_menu, false, "back")

	var gallery: Panel = UI.panel(main_layer, Vector2(x, 492), Vector2(width, 96), UI.PANEL)
	UI.enter(gallery, 4)
	gallery.add_child(UI.at(UI.caps("FINAIS DESCOBERTOS  %d / %d" % [Campaign.unlocked_endings.size(), B.ENDING_ORDER.size()], UI.MUTED), Vector2(24, 14)))
	_endings_row(gallery, Vector2(24, 38), width - 48.0)

# =========================================================
# CONFIGURAÇÕES / CRÉDITOS
# =========================================================

func show_settings() -> void:
	_begin_screen("settings", "plain")
	UI.animating = true
	var top: Label = UI.display("CONFIGURAÇÕES", 34, UI.WHITE)
	top.position = Vector2(72, 34)
	main_layer.add_child(top)
	UI.enter(top, 0, Vector2(-12, 0))
	main_layer.add_child(UI.at(UI.label("Áudio e apresentação.", 14, UI.MUTED), Vector2(74, 80)))

	var panel: Panel = UI.panel(main_layer, Vector2(72, 122), Vector2(820, 470))
	UI.enter(panel, 1)
	panel.add_child(UI.at(UI.caps("ÁUDIO", UI.MUTED), Vector2(26, 26)))
	panel.add_child(UI.at(UI.label("Volume geral", 16, UI.WHITE), Vector2(26, 52)))
	var volume_value: Label = UI.right(UI.mono("%d%%" % int(GameManager.volume * 100.0), 16, UI.CYAN), Vector2(26, 52), 500.0)
	panel.add_child(volume_value)
	var slider: HSlider = HSlider.new()
	slider.position = Vector2(26, 84)
	slider.size = Vector2(500, 28)
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = GameManager.volume
	slider.value_changed.connect(func(v: float) -> void:
		GameManager.volume = v
		AudioManager.set_volume(v)
		volume_value.text = "%d%%" % int(v * 100.0)
	)
	panel.add_child(slider)
	panel.add_child(UI.at(UI.label("Silenciar", 16, UI.WHITE), Vector2(26, 134)))
	var mute: Button = UI.toggle(GameManager.muted, func(v: bool) -> void:
		GameManager.muted = v
		AudioManager.set_muted(v)
	)
	mute.position = Vector2(406, 128)
	mute.size = Vector2(120, 36)
	panel.add_child(mute)

	panel.add_child(UI.at(UI.caps("APRESENTAÇÃO", UI.MUTED), Vector2(26, 196)))
	panel.add_child(UI.at(UI.label("Reduzir animações", 16, UI.WHITE), Vector2(26, 228)))
	panel.add_child(UI.at(UI.label("Telas aparecem prontas e a troca de turno vira um resumo rápido.", 12, UI.MUTED), Vector2(26, 252)))
	var reduce: Button = UI.toggle(not UI.motion, func(v: bool) -> void: UI.motion = not v)
	reduce.position = Vector2(406, 226)
	reduce.size = Vector2(120, 36)
	panel.add_child(reduce)
	panel.add_child(UI.at(UI.label("Resolução recomendada: 1366 × 768", 15, UI.WHITE), Vector2(26, 300)))
	panel.add_child(UI.at(UI.label("Atalhos: 1 a 8 trocam de aba, F1 abre a ajuda, Esc fecha janelas.", 14, UI.MUTED), Vector2(26, 326)))
	panel.add_child(UI.at(UI.label("Na troca de turno, clique ou aperte Espaço para pular a animação.", 14, UI.MUTED), Vector2(26, 350)))
	UI.button_at(panel, Vector2(26, 398), Vector2(160, 46), "VOLTAR", show_menu, true, "back")

func show_credits() -> void:
	_begin_screen("credits", "menu")
	UI.animating = true
	var top: Label = UI.display("CRÉDITOS", 34, UI.WHITE)
	top.position = Vector2(72, 34)
	main_layer.add_child(top)
	UI.enter(top, 0, Vector2(-12, 0))
	var panel: Panel = UI.panel(main_layer, Vector2(72, 122), Vector2(800, 470), Color("#0B121A"), Color("#28424D"))
	UI.enter(panel, 1)
	panel.add_child(UI.at(UI.display("CLEAN SLATE", 30, UI.CYAN), Vector2(30, 26)))
	panel.add_child(UI.at(UI.label("Simulador acadêmico de estratégia e gerenciamento.", 16, UI.WHITE), Vector2(30, 72)))
	var entries: Array = [
		["TECNOLOGIA", "Godot 4.7 / GDScript / UI procedural 2D", UI.WHITE],
		["DIREÇÃO VISUAL", "Dashboard corporativo + terminal dark + CRT + pixel art", UI.WHITE],
		["FONTES", "IBM Plex Sans e IBM Plex Mono (SIL Open Font License)", UI.WHITE],
		["BUILD", "2.0.0 — ACADÊMICA", UI.GREEN]
	]
	for i: int in range(entries.size()):
		var y: float = 124.0 + float(i) * 64.0
		panel.add_child(UI.at(UI.caps(str(entries[i][0]), UI.MUTED), Vector2(30, y)))
		panel.add_child(UI.at(UI.label(str(entries[i][1]), 17, entries[i][2]), Vector2(30, y + 18.0)))
	UI.button_at(panel, Vector2(30, 398), Vector2(160, 46), "VOLTAR", show_menu, true, "back")
