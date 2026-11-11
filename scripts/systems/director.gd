extends Node
## Director — o ritmo dos acontecimentos.
##
## Decide, a cada noite, se acontece algo que exija uma decisão: oportunidades,
## crises de empresa, problemas com laranjas, ofertas de contrato, eventos
## raros e reações ao comportamento do jogador (concentrar tudo numa empresa,
## deixar dinheiro sujo parado). As ameaças de cada ato continuam em Campaign;
## o Director entra depois delas e respeita um limite de popups por noite.
##
## Cadência: a chance de um acontecimento sobe a cada noite tranquila, então
## na prática algo relevante aparece a cada 1 ou 2 turnos. Algumas escolhas
## agendam consequências para turnos seguintes (dívidas, favores, rebotes).
##
## Os popups seguem o formato do PopupManager. Toda escolha passa por _wrap,
## que conta a decisão para os objetivos.

const B = preload("res://scripts/data/balance.gd")

var quiet: int = 0                   # noites seguidas sem nenhuma decisão
var last_seen: Dictionary = {}       # id do acontecimento -> day_total em que apareceu
var schedule: Array = []             # [{at, id, data}] consequências agendadas
var usage_streak: Dictionary = {}    # empresa -> noites seguidas usada perto do teto
var last_contract_day: int = 0
var remessa_cut: int = 0             # noites com a remessa pela metade (pedido de paciência)
var stats: Dictionary = {}           # contagens para os testes de ritmo

## Celular de trabalho (só com o apartamento 3D): um acontecimento da noite
## pode ficar guardado para tocar no dia seguinte, como ligação. Se ninguém
## atender, ele volta para a fila da noite seguinte ("ligação perdida"). Assim o
## dia ganha imprevistos sem mudar o ritmo nem o número de decisões.
var phone_enabled: bool = false
var phone_call: Dictionary = {}
var _tonight: Array = []

## Quem liga para cada acontecimento: um elenco pequeno e recorrente.
const CALLERS: Dictionary = {
	"queda": ["Beto Vidal", "gerente das suas empresas"],
	"aquisicao": ["Beto Vidal", "gerente das suas empresas"],
	"ponto": ["Beto Vidal", "gerente das suas empresas"],
	"blitz": ["Beto Vidal", "gerente das suas empresas"],
	"investidor": ["Dr. Henrique Lacerda", "investidor de ocasião"],
	"reportagem": ["Marina Prado", "repórter da Folha da Cidade"],
	"capa": ["Marina Prado", "repórter da Folha da Cidade"],
	"panico": ["Lúcio", "seu doleiro"],
	"malote": ["Lúcio", "seu doleiro"],
	"doleiro_preso": ["Dra. Vera Castro", "advogada do Lúcio"],
	"vereador": ["Vereador Siqueira", "Câmara Municipal"],
	"banco_suico": ["Sr. Albrecht", "private banker em Genebra"],
	"rota_cartel": ["O Contador", "cartel"],
	"concentracao": ["Dona Célia", "sua contadora"],
	"impaciente": ["O Cliente", "número sem nome"],
	"aumento": ["Um dos seus laranjas", "ligando do trabalho"],
	"socio": ["Um dos seus laranjas", "ligando do trabalho"],
	"delator": ["Número restrito", ""],
	"golpe": ["Número restrito", ""],
}

## Catálogo: id, ato mínimo, peso no sorteio, raro.
const EVENTS: Array = [
	{"id": "queda", "act": 1, "weight": 3.0},
	{"id": "aumento", "act": 1, "weight": 3.0},
	{"id": "investidor", "act": 1, "weight": 2.0},
	{"id": "aquisicao", "act": 1, "weight": 2.0},
	{"id": "reportagem", "act": 1, "weight": 2.5},
	{"id": "ponto", "act": 1, "weight": 2.0},
	{"id": "blitz", "act": 1, "weight": 2.0},
	{"id": "capa", "act": 1, "weight": 1.5},
	{"id": "panico", "act": 2, "weight": 2.0},
	{"id": "vereador", "act": 2, "weight": 2.5},
	{"id": "socio", "act": 2, "weight": 2.0},
	{"id": "banco_suico", "act": 3, "weight": 3.0},
	{"id": "doleiro_preso", "act": 3, "weight": 2.5},
	{"id": "rota_cartel", "act": 3, "weight": 2.0},
	{"id": "malote", "act": 1, "weight": 1.0, "rare": true},
	{"id": "delator", "act": 2, "weight": 1.0, "rare": true},
	{"id": "golpe", "act": 1, "weight": 1.0, "rare": true}
]

func reset() -> void:
	quiet = 0
	last_seen = {}
	schedule = []
	usage_streak = {}
	last_contract_day = 0
	remessa_cut = 0
	phone_call = {}
	_tonight = []
	stats = {"nights": 0, "events": 0, "decision_nights": 0, "rare": 0, "contracts": 0}

func _ready() -> void:
	reset()

func remessa_factor() -> float:
	return 0.5 if remessa_cut > 0 else 1.0

# ---------------------------------------------------------
# Noite
# ---------------------------------------------------------

## Antes de zerar o uso do dia: quem está sendo usado perto do teto.
func observe_usage() -> void:
	for company_id_v: Variant in GameManager.owned_ids():
		var company_id: String = str(company_id_v)
		var cap: float = GameManager.capacity_of(company_id)
		var used: float = float(GameManager.companies[company_id]["used"])
		usage_streak[company_id] = int(usage_streak.get(company_id, 0)) + 1 if cap > 0.0 and used >= cap * 0.9 else 0

