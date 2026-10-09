extends Node
## GameManager — estado central e regras do dia a dia.
##
## Guarda dinheiro, suspeita, empresas e o relógio, e executa a virada do dia.
## Os outros sistemas são autoloads próprios e conversam com este:
##   Campaign   atos, metas, ameaças, Operação Fuga e finais
##   Staff      laranjas e delação premiada
##   Lifestyle  bens, prestígio e malha fina
##   Portfolio  cripto, fundos e Monero
## Os números vêm todos de res://scripts/data/balance.gd.

const B = preload("res://scripts/data/balance.gd")

signal state_changed(state: int)
signal stats_changed
signal day_changed(day: int)

const SAVE_PATH: String = "user://clean_slate_save.json"
const SAVE_VERSION: int = 2
const MAX_TRANSACTIONS: int = 300
const MAX_NEWS: int = 60

enum GameState { MENU, TUTORIAL, WORK, DAY_TRANSITION, ENDED }

var state: int = GameState.MENU
var current_day: int = 1            # dia dentro do ato atual
var total_days: int = 30            # prazo do ato (já com prorrogação, se houver)
var day_total: int = 1              # dias desde o começo da campanha
var current_time_minutes: int = B.WORK_START_MINUTES
var dirty_money: float = B.START_DIRTY
var clean_money: float = B.START_CLEAN
var suspicion: float = B.START_SUSPICION
var max_suspicion: float = B.MAX_SUSPICION
var tutorial_completed: bool = false
var total_processed: float = 0.0
var total_clean_generated: float = 0.0
var transactions: Array = []
var news_log: Array = []
var selected_company: String = ""
var muted: bool = false
var volume: float = 0.7

## Estado de cada empresa: os dados do balanceamento mais
##   owned (é sua?), used (quanto já processou hoje), blocked (dias parada).
var companies: Dictionary = {}
## Efeitos temporários de notícias: {target, stat, value, days, label}.
var modifiers: Array = []
## Dias de espera de cada ação de risco: {id: dias}.
var cooldowns: Dictionary = {}
var influence: int = 0
var wiretap_days: int = 0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _batch: int = 0                 # > 0 enquanto várias mudanças são agrupadas
var _stats_pending: bool = false
var _today: Dictionary = {}         # acumuladores do dia (viram o fechamento)

func _ready() -> void:
	rng.randomize()
	_build_companies()
	_reset_today()
	set_state(GameState.MENU)

func _build_companies() -> void:
	companies = {}
	for company_id: String in B.COMPANY_ORDER:
		var data: Dictionary = (B.COMPANIES[company_id] as Dictionary).duplicate(true)
		data["owned"] = float(data["price"]) <= 0.0
		data["used"] = 0.0
		data["blocked"] = 0
		companies[company_id] = data

func _reset_today() -> void:
	_today = {"processed": 0.0, "clean": 0.0, "fees": 0.0, "operations": 0, "suspicion_start": suspicion}

func set_state(new_state: int) -> void:
	state = new_state
	state_changed.emit(state)

## Agrupa várias mudanças em um único stats_changed (a interface refaz a tela
## a cada sinal, então emitir dez vezes seguidas seria desperdício).
func begin_batch() -> void:
	_batch += 1

func end_batch() -> void:
	_batch = maxi(0, _batch - 1)
	if _batch == 0 and _stats_pending:
		_stats_pending = false
		stats_changed.emit()

func touch() -> void:
	if _batch > 0:
		_stats_pending = true
	else:
		stats_changed.emit()

# ---------------------------------------------------------
# Campanha
# ---------------------------------------------------------

func new_game() -> void:
	begin_batch()
	current_day = 1
	day_total = 1
	current_time_minutes = B.WORK_START_MINUTES
	dirty_money = B.START_DIRTY
	clean_money = B.START_CLEAN
	suspicion = B.START_SUSPICION
	tutorial_completed = false
	total_processed = 0.0
	total_clean_generated = 0.0
	transactions.clear()
	news_log.clear()
	modifiers.clear()
	cooldowns.clear()
	influence = 0
	wiretap_days = 0
	selected_company = ""
	_build_companies()
	Campaign.reset()
	Staff.reset()
	Lifestyle.reset()
	Portfolio.reset()
	total_days = Campaign.days()
	_reset_today()
	set_state(GameState.TUTORIAL)
	end_batch()
	stats_changed.emit()
	day_changed.emit(current_day)

