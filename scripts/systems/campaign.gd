extends Node
## Campaign — atos, metas, ameaças, Operação Fuga e finais.
##
## A campanha tem três atos. Cada um tem meta de patrimônio, prazo e uma
## ameaça própria. Bater a meta do Ato 3 (ou receber um mandado de prisão)
## inicia a Operação Fuga, que decide o final.
##
## Este script também guarda a "fila de eventos" da virada do dia: popups de
## decisão criados durante a noite, que a interface mostra um por um.

const B = preload("res://scripts/data/balance.gd")

signal ending_reached(ending_id: String)

const META_PATH: String = "user://clean_slate_meta.json"

var act: int = 1
var goals_hit: int = 0              # quantas metas de ato já foram batidas
var extension_used: bool = false    # prorrogação de prazo já usada neste ato
var mandado: bool = false
var mandado_streak: int = 0         # noites seguidas com a suspeita acima do nível de mandado
var cartel_warned: bool = false
var threat_cooldown: int = 0
var ending: String = ""
var ending_reason: String = ""
var events: Array = []              # popups esperando a virada do dia
var fresh_news: int = 0             # notícias novas desde a última visita à aba
## Tela de passagem que a interface deve mostrar: "", "act" ou "escape".
var pending_screen: String = ""

# Operação Fuga
var escape_active: bool = false
var escape_reason: String = ""      # "meta" ou "mandado"
var escape_hours: float = 0.0       # horas restantes
var escape_start_worth: float = 0.0
var passport: String = ""
var jet: String = ""
var escape_result: Dictionary = {}

# Progresso entre partidas (finais já vistos)
var unlocked_endings: Array = []

func _ready() -> void:
	_load_meta()

func reset() -> void:
	act = 1
	goals_hit = 0
	extension_used = false
	mandado = false
	mandado_streak = 0
	cartel_warned = false
	threat_cooldown = 0
	ending = ""
	ending_reason = ""
	events = []
	fresh_news = 0
	pending_screen = ""
	escape_active = false
	escape_reason = ""
	escape_hours = 0.0
	escape_start_worth = 0.0
	passport = ""
	jet = ""
	escape_result = {}

# ---------------------------------------------------------
# Consultas
# ---------------------------------------------------------

func data() -> Dictionary:
	return B.act_data(act)

func goal() -> float:
	return float(data()["goal"])

func days() -> int:
	return int(data()["days"])

func scale() -> float:
	return float(data()["scale"])

## Suspeita que encerra o jogo neste ato.
func limit() -> float:
	return float(data()["limit"])

## Fração da suspeita que some sozinha a cada noite neste ato.
func decay_rate() -> float:
	return float(data()["decay"])

## Quantos pontos a suspeita cai esta noite: a fração do ato sobre o nível
## atual, mais o bônus da influência política. Na fuga, não cai.
func decay() -> float:
	if escape_active:
		return 0.0
	return GameManager.suspicion * decay_rate() + float(GameManager.influence) * B.INFLUENCE_DECAY

## Dinheiro sujo entregue por noite. Na fuga, o cliente some.
func remessa() -> float:
	return 0.0 if escape_active else float(data()["remessa"])

func progress() -> float:
	return clampf(GameManager.net_worth() / maxf(goal(), 1.0), 0.0, 1.0)

func goal_reached() -> bool:
	return not escape_active and GameManager.net_worth() >= goal()

func days_left() -> int:
	return maxi(0, GameManager.total_days - GameManager.current_day)

func push_event(event: Dictionary) -> void:
	events.append(event)

## Entrega e esvazia a fila de popups.
func take_events() -> Array:
	var out: Array = events
	events = []
	return out

# ---------------------------------------------------------
# Limites de suspeita e finais
# ---------------------------------------------------------

## Chamado sempre que a suspeita muda. Encerra a campanha se o limite estourou.
func check_limits() -> void:
	if ending != "" or GameManager.state == GameManager.GameState.MENU or GameManager.state == GameManager.GameState.TUTORIAL:
		return
	if GameManager.suspicion < limit():
		return
	if act >= 3:
		trigger_ending("queima", "A suspeita passou de %d%% no Ato 3. Para o cartel, você virou um risco, e risco se elimina." % int(limit()))
	else:
		trigger_ending("preso", "A suspeita chegou ao limite. A Polícia Federal reuniu o que precisava.")