## Chamado por Campaign.daily_tick, depois das ameaças e notícias do ato.
func nightly() -> void:
	if Campaign.ending != "" or Campaign.escape_active:
		return
	stats["nights"] = int(stats.get("nights", 0)) + 1
	_tonight = []
	# Ligação de ontem que ninguém atendeu: vira decisão desta noite.
	if not phone_call.is_empty():
		phone_call["kicker"] = "LIGAÇÃO PERDIDA  /  " + str(phone_call.get("caller_name", "")).to_upper()
		Campaign.push_event(phone_call)
		phone_call = {}
	remessa_cut = maxi(0, remessa_cut - 1)
	var day: int = GameManager.day_total

	# 1. Consequências agendadas: sempre acontecem.
	for item_v: Variant in schedule.duplicate():
		var item: Dictionary = item_v
		if int(item["at"]) <= day:
			schedule.erase(item)
			_followup(str(item["id"]), item.get("data", {}) as Dictionary)

	# 2. Oferta de contrato, se não houver nenhum na mesa.
	if Missions.offered_contracts().is_empty() and Missions.active_contracts().is_empty() and day - last_contract_day >= B.CONTRACT_INTERVAL and Campaign.events.size() < B.DIRECTOR_MAX_POPUPS:
		var offer: Dictionary = Missions.make_offer()
		if not offer.is_empty():
			last_contract_day = day
			stats["contracts"] = int(stats.get("contracts", 0)) + 1
			Campaign.push_event(_contract_popup(offer))

	# 3. Reações ao comportamento do jogador.
	if Campaign.events.size() < B.DIRECTOR_MAX_POPUPS:
		for company_id: String in usage_streak:
			if int(usage_streak[company_id]) >= 3 and GameManager.owns(company_id) and _ready_again("concentracao"):
				usage_streak[company_id] = 0
				_push("concentracao", _ev_concentracao(company_id))
				break
	if Campaign.events.size() < B.DIRECTOR_MAX_POPUPS and GameManager.dirty_money > Campaign.remessa() * B.PILE_DAYS and Campaign.remessa() > 0.0 and _ready_again("impaciente"):
		_push("impaciente", _ev_impaciente())

	# 4. Acontecimento sorteado. A chance cresce a cada noite tranquila.
	if Campaign.events.size() < B.DIRECTOR_MAX_POPUPS:
		var rng: RandomNumberGenerator = GameManager.rng
		var chance: float = B.DIRECTOR_BASE_CHANCE + float(quiet) * B.DIRECTOR_QUIET_BONUS
		if rng.randf() < chance:
			var picked: String = _pick(rng.randf() < B.DIRECTOR_RARE_CHANCE)
			if picked != "":
				_push(picked, _build(picked))

	if Campaign.events.is_empty():
		quiet += 1
	else:
		quiet = 0
		stats["decision_nights"] = int(stats.get("decision_nights", 0)) + 1
	_hold_for_phone()

## Separa um acontecimento desta noite para tocar amanhã no celular (o ritmo
## acima já foi calculado com ele contado).
func _hold_for_phone() -> void:
	if not phone_enabled or _tonight.is_empty() or randf() > 0.65:
		return
	var event: Dictionary = _tonight[_tonight.size() - 1]
	if not Campaign.events.has(event):
		return
	Campaign.events.erase(event)
	var caller: Array = CALLERS.get(str(event.get("id", "")), ["Número desconhecido", ""]) as Array
	event["caller_name"] = str(caller[0])
	event["caller_role"] = str(caller[1])
	event["kicker"] = "CELULAR  /  %s%s" % [str(caller[0]).to_upper(), ("  ·  " + str(caller[1]).to_upper()) if str(caller[1]) != "" else ""]
	phone_call = event

## A ligação atendida sai da espera (o celular entrega e o popup resolve).
func take_phone_call() -> Dictionary:
	var call: Dictionary = phone_call
	phone_call = {}
	return call

func _ready_again(event_id: String) -> bool:
	var cooldown: int = B.DIRECTOR_RARE_COOLDOWN if _is_rare(event_id) else B.DIRECTOR_EVENT_COOLDOWN
	return not last_seen.has(event_id) or GameManager.day_total - int(last_seen[event_id]) >= cooldown

func _is_rare(event_id: String) -> bool:
	for e_v: Variant in EVENTS:
		if str((e_v as Dictionary)["id"]) == event_id:
			return bool((e_v as Dictionary).get("rare", false))
	return false

## Sorteio ponderado entre os acontecimentos que fazem sentido agora.
func _pick(rare: bool) -> String:
	var pool: Array = []
	var total: float = 0.0
	for e_v: Variant in EVENTS:
		var e: Dictionary = e_v
		if bool(e.get("rare", false)) != rare or int(e["act"]) > Campaign.act:
			continue
		var event_id: String = str(e["id"])
		if not _ready_again(event_id) or not _eligible(event_id):
			continue
		pool.append(e)
		total += float(e["weight"])
	if pool.is_empty():
		return "" if not rare else _pick(false)
	var roll: float = GameManager.rng.randf() * total
	for e_v: Variant in pool:
		roll -= float((e_v as Dictionary)["weight"])
		if roll <= 0.0:
			return str((e_v as Dictionary)["id"])
	return str((pool[pool.size() - 1] as Dictionary)["id"])

func _eligible(event_id: String) -> bool:
	match event_id:
		"queda":
			return not _active_companies().is_empty()
		"aumento":
			return not _calm_members(0).is_empty()
		"aquisicao":
			return GameManager.owned_ids().size() >= 2
		"reportagem":
			return GameManager.suspicion >= 30.0
		"ponto":
			return _expansion_target() != ""
		"blitz":
			return GameManager.owns("bar") or GameManager.owns("boate")
		"capa":
			return Lifestyle.prestige() >= 15
		"panico":
			return Portfolio.crypto_units > 0.0 or GameManager.clean_money > 200000.0
		"socio":
			return not _calm_members(2).is_empty()
		"banco_suico":
			return Portfolio.fund_balance("offshore") > 0.0 or Portfolio.funds_value() > 0.0
		"doleiro_preso":
			return not _calm_members(3).is_empty()
		"delator":
			return GameManager.suspicion >= 25.0
		"golpe":
			return GameManager.dirty_money >= Campaign.remessa()
	return true

func _push(event_id: String, event: Dictionary) -> void:
	if event.is_empty():
		return
	last_seen[event_id] = GameManager.day_total
	stats["events"] = int(stats.get("events", 0)) + 1
	if _is_rare(event_id):
		stats["rare"] = int(stats.get("rare", 0)) + 1
	for opt_v: Variant in event.get("options", []) as Array:
		var opt: Dictionary = opt_v
		opt["action"] = _wrap(opt["action"])
	event["id"] = event_id
	Campaign.push_event(event)
	_tonight.append(event)

## Toda escolha conta como decisão para os objetivos.
func _wrap(inner: Callable) -> Callable:
	return func() -> Dictionary:
		Missions.note("events")
		var result: Variant = inner.call()
		return result if typeof(result) == TYPE_DICTIONARY else {"ok": true, "message": ""}

func schedule_event(event_id: String, in_turns: int, payload: Dictionary = {}) -> void:
	schedule.append({"at": GameManager.day_total + in_turns, "id": event_id, "data": payload})

# ---------------------------------------------------------
# Apoio
# ---------------------------------------------------------

func _money(v: float) -> String:
	return GameManager.format_money(v)

func _name(company_id: String) -> String:
	return str(GameManager.companies[company_id]["name"])

func _active_companies() -> Array:
	return GameManager.owned_ids().filter(func(c: Variant) -> bool: return int(GameManager.companies[str(c)]["blocked"]) <= 0)

func _calm_members(min_tier: int) -> Array:
	return Staff.roster.filter(func(m: Variant) -> bool: return int((m as Dictionary)["delation"]) < 0 and int((m as Dictionary)["tier"]) >= min_tier)