func begin_work() -> void:
	tutorial_completed = true
	set_state(GameState.WORK)
	current_time_minutes = B.WORK_START_MINUTES
	stats_changed.emit()

## Encerra o dia: roda a noite inteira (folha, rendimentos, remessa, ameaças,
## metas) e devolve o fechamento para a tela de troca de turno.
## O jogo fica em DAY_TRANSITION até begin_day().
func end_day() -> Dictionary:
	if state != GameState.WORK:
		return {}
	set_state(GameState.DAY_TRANSITION)
	begin_batch()
	var report: Dictionary = {
		"act": Campaign.act,
		"day": current_day,
		"processed": float(_today["processed"]),
		"clean": float(_today["clean"]),
		"fees": float(_today["fees"]),
		"operations": int(_today["operations"]),
		"suspicion_start": float(_today["suspicion_start"]),
		"suspicion_day": suspicion
	}

	# 1. Laranjas: folha, estresse e delações.
	var staff_report: Dictionary = Staff.daily_tick()
	report["wages"] = float(staff_report.get("wages", 0.0))
	report["unpaid"] = int(staff_report.get("unpaid", 0))
	# 2. Carteira: preço da cripto e rendimento dos fundos.
	report["yield"] = Portfolio.daily_tick()
	# 3. Malha fina.
	Lifestyle.daily_tick()

	# 4. Prazos: notícias, esperas das ações, empresas paradas, grampo.
	for i: int in range(modifiers.size() - 1, -1, -1):
		var mod: Dictionary = modifiers[i]
		mod["days"] = int(mod["days"]) - 1
		if int(mod["days"]) <= 0:
			modifiers.remove_at(i)
	for action_id: String in cooldowns.keys():
		cooldowns[action_id] = maxi(0, int(cooldowns[action_id]) - 1)
	for company_id: String in companies:
		var company: Dictionary = companies[company_id]
		company["used"] = 0.0
		company["blocked"] = maxi(0, int(company["blocked"]) - 1)
	wiretap_days = maxi(0, wiretap_days - 1)

	# 5. Remessa do cliente e dinheiro parado.
	var remessa: float = Campaign.remessa()
	dirty_money += remessa
	report["remessa"] = remessa
	var pile: bool = remessa > 0.0 and dirty_money > remessa * (B.PILE_DAYS + 1.0)
	if pile:
		suspicion += B.PILE_PENALTY
	report["pile"] = pile

	# 6. A suspeita esfria durante a noite.
	var decay: float = Campaign.decay()
	suspicion = clampf(suspicion - decay, 0.0, max_suspicion)
	report["decay"] = decay

	# 7. Campanha: ameaças do ato, notícias, mandado, meta e prazo. Avança o dia.
	Campaign.daily_tick()

	report["suspicion_end"] = suspicion
	report["net_worth"] = net_worth()
	report["goal"] = Campaign.goal()
	report["next_day"] = current_day
	report["next_act"] = Campaign.act
	current_time_minutes = B.WORK_START_MINUTES
	_reset_today()
	end_batch()
	return report

## Abre o dia seguinte, depois da animação de troca de turno.
func begin_day() -> void:
	if state != GameState.DAY_TRANSITION:
		return
	if Campaign.ending != "":
		set_state(GameState.ENDED)
		return
	set_state(GameState.WORK)
	day_changed.emit(current_day)
	stats_changed.emit()

# ---------------------------------------------------------
# Empresas
# ---------------------------------------------------------

func _modifier_sum(company_id: String, stat: String) -> float:
	var total: float = 0.0
	for mod_v: Variant in modifiers:
		var mod: Dictionary = mod_v as Dictionary
		if str(mod["stat"]) == stat and (str(mod["target"]) == "*" or str(mod["target"]) == company_id):
			total += float(mod["value"])
	return total

## Capacidade do dia: base + laranjas, ajustada pelas notícias.
func capacity_of(company_id: String) -> float:
	var company: Dictionary = companies[company_id]
	var base: float = float(company["capacity"]) + Staff.capacity_bonus(company_id)
	return maxf(0.0, base * (1.0 + _modifier_sum(company_id, "capacity")))

func remaining_capacity(company_id: String) -> float:
	var company: Dictionary = companies[company_id]
	if int(company["blocked"]) > 0:
		return 0.0
	return maxf(0.0, capacity_of(company_id) - float(company["used"]))

