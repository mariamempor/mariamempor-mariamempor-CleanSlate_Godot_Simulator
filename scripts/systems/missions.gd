extends Node
## Missions — objetivos do ato e contratos do cliente.
##
## Objetivos: sorteados no começo de cada ato (ver missions_data.gd). O
## progresso é lido do estado do jogo sempre que possível (laranjas, empresas,
## prestígio, fundos...), para não existir uma segunda cópia desses números.
## Só o que não existe em outro lugar vira contador aqui: operações e volume do
## ato, ameaças resolvidas, sequências de turnos calmos, etapas de preparação.
##
## Contratos: oferecidos pelo Director de tempos em tempos. "offered" (o jogador
## pode aceitar na aba Missões ou no popup), "active", "done", "failed" ou
## "expired".
##
## Vantagens (perks) conquistadas valem até o fim da campanha e são lidas pelos
## outros sistemas com Missions.perk(id).

const B = preload("res://scripts/data/balance.gd")
const M = preload("res://scripts/data/missions_data.gd")

signal completed(title: String, reward_text: String)

var act: int = 0                     # ato a que os objetivos atuais pertencem
var objectives: Array = []           # [{id, state: "active"|"done"}]
var contracts: Array = []            # contratos desta campanha (os mais recentes primeiro)
var counters: Dictionary = {}        # contadores do ato atual
var perks: Dictionary = {}           # vantagens permanentes {id: valor}
var perfect_acts: int = 0
var unlocked: Array = []             # empresas liberadas antes do ato
var night_log: Array = []            # concluídos/falhos desde o último fechamento
var action_used_day: int = -1        # dia (day_total) da última etapa de preparação
var _next_contract: int = 1
var _checking: bool = false

func _ready() -> void:
	GameManager.stats_changed.connect(_on_stats_changed)

func reset() -> void:
	act = 0
	objectives = []
	contracts = []
	counters = {}
	perks = {}
	perfect_acts = 0
	unlocked = []
	night_log = []
	action_used_day = -1
	_next_contract = 1

# ---------------------------------------------------------
# Consultas
# ---------------------------------------------------------

func perk(perk_id: String) -> float:
	return float(perks.get(perk_id, 0.0))

func is_unlocked(company_id: String) -> bool:
	return unlocked.has(company_id)

func data(mission_id: String) -> Dictionary:
	for item_v: Variant in M.CATALOG:
		if str((item_v as Dictionary)["id"]) == mission_id:
			return item_v
	return {}

func counter(key: String) -> float:
	return float(counters.get(key, 0.0))

func objectives_done() -> int:
	var done: int = 0
	for obj_v: Variant in objectives:
		if str((obj_v as Dictionary)["state"]) == "done":
			done += 1
	return done

func offered_contracts() -> Array:
	return contracts.filter(func(c: Variant) -> bool: return str((c as Dictionary)["state"]) == "offered")

func active_contracts() -> Array:
	return contracts.filter(func(c: Variant) -> bool: return str((c as Dictionary)["state"]) == "active")

## Valor atual de uma métrica. O que existe em outro sistema é lido de lá.
func metric_value(metric: String, param: Variant = null) -> float:
	match metric:
		"ops", "laundered", "care", "prep", "donation":
			return counter(metric)
		"staff":
			return float(Staff.roster.size())
		"staff_tier":
			var n: int = 0
			for member_v: Variant in Staff.roster:
				if int((member_v as Dictionary)["tier"]) >= int(param):
					n += 1
			return float(n)
		"companies":
			return float(GameManager.owned_ids().size())
		"owns":
			return 1.0 if GameManager.owns(str(param)) else 0.0
		"prestige":
			return float(Lifestyle.prestige())
		"influence":
			return float(GameManager.influence)
		"declared":
			return Lifestyle.declared_income
		"funds":
			return Portfolio.funds_value()
		"offshore":
			return Portfolio.fund_balance("offshore")
		"crypto":
			return Portfolio.crypto_value()
		"threats":
			return counter("threat:" + str(param))
		"calm_streak":
			return counter("calm:%d" % int(param))
	return 0.0

func progress_of(mission: Dictionary) -> float:
	return metric_value(str(mission["metric"]), mission.get("param", null))