func _random(list: Array) -> Variant:
	return list[GameManager.rng.randi_range(0, list.size() - 1)]

func _modifier(target: String, stat: String, value: float, turns: int, label: String) -> void:
	GameManager.modifiers.append({"target": target, "stat": stat, "value": value, "days": turns, "label": label})

func _result(message: String) -> Dictionary:
	GameManager.touch()
	return {"ok": true, "message": message}

## Paga em limpo; devolve false se não houver saldo.
func _pay(cost: float) -> bool:
	if cost > GameManager.clean_money + 0.5:
		return false
	GameManager.clean_money = maxf(0.0, GameManager.clean_money - cost)
	return true

func _opt(label: String, detail: String, action: Callable, enabled: bool = true, danger: bool = false) -> Dictionary:
	return {"label": label, "detail": detail, "enabled": enabled, "danger": danger, "action": action}

func _sell_company(company_id: String, price: float) -> void:
	GameManager.companies[company_id]["owned"] = false
	GameManager.companies[company_id]["used"] = 0.0
	Staff.release_company(company_id)
	GameManager.clean_money += price

## A empresa mais barata que o jogador ainda não tem e poderia ganhar agora.
func _expansion_target() -> String:
	for company_id: String in B.COMPANY_ORDER:
		var status: String = GameManager.company_status(company_id)
		if status == "owned":
			continue
		var data: Dictionary = GameManager.companies[company_id]
		if int(data["act"]) > Campaign.act + 1:
			continue
		var price: float = float(data["price"]) * B.EXPANSION_DISCOUNT
		if price <= GameManager.clean_money * 1.3 and price > 0.0:
			return company_id
	return ""

# ---------------------------------------------------------
# Construção dos popups
# ---------------------------------------------------------

func _build(event_id: String) -> Dictionary:
	match event_id:
		"queda": return _ev_queda()
		"aumento": return _ev_aumento()
		"investidor": return _ev_investidor()
		"aquisicao": return _ev_aquisicao()
		"reportagem": return _ev_reportagem()
		"ponto": return _ev_ponto()
		"blitz": return _ev_blitz()
		"capa": return _ev_capa()
		"panico": return _ev_panico()
		"vereador": return _ev_vereador()
		"socio": return _ev_socio()
		"banco_suico": return _ev_banco_suico()
		"doleiro_preso": return _ev_doleiro_preso()
		"rota_cartel": return _ev_rota_cartel()
		"malote": return _ev_malote()
		"delator": return _ev_delator()
		"golpe": return _ev_golpe()
	return {}

func _ev_queda() -> Dictionary:
	var company_id: String = str(_random(_active_companies()))
	var cost: float = snappedf(float(GameManager.companies[company_id]["value"]) * 0.25, 1000.0)
	var sale: float = snappedf(float(GameManager.companies[company_id]["value"]) * 0.8, 1000.0)
	var options: Array = [
		_opt("INVESTIR NA RECUPERAÇÃO", "%s  /  capacidade +15%% por 3 turnos" % _money(cost), _queda_invest.bind(company_id, cost), GameManager.clean_money >= cost),
		_opt("ACEITAR A QUEDA", "sem custo  /  capacidade -40% por 3 turnos", _queda_accept.bind(company_id))
	]
	if GameManager.owned_ids().size() >= 2:
		options.append(_opt("FECHAR E VENDER", "+%s  /  a empresa e os laranjas dela saem da operação" % _money(sale), _queda_sell.bind(company_id, sale), true, true))
	return {"style": "official", "kicker": "EMPRESA / QUEDA DE DESEMPENHO",
		"title": "%s perdeu clientes" % _name(company_id),
		"body": "Uma concorrente abriu na mesma rua e o movimento caiu. Sem movimento real, fica difícil justificar o caixa da %s." % _name(company_id),
		"options": options}

func _queda_invest(company_id: String, cost: float) -> Dictionary:
	if not _pay(cost):
		return {"ok": false, "message": "Saldo limpo insuficiente."}
	_modifier(company_id, "capacity", 0.15, 3, "%s reformada: +15%% de capacidade" % _name(company_id))
	return _result("Reforma feita. A %s volta mais forte." % _name(company_id))

func _queda_accept(company_id: String) -> Dictionary:
	_modifier(company_id, "capacity", -0.40, 3, "%s em baixa: -40%% de capacidade" % _name(company_id))
	return _result("A %s vai operar no mínimo por uns dias." % _name(company_id))

func _queda_sell(company_id: String, sale: float) -> Dictionary:
	_sell_company(company_id, sale)
	return _result("%s vendida por %s." % [_name(company_id), _money(sale)])

func _ev_aumento() -> Dictionary:
	var member: Dictionary = _random(_calm_members(0))
	var staff_id: int = int(member["id"])
	var raise_cost: float = snappedf(float(member["cost"]) * 0.4, 50.0)
	var dismiss_cost: float = Staff.dismiss_cost(member)
	return {"style": "official", "kicker": "LARANJAS / LEALDADE",
		"title": "%s quer um aumento" % str(member["name"]),
		"body": "%s sabe o que assina e quanto isso vale. Lealdade %d, estresse %d. Diz que tem outra proposta." % [str(member["name"]), int(member["loyalty"]), int(member["stress"])],
		"options": [
			_opt("DAR O AUMENTO", "diária +%s  /  lealdade +25  /  estresse -15" % _money(raise_cost), _aumento_give.bind(staff_id, raise_cost)),
			_opt("NEGAR", "lealdade -20  /  estresse +20", _aumento_deny.bind(staff_id), true, true),
			_opt("DISPENSAR", "%s de acerto  /  a vaga fica livre" % _money(dismiss_cost), _aumento_dismiss.bind(staff_id), GameManager.clean_money >= dismiss_cost)
		]}

func _aumento_give(staff_id: int, raise_cost: float) -> Dictionary:
	var member: Dictionary = Staff.find(staff_id)
	if member.is_empty():
		return _result("")
	member["cost"] = float(member["cost"]) + raise_cost
	member["loyalty"] = minf(100.0, float(member["loyalty"]) + 25.0)
	member["stress"] = maxf(0.0, float(member["stress"]) - 15.0)
	return _result("%s ficou satisfeito." % str(member["name"]))

func _aumento_deny(staff_id: int) -> Dictionary:
	var member: Dictionary = Staff.find(staff_id)
	if member.is_empty():
		return _result("")
	member["loyalty"] = maxf(0.0, float(member["loyalty"]) - 20.0)
	member["stress"] = minf(99.0, float(member["stress"]) + 20.0)
	return _result("%s saiu da conversa calado. Isso não é bom sinal." % str(member["name"]))