## Custo da operação: base - desconto de prestígio + notícias.
func loss_of(company_id: String) -> float:
	var company: Dictionary = companies[company_id]
	return clampf(float(company["loss"]) - Lifestyle.loss_discount() + _modifier_sum(company_id, "loss"), 0.02, 0.60)

## Suspeita gerada ao usar 100% da capacidade do dia.
func risk_of(company_id: String) -> float:
	var company: Dictionary = companies[company_id]
	var risk: float = float(company["risk"]) * maxf(0.2, 1.0 + _modifier_sum(company_id, "risk"))
	if wiretap_days > 0:
		risk *= 1.0 + B.WIRETAP_RISK
	return risk

func owns(company_id: String) -> bool:
	return companies.has(company_id) and bool(companies[company_id]["owned"])

func owned_ids() -> Array:
	var ids: Array = []
	for company_id: String in B.COMPANY_ORDER:
		if owns(company_id):
			ids.append(company_id)
	return ids

## "owned", "sale" (à venda), "prestige" (falta prestígio) ou "act" (ato futuro).
func company_status(company_id: String) -> String:
	var company: Dictionary = companies[company_id]
	if bool(company["owned"]):
		return "owned"
	if int(company["act"]) > Campaign.act:
		return "act"
	if Lifestyle.prestige_tier() < int(company["prestige"]):
		return "prestige"
	return "sale"

func buy_company(company_id: String) -> Dictionary:
	if state != GameState.WORK or Campaign.escape_active:
		return {"ok": false, "message": "A compra não está disponível agora."}
	var status: String = company_status(company_id)
	if status != "sale":
		return {"ok": false, "message": "Esta empresa ainda não está à venda para você."}
	var company: Dictionary = companies[company_id]
	var price: float = float(company["price"])
	if price > clean_money:
		return {"ok": false, "message": "Saldo limpo insuficiente."}
	clean_money -= price
	company["owned"] = true
	_advance_clock(40)
	touch()
	return {"ok": true, "message": "%s agora é sua." % str(company["name"])}

func companies_value() -> float:
	var total: float = 0.0
	for company_id: String in companies:
		if bool(companies[company_id]["owned"]):
			total += float(companies[company_id]["value"])
	return total

func process_company(company_id: String, amount: float) -> Dictionary:
	if state != GameState.WORK:
		return {"ok": false, "message": "A operação não está disponível agora."}
	if Campaign.escape_active:
		return {"ok": false, "message": "Durante a fuga, as empresas só podem ser liquidadas."}
	if not owns(company_id):
		return {"ok": false, "message": "Empresa inválida."}
	var company: Dictionary = companies[company_id]
	if int(company["blocked"]) > 0:
		return {"ok": false, "message": "Empresa parada por mais %d dia(s)." % int(company["blocked"])}
	amount = minf(amount, remaining_capacity(company_id))
	if amount < B.MIN_OPERATION:
		return {"ok": false, "message": "A capacidade de hoje desta empresa acabou."}
	if amount > dirty_money:
		return {"ok": false, "message": "Saldo sujo insuficiente."}

	var capacity: float = capacity_of(company_id)
	var fee: float = amount * loss_of(company_id)
	var clean_generated: float = amount - fee
	var risk: float = risk_of(company_id) * amount / maxf(capacity, 1.0)
	begin_batch()
	dirty_money -= amount
	clean_money += clean_generated
	company["used"] = float(company["used"]) + amount
	total_processed += amount
	total_clean_generated += clean_generated
	_today["processed"] = float(_today["processed"]) + amount
	_today["clean"] = float(_today["clean"]) + clean_generated
	_today["fees"] = float(_today["fees"]) + fee
	_today["operations"] = int(_today["operations"]) + 1
	_advance_clock(22)
	var tx: Dictionary = {
		"day": day_total,
		"time": format_time(current_time_minutes),
		"company": str(company["name"]),
		"amount": amount,
		"fee": fee,
		"clean": clean_generated,
		"risk": risk
	}
	transactions.push_front(tx)
	if transactions.size() > MAX_TRANSACTIONS:
		transactions.resize(MAX_TRANSACTIONS)
	add_suspicion(risk)
	touch()
	end_batch()
	return {"ok": true, "message": "Operação registrada.", "transaction": tx}

## Operações feitas hoje (para a interface).
func operations_today() -> int:
	return int(_today.get("operations", 0))

# ---------------------------------------------------------
# Dinheiro, suspeita e risco
# ---------------------------------------------------------