func trigger_ending(ending_id: String, reason: String) -> void:
	if ending != "":
		return
	ending = ending_id
	ending_reason = reason
	events = []
	if not unlocked_endings.has(ending_id):
		unlocked_endings.append(ending_id)
		_save_meta()
	# A campanha acabou: o save deixa de existir, para "Continuar" não ressuscitar a partida.
	if FileAccess.file_exists(GameManager.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GameManager.SAVE_PATH))
	if GameManager.state == GameManager.GameState.WORK:
		GameManager.set_state(GameManager.GameState.ENDED)
	ending_reached.emit(ending_id)

# ---------------------------------------------------------
# Virada do dia
# ---------------------------------------------------------

func daily_tick() -> void:
	if ending != "" or escape_active:
		return
	check_limits()
	if ending != "":
		return
	_roll_threats()
	_roll_news()

	# Mandado de prisão: suspeita alta por várias noites seguidas (atos 2 e 3).
	if act >= 2 and not mandado:
		mandado_streak = mandado_streak + 1 if GameManager.suspicion >= B.MANDADO_LEVEL else 0
		if mandado_streak >= B.MANDADO_DAYS:
			mandado = true
			start_escape("mandado")
			return

	# Recado do cartel, no Ato 3, quando a suspeita chega perto do limite.
	if act >= 3:
		if GameManager.suspicion >= B.CARTEL_WARNING_LEVEL and not cartel_warned:
			cartel_warned = true
			push_event(_cartel_event())
		elif GameManager.suspicion < B.CARTEL_WARNING_LEVEL - 10.0:
			cartel_warned = false

	if goal_reached():
		_complete_act()
		return

	GameManager.current_day += 1
	GameManager.day_total += 1
	if GameManager.current_day > GameManager.total_days:
		_deadline()

func _complete_act() -> void:
	goals_hit = act
	match act:
		1:
			_start_act(2)
		2:
			push_event(_immunity_event())
		_:
			start_escape("meta")

func _start_act(new_act: int) -> void:
	act = clampi(new_act, 1, B.ACTS.size())
	extension_used = false
	mandado_streak = 0
	cartel_warned = false
	GameManager.current_day = 1
	GameManager.day_total += 1
	GameManager.total_days = days()
	pending_screen = "act"
	# Promoção: o cliente adianta capital para a operação subir de porte.
	GameManager.clean_money += float(data()["bonus"])
	Staff.refresh_candidates()
	GameManager.add_news("CAMPANHA", "Ato %d: %s" % [act, str(data()["name"])], str(data()["focus"]), "Meta de %s em %d dias" % [GameManager.format_money(goal()), days()])

## O prazo do ato acabou sem a meta. A primeira vez tem prorrogação, com multa.
func _deadline() -> void:
	if not extension_used:
		extension_used = true
		GameManager.total_days += B.DEADLINE_EXTENSION_DAYS
		var penalty: float = GameManager.clean_money * B.DEADLINE_PENALTY
		GameManager.clean_money -= penalty
		GameManager.add_news("CARTEL", "O cliente cobra o atraso", "O prazo do ato venceu sem a meta. Houve prorrogação, e ela teve preço.", "-%s e mais %d dias" % [GameManager.format_money(penalty), B.DEADLINE_EXTENSION_DAYS])
		push_event({
			"style": "cartel",
			"kicker": "RECADO DO CLIENTE",
			"title": "O prazo acabou",
			"body": "A meta de %s não foi batida a tempo. O cliente concedeu mais %d dias e descontou %s do seu saldo limpo pelo incômodo. Não haverá segunda prorrogação." % [GameManager.format_money(goal()), B.DEADLINE_EXTENSION_DAYS, GameManager.format_money(penalty)],
			"options": []
		})
		return
	if act >= 3:
		trigger_ending("queima", "O prazo venceu pela segunda vez. O cartel não renegocia com quem não entrega.")
	else:
		trigger_ending("preso", "O prazo venceu pela segunda vez. O cliente retirou a proteção, e a Polícia Federal chegou no dia seguinte.")