func _aumento_dismiss(staff_id: int) -> Dictionary:
	return Staff.dismiss(staff_id)

func _ev_investidor() -> Dictionary:
	var amount: float = snappedf(Campaign.goal() * 0.12, 1000.0)
	var options: Array = [
		_opt("ACEITAR O CAPITAL", "+%s agora  /  devolver %s em 3 turnos" % [_money(amount), _money(amount * 1.35)], _investidor_accept.bind(amount, 1.35)),
		_opt("RECUSAR", "nada muda", func() -> Dictionary: return _result("Você agradeceu e recusou."))
	]
	if Lifestyle.prestige_tier() >= 2:
		options.insert(1, _opt("NEGOCIAR OS JUROS", "+%s agora  /  devolver %s em 3 turnos (seu prestígio pesa)" % [_money(amount), _money(amount * 1.15)], _investidor_accept.bind(amount, 1.15)))
	return {"style": "official", "kicker": "OPORTUNIDADE / CAPITAL",
		"title": "Um investidor oferece dinheiro rápido",
		"body": "Um empresário de fora quer \"participar\" da operação. Entra com dinheiro limpo agora e cobra com juros daqui a três turnos. Quem não paga esse tipo de gente não costuma reclamar depois.",
		"options": options}

func _investidor_accept(amount: float, rate: float) -> Dictionary:
	GameManager.clean_money += amount
	schedule_event("cobranca", 3, {"amount": snappedf(amount * rate, 1000.0), "deferred": false})
	return _result("%s na conta. A cobrança vem em 3 turnos." % _money(amount))

func _ev_aquisicao() -> Dictionary:
	var owned: Array = GameManager.owned_ids()
	var company_id: String = str(_random(owned))
	var offer: float = snappedf(float(GameManager.companies[company_id]["value"]) * 1.5, 1000.0)
	return {"style": "official", "kicker": "MERCADO / PROPOSTA DE COMPRA",
		"title": "Querem comprar a %s" % _name(company_id),
		"body": "Um grupo do setor oferece %s pela %s, 50%% acima do valor contábil. Vender encolhe a operação; recusar mostra que você não precisa de dinheiro." % [_money(offer), _name(company_id)],
		"options": [
			_opt("VENDER", "+%s  /  a empresa e os laranjas dela saem" % _money(offer), _aquisicao_sell.bind(company_id, offer)),
			_opt("RECUSAR", "prestígio +3", _aquisicao_refuse)
		]}

func _aquisicao_sell(company_id: String, offer: float) -> Dictionary:
	if not GameManager.owns(company_id):
		return _result("")
	_sell_company(company_id, offer)
	return _result("%s vendida por %s." % [_name(company_id), _money(offer)])

func _aquisicao_refuse() -> Dictionary:
	Lifestyle.bonus_prestige += 3
	return _result("A recusa correu a cidade. Seu nome pesa mais.")

func _ev_reportagem() -> Dictionary:
	var s: float = Campaign.scale()
	var pr: float = 15000.0 * s
	var suit: float = 30000.0 * s
	return {"style": "news", "kicker": "IMPRENSA / REPORTAGEM", "source": "JORNAL DA CIDADE",
		"title": "Um repórter está cavando os seus negócios",
		"body": "Um jornal pediu os balanços das suas empresas e está ligando para ex-funcionários. A matéria sai em poucos dias.",
		"options": [
			_opt("ASSESSORIA DE IMPRENSA", "%s  /  suspeita -6" % _money(pr), _reportagem_pr.bind(pr), GameManager.clean_money >= pr),
			_opt("PROCESSAR O JORNAL", "%s  /  60%%: suspeita -10 e prestígio +4  /  40%%: a história cresce (+6)" % _money(suit), _reportagem_suit.bind(suit), GameManager.clean_money >= suit),
			_opt("IGNORAR", "suspeita +4  /  operações geram 20% mais suspeita por 3 turnos", _reportagem_ignore, true, true)
		]}

func _reportagem_pr(cost: float) -> Dictionary:
	if not _pay(cost):
		return {"ok": false, "message": "Saldo limpo insuficiente."}
	GameManager.add_suspicion(-6.0)
	return _result("A matéria saiu na página 14, sem foto.")

func _reportagem_suit(cost: float) -> Dictionary:
	if not _pay(cost):
		return {"ok": false, "message": "Saldo limpo insuficiente."}
	if GameManager.rng.randf() < 0.6:
		GameManager.add_suspicion(-10.0)
		Lifestyle.bonus_prestige += 4
		return _result("O juiz mandou recolher a edição. Ninguém mais toca no assunto.")
	GameManager.add_suspicion(6.0)
	return _result("O processo virou notícia. A matéria foi parar na TV.")

func _reportagem_ignore() -> Dictionary:
	GameManager.add_suspicion(4.0)
	_modifier("*", "risk", 0.20, 3, "Matéria no jornal: +20% de suspeita por operação")
	return _result("A matéria saiu. Agora todo mundo está olhando.")

func _ev_ponto() -> Dictionary:
	var company_id: String = _expansion_target()
	if company_id == "":
		return {}
	var price: float = snappedf(float(GameManager.companies[company_id]["price"]) * B.EXPANSION_DISCOUNT, 1000.0)
	var early: bool = int(GameManager.companies[company_id]["act"]) > Campaign.act or GameManager.company_status(company_id) == "prestige"
	return {"style": "official", "kicker": "OPORTUNIDADE / EXPANSÃO",
		"title": "%s à venda com desconto" % _name(company_id),
		"body": "O dono precisa de dinheiro rápido e aceita %s pela %s, %d%% abaixo do preço.%s A oferta vale só hoje." % [_money(price), _name(company_id), int(round((1.0 - B.EXPANSION_DISCOUNT) * 100.0)), " Normalmente ela nem estaria ao seu alcance agora." if early else ""],
		"options": [
			_opt("COMPRAR AGORA", "%s do saldo limpo" % _money(price), _ponto_buy.bind(company_id, price), GameManager.clean_money >= price),
			_opt("DEIXAR PASSAR", "nada muda", func() -> Dictionary: return _result("Outro comprador fechou negócio."))
		]}

func _ponto_buy(company_id: String, price: float) -> Dictionary:
	if GameManager.owns(company_id) or not _pay(price):
		return {"ok": false, "message": "Compra indisponível."}
	GameManager.companies[company_id]["owned"] = true
	return _result("%s agora é sua." % _name(company_id))