func spend_clean(amount: float) -> bool:
	if amount > clean_money + 0.01:
		return false
	clean_money = maxf(0.0, clean_money - amount)
	touch()
	return true

## Ponto único por onde a suspeita sobe ou desce durante o dia.
## É aqui que os limites do ato são conferidos.
func add_suspicion(delta: float) -> void:
	suspicion = clampf(suspicion + delta, 0.0, max_suspicion)
	touch()
	Campaign.check_limits()

func action_cost(action: Dictionary) -> float:
	return float(action["cost"]) * Campaign.scale()

func action_cooldown(action_id: String) -> int:
	return int(cooldowns.get(action_id, 0))

func reduce_risk(action_id: String) -> Dictionary:
	if state != GameState.WORK:
		return {"ok": false, "message": "Ação indisponível agora."}
	var action: Dictionary = B.risk_action(action_id)
	if action.is_empty() or int(action["act"]) > Campaign.act:
		return {"ok": false, "message": "Ação indisponível neste ato."}
	if action_cooldown(action_id) > 0:
		return {"ok": false, "message": "Disponível de novo em %d dia(s)." % action_cooldown(action_id)}
	if bool(action.get("clears_wiretap", false)) and wiretap_days <= 0:
		return {"ok": false, "message": "Não há grampo ativo."}
	var cost: float = action_cost(action)
	if cost > clean_money:
		return {"ok": false, "message": "Saldo limpo insuficiente."}
	begin_batch()
	clean_money -= cost
	cooldowns[action_id] = int(action["cooldown"])
	if bool(action.get("clears_wiretap", false)):
		wiretap_days = 0
	influence = mini(B.INFLUENCE_MAX, influence + int(action.get("influence", 0)))
	_advance_clock(14)
	add_suspicion(-float(action["reduce"]))
	end_batch()
	return {"ok": true, "message": "%s concluída." % str(action["name"])}

func _advance_clock(minutes: int) -> void:
	current_time_minutes = clampi(current_time_minutes + minutes, 0, 23 * 60 + 59)

## Patrimônio: é isto que conta para a meta de cada ato.
func net_worth() -> float:
	return clean_money + companies_value() + Lifestyle.goods_value() + Portfolio.total_value()

# ---------------------------------------------------------
# Notícias
# ---------------------------------------------------------

func add_news(tag: String, title: String, body: String, effect: String = "") -> void:
	news_log.push_front({"day": day_total, "act": Campaign.act, "tag": tag, "title": title, "body": body, "effect": effect})
	if news_log.size() > MAX_NEWS:
		news_log.resize(MAX_NEWS)
	touch()

## Aplica uma notícia de ambiente do balanceamento e registra na central.
func apply_news(item: Dictionary) -> void:
	var stat: String = str(item["stat"])
	if stat == "suspicion":
		suspicion = clampf(suspicion + float(item["value"]), 0.0, max_suspicion)
	else:
		modifiers.append({"target": str(item["target"]), "stat": stat, "value": float(item["value"]), "days": int(item["days"]), "label": str(item["effect"])})
	add_news(str(item["tag"]), str(item["title"]), str(item["body"]), str(item["effect"]))

# ---------------------------------------------------------
# Formatação
# ---------------------------------------------------------

func format_money(value: float) -> String:
	var negative: bool = value < -0.5
	var raw: String = str(absi(int(round(value))))
	var groups: Array[String] = []
	while raw.length() > 3:
		groups.push_front(raw.substr(raw.length() - 3, 3))
		raw = raw.substr(0, raw.length() - 3)
	groups.push_front(raw)
	return "%sR$ %s" % ["-" if negative else "", ".".join(groups)]

func format_time(total_minutes: int) -> String:
	@warning_ignore("integer_division")
	var hours: int = (total_minutes / 60) % 24
	return "%02d:%02d" % [hours, total_minutes % 60]