# ---------------------------------------------------------
# Ameaças e notícias
# ---------------------------------------------------------

func _roll_threats() -> void:
	if threat_cooldown > 0:
		threat_cooldown -= 1
		return
	var rng: RandomNumberGenerator = GameManager.rng
	var kinds: Array = B.THREATS.keys()
	# Ordem sorteada: no máximo uma ameaça por noite, sem favorecer a primeira da lista.
	for i: int in range(kinds.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap: Variant = kinds[i]
		kinds[i] = kinds[j]
		kinds[j] = swap
	for kind_v: Variant in kinds:
		var kind: String = str(kind_v)
		var threat: Dictionary = B.THREATS[kind]
		if int(threat["act"]) > act:
			continue
		if kind == "grampo" and (GameManager.wiretap_days > 0 or GameManager.suspicion < float(threat["from"])):
			continue
		var chance: float = float(threat["base"])
		if float(threat["slope"]) > 0.0:
			chance += maxf(0.0, GameManager.suspicion - float(threat["from"])) / float(threat["slope"])
		if rng.randf() < chance:
			threat_cooldown = B.THREAT_COOLDOWN
			push_event(_threat_event(kind))
			return

func _roll_news() -> void:
	var rng: RandomNumberGenerator = GameManager.rng
	if rng.randf() >= B.NEWS_CHANCE:
		return
	var pool: Array = []
	for item_v: Variant in B.NEWS:
		var item: Dictionary = item_v as Dictionary
		if int(item.get("act", 1)) > act:
			continue
		var target: String = str(item["target"])
		if target != "*" and not GameManager.owns(target):
			continue
		pool.append(item)
	if pool.is_empty():
		return
	var chosen: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
	GameManager.apply_news(chosen)
	fresh_news += 1
	if str(chosen["tag"]) == "URGENTE":
		push_event({
			"style": "news",
			"kicker": "BREAKING NEWS / URGENTE",
			"source": "CLEAN SLATE / NEWSWIRE",
			"title": str(chosen["title"]),
			"body": str(chosen["body"]),
			"impact": str(chosen["effect"]),
			"options": []
		})

## Paga um custo (se houver) e mexe na suspeita. Base das opções de ameaça.
func _pay_and_risk(cost: float, risk: float, message: String) -> Dictionary:
	GameManager.begin_batch()
	GameManager.clean_money = maxf(0.0, GameManager.clean_money - cost)
	GameManager.add_suspicion(risk)
	GameManager.end_batch()
	return {"ok": true, "message": message}

func _option(label: String, cost: float, risk: float, detail: String, message: String, danger: bool = false) -> Dictionary:
	var parts: Array[String] = []
	if cost > 0.0:
		parts.append(GameManager.format_money(cost))
	if risk != 0.0:
		parts.append("suspeita %+.0f" % risk)
	if detail != "":
		parts.append(detail)
	return {
		"label": label,
		"detail": "  /  ".join(parts),
		"enabled": GameManager.clean_money >= cost,
		"danger": danger,
		"action": func() -> Dictionary: return _pay_and_risk(cost, risk, message)
	}

# Escolhas com mais de um efeito viram funções próprias (o popup só chama).

## Cooperar com a fiscalização: a maior empresa do jogador para por um dia.
func _choice_cooperate() -> Dictionary:
	var biggest: String = ""
	for company_id_v: Variant in GameManager.owned_ids():
		var company_id: String = str(company_id_v)
		if biggest == "" or GameManager.capacity_of(company_id) > GameManager.capacity_of(biggest):
			biggest = company_id
	if biggest == "":
		return _pay_and_risk(0.0, -1.0, "Você abriu os livros para o auditor.")
	GameManager.companies[biggest]["blocked"] = maxi(int(GameManager.companies[biggest]["blocked"]), 1)
	return _pay_and_risk(0.0, -1.0, "%s fica parada hoje para a conferência." % str(GameManager.companies[biggest]["name"]))

func _choice_testify() -> Dictionary:
	Staff.add_stress_all(12.0)
	return _pay_and_risk(0.0, 3.0, "Você depôs. A notícia correu entre os laranjas.")

func _choice_cut_ties() -> Dictionary:
	GameManager.influence = maxi(0, GameManager.influence - 2)
	return _pay_and_risk(0.0, 3.0, "Você nunca ouviu falar desse vereador.")

func _choice_freeze() -> Dictionary:
	var lost: float = Portfolio.seize(0.25)
	return {"ok": true, "message": "%s congelados." % GameManager.format_money(lost)}

func _choice_immunity() -> Dictionary:
	GameManager.clean_money -= B.IMMUNITY_COST
	trigger_ending("politico", "Você trocou o risco pelo mandato. Eleito com folga, discursou sobre ética no primeiro dia.")
	return {"ok": true, "message": ""}

func _choice_next_act() -> Dictionary:
	_start_act(3)
	return {"ok": true, "message": ""}

func _threat_event(kind: String) -> Dictionary:
	var s: float = scale()
	match kind:
		"fiscalizacao":
			return {
				"style": "official", "kicker": "RECEITA FEDERAL / FISCALIZAÇÃO DE ROTINA",
				"title": "Um auditor quer ver os livros",
				"body": "A Receita selecionou uma das suas empresas para conferência de caixa. É rotina, mas rotina mal resolvida vira processo.",
				"options": [
					_option("CONTRATAR CONTADOR", 12000.0 * s, -3.0, "", "O contador arrumou os livros."),
					{
						"label": "COOPERAR", "detail": "sem custo  /  suspeita -1  /  sua maior empresa para por 1 dia para a conferência", "enabled": true,
						"action": _choice_cooperate
					},
					_option("IGNORAR", 0.0, 7.0, "", "A notificação ficou sem resposta.", true)
				]
			}
		"intimacao":
			return {
				"style": "official", "kicker": "POLÍCIA FEDERAL / INTIMAÇÃO",
				"title": "Você foi chamado para depor",
				"body": "Um inquérito sobre contratos públicos cita o seu nome. O delegado quer ouvir você na próxima semana.",
				"options": [
					_option("ADVOGADO CRIMINALISTA", 30000.0 * s, -4.0, "", "O advogado conseguiu adiar o depoimento."),
					{
						"label": "DEPOR PESSOALMENTE", "detail": "suspeita +3  /  estresse +12 em todos os laranjas", "enabled": true,
						"action": _choice_testify
					},
					_option("IGNORAR", 0.0, 10.0, "", "Você não apareceu. O delegado anotou.", true)
				]
			}
		"grampo":
			GameManager.wiretap_days = B.WIRETAP_DAYS
			GameManager.add_news("URGENTE", "Seu contato avisa: há um grampo ativo", "A Polícia Federal está ouvindo as linhas da operação.", "Operações geram %d%% mais suspeita por %d dias" % [int(B.WIRETAP_RISK * 100.0), B.WIRETAP_DAYS])
			return {
				"style": "official", "kicker": "POLÍCIA FEDERAL / INTERCEPTAÇÃO",
				"title": "Seus telefones estão grampeados",
				"body": "Um contato na operadora avisou: há interceptação autorizada nas suas linhas. Por %d dias, cada operação gera %d%% mais suspeita. A Varredura eletrônica, na aba Risco, remove o grampo." % [B.WIRETAP_DAYS, int(B.WIRETAP_RISK * 100.0)],
				"options": []
			}
		"aliado":
			return {
				"style": "official", "kicker": "POLÍCIA FEDERAL / DELAÇÃO DE ALIADO",
				"title": "Um aliado político negocia delação",
				"body": "Um vereador que recebeu doações suas foi preso e está conversando com os procuradores. O nome da sua construtora pode aparecer.",
				"options": [
					_option("FINANCIAR A DEFESA", 45000.0 * s, 0.0, "ele fica calado", "A defesa dele agora é problema seu, e está resolvido."),
					{
						"label": "CORTAR LAÇOS", "detail": "suspeita +3  /  influência -2", "enabled": true,
						"action": _choice_cut_ties
					},
					_option("IGNORAR", 0.0, 11.0, "", "Ele falou. Seu nome está nos autos.", true)
				]
			}
		_:
			var frozen: float = (Portfolio.crypto_value() + Portfolio.fund_balance("offshore")) * 0.25
			return {
				"style": "official", "kicker": "INTERPOL / AUDITORIA INTERNACIONAL",
				"title": "Suas contas no exterior estão sob auditoria",
				"body": "Um pedido de cooperação internacional chegou a três jurisdições onde você tem dinheiro. Os bancos querem explicações.",
				"options": [
					_option("BANCA INTERNACIONAL", 40000.0 * s, -3.0, "", "Os advogados responderam em três idiomas."),
					{
						"label": "ACEITAR O CONGELAMENTO", "detail": "perde 25%% da cripto e do fundo offshore (%s)" % GameManager.format_money(frozen), "enabled": true,
						"action": _choice_freeze
					},
					_option("IGNORAR", 0.0, 12.0, "", "O pedido ficou sem resposta. A Interpol insistiu.", true)
				]
			}

func _cartel_event() -> Dictionary:
	return {
		"style": "cartel",
		"kicker": "RECADO DO CARTEL",
		"title": "Você está chamando atenção",
		"body": "A suspeita passou de %d%%. O recado chegou por um intermediário, sem assinatura: se passar de %d%%, a sociedade acaba. Do jeito deles." % [int(B.CARTEL_WARNING_LEVEL), int(limit())],
		"options": []
	}

## Fim do Ato 2: comprar imunidade (final Político) ou seguir para o Ato 3.
func _immunity_event() -> Dictionary:
	var enough_influence: bool = GameManager.influence >= B.IMMUNITY_INFLUENCE
	var enough_money: bool = GameManager.clean_money >= B.IMMUNITY_COST
	var block: String = ""
	if not enough_influence:
		block = "Exige influência %d (você tem %d)." % [B.IMMUNITY_INFLUENCE, GameManager.influence]
	elif not enough_money:
		block = "Exige %s em saldo limpo." % GameManager.format_money(B.IMMUNITY_COST)
	return {
		"style": "official",
		"kicker": "ATO 2 CONCLUÍDO / UMA PROPOSTA",
		"title": "Uma cadeira na Câmara está à venda",
		"body": "Você bateu a meta do ato. Um partido oferece legenda, campanha e foro privilegiado. É uma saída segura: a campanha termina aqui, com você eleito. Ou você recusa e sobe mais um degrau, onde o dinheiro é maior e o cartel não perdoa.",
		"options": [
			{
				"label": "COMPRAR IMUNIDADE PARLAMENTAR",
				"detail": "%s  /  encerra a campanha com o final O Político Influente. %s" % [GameManager.format_money(B.IMMUNITY_COST), block],
				"enabled": enough_influence and enough_money,
				"action": _choice_immunity
			},
			{
				"label": "SEGUIR PARA O ATO 3",
				"detail": "Meta de %s. O limite de suspeita cai para 90%%." % GameManager.format_money(float(B.act_data(3)["goal"])),
				"enabled": true,
				"action": _choice_next_act
			}
		]
	}

# ---------------------------------------------------------
# Operação Fuga
# ---------------------------------------------------------
# 72 horas, sem noites: cada ação gasta horas. Quanto mais tempo o jogador
# fica para liquidar e converter, mais leva embora e maior a chance de ser
# interceptado. Só o Monero sai do país.

func start_escape(reason: String) -> void:
	if escape_active or ending != "":
		return
	escape_active = true
	escape_reason = reason
	escape_hours = B.ESCAPE_HOURS
	escape_start_worth = GameManager.net_worth()
	passport = ""
	jet = ""
	pending_screen = "escape"
	events = []
	var headline: String = "Mandado de prisão preventiva expedido" if reason == "mandado" else "Meta final batida: hora de sumir"
	GameManager.add_news("URGENTE", headline, "A Operação Fuga começou. Você tem %d horas para liquidar o que puder, converter em Monero e decolar." % int(B.ESCAPE_HOURS), "Aba Dark Web liberada")

func escape_hours_used() -> float:
	return B.ESCAPE_HOURS - escape_hours

func escape_can_spend(hours: float) -> bool:
	return escape_active and ending == "" and escape_hours >= hours

## Gasta horas da fuga. A cada 24 h consumidas, o cerco fecha e a suspeita sobe.
func escape_spend(hours: float) -> void:
	if not escape_active or ending != "":
		return
	var day_before: int = int(floor(escape_hours_used() / 24.0))
	escape_hours = maxf(0.0, escape_hours - hours)
	var day_after: int = int(floor(escape_hours_used() / 24.0))
	GameManager.current_time_minutes = int(fmod(float(B.WORK_START_MINUTES) + escape_hours_used() * 60.0, 24.0 * 60.0))
	for i: int in range(day_after - day_before):
		GameManager.add_news("URGENTE", "O cerco fecha", "A Polícia Federal amplia as buscas. Aeroportos e fronteiras estão em alerta.", "+%d de suspeita" % int(B.ESCAPE_DAILY_SUSPICION))
		GameManager.add_suspicion(B.ESCAPE_DAILY_SUSPICION)
	GameManager.touch()
	if ending == "" and escape_hours <= 0.0:
		resolve_escape()

func escape_item_cost(item: Dictionary) -> float:
	return float(item["cost"]) * scale()

func liquidate_company(company_id: String) -> Dictionary:
	if not escape_active or not GameManager.owns(company_id):
		return {"ok": false, "message": "Venda indisponível."}
	if not escape_can_spend(B.ESCAPE_HOURS_COMPANY):
		return {"ok": false, "message": "Não há tempo para esta venda."}
	var company: Dictionary = GameManager.companies[company_id]
	var value: float = float(company["value"]) * B.ESCAPE_COMPANY_SALE
	GameManager.begin_batch()
	company["owned"] = false
	Staff.release_company(company_id)
	GameManager.clean_money += value
	GameManager.touch()
	escape_spend(B.ESCAPE_HOURS_COMPANY)
	GameManager.end_batch()
	return {"ok": true, "message": "%s liquidada por %s." % [str(company["name"]), GameManager.format_money(value)]}

func _buy_escape_item(list: Array, item_id: String, hours: float) -> Dictionary:
	var item: Dictionary = B.tier_item(list, item_id)
	if item.is_empty() or not escape_active:
		return {"ok": false, "message": "Item indisponível."}
	if not escape_can_spend(hours):
		return {"ok": false, "message": "Não há tempo para isso."}
	var cost: float = escape_item_cost(item)
	if cost > GameManager.clean_money:
		return {"ok": false, "message": "Saldo limpo insuficiente."}
	GameManager.clean_money -= cost
	return {"ok": true, "message": "%s garantido." % str(item["name"])}

func buy_passport(item_id: String) -> Dictionary:
	if passport != "":
		return {"ok": false, "message": "Você já tem um passaporte."}
	GameManager.begin_batch()
	var result: Dictionary = _buy_escape_item(B.PASSPORTS, item_id, B.ESCAPE_HOURS_PASSPORT)
	if bool(result["ok"]):
		passport = item_id
		GameManager.touch()
		escape_spend(B.ESCAPE_HOURS_PASSPORT)
	GameManager.end_batch()
	return result

func buy_jet(item_id: String) -> Dictionary:
	if jet != "":
		return {"ok": false, "message": "O avião já está contratado."}
	GameManager.begin_batch()
	var result: Dictionary = _buy_escape_item(B.JETS, item_id, B.ESCAPE_HOURS_JET)
	if bool(result["ok"]):
		jet = item_id
		GameManager.touch()
		escape_spend(B.ESCAPE_HOURS_JET)
	GameManager.end_batch()
	return result

func ready_to_fly() -> bool:
	return escape_active and passport != "" and jet != ""

## Chance, de 0 a 100, de a PF interceptar o avião se a decolagem fosse agora.
func interception_chance() -> float:
	var chance: float = GameManager.suspicion * B.ESCAPE_CHANCE_SUSPICION + escape_hours_used() * B.ESCAPE_CHANCE_HOUR
	if mandado:
		chance += B.ESCAPE_CHANCE_MANDADO
	chance -= float(B.tier_item(B.PASSPORTS, passport).get("bonus", 0.0))
	chance -= float(B.tier_item(B.JETS, jet).get("bonus", 0.0))
	return clampf(chance, B.ESCAPE_CHANCE_MIN, B.ESCAPE_CHANCE_MAX)

func takeoff() -> Dictionary:
	if not ready_to_fly():
		return {"ok": false, "message": "Faltam o passaporte e o avião."}
	resolve_escape()
	return {"ok": true, "message": ""}

## Decide a fuga. Sem passaporte ou sem avião, não há fuga. Com os dois, sorteia
## contra a chance de interceptação.
func resolve_escape() -> void:
	if ending != "":
		return
	if not ready_to_fly():
		escape_result = {"success": false, "flew": false, "chance": 100.0, "monero": Portfolio.monero}
		trigger_ending("preso", "As 72 horas acabaram sem passaporte e sem avião. A Polícia Federal cumpriu o mandado em casa.")
		return
	var chance: float = interception_chance()
	var caught: bool = GameManager.rng.randf() * 100.0 < chance
	escape_result = {"success": not caught, "flew": true, "chance": chance, "monero": Portfolio.monero}
	if caught:
		trigger_ending("preso", "A Polícia Federal interceptou o avião na pista de decolagem. O Monero ficou em uma carteira que ninguém mais vai abrir.")
	elif not mandado and goals_hit >= B.ACTS.size():
		trigger_ending("rei", "Três metas batidas, nenhum mandado, %s em Monero. Mônaco tem um novo morador." % GameManager.format_money(Portfolio.monero))
	else:
		trigger_ending("foragido", "O avião decolou com %s em Monero. Seu nome está na lista vermelha da Interpol." % GameManager.format_money(Portfolio.monero))

# ---------------------------------------------------------
# Save / load
# ---------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"act": act, "goals_hit": goals_hit, "extension_used": extension_used,
		"mandado": mandado, "mandado_streak": mandado_streak, "cartel_warned": cartel_warned,
		"threat_cooldown": threat_cooldown, "fresh_news": fresh_news,
		"escape_active": escape_active, "escape_reason": escape_reason,
		"escape_hours": escape_hours, "escape_start_worth": escape_start_worth,
		"passport": passport, "jet": jet
	}