func _ev_blitz() -> Dictionary:
	var target: String = "boate" if GameManager.owns("boate") else "bar"
	var guard: float = 10000.0 * Campaign.scale()
	return {"style": "news", "kicker": "POLÍCIA / BLITZ NA NOITE", "source": "PLANTÃO POLICIAL",
		"title": "Blitz nas casas noturnas da região",
		"body": "A polícia está fechando o cerco à vida noturna: alvará, caixa, segurança. A %s está na lista." % _name(target),
		"options": [
			_opt("FECHAR POR 2 TURNOS", "a %s para  /  suspeita -3" % _name(target), _blitz_close.bind(target)),
			_opt("SEGURANÇA REFORÇADA", "%s  /  nada mais muda" % _money(guard), _blitz_guard.bind(guard), GameManager.clean_money >= guard),
			_opt("SEGUIR NORMAL", "operações na %s geram 60%% mais suspeita por 3 turnos" % _name(target), _blitz_ignore.bind(target), true, true)
		]}

func _blitz_close(target: String) -> Dictionary:
	GameManager.companies[target]["blocked"] = maxi(int(GameManager.companies[target]["blocked"]), 2)
	GameManager.add_suspicion(-3.0)
	return _result("Portas fechadas \"para reforma\".")

func _blitz_guard(cost: float) -> Dictionary:
	if not _pay(cost):
		return {"ok": false, "message": "Saldo limpo insuficiente."}
	return _result("Alvarás em dia e seguranças na porta.")

func _blitz_ignore(target: String) -> Dictionary:
	_modifier(target, "risk", 0.60, 3, "%s sob blitz: +60%% de suspeita" % _name(target))
	return _result("A casa segue aberta. A polícia anotou.")

func _ev_capa() -> Dictionary:
	return {"style": "news", "kicker": "SOCIEDADE / REVISTA", "source": "REVISTA CARAS & BOCAS",
		"title": "Querem você na capa",
		"body": "Uma revista de celebridades quer fotografar você na cobertura. Fama abre portas e também chama gente curiosa.",
		"options": [
			_opt("ACEITAR A CAPA", "prestígio +8  /  suspeita +5", _capa_accept),
			_opt("RECUSAR", "nada muda", func() -> Dictionary: return _result("Discrição também é estilo."))
		]}

func _capa_accept() -> Dictionary:
	Lifestyle.bonus_prestige += 8
	GameManager.add_suspicion(5.0)
	return _result("A capa vendeu bem. Seu nome agora está em todas as rodas.")

func _ev_panico() -> Dictionary:
	Portfolio.crypto_price = snappedf(Portfolio.crypto_price * 0.82, 1.0)
	Portfolio.price_history.append(Portfolio.crypto_price)
	var budget: float = snappedf(GameManager.clean_money * 0.2, 1000.0)
	return {"style": "news", "kicker": "MERCADO / PÂNICO", "source": "CLEAN SLATE / NEWSWIRE",
		"title": "Cripto despenca 18% em uma noite",
		"body": "Um rumor sobre regulação derrubou o mercado. Ninguém sabe se é o fundo do poço ou o começo da queda.",
		"options": [
			_opt("COMPRAR NA BAIXA", "%s em cripto" % _money(budget), _panico_buy.bind(budget), budget >= 1000.0),
			_opt("VENDER TUDO", "zera a posição em cripto", _panico_sell, Portfolio.crypto_units > 0.0, true),
			_opt("SEGURAR", "espera o mercado decidir", func() -> Dictionary: return _result("Você não mexeu em nada."))
		]}

func _panico_buy(budget: float) -> Dictionary:
	schedule_event("rebote", 2)
	return Portfolio.buy_crypto(budget)

func _panico_sell() -> Dictionary:
	schedule_event("rebote", 2)
	return Portfolio.sell_crypto(Portfolio.crypto_value())

func _ev_vereador() -> Dictionary:
	var target: String = "construtora" if GameManager.owns("construtora") else str(GameManager.owned_ids().back())
	var bribe: float = 40000.0 * Campaign.scale()
	return {"style": "official", "kicker": "POLÍTICA / CONTRATO DE OBRA",
		"title": "Um vereador oferece um contrato",
		"body": "Uma obra superfaturada precisa de uma empresa amiga. A %s pode faturar alto por uns dias. O vereador cobra adiantado e não esquece quem pagou." % _name(target),
		"options": [
			_opt("PAGAR A PROPINA", "%s  /  influência +1  /  %s +40%% de capacidade por 3 turnos  /  ele pode ser preso depois" % [_money(bribe), _name(target)], _vereador_pay.bind(target, bribe), GameManager.clean_money >= bribe),
			_opt("RECUSAR", "prestígio +2", _vereador_refuse)
		]}

func _vereador_pay(target: String, cost: float) -> Dictionary:
	if not _pay(cost):
		return {"ok": false, "message": "Saldo limpo insuficiente."}
	GameManager.influence = mini(B.INFLUENCE_MAX, GameManager.influence + 1)
	_modifier(target, "capacity", 0.40, 3, "Obra pública na %s: +40%% de capacidade" % _name(target))
	schedule_event("conta_vereador", 4)
	return _result("Contrato assinado. O vereador sorriu.")

func _vereador_refuse() -> Dictionary:
	Lifestyle.bonus_prestige += 2
	return _result("Você ganhou fama de sério. Por enquanto.")

func _ev_socio() -> Dictionary:
	var member: Dictionary = _random(_calm_members(2))
	var staff_id: int = int(member["id"])
	return {"style": "official", "kicker": "LARANJAS / AMBIÇÃO",
		"title": "%s quer virar sócio" % str(member["name"]),
		"body": "%s movimenta muito dinheiro seu e acha que merece uma fatia. Recusar tem preço; aceitar também." % str(member["name"]),
		"options": [
			_opt("DAR SOCIEDADE", "diária dobra  /  lealdade 100  /  estresse 0", _socio_accept.bind(staff_id)),
			_opt("RECUSAR", "estresse +25  /  lealdade -10", _socio_refuse.bind(staff_id), true, true)
		]}

func _socio_accept(staff_id: int) -> Dictionary:
	var member: Dictionary = Staff.find(staff_id)
	if member.is_empty():
		return _result("")
	member["cost"] = float(member["cost"]) * 2.0
	member["loyalty"] = 100.0
	member["stress"] = 0.0
	return _result("%s agora é sócio. E fiel." % str(member["name"]))

func _socio_refuse(staff_id: int) -> Dictionary:
	var member: Dictionary = Staff.find(staff_id)
	if member.is_empty():
		return _result("")
	member["stress"] = minf(99.0, float(member["stress"]) + 25.0)
	member["loyalty"] = maxf(0.0, float(member["loyalty"]) - 10.0)
	return _result("%s engoliu a recusa." % str(member["name"]))