# ---------------------------------------------------------
# Save / load
# ---------------------------------------------------------
# Um único arquivo JSON, com versão. Cada sistema salva e carrega o próprio
# estado em to_dict() / from_dict(). Saves da versão 1 (antes da expansão)
# carregam o que existia e começam o resto no Ato 1.

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game() -> bool:
	if state != GameState.WORK:
		return false
	var company_state: Dictionary = {}
	for company_id: String in companies:
		var company: Dictionary = companies[company_id]
		company_state[company_id] = {"owned": company["owned"], "used": company["used"], "blocked": company["blocked"]}
	var data: Dictionary = {
		"version": SAVE_VERSION,
		"core": {
			"day": current_day, "total_days": total_days, "day_total": day_total,
			"time": current_time_minutes, "dirty": dirty_money, "clean": clean_money,
			"suspicion": suspicion, "tutorial_completed": tutorial_completed,
			"total_processed": total_processed, "total_clean_generated": total_clean_generated,
			"transactions": transactions, "news_log": news_log, "companies": company_state,
			"modifiers": modifiers, "cooldowns": cooldowns, "influence": influence,
			"wiretap_days": wiretap_days, "today": _today
		},
		"campaign": Campaign.to_dict(),
		"staff": Staff.to_dict(),
		"lifestyle": Lifestyle.to_dict(),
		"portfolio": Portfolio.to_dict()
	}
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	return true

## Leitura tolerante de um save: se o valor não for do tipo esperado (arquivo
## editado à mão ou de outra versão), devolve o padrão em vez de gerar erro.
func as_list(value: Variant, fallback: Array = []) -> Array:
	return value if typeof(value) == TYPE_ARRAY else fallback

func as_dict(value: Variant, fallback: Dictionary = {}) -> Dictionary:
	return value if typeof(value) == TYPE_DICTIONARY else fallback

func load_game() -> bool:
	if not has_save():
		return false
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var data: Dictionary = parsed
	# Versão 1: os campos ficavam soltos na raiz do arquivo.
	var core: Dictionary = as_dict(data.get("core"), data)

	begin_batch()
	_build_companies()
	Campaign.reset()
	Staff.reset()
	Lifestyle.reset()
	Portfolio.reset()
	current_day = int(core.get("day", 1))
	day_total = int(core.get("day_total", current_day))
	current_time_minutes = int(core.get("time", B.WORK_START_MINUTES))
	dirty_money = float(core.get("dirty", B.START_DIRTY))
	clean_money = float(core.get("clean", B.START_CLEAN))
	suspicion = float(core.get("suspicion", B.START_SUSPICION))
	tutorial_completed = bool(core.get("tutorial_completed", false))
	total_processed = float(core.get("total_processed", 0.0))
	total_clean_generated = float(core.get("total_clean_generated", 0.0))
	# O JSON devolve arrays sem tipo: copiar item a item evita erro de tipo.
	transactions = []
	for tx_v: Variant in as_list(core.get("transactions")):
		if typeof(tx_v) == TYPE_DICTIONARY:
			transactions.append(tx_v)
	news_log = []
	for news_v: Variant in as_list(core.get("news_log")):
		if typeof(news_v) == TYPE_DICTIONARY:
			news_log.append(news_v)
	var company_state: Dictionary = as_dict(core.get("companies"))
	for company_id: String in company_state:
		if companies.has(company_id):
			var saved: Dictionary = as_dict(company_state[company_id])
			companies[company_id]["owned"] = bool(saved.get("owned", false))
			companies[company_id]["used"] = float(saved.get("used", 0.0))
			companies[company_id]["blocked"] = int(saved.get("blocked", 0))
	modifiers = []
	for mod_v: Variant in as_list(core.get("modifiers")):
		if typeof(mod_v) == TYPE_DICTIONARY:
			modifiers.append(mod_v)
	cooldowns = {}
	var saved_cooldowns: Dictionary = as_dict(core.get("cooldowns"))
	for action_id: String in saved_cooldowns:
		cooldowns[action_id] = int(saved_cooldowns[action_id])
	influence = int(core.get("influence", 0))
	wiretap_days = int(core.get("wiretap_days", 0))

	Campaign.from_dict(as_dict(data.get("campaign")))
	Staff.from_dict(as_dict(data.get("staff")))
	Lifestyle.from_dict(as_dict(data.get("lifestyle")))
	Portfolio.from_dict(as_dict(data.get("portfolio")))
	total_days = int(core.get("total_days", Campaign.days()))
	if int(data.get("version", 1)) < 2:
		total_days = Campaign.days()
		current_day = clampi(current_day, 1, total_days)
	_reset_today()
	var today: Dictionary = as_dict(core.get("today"))
	for key: String in today:
		if key == "operations":
			_today[key] = int(today[key])
		else:
			_today[key] = float(today[key])
	# Só existe save feito durante um dia de trabalho: a campanha volta nele.
	tutorial_completed = true
	set_state(GameState.WORK)
	end_batch()
	stats_changed.emit()
	day_changed.emit(current_day)
	return true