## Texto do objetivo com os números preenchidos.
func describe(mission: Dictionary) -> String:
	var text: String = str(mission["text"])
	text = text.replace("{target_money}", GameManager.format_money(float(mission["target"])))
	text = text.replace("{target}", "%d" % int(mission["target"]))
	if mission.has("param"):
		var param: Variant = mission["param"]
		text = text.replace("{param}", str(int(param)) if typeof(param) == TYPE_FLOAT else str(param))
	return text

func reward_text(reward: Dictionary) -> String:
	var parts: Array[String] = []
	if float(reward.get("clean", 0.0)) > 0.0:
		parts.append(GameManager.format_money(float(reward["clean"])))
	if int(reward.get("prestige", 0)) != 0:
		parts.append("%+d prestígio" % int(reward["prestige"]))
	if int(reward.get("influence", 0)) != 0:
		parts.append("%+d influência" % int(reward["influence"]))
	if float(reward.get("suspicion", 0.0)) != 0.0:
		parts.append("suspeita %+d" % int(reward["suspicion"]))
	if bool(reward.get("candidate", false)):
		parts.append("candidato de elite")
	if reward.has("unlock"):
		var company: Dictionary = B.COMPANIES.get(str(reward["unlock"]), {})
		parts.append("%s liberada com 25%% de desconto" % str(company.get("name", "empresa")))
	if reward.has("perk"):
		parts.append(perk_text(reward["perk"]))
	return "  /  ".join(parts)

func perk_text(p: Dictionary) -> String:
	var value: float = float(p.get("value", 0.0))
	match str(p.get("id", "")):
		"loss_discount":
			return "custo das empresas -%s pt" % str(snappedf(value * 100.0, 0.1)).replace(".", ",")
		"staff_cost":
			return "diárias da rede -%d%%" % int(round(value * 100.0))
		"yield":
			return "fundos +%s%% por turno" % str(snappedf(value * 100.0, 0.1)).replace(".", ",")
		"interception":
			return "interceptação na fuga -%d pts" % int(value)
		"monero_fee":
			return "taxa do Monero -%d pts" % int(round(value * 100.0))
		"escape":
			return "passaporte e avião pela metade, interceptação -8"
	return ""

# ---------------------------------------------------------
# Ganchos chamados pelos outros sistemas
# ---------------------------------------------------------

func note(key: String, amount: float = 1.0) -> void:
	counters[key] = counter(key) + amount
	if key == "donation":
		_bump_contracts("donation", amount)

func on_operation(company_id: String, amount: float) -> void:
	note("ops")
	note("laundered", amount)
	note("laundered:" + company_id, amount)
	_bump_contracts("laundered", amount)
	_bump_contracts("company:" + company_id, amount)

## Ameaça resolvida sem ignorar. Os tipos viram grupos usados pelos objetivos.
func note_threat(kind: String) -> void:
	note("threat:" + kind)
	match kind:
		"intimacao", "aliado":
			note("threat:pf")
		"interpol", "intl":
			if kind == "interpol":
				note("threat:intl")

# ---------------------------------------------------------
# Objetivos do ato
# ---------------------------------------------------------