func _ev_banco_suico() -> Dictionary:
	var lawyers: float = 50000.0 * Campaign.scale()
	var offshore: float = Portfolio.fund_balance("offshore")
	var exposed: float = offshore if offshore > 0.0 else Portfolio.funds_value()
	return {"style": "official", "kicker": "INTERNACIONAL / BANCO SUÍÇO",
		"title": "O banco quer saber de onde veio o dinheiro",
		"body": "O compliance de um banco em Zurique pediu a origem dos recursos aplicados. Sem resposta, a conta é bloqueada.",
		"options": [
			_opt("PAGAR OS ADVOGADOS", "%s  /  suspeita -2" % _money(lawyers), _suico_lawyers.bind(lawyers), GameManager.clean_money >= lawyers),
			_opt("RESGATAR TUDO", "os fundos voltam para o saldo limpo (com a taxa de resgate)", _suico_move),
			_opt("IGNORAR", "30%% dos fundos ficam bloqueados (%s)" % _money(exposed * 0.3), _suico_ignore, true, true)
		]}

func _suico_lawyers(cost: float) -> Dictionary:
	if not _pay(cost):
		return {"ok": false, "message": "Saldo limpo insuficiente."}
	Missions.note_threat("intl")
	GameManager.add_suspicion(-2.0)
	return _result("Os advogados mandaram 400 páginas. O banco se deu por satisfeito.")

func _suico_move() -> Dictionary:
	Missions.note_threat("intl")
	var moved: float = 0.0
	for fund_id: String in Portfolio.funds.keys():
		var balance: float = Portfolio.fund_balance(fund_id)
		if balance > 0.0:
			Portfolio.withdraw(fund_id, balance)
			moved += balance
	return _result("%s resgatados antes do bloqueio." % _money(moved))

func _suico_ignore() -> Dictionary:
	var lost: float = 0.0
	for fund_id: String in Portfolio.funds.keys():
		var cut: float = Portfolio.fund_balance(fund_id) * 0.3
		Portfolio.funds[fund_id] = Portfolio.fund_balance(fund_id) - cut
		lost += cut
	return _result("%s bloqueados em Zurique." % _money(lost))

func _ev_doleiro_preso() -> Dictionary:
	var member: Dictionary = _random(_calm_members(3))
	var staff_id: int = int(member["id"])
	var bail: float = snappedf(float(member["cost"]) * 8.0, 1000.0)
	return {"style": "official", "kicker": "INTERNACIONAL / PRISÃO EM MIAMI",
		"title": "%s foi preso em Miami" % str(member["name"]),
		"body": "Seu doleiro foi detido no aeroporto com documentos da operação. Os promotores americanos já ofereceram um acordo.",
		"options": [
			_opt("PAGAR A FIANÇA", "%s  /  lealdade 100" % _money(bail), _doleiro_bail.bind(staff_id, bail), GameManager.clean_money >= bail),
			_opt("ABANDONAR", "ele começa a negociar delação", _doleiro_abandon.bind(staff_id), true, true)
		]}

func _doleiro_bail(staff_id: int, bail: float) -> Dictionary:
	var member: Dictionary = Staff.find(staff_id)
	if member.is_empty() or not _pay(bail):
		return {"ok": false, "message": "Não foi possível pagar a fiança."}
	Missions.note_threat("intl")
	member["loyalty"] = 100.0
	member["stress"] = maxf(0.0, float(member["stress"]) - 20.0)
	return _result("%s está solto e devendo a você." % str(member["name"]))

func _doleiro_abandon(staff_id: int) -> Dictionary:
	var member: Dictionary = Staff.find(staff_id)
	if member.is_empty():
		return _result("")
	member["stress"] = 100.0
	member["delation"] = B.DELATION_DEADLINE
	GameManager.add_news("URGENTE", "%s negocia delação nos EUA" % str(member["name"]), "Abandonado, o doleiro procurou os promotores.", "Decisão pendente na aba Laranjas")
	return _result("%s ficou sozinho. E começou a falar." % str(member["name"]))

func _ev_rota_cartel() -> Dictionary:
	return {"style": "cartel", "kicker": "CARTEL / NOVA ROTA",
		"title": "O cartel oferece uma rota própria",
		"body": "Portos, contêineres e alfândega comprada. Por três turnos, tudo que você tem gira mais rápido. Em troca, o cartel fica de olho em você.",
		"options": [
			_opt("ACEITAR A ROTA", "capacidade de todas as empresas +30% por 3 turnos  /  suspeita +6", _rota_accept),
			_opt("RECUSAR", "custo das empresas +2 pts por 3 turnos (o cartel não gosta de recusa)", _rota_refuse)
		]}

func _rota_accept() -> Dictionary:
	_modifier("*", "capacity", 0.30, 3, "Rota do cartel: +30% de capacidade")
	GameManager.add_suspicion(6.0)
	return _result("Os contêineres começaram a chegar.")

func _rota_refuse() -> Dictionary:
	_modifier("*", "loss", 0.02, 3, "Cartel contrariado: custo +2 pts")
	return _result("O recado foi entendido. Dos dois lados.")

func _ev_malote() -> Dictionary:
	var held: float = snappedf(Campaign.remessa() * 0.5, 1000.0)
	var bribe: float = snappedf(held * 0.15, 1000.0)
	return {"style": "cartel", "kicker": "RARO / MALOTE RETIDO",
		"title": "Um malote ficou preso na alfândega",
		"body": "Metade da remessa desta noite (%s) está com um fiscal que fez perguntas demais." % _money(held),
		"options": [
			_opt("SUBORNAR O FISCAL", "%s  /  suspeita +3" % _money(bribe), _malote_bribe.bind(bribe), GameManager.clean_money >= bribe),
			_opt("ABANDONAR O MALOTE", "perde %s de saldo sujo" % _money(held), _malote_lose.bind(held), true, true)
		]}

func _malote_bribe(cost: float) -> Dictionary:
	if not _pay(cost):
		return {"ok": false, "message": "Saldo limpo insuficiente."}
	GameManager.add_suspicion(3.0)
	return _result("O fiscal esqueceu o que viu.")

func _malote_lose(held: float) -> Dictionary:
	GameManager.dirty_money = maxf(0.0, GameManager.dirty_money - held)
	return _result("O malote sumiu nos registros da alfândega.")

func _ev_delator() -> Dictionary:
	var cost: float = 80000.0 * Campaign.scale()
	return {"style": "official", "kicker": "RARO / DENÚNCIA ANÔNIMA",
		"title": "Alguém está entregando você",
		"body": "Um disque-denúncia descreve a sua operação com detalhes que só gente de dentro conhece.",
		"options": [
			_opt("DESCOBRIR QUEM É", "%s  /  suspeita -8" % _money(cost), _delator_hunt.bind(cost), GameManager.clean_money >= cost),
			_opt("SEGUIR EM FRENTE", "suspeita +15  /  estresse +10 em todos os laranjas", _delator_ignore, true, true)
		]}

