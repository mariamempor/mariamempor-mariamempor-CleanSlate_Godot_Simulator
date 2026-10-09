extends Node
# Teste de interface: joga pela tela, com cliques e teclas de verdade.
#   parte 1  um dia completo, ação por ação, conferindo o efeito de cada clique
#   parte 2  salvar, voltar ao menu, continuar e comparar o estado
#   parte 3  campanha inteira: decisões do bot, fluxo de turno/popup/ato/fuga pela tela
#   parte 4  os outros finais, forçados
const B = preload("res://scripts/data/balance.gd")
const Bot = preload("res://tests/bot.gd")
const Keep = preload("res://tests/keep.gd")

var m: Control
var fails: int = 0
var checks: int = 0

var _backup: Dictionary = {}

func _ready() -> void:
	_backup = Keep.take()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameManager.SAVE_PATH))
	m = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(m)
	GameManager.rng.seed = 7
	await _wait(0.8)
	var parts: String = OS.get_environment("PARTS") if OS.get_environment("PARTS") != "" else "1234"
	if parts.contains("1"):
		await _part1()
	if parts.contains("2"):
		await _part2()
	if parts.contains("3"):
		await _part3()
	if parts.contains("4"):
		await _part4()
	Keep.give(_backup)
	print("\n== %d verificacoes, %d falhas ==" % [checks, fails])
	get_tree().quit(1 if fails > 0 else 0)