## Sorteia os objetivos do ato (os fixos entram sempre).
func start_act(new_act: int) -> void:
	act = new_act
	counters = {}
	objectives = []
	var pinned: Array = []
	var pool: Array = []
	for item_v: Variant in M.CATALOG:
		var item: Dictionary = item_v
		if int(item["act"]) != new_act:
			continue
		if bool(item.get("pinned", false)):
			pinned.append(item)
		elif _eligible(item):
			pool.append(item)
	var rng: RandomNumberGenerator = GameManager.rng
	for i: int in range(pool.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap: Variant = pool[i]
		pool[i] = pool[j]
		pool[j] = swap
	for item_v: Variant in pinned + pool:
		if objectives.size() >= M.MISSIONS_PER_ACT:
			break
		objectives.append({"id": str((item_v as Dictionary)["id"]), "state": "active"})
	# Contratos que sobraram do ato anterior não fazem mais sentido.
	for c_v: Variant in contracts:
		var c: Dictionary = c_v
		if str(c["state"]) == "offered" or str(c["state"]) == "active":
			c["state"] = "expired"

## Um objetivo só entra no sorteio se fizer sentido agora.
func _eligible(item: Dictionary) -> bool:
	match str(item["metric"]):
		"owns":
			return not GameManager.owns(str(item["param"]))
		"prestige", "influence", "staff", "companies", "staff_tier", "funds", "offshore", "crypto", "declared":
			return progress_of(item) < float(item["target"]) * 0.8
	return true

func _on_stats_changed() -> void:
	if not _checking and GameManager.state == GameManager.GameState.WORK:
		check.call_deferred()

## Confere todos os objetivos e paga os que foram concluídos.
func check() -> void:
	if _checking or act == 0 or Campaign.ending != "":
		return
	_checking = true
	GameManager.begin_batch()
	for obj_v: Variant in objectives:
		var obj: Dictionary = obj_v
		if str(obj["state"]) != "active":
			continue
		var mission: Dictionary = data(str(obj["id"]))
		if mission.is_empty() or progress_of(mission) < float(mission["target"]):
			continue
		obj["state"] = "done"
		var reward: Dictionary = mission["reward"]
		_grant(reward)
		_log("done", str(mission["title"]), reward_text(reward))
	if not objectives.is_empty() and objectives_done() == objectives.size() and not bool(counters.get("perfect", false)):
		counters["perfect"] = true
		perfect_acts += 1
		_grant(M.PERFECT_BONUS)
		_log("done", "Ato impecável: todos os objetivos", reward_text(M.PERFECT_BONUS))
	GameManager.end_batch()
	_checking = false

func _log(kind: String, title: String, reward: String) -> void:
	night_log.append({"kind": kind, "title": title, "reward": reward})
	GameManager.add_news("OBJETIVO" if kind == "done" else "CONTRATO", ("Concluído: " if kind == "done" else "Falhou: ") + title, "", reward)
	if kind == "done":
		completed.emit(title, reward)

func _grant(reward: Dictionary) -> void:
	GameManager.clean_money += float(reward.get("clean", 0.0))
	Lifestyle.bonus_prestige += int(reward.get("prestige", 0))
	GameManager.influence = clampi(GameManager.influence + int(reward.get("influence", 0)), 0, B.INFLUENCE_MAX)
	if float(reward.get("suspicion", 0.0)) != 0.0:
		GameManager.add_suspicion(float(reward["suspicion"]))
	if bool(reward.get("candidate", false)):
		Staff.add_elite_candidate()
	if reward.has("unlock") and not unlocked.has(str(reward["unlock"])):
		unlocked.append(str(reward["unlock"]))
	if reward.has("perk"):
		var p: Dictionary = reward["perk"]
		perks[str(p["id"])] = perk(str(p["id"])) + float(p["value"])
		if str(p["id"]) == "staff_cost":
			Staff.apply_cost_cut(float(p["value"]))
	GameManager.touch()

## Botão de ação de um objetivo (ex.: financiar uma etapa da fuga).
func can_act(mission: Dictionary) -> String:
	if not mission.has("action"):
		return "Sem ação."
	if action_used_day == GameManager.day_total:
		return "Uma etapa por turno. Volte amanhã."
	if GameManager.clean_money < action_cost(mission):
		return "Saldo limpo insuficiente."
	return ""

func action_cost(mission: Dictionary) -> float:
	return float((mission["action"] as Dictionary)["cost"]) * Campaign.scale()

func run_action(mission_id: String) -> Dictionary:
	var mission: Dictionary = data(mission_id)
	var block: String = can_act(mission)
	if block != "":
		return {"ok": false, "message": block}
	GameManager.begin_batch()
	GameManager.clean_money -= action_cost(mission)
	action_used_day = GameManager.day_total
	note(str((mission["action"] as Dictionary)["metric"]))
	GameManager.touch()
	GameManager.end_batch()
	check()
	return {"ok": true, "message": "Etapa financiada: %d de %d." % [int(progress_of(mission)), int(mission["target"])]}

# ---------------------------------------------------------
# Contratos
# ---------------------------------------------------------

## Cria uma oferta de contrato adequada ao ato e ao estado. Devolve {} se não houver.
func make_offer() -> Dictionary:
	var pool: Array = []
	for template_v: Variant in M.CONTRACTS:
		var template: Dictionary = template_v
		if int(template["act"]) > Campaign.act:
			continue
		if str(template["metric"]) == "company":
			var wanted: String = str(template.get("company", ""))
			if wanted != "" and not GameManager.owns(wanted):
				continue
		pool.append(template)
	if pool.is_empty():
		return {}
	var rng: RandomNumberGenerator = GameManager.rng
	var t: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
	var remessa: float = float(B.act_data(Campaign.act)["remessa"])
	var offer: Dictionary = {
		"uid": _next_contract, "id": str(t["id"]), "title": str(t["title"]), "metric": str(t["metric"]),
		"turns": int(t["turns"]), "state": "offered", "progress": 0.0,
		"offered_until": GameManager.day_total + B.CONTRACT_OFFER_DAYS, "deadline": 0,
		"param": float(t.get("param", 0.0)), "company": ""
	}
	_next_contract += 1
	var target: float = float(t.get("target", 0.0))
	if t.has("size"):
		target = snappedf(remessa * float(t["size"]), 1000.0)
	if str(t["metric"]) == "company":
		var company_id: String = str(t.get("company", ""))
		if company_id == "":
			var owned: Array = GameManager.owned_ids()
			company_id = str(owned[rng.randi_range(0, owned.size() - 1)])
			target = snappedf(minf(target, GameManager.capacity_of(company_id) * float(t["turns"]) * 0.8), 1000.0)
		offer["company"] = company_id
	offer["target"] = target
	var reward: Dictionary = {"clean": snappedf(remessa * float(t.get("reward_share", 0.0)) * (1.0 + float(t["turns"]) * 0.25), 1000.0)}
	if t.has("reward_prestige"):
		reward["prestige"] = int(t["reward_prestige"])
	if t.has("reward_suspicion"):
		reward["suspicion"] = float(t["reward_suspicion"])
	if t.has("reward_influence"):
		reward["influence"] = int(t["reward_influence"])
	offer["reward"] = reward
	var penalty: Dictionary = (t["penalty"] as Dictionary).duplicate()
	if penalty.has("clean_share"):
		penalty["clean"] = snappedf(remessa * float(penalty["clean_share"]) * 4.0, 1000.0)
		penalty.erase("clean_share")
	offer["penalty"] = penalty
	var text: String = str(t["text"])
	text = text.replace("{target_money}", GameManager.format_money(target)).replace("{target}", "%d" % int(target))
	text = text.replace("{turns}", "%d" % int(t["turns"])).replace("{param}", "%d" % int(offer["param"]))
	if offer["company"] != "":
		text = text.replace("{company}", str(GameManager.companies[str(offer["company"])]["name"]))
	offer["text"] = text
	contracts.push_front(offer)
	if contracts.size() > 20:
		contracts.resize(20)
	return offer

func find_contract(uid: int) -> Dictionary:
	for c_v: Variant in contracts:
		if int((c_v as Dictionary)["uid"]) == uid:
			return c_v
	return {}

func accept_contract(uid: int) -> Dictionary:
	var c: Dictionary = find_contract(uid)
	if c.is_empty() or str(c["state"]) != "offered":
		return {"ok": false, "message": "Contrato indisponível."}
	if not active_contracts().is_empty():
		return {"ok": false, "message": "Termine o contrato em andamento antes de aceitar outro."}
	c["state"] = "active"
	c["progress"] = 0.0
	# Último turno que conta: aceitar no turno D com prazo de 2 turnos vale D e D+1.
	c["deadline"] = GameManager.day_total + int(c["turns"]) - 1
	GameManager.touch()
	return {"ok": true, "message": "Contrato aceito: %s." % str(c["title"])}

func decline_contract(uid: int) -> Dictionary:
	var c: Dictionary = find_contract(uid)
	if c.is_empty() or str(c["state"]) != "offered":
		return {"ok": false, "message": "Contrato indisponível."}
	c["state"] = "expired"
	GameManager.touch()
	return {"ok": true, "message": "Contrato recusado."}

func _bump_contracts(metric: String, amount: float) -> void:
	for c_v: Variant in active_contracts():
		var c: Dictionary = c_v
		var key: String = str(c["metric"])
		if key == "company":
			key = "company:" + str(c["company"])
		if key == metric:
			c["progress"] = float(c["progress"]) + amount
			if float(c["progress"]) >= float(c["target"]):
				_finish_contract(c, true)

func _finish_contract(c: Dictionary, success: bool) -> void:
	c["state"] = "done" if success else "failed"
	if success:
		note("contracts")
		_grant(c["reward"])
		_log("done", "Contrato: " + str(c["title"]), reward_text(c["reward"]))
	else:
		var p: Dictionary = c["penalty"]
		GameManager.clean_money = maxf(0.0, GameManager.clean_money - float(p.get("clean", 0.0)))
		Lifestyle.bonus_prestige += int(p.get("prestige", 0))
		GameManager.influence = clampi(GameManager.influence + int(p.get("influence", 0)), 0, B.INFLUENCE_MAX)
		if float(p.get("suspicion", 0.0)) != 0.0:
			GameManager.add_suspicion(float(p["suspicion"]))
		_log("failed", str(c["title"]), reward_text(p))

# ---------------------------------------------------------
# Fechamento do turno
# ---------------------------------------------------------

## Chamado na virada do dia, antes da conferência da meta do ato.
## ops_today: operações feitas no turno que fechou.
func nightly(ops_today: int) -> void:
	if act == 0:
		start_act(Campaign.act)
	# Sequências de turnos calmos (cada limite usado por um objetivo ou contrato).
	var limits: Array = []
	for obj_v: Variant in objectives:
		var mission: Dictionary = data(str((obj_v as Dictionary)["id"]))
		if str(mission.get("metric", "")) == "calm_streak":
			limits.append(int(mission["param"]))
	for limit_v: Variant in limits:
		var key: String = "calm:%d" % int(limit_v)
		counters[key] = counter(key) + 1.0 if GameManager.suspicion < float(limit_v) else 0.0
	for c_v: Variant in active_contracts():
		var c: Dictionary = c_v
		match str(c["metric"]):
			"quiet":
				if ops_today == 0:
					c["progress"] = float(c["progress"]) + 1.0
			"calm":
				c["progress"] = float(c["progress"]) + 1.0 if GameManager.suspicion < float(c["param"]) else 0.0
		if float(c["progress"]) >= float(c["target"]):
			_finish_contract(c, true)
		elif GameManager.day_total >= int(c["deadline"]):
			_finish_contract(c, false)
	for c_v: Variant in offered_contracts():
		var c: Dictionary = c_v
		if GameManager.day_total >= int(c["offered_until"]):
			c["state"] = "expired"
	check()

## Entrega e limpa o que aconteceu desde o último fechamento (para o relatório).
func take_log() -> Array:
	var out: Array = night_log
	night_log = []
	return out

# ---------------------------------------------------------
# Save / load
# ---------------------------------------------------------

func to_dict() -> Dictionary:
	return {"act": act, "objectives": objectives, "contracts": contracts, "counters": counters,
		"perks": perks, "perfect_acts": perfect_acts, "unlocked": unlocked,
		"action_used_day": action_used_day, "next_contract": _next_contract}

func from_dict(saved: Dictionary) -> void:
	reset()
	act = int(saved.get("act", 0))
	for obj_v: Variant in GameManager.as_list(saved.get("objectives")):
		if typeof(obj_v) == TYPE_DICTIONARY and not data(str((obj_v as Dictionary).get("id", ""))).is_empty():
			objectives.append({"id": str(obj_v["id"]), "state": "done" if str(obj_v.get("state", "")) == "done" else "active"})
	# O JSON devolve todo número como float: os campos inteiros voltam a ser int.
	for c_v: Variant in GameManager.as_list(saved.get("contracts")):
		if typeof(c_v) == TYPE_DICTIONARY and (c_v as Dictionary).has("uid"):
			var c: Dictionary = (c_v as Dictionary).duplicate()
			for key: String in ["uid", "turns", "offered_until", "deadline"]:
				c[key] = int(c.get(key, 0))
			for key: String in ["progress", "target", "param"]:
				c[key] = float(c.get(key, 0.0))
			for key: String in ["reward", "penalty"]:
				var part: Dictionary = GameManager.as_dict(c.get(key)).duplicate()
				for field: String in ["prestige", "influence"]:
					if part.has(field):
						part[field] = int(part[field])
				c[key] = part
			contracts.append(c)
	var saved_counters: Dictionary = GameManager.as_dict(saved.get("counters"))
	for key: String in saved_counters:
		counters[key] = saved_counters[key] if typeof(saved_counters[key]) == TYPE_BOOL else float(saved_counters[key])
	var saved_perks: Dictionary = GameManager.as_dict(saved.get("perks"))
	for key: String in saved_perks:
		perks[key] = float(saved_perks[key])
	perfect_acts = int(saved.get("perfect_acts", 0))
	for company_v: Variant in GameManager.as_list(saved.get("unlocked")):
		if B.COMPANIES.has(str(company_v)):
			unlocked.append(str(company_v))
	action_used_day = int(saved.get("action_used_day", -1))
	_next_contract = int(saved.get("next_contract", contracts.size() + 1))
	# Save sem objetivos (versão anterior): sorteia os do ato atual.
	if objectives.is_empty() and Campaign.act >= 1:
		start_act(Campaign.act)