func _delator_hunt(cost: float) -> Dictionary:
	if not _pay(cost):
		return {"ok": false, "message": "Saldo limpo insuficiente."}
	GameManager.add_suspicion(-8.0)
	return _result("Era um ex-funcionário. Ele mudou de cidade.")

func _delator_ignore() -> Dictionary:
	Staff.add_stress_all(10.0)
	GameManager.add_suspicion(15.0)
	return _result("As denúncias continuam chegando.")

func _ev_golpe() -> Dictionary:
	var amount: float = snappedf(minf(GameManager.dirty_money, Campaign.remessa() * 2.0), 1000.0)
	return {"style": "official", "kicker": "RARO / GERENTE DE BANCO",
		"title": "Um gerente oferece uma janela única",
		"body": "Um gerente com dívidas de jogo pode passar %s de uma vez, por fora do sistema, com taxa de 5%%. Só hoje. Um volume desses chama atenção." % _money(amount),
		"options": [
			_opt("FECHAR NEGÓCIO", "%s viram %s limpos  /  suspeita +10" % [_money(amount), _money(amount * 0.95)], _golpe_accept.bind(amount)),
			_opt("RECUSAR", "nada muda", func() -> Dictionary: return _result("Você não conhece esse gerente."))
		]}

func _golpe_accept(amount: float) -> Dictionary:
	var real: float = minf(amount, GameManager.dirty_money)
	GameManager.dirty_money -= real
	GameManager.clean_money += real * 0.95
	GameManager.total_clean_generated += real * 0.95
	Missions.note("laundered", real)
	GameManager.add_suspicion(10.0)
	return _result("%s limpos numa tacada só." % _money(real * 0.95))

## Comportamento: uma empresa usada perto do teto por 3 turnos seguidos.
func _ev_concentracao(company_id: String) -> Dictionary:
	var cost: float = 15000.0 * Campaign.scale()
	return {"style": "official", "kicker": "RECEITA / MOVIMENTO ATÍPICO",
		"title": "A %s está movimentando demais" % _name(company_id),
		"body": "Três turnos seguidos no limite da capacidade. O sistema de cruzamento de dados marcou a empresa para análise.",
		"options": [
			_opt("ESPALHAR AS OPERAÇÕES", "%s com -50%% de capacidade por 2 turnos  /  suspeita -3" % _name(company_id), _concentracao_spread.bind(company_id)),
			_opt("NOTAS FRIAS", "%s  /  nada mais muda" % _money(cost), _concentracao_notes.bind(cost), GameManager.clean_money >= cost),
			_opt("IGNORAR", "suspeita +8", _concentracao_ignore, true, true)
		]}

func _concentracao_spread(company_id: String) -> Dictionary:
	_modifier(company_id, "capacity", -0.5, 2, "%s em análise: -50%% de capacidade" % _name(company_id))
	GameManager.add_suspicion(-3.0)
	return _result("O movimento da %s vai parecer normal por uns dias." % _name(company_id))

func _concentracao_notes(cost: float) -> Dictionary:
	if not _pay(cost):
		return {"ok": false, "message": "Saldo limpo insuficiente."}
	return _result("Notas fiscais para justificar cada centavo.")

func _concentracao_ignore() -> Dictionary:
	GameManager.add_suspicion(8.0)
	return _result("A análise continua.")

## Comportamento: dinheiro sujo acumulando sem ser lavado.
func _ev_impaciente() -> Dictionary:
	var share: float = snappedf(GameManager.dirty_money * 0.3, 1000.0)
	return {"style": "cartel", "kicker": "RECADO DO CLIENTE",
		"title": "O cliente quer saber do dinheiro dele",
		"body": "Tem %s sujos parados com você. O cliente acha que dinheiro parado é dinheiro perdido." % _money(GameManager.dirty_money),
		"options": [
			_opt("LAVADOR TERCEIRIZADO", "%s viram %s limpos (25%% de taxa)" % [_money(share), _money(share * 0.75)], _impaciente_outsource.bind(share)),
			_opt("PEDIR PACIÊNCIA", "a próxima remessa vem pela metade  /  prestígio -2", _impaciente_wait)
		]}

func _impaciente_outsource(share: float) -> Dictionary:
	var real: float = minf(share, GameManager.dirty_money)
	GameManager.dirty_money -= real
	GameManager.clean_money += real * 0.75
	GameManager.total_clean_generated += real * 0.75
	return _result("O terceirizado levou a parte dele.")

func _impaciente_wait() -> Dictionary:
	remessa_cut = 2
	Lifestyle.bonus_prestige -= 2
	return _result("O cliente vai mandar menos até você dar conta.")

# ---------------------------------------------------------
# Contratos (popup de oferta)
# ---------------------------------------------------------

func _contract_popup(offer: Dictionary) -> Dictionary:
	var uid: int = int(offer["uid"])
	return {"style": "cartel", "kicker": "NOVO CONTRATO DO CLIENTE",
		"title": str(offer["title"]),
		"body": "%s\n\nRecompensa: %s.\nSe falhar: %s." % [str(offer["text"]), Missions.reward_text(offer["reward"]), Missions.reward_text(offer["penalty"])],
		"options": [
			_opt("ACEITAR", "o prazo começa agora", func() -> Dictionary: return Missions.accept_contract(uid)),
			_opt("DECIDIR DEPOIS", "a oferta fica %d turnos na aba Missões" % B.CONTRACT_OFFER_DAYS, func() -> Dictionary: return {"ok": true, "message": ""}, true, false),
			_opt("RECUSAR", "sem consequência", func() -> Dictionary: return Missions.decline_contract(uid))
		]}

# ---------------------------------------------------------
# Consequências agendadas
# ---------------------------------------------------------

func _followup(event_id: String, payload: Dictionary) -> void:
	match event_id:
		"cobranca":
			_push("cobranca", _ev_cobranca(float(payload.get("amount", 0.0)), bool(payload.get("deferred", false))))
		"rebote":
			if GameManager.rng.randf() < 0.65:
				Portfolio.crypto_price = snappedf(Portfolio.crypto_price * 1.30, 1.0)
				GameManager.add_news("MERCADO", "Cripto se recupera com força", "Quem segurou ou comprou na baixa saiu ganhando.", "Preço +30%")
			else:
				Portfolio.crypto_price = snappedf(Portfolio.crypto_price * 0.85, 1.0)
				GameManager.add_news("MERCADO", "Cripto continua caindo", "O rumor virou regra. O mercado não se recuperou.", "Preço -15%")
			Portfolio.price_history.append(Portfolio.crypto_price)
		"conta_vereador":
			if GameManager.rng.randf() < 0.45:
				GameManager.add_news("URGENTE", "Vereador preso em operação da PF", "O vereador do contrato de obra foi preso e está falando.", "Uma decisão espera por você")
				Campaign.push_event(Campaign._threat_event("aliado"))
		"favor_padrinho":
			_push("favor_padrinho", _ev_favor_padrinho())