# ---------------------------------------------------------
func check(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("   FALHOU: ", what)
	elif OS.get_environment("VERBOSE") == "1":
		print("   ok: ", what)

func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

func _scope() -> Node:
	if PopupManager.is_open():
		return PopupManager.root_ui
	if m.modal_open():
		return m.modal_layer
	return m.main_layer

func _buttons(root: Node, out: Array) -> void:
	for child: Node in root.get_children():
		var b: Button = child as Button
		if b != null and b.is_visible_in_tree():
			out.append(b)
		_buttons(child, out)

func find_button(text: String, nth: int = 0, only_enabled: bool = true) -> Button:
	var all: Array = []
	_buttons(_scope(), all)
	var hits: int = 0
	for b_v: Variant in all:
		var b: Button = b_v as Button
		if b.text.strip_edges() == text and (not only_enabled or not b.disabled):
			if hits == nth:
				return b
			hits += 1
	return null

## Clique de verdade: o evento entra pela viewport, então um botão coberto por
## outra camada não recebe o clique, igual ao que acontece com o jogador.
func click(b: Button) -> void:
	var pos: Vector2 = b.get_global_rect().get_center()
	var move: InputEventMouseMotion = InputEventMouseMotion.new()
	move.position = pos
	move.global_position = pos
	get_viewport().push_input(move)
	for pressed: bool in [true, false]:
		var ev: InputEventMouseButton = InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = pos
		ev.global_position = pos
		get_viewport().push_input(ev)
		await get_tree().process_frame

func tap(text: String, nth: int = 0, pause: float = 0.45) -> bool:
	var b: Button = find_button(text, nth)
	if b == null:
		check(false, "botao '%s' nao encontrado (ou desabilitado)" % text)
		return false
	await click(b)
	await _wait(pause)
	return true

func key(code: Key, pause: float = 0.35) -> void:
	for pressed: bool in [true, false]:
		var ev: InputEventKey = InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = pressed
		get_viewport().push_input(ev)
		await get_tree().process_frame
	await _wait(pause)

func _popup_title() -> String:
	var labels: Array = []
	_labels(PopupManager.root_ui, labels)
	var out: String = ""
	for l_v: Variant in labels:
		out += (l_v as Label).text + " | "
	return out

func _labels(root: Node, out: Array) -> void:
	for child: Node in root.get_children():
		if child is Label:
			out.append(child)
		_labels(child, out)

## Espera a troca de turno / popups / final terminarem, respondendo aos popups.
## prefer: texto do botão a escolher quando ele existir (ex.: imunidade).
func settle(prefer: String = "") -> void:
	var guard: int = 0
	await _wait(0.15)
	while (m._flow_busy or TurnManager.running or PopupManager.is_open()) and guard < 400:
		guard += 1
		if TurnManager.running:
			await key(KEY_SPACE, 0.15)
		elif PopupManager.is_open():
			var all: Array = []
			_buttons(PopupManager.root_ui, all)
			var chosen: Button = null
			for b_v: Variant in all:
				var b: Button = b_v as Button
				if prefer != "" and b.text.strip_edges() == prefer and not b.disabled:
					chosen = b
			if chosen == null:
				for b_v: Variant in all:
					var b: Button = b_v as Button
					if not b.disabled:
						chosen = b
						break
			check(chosen != null, "popup sem botao habilitado: " + _popup_title().left(80))
			if chosen == null:
				PopupManager.clear_popup()
			else:
				# o painel do popup precisa caber na tela
				var panel_rect: Rect2 = Rect2()
				var panels: Array = PopupManager.root_ui.find_children("*", "PanelContainer", true, false)
				for p_v: Variant in panels:
					if (p_v as Control).size.x > 500.0:
						panel_rect = (p_v as Control).get_global_rect()
						break
				if panel_rect.size.y > 0.0:
					check(panel_rect.position.y >= 0.0 and panel_rect.end.y <= 768.0, "popup maior que a tela (%d px): %s" % [int(panel_rect.size.y), _popup_title().left(60)])
				await click(chosen)
				await _wait(0.2)
		else:
			await _wait(0.1)
	check(guard < 400, "fluxo travou (flow_busy=%s turn=%s popup=%s)" % [m._flow_busy, TurnManager.running, PopupManager.is_open()])

# ---------------------------------------------------------
func _part1() -> void:
	print("-- parte 1: um dia pela interface")
	check(m._screen == "menu", "abre no menu")
	check(find_button("CONTINUAR") == null, "sem save, nao ha CONTINUAR")
	await tap("NOVA CAMPANHA")
	check(m._screen == "tutorial", "nova campanha abre o manual")
	await key(KEY_RIGHT)
	check(m.tutorial_step == 1, "seta direita avanca o manual")
	await tap("PULAR O MANUAL")
	check(m._screen == "act", "pular o manual abre a abertura do ato")
	await tap("COMEÇAR O ATO 1", 0, 0.9)
	check(m._screen == "dashboard" and m.current_tab == "overview", "dashboard na visao geral")
	check(GameManager.state == GameManager.GameState.WORK, "estado WORK")

	await key(KEY_2)
	check(m.current_tab == "companies", "tecla 2 abre empresas")
	var dirty: float = GameManager.dirty_money
	await tap("OPERAR")
	check(m.modal_open(), "OPERAR abre o modal")
	await tap("50%")
	await key(KEY_ENTER)
	check(not m.modal_open(), "Enter confirma e fecha o modal")
	check(GameManager.transactions.size() == 1, "uma transacao registrada")
	check(is_equal_approx(GameManager.dirty_money, dirty - 9000.0), "50%% da lavanderia = 9 mil (saiu %s)" % str(dirty - GameManager.dirty_money))
	# Esc cancela
	await tap("OPERAR")
	await key(KEY_ESCAPE)
	check(not m.modal_open() and GameManager.transactions.size() == 1, "Esc cancela sem operar")
	# clicar no botão de baixo com o modal aberto não pode vazar
	await tap("OPERAR")
	var all: Array = []
	_buttons(m.main_layer, all)
	var behind: Button = null
	for b_v: Variant in all:
		if (b_v as Button).text.strip_edges() == "FINALIZAR TURNO":
			behind = b_v
	if behind != null:
		await click(behind)
		await _wait(0.3)
	check(GameManager.current_day == 1 and not TurnManager.running, "modal bloqueia o clique no botao de tras")
	if m.modal_open():
		await tap("CANCELAR")
	check(not m.modal_open(), "CANCELAR fecha o modal")

	await tap("LARANJAS")
	check(m.current_tab == "staff", "menu lateral abre laranjas")
	await tap("CONTRATAR")
	check(m.modal_open(), "CONTRATAR abre a escolha de empresa")
	await tap("LAVANDERIA PURA VIDA")
	check(Staff.roster.size() == 1, "laranja contratado")
	check(GameManager.capacity_of("lavanderia") > 18000.0, "capacidade da lavanderia subiu")
	await tap("GERIR")
	check(m.modal_open(), "GERIR abre o laranja")
	await tap("DAR UM AGRADO")
	check(not m.modal_open(), "agrado fecha o modal")

	GameManager.clean_money += 400000.0
	GameManager.total_clean_generated += 400000.0
	GameManager.touch()
	await _wait(0.3)
	await key(KEY_4)
	check(m.current_tab == "lifestyle", "tecla 4 abre bens")
	await tap("COMPRAR")
	check(m.modal_open(), "COMPRAR abre a confirmacao")
	await tap("COMPRAR")
	check(Lifestyle.owned.size() == 1, "bem comprado")
	await tap("DECLARAR RENDA")
	check(m.modal_open(), "DECLARAR RENDA abre o modal")
	await key(KEY_ENTER)
	check(Lifestyle.declared_income > 0.0 and Lifestyle.excess() <= 0.0, "renda declarada cobre a ostentacao")

	await key(KEY_5)
	check(m.current_tab == "wallet", "tecla 5 abre carteira")
	await tap("COMPRAR")
	await tap("25%")
	await key(KEY_ENTER)
	check(Portfolio.crypto_units > 0.0, "cripto comprada")

	await key(KEY_6)
	check(m.current_tab == "transactions", "tecla 6 abre transacoes")
	await key(KEY_7)
	check(m.current_tab == "news", "tecla 7 abre noticias")
	await key(KEY_8)
	check(m.current_tab == "risk", "tecla 8 abre risco")
	var before: float = GameManager.suspicion
	await tap("APLICAR")
	check(GameManager.suspicion < before, "acao de risco reduziu a suspeita")
	check(find_button("APLICAR", 0) != null and GameManager.action_cooldown("revisao") > 0, "acao entra em espera")

	await key(KEY_F1)
	check(m.modal_open(), "F1 abre a ajuda")
	await key(KEY_ESCAPE)
	check(not m.modal_open(), "Esc fecha a ajuda")
	await tap("COMO FUNCIONA")
	check(m.modal_open(), "COMO FUNCIONA abre a ajuda")
	await tap("ENTENDI")

	await tap("SALVAR JOGO")
	check(GameManager.has_save(), "save criado")

func _state() -> String:
	return JSON.stringify({"g": [GameManager.current_day, GameManager.day_total, snappedf(GameManager.dirty_money, 0.01), snappedf(GameManager.clean_money, 0.01), snappedf(GameManager.suspicion, 0.001), GameManager.transactions.size(), GameManager.influence, GameManager.wiretap_days, GameManager.cooldowns, GameManager.modifiers.size()], "c": Campaign.to_dict(), "s": Staff.to_dict(), "l": Lifestyle.to_dict(), "p": Portfolio.to_dict(), "w": snappedf(GameManager.net_worth(), 0.01)})

func _part2() -> void:
	print("-- parte 2: troca de turno, salvar e carregar")
	var saved: String = _state()
	var day: int = GameManager.current_day
	# Depois de clicar em FINALIZAR, o Espaço tem de pular a cena (e não reapertar o botão).
	await tap("FINALIZAR TURNO", 0, 0.5)
	check(TurnManager.running, "FINALIZAR TURNO inicia a cena da noite")
	check(GameManager.current_day == day + 1, "o dia avancou")
	await _wait(1.0)
	await key(KEY_SPACE, 0.6)
	check(not TurnManager.running, "Espaco pula a cena")
	await settle()
	check(m._screen == "dashboard", "depois da noite, volta ao dashboard")
	check(GameManager.state == GameManager.GameState.WORK, "estado WORK no dia 2")
	check(GameManager.dirty_money > 100000.0, "remessa chegou")
	# segunda noite assistindo a cena inteira (sem pular)
	GameManager.process_company("bar", 10000.0)
	await tap("FINALIZAR TURNO", 0, 0.3)
	var waited: float = 0.0
	while TurnManager.running and waited < 12.0:
		await _wait(0.25)
		waited += 0.25
	check(waited > 6.0 and waited < 9.0, "cena inteira dura ~7 s (durou %.1f)" % waited)
	await settle()
	check(GameManager.current_day == day + 2, "dia 3")
	# carregar: volta ao estado salvo no dia 1
	await tap("MENU PRINCIPAL")
	check(m._screen == "menu", "menu principal")
	check(find_button("CONTINUAR") != null, "com save, aparece CONTINUAR")
	await tap("CONTINUAR", 0, 0.8)
	check(m._screen == "dashboard", "continuar abre o dashboard")
	check(_state() == saved, "estado carregado igual ao salvo")
	if _state() != saved:
		print("      salvo:     ", saved.left(400))
		print("      carregado: ", _state().left(400))
	# nova campanha com save existente pede confirmação
	await tap("MENU PRINCIPAL")
	await tap("NOVA CAMPANHA")
	check(m.modal_open(), "nova campanha com save pede confirmacao")
	await key(KEY_ESCAPE)
	await tap("CONTINUAR", 0, 0.8)
	# configurações: reduzir animações
	await tap("MENU PRINCIPAL")
	await tap("CONFIGURAÇÕES")
	check(m._screen == "settings", "tela de configuracoes")
	await key(KEY_ESCAPE)
	check(m._screen == "menu", "Esc volta ao menu")
	await tap("CRÉDITOS")
	check(m._screen == "credits", "tela de creditos")
	await tap("VOLTAR")
	await tap("CONTINUAR", 0, 0.8)

## Uma campanha inteira. As decisões do dia vêm do bot (direto nas regras);
## fim de turno, popups, passagem de ato, fuga e final passam pela interface.
func _campaign(style: String, prefer: String, seed_value: int) -> void:
	GameManager.rng.seed = seed_value
	var guard: int = 0
	var acts_seen: Array = [Campaign.act]
	while Campaign.ending == "" and not Campaign.escape_active and guard < 220:
		guard += 1
		if m._screen == "act":
			check(find_button("COMEÇAR O ATO %d" % Campaign.act) != null, "abertura do ato %d" % Campaign.act)
			if not acts_seen.has(Campaign.act):
				acts_seen.append(Campaign.act)
			await tap("COMEÇAR O ATO %d" % Campaign.act, 0, 0.3)
			continue
		if m._screen != "dashboard":
			break
		Bot.day(style)
		await get_tree().process_frame
		m.request_end_turn()
		await get_tree().process_frame
		if m.modal_open():
			await tap("FINALIZAR TURNO", 0, 0.1)
		await settle(prefer)
	print("   %s: parou em ato %d dia %d (total %d), tela '%s', final '%s', fuga %s" % [style, Campaign.act, GameManager.current_day, GameManager.day_total, m._screen, Campaign.ending, Campaign.escape_active])

func _part3() -> void:
	print("-- parte 3: campanha inteira pela interface")
	UI.motion = false
	await tap("MENU PRINCIPAL")
	await tap("NOVA CAMPANHA")
	await tap("COMEÇAR DO ZERO")
	await tap("PULAR O MANUAL")
	await tap("COMEÇAR O ATO 1", 0, 0.3)
	await _campaign("sensato", "SEGUIR PARA O ATO 3", 1001)
	check(Campaign.escape_active and Campaign.escape_reason == "meta", "chegou a fuga pela meta do ato 3")
	check(m._screen == "escape", "tela de inicio da fuga")
	if not Campaign.escape_active:
		return
	UI.motion = true
	await tap("ABRIR A DARK WEB", 0, 1.0)
	check(m._screen == "dashboard" and m.current_tab == "darkweb", "dark web aberta")
	check(m.visible_tabs().size() == 4, "na fuga, so 4 abas")
	check(find_button("DECOLAR") == null, "DECOLAR desabilitado sem passaporte e aviao")
	var hours: float = Campaign.escape_hours
	await tap("COMPRAR", 1)
	check(Campaign.passport == "bom", "passaporte comprado (%s)" % Campaign.passport)
	await tap("COMPRAR", 1)
	check(Campaign.jet == "executivo", "aviao contratado (%s)" % Campaign.jet)
	check(Campaign.escape_hours < hours, "as compras gastaram horas")
	var sold: int = 0
	while sold < 5 and find_button("VENDER") != null and Campaign.escape_hours > 36.0:
		await tap("VENDER", 0, 0.3)
		sold += 1
	check(sold > 0, "liquidou ativos (%d)" % sold)
	var lots: int = 0
	while lots < 12 and find_button("CONVERTER UM LOTE") != null and Campaign.escape_hours >= B.ESCAPE_HOURS_CONVERT:
		var monero: float = Portfolio.monero
		await tap("CONVERTER UM LOTE", 0, 0.3)
		if Portfolio.monero <= monero:
			break
		lots += 1
		await settle()
		if Campaign.ending != "":
			break
	check(Portfolio.monero > 0.0, "converteu em Monero (%d lotes)" % lots)
	if Campaign.ending == "":
		await tap("DECOLAR")
		check(m.modal_open(), "DECOLAR pede confirmacao")
		await tap("DECOLAR", 0, 1.0)
	check(Campaign.ending != "", "a decolagem resolve a campanha (%s)" % Campaign.ending)
	check(TurnManager.running, "cutscene do final rodando")
	await _wait(1.5)
	await key(KEY_SPACE, 0.8)
	await settle()
	check(m._screen == "end", "tela de final")
	check(not GameManager.has_save(), "o save e apagado no final")
	check(Campaign.unlocked_endings.has(Campaign.ending), "final entra na galeria")
	print("   final: ", Campaign.ending, " | ", Campaign.ending_reason)
	await tap("VOLTAR AO MENU")
	check(m._screen == "menu" and find_button("CONTINUAR") == null, "menu sem CONTINUAR depois do final")

func _fresh() -> void:
	if m._screen != "menu":
		m.show_menu()
		await _wait(0.4)
	await tap("NOVA CAMPANHA", 0, 0.3)
	if m.modal_open():
		await tap("COMEÇAR DO ZERO", 0, 0.3)
	await tap("PULAR O MANUAL", 0, 0.3)
	await tap("COMEÇAR O ATO 1", 0, 0.3)

func _finish_scene(expected: String, kind: String) -> void:
	await _wait(0.4)
	check(Campaign.ending == expected, "final '%s' (veio '%s': %s)" % [expected, Campaign.ending, Campaign.ending_reason])
	check(TurnManager.ending_kind(Campaign.ending) == kind, "cena '%s'" % kind)
	await settle()
	await _wait(0.3)
	check(m._screen == "end", "tela de final depois de '%s'" % expected)

func _part4() -> void:
	print("-- parte 4: outros finais")
	UI.motion = false
	# preso: suspeita no limite durante uma operação feita pela tela
	await _fresh()
	GameManager.suspicion = 99.0
	GameManager.touch()
	await key(KEY_2)
	await tap("OPERAR")
	await key(KEY_ENTER, 0.2)
	await _finish_scene("preso", "arrest")
	# queima de arquivo: ato 3 acima de 90%
	await _fresh()
	Campaign._start_act(3)
	Campaign.pending_screen = ""
	GameManager.suspicion = 89.5
	GameManager.touch()
	await key(KEY_2)
	await tap("OPERAR")
	await key(KEY_ENTER, 0.2)
	await _finish_scene("queima", "cartel")
	# politico: ato 2 batido com influência e caixa
	await _fresh()
	Campaign._start_act(2)
	Campaign.pending_screen = ""
	GameManager.influence = B.IMMUNITY_INFLUENCE
	GameManager.clean_money = 30000000.0
	GameManager.touch()
	m.request_end_turn()
	await get_tree().process_frame
	if m.modal_open():
		await tap("FINALIZAR TURNO", 0, 0.1)
	await settle("COMPRAR IMUNIDADE PARLAMENTAR")
	await _finish_scene("politico", "congress")
	# mandado: 3 noites acima de 80% no ato 2 -> fuga antecipada -> foragido ou preso
	await _fresh()
	Campaign._start_act(2)
	Campaign.pending_screen = ""
	GameManager.clean_money = 4000000.0
	for night: int in range(B.MANDADO_DAYS):
		GameManager.suspicion = 93.0
		GameManager.touch()
		m.request_end_turn()
		await get_tree().process_frame
		if m.modal_open():
			await tap("FINALIZAR TURNO", 0, 0.1)
		await settle()
	check(Campaign.mandado and Campaign.escape_active, "mandado inicia a fuga")
	check(m._screen == "escape", "tela de fuga por mandado")
	await tap("ABRIR A DARK WEB", 0, 0.4)
	await tap("COMPRAR", 0)
	await tap("COMPRAR", 0)
	check(Campaign.ready_to_fly(), "pronto para decolar")
	await tap("CONVERTER UM LOTE", 0, 0.3)
	await tap("DECOLAR")
	await tap("DECOLAR", 0, 0.5)
	check(Campaign.ending in ["foragido", "preso"], "fuga por mandado termina em foragido ou preso (%s)" % Campaign.ending)
	await settle()
	check(m._screen == "end", "tela de final depois da fuga por mandado")
	# fuga sem decolar: 72 horas acabam -> preso
	await _fresh()
	Campaign._start_act(2)
	Campaign.pending_screen = ""
	Campaign.start_escape("mandado")
	Campaign.pending_screen = ""
	m.show_dashboard("darkweb")
	await _wait(0.3)
	var spins: int = 0
	while Campaign.ending == "" and spins < 40 and find_button("VENDER") != null:
		await tap("VENDER", 0, 0.15)
		spins += 1
	if Campaign.ending == "":
		Campaign.escape_spend(Campaign.escape_hours)
	await _finish_scene("preso", "arrest")
	# prazo: sem bater a meta, prorroga uma vez; na segunda, acaba
	await _fresh()
	GameManager.current_day = int(B.ACTS[0]["days"])
	GameManager.touch()
	m.request_end_turn()
	await get_tree().process_frame
	if m.modal_open():
		await tap("FINALIZAR TURNO", 0, 0.1)
	await settle()
	check(Campaign.ending == "" and Campaign.extension_used, "primeiro prazo vencido: prorrogacao")
	for extra: int in range(B.DEADLINE_EXTENSION_DAYS + 1):
		if Campaign.ending != "":
			break
		m.request_end_turn()
		await get_tree().process_frame
		if m.modal_open():
			await tap("FINALIZAR TURNO", 0, 0.1)
		await settle()
	await _finish_scene("preso", "arrest")
	await tap("NOVA CAMPANHA", 0, 0.4)
	check(m._screen == "tutorial" and GameManager.current_day == 1 and Campaign.ending == "", "nova campanha a partir da tela de final")