func from_dict(saved: Dictionary) -> void:
	reset()
	act = clampi(int(saved.get("act", 1)), 1, B.ACTS.size())
	goals_hit = int(saved.get("goals_hit", 0))
	extension_used = bool(saved.get("extension_used", false))
	mandado = bool(saved.get("mandado", false))
	mandado_streak = int(saved.get("mandado_streak", 0))
	cartel_warned = bool(saved.get("cartel_warned", false))
	threat_cooldown = int(saved.get("threat_cooldown", 0))
	fresh_news = int(saved.get("fresh_news", 0))
	escape_active = bool(saved.get("escape_active", false))
	escape_reason = str(saved.get("escape_reason", ""))
	escape_hours = float(saved.get("escape_hours", 0.0))
	escape_start_worth = float(saved.get("escape_start_worth", 0.0))
	passport = str(saved.get("passport", ""))
	jet = str(saved.get("jet", ""))

func _load_meta() -> void:
	unlocked_endings = []
	if not FileAccess.file_exists(META_PATH):
		return
	var file: FileAccess = FileAccess.open(META_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	for ending_id_v: Variant in GameManager.as_list((parsed as Dictionary).get("endings")):
		if B.ENDINGS.has(str(ending_id_v)) and not unlocked_endings.has(str(ending_id_v)):
			unlocked_endings.append(str(ending_id_v))

func _save_meta() -> void:
	var file: FileAccess = FileAccess.open(META_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"endings": unlocked_endings}))
	file.close()