func _ev_cobranca(amount: float, deferred: bool) -> Dictionary:
	var options: Array = [
		_opt("PAGAR", "%s do saldo limpo" % _money(amount), _cobranca_pay.bind(amount), GameManager.clean_money >= amount)
	]
	if not deferred:
		options.append(_opt("PEDIR MAIS PRAZO", "paga %s daqui a 2 turnos  /  suspeita +3" % _money(amount * 1.2), _cobranca_defer.bind(amount)))
	options.append(_opt("DAR O CALOTE", "suspeita +12  /  suas empresas param 1 turno", _cobranca_default, true, true))
	return {"style": "cartel", "kicker": "COBRANÇA / O INVESTIDOR VOLTOU",
		"title": "Hora de devolver o capital",
		"body": "O investidor mandou dois homens buscar %s. Eles não aceitam cheque." % _money(amount),
		"options": options}

func _cobranca_pay(amount: float) -> Dictionary:
	if not _pay(amount):
		return {"ok": false, "message": "Saldo limpo insuficiente."}
	return _result("Dívida quitada. O investidor mandou lembranças.")

func _cobranca_defer(amount: float) -> Dictionary:
	GameManager.add_suspicion(3.0)
	schedule_event("cobranca", 2, {"amount": snappedf(amount * 1.2, 1000.0), "deferred": true})
	return _result("Mais dois turnos. Com juros.")

func _cobranca_default() -> Dictionary:
	GameManager.add_suspicion(12.0)
	for company_id_v: Variant in GameManager.owned_ids():
		var company: Dictionary = GameManager.companies[str(company_id_v)]
		company["blocked"] = maxi(int(company["blocked"]), 1)
	return _result("Os homens do investidor fecharam suas portas por um dia. E fizeram barulho.")

# ---------------------------------------------------------
# Eventos especiais de passagem de ato
# ---------------------------------------------------------

func act_event(new_act: int) -> void:
	match new_act:
		2:
			_push("padrinho", {"style": "official", "kicker": "ATO 2 / UM PADRINHO",
				"title": "Um deputado quer apadrinhar você",
				"body": "Na política, quem tem padrinho não morre pagão. Ele abre portas em Brasília agora e cobra um favor mais adiante.",
				"options": [
					_opt("ACEITAR O PADRINHO", "influência +2 agora  /  ele cobra um favor em 5 turnos", _padrinho_accept),
					_opt("SEGUIR SOZINHO", "prestígio +5", _padrinho_refuse)
				]})
		3:
			_push("contador", {"style": "cartel", "kicker": "ATO 3 / O CONTADOR DO CARTEL",
				"title": "O cartel oferece o próprio contador",
				"body": "Um contador que já lavou dinheiro em quatro continentes. Ele barateia cada operação, mas responde ao cartel, não a você.",
				"options": [
					_opt("ACEITAR O CONTADOR", "custo das empresas -2 pts até o fim  /  suspeita +5", _contador_accept),
					_opt("USAR A PRÓPRIA REDE", "prestígio +5", _contador_refuse)
				]})

func _padrinho_accept() -> Dictionary:
	GameManager.influence = mini(B.INFLUENCE_MAX, GameManager.influence + 2)
	schedule_event("favor_padrinho", 5)
	return _result("O deputado já fala de você como afilhado.")

func _padrinho_refuse() -> Dictionary:
	Lifestyle.bonus_prestige += 5
	return _result("Independência também é capital.")

func _ev_favor_padrinho() -> Dictionary:
	var cost: float = 60000.0 * Campaign.scale()
	return {"style": "official", "kicker": "POLÍTICA / O FAVOR",
		"title": "O padrinho veio cobrar",
		"body": "A campanha dele precisa de %s. Ele lembra, com um sorriso, quem abriu as portas para você." % _money(cost),
		"options": [
			_opt("PAGAR O FAVOR", "%s  /  influência +1" % _money(cost), _favor_pay.bind(cost), GameManager.clean_money >= cost),
			_opt("NEGAR", "influência -2  /  suspeita +5", _favor_deny, true, true)
		]}

func _favor_pay(cost: float) -> Dictionary:
	if not _pay(cost):
		return {"ok": false, "message": "Saldo limpo insuficiente."}
	GameManager.influence = mini(B.INFLUENCE_MAX, GameManager.influence + 1)
	return _result("O padrinho agradece. Brasília também.")

func _favor_deny() -> Dictionary:
	GameManager.influence = maxi(0, GameManager.influence - 2)
	GameManager.add_suspicion(5.0)
	return _result("O padrinho virou desafeto. E desafeto fala.")

func _contador_accept() -> Dictionary:
	Missions.perks["loss_discount"] = Missions.perk("loss_discount") + 0.02
	GameManager.add_suspicion(5.0)
	return _result("O contador do cartel assumiu os livros.")

func _contador_refuse() -> Dictionary:
	Lifestyle.bonus_prestige += 5
	return _result("Sua rede, suas regras.")

# ---------------------------------------------------------
# Save / load
# ---------------------------------------------------------

func to_dict() -> Dictionary:
	return {"quiet": quiet, "last_seen": last_seen, "schedule": schedule, "usage_streak": usage_streak,
		"last_contract_day": last_contract_day, "remessa_cut": remessa_cut, "stats": stats}

func from_dict(saved: Dictionary) -> void:
	reset()
	quiet = int(saved.get("quiet", 0))
	var seen: Dictionary = GameManager.as_dict(saved.get("last_seen"))
	for key: String in seen:
		last_seen[key] = int(seen[key])
	for item_v: Variant in GameManager.as_list(saved.get("schedule")):
		if typeof(item_v) == TYPE_DICTIONARY and (item_v as Dictionary).has("id"):
			schedule.append({"at": int(item_v.get("at", 0)), "id": str(item_v["id"]), "data": GameManager.as_dict(item_v.get("data"))})
	var streak: Dictionary = GameManager.as_dict(saved.get("usage_streak"))
	for key: String in streak:
		usage_streak[key] = int(streak[key])
	last_contract_day = int(saved.get("last_contract_day", GameManager.day_total))
	remessa_cut = int(saved.get("remessa_cut", 0))
	var saved_stats: Dictionary = GameManager.as_dict(saved.get("stats"))
	for key: String in saved_stats:
		stats[key] = int(saved_stats[key])
