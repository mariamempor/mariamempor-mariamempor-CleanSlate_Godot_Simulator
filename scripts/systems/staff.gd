extends Node
## Staff — laranjas, operadores e delação premiada.
##
## Cada laranja contratado soma capacidade à empresa em que trabalha e custa
## uma diária. Com a suspeita global acima de 50%, o estresse dele sobe a cada
## noite. Em 100, ele procura a Polícia Federal: o jogador tem duas noites
## para intervir (pagar silêncio, exilar ou descartar) antes de o acordo fechar.

const B = preload("res://scripts/data/balance.gd")

## Contratados: {id, name, tier, title, capacity, cost, loyalty, stress, company, delation}
## delation: -1 = normal; >= 0 = noites que faltam para o acordo fechar.
var roster: Array = []
## Candidatos do dia, no mesmo formato (company vazio).
var candidates: Array = []
var _next_id: int = 1

func reset() -> void:
	roster = []
	candidates = []
	_next_id = 1

# ---------------------------------------------------------
# Consultas
# ---------------------------------------------------------

func find(staff_id: int) -> Dictionary:
	for member_v: Variant in roster:
		var member: Dictionary = member_v as Dictionary
		if int(member["id"]) == staff_id:
			return member
	return {}

func members_of(company_id: String) -> Array:
	var out: Array = []
	for member_v: Variant in roster:
		var member: Dictionary = member_v as Dictionary
		if str(member["company"]) == company_id:
			out.append(member)
	return out

func slots_free(company_id: String) -> int:
	if not GameManager.companies.has(company_id):
		return 0
	return maxi(0, int(GameManager.companies[company_id]["slots"]) - members_of(company_id).size())

## Capacidade somada à empresa. Quem está delatando não trabalha.
func capacity_bonus(company_id: String) -> float:
	var total: float = 0.0
	for member_v: Variant in roster:
		var member: Dictionary = member_v as Dictionary
		if str(member["company"]) == company_id and int(member["delation"]) < 0:
			total += float(member["capacity"])
	return total

func daily_cost() -> float:
	var total: float = 0.0
	for member_v: Variant in roster:
		total += float((member_v as Dictionary)["cost"])
	return total

func delating() -> Array:
	var out: Array = []
	for member_v: Variant in roster:
		var member: Dictionary = member_v as Dictionary
		if int(member["delation"]) >= 0:
			out.append(member)
	return out

func hire_fee(candidate: Dictionary) -> float:
	return float(candidate["cost"]) * B.STAFF_HIRE_DAYS

func bonus_cost(member: Dictionary) -> float:
	return float(member["cost"]) * B.STAFF_BONUS_DAYS

func dismiss_cost(member: Dictionary) -> float:
	return float(member["cost"]) * B.STAFF_DISMISS_DAYS

func silence_cost(member: Dictionary) -> float:
	return float(member["cost"]) * B.DELATION_SILENCE_DAYS

func exile_cost(member: Dictionary) -> float:
	return float(member["cost"]) * B.DELATION_EXILE_DAYS

func discard_loss(member: Dictionary) -> float:
	return minf(GameManager.clean_money, float(member["capacity"]) * B.DELATION_DISCARD_LOSS)

## Quanto o estresse deste laranja muda na próxima noite, com a suspeita atual.
func stress_forecast(member: Dictionary) -> float:
	var suspicion: float = GameManager.suspicion
	if suspicion <= B.STAFF_STRESS_LEVEL:
		return -B.STAFF_STRESS_RELIEF
	return maxf(1.0, B.STAFF_STRESS_BASE + (suspicion - B.STAFF_STRESS_LEVEL) / 5.0 - float(member["loyalty"]) / 25.0)

# ---------------------------------------------------------
# Candidatos
# ---------------------------------------------------------

func ensure_candidates() -> void:
	if candidates.is_empty():
		refresh_candidates()

func refresh_candidates() -> void:
	candidates = []
	for i: int in range(B.STAFF_CANDIDATES):
		candidates.append(_make_candidate())

func _make_candidate() -> Dictionary:
	var rng: RandomNumberGenerator = GameManager.rng
	var act: int = Campaign.act
	# Na maior parte das vezes aparece gente do nível do ato atual.
	var tier_index: int = act - 1
	if act > 1 and rng.randf() > 0.7:
		tier_index = rng.randi_range(0, act - 2)
	var tier: Dictionary = B.STAFF_TIERS[tier_index]
	var capacity_range: Array = tier["capacity"]
	var cost_range: Array = tier["cost"]
	var quality: float = rng.randf()
	# Quem rende mais costuma cobrar mais, mas nem sempre: aí estão os bons negócios.
	var price_point: float = clampf(quality + rng.randf_range(-0.3, 0.3), 0.0, 1.0)
	var capacity: float = snappedf(lerpf(float(capacity_range[0]), float(capacity_range[1]), quality), 1000.0)
	var cost: float = snappedf(lerpf(float(cost_range[0]), float(cost_range[1]), price_point), 50.0)
	var first: String = str(B.STAFF_FIRST_NAMES[rng.randi_range(0, B.STAFF_FIRST_NAMES.size() - 1)])
	var last: String = str(B.STAFF_LAST_NAMES[rng.randi_range(0, B.STAFF_LAST_NAMES.size() - 1)])
	var candidate: Dictionary = {
		"id": _next_id,
		"name": "%s %s" % [first, last],
		"tier": int(tier["tier"]),
		"title": str(tier["title"]),
		"capacity": capacity,
		"cost": cost,
		"loyalty": float(rng.randi_range(35, 85)),
		"stress": float(rng.randi_range(0, 15)),
		"company": "",
		"delation": -1
	}
	_next_id += 1
	return candidate

# ---------------------------------------------------------
# Ações do jogador
# ---------------------------------------------------------

func hire(candidate_id: int, company_id: String) -> Dictionary:
	if GameManager.state != GameManager.GameState.WORK or Campaign.escape_active:
		return {"ok": false, "message": "Contratação indisponível agora."}
	if not GameManager.owns(company_id):
		return {"ok": false, "message": "Escolha uma empresa sua."}
	if slots_free(company_id) <= 0:
		return {"ok": false, "message": "Não há vaga nesta empresa."}
	for i: int in range(candidates.size()):
		var candidate: Dictionary = candidates[i]
		if int(candidate["id"]) != candidate_id:
			continue
		if not GameManager.spend_clean(hire_fee(candidate)):
			return {"ok": false, "message": "Saldo limpo insuficiente para a taxa de contratação."}
		candidate["company"] = company_id
		roster.append(candidate)
		candidates.remove_at(i)
		GameManager.touch()
		return {"ok": true, "message": "%s contratado." % str(candidate["name"])}
	return {"ok": false, "message": "Candidato indisponível."}

## Agrado: baixa o estresse e sobe um pouco a lealdade.
func give_bonus(staff_id: int) -> Dictionary:
	var member: Dictionary = find(staff_id)
	if member.is_empty() or int(member["delation"]) >= 0:
		return {"ok": false, "message": "Agrado indisponível."}
	if not GameManager.spend_clean(bonus_cost(member)):
		return {"ok": false, "message": "Saldo limpo insuficiente."}
	member["stress"] = maxf(0.0, float(member["stress"]) - B.STAFF_BONUS_STRESS)
	member["loyalty"] = minf(100.0, float(member["loyalty"]) + B.STAFF_BONUS_LOYALTY)
	GameManager.touch()
	return {"ok": true, "message": "%s ficou mais tranquilo." % str(member["name"])}

## Dispensa amigável, fora de delação.
func dismiss(staff_id: int) -> Dictionary:
	var member: Dictionary = find(staff_id)
	if member.is_empty() or int(member["delation"]) >= 0:
		return {"ok": false, "message": "Dispensa indisponível."}
	if not GameManager.spend_clean(dismiss_cost(member)):
		return {"ok": false, "message": "Saldo limpo insuficiente para o acerto."}
	roster.erase(member)
	GameManager.touch()
	return {"ok": true, "message": "%s dispensado." % str(member["name"])}

func add_stress_all(amount: float) -> void:
	for member_v: Variant in roster:
		var member: Dictionary = member_v as Dictionary
		if int(member["delation"]) < 0:
			member["stress"] = clampf(float(member["stress"]) + amount, 0.0, 99.0)

## Tira da folha todos os laranjas de uma empresa (venda na fuga).
func release_company(company_id: String) -> void:
	for member_v: Variant in members_of(company_id):
		roster.erase(member_v)

# ---------------------------------------------------------
# Delação premiada
# ---------------------------------------------------------

## choice: "silence_clean", "silence_dirty", "exile" ou "discard".
func resolve_delation(staff_id: int, choice: String) -> Dictionary:
	var member: Dictionary = find(staff_id)
	if member.is_empty() or int(member["delation"]) < 0:
		return {"ok": false, "message": "Não há delação em andamento."}
	var member_name: String = str(member["name"])
	GameManager.begin_batch()
	var result: Dictionary = {"ok": false, "message": "Opção inválida."}
	match choice:
		"silence_clean", "silence_dirty":
			var cost: float = silence_cost(member)
			var from_dirty: bool = choice == "silence_dirty"
			var available: float = GameManager.dirty_money if from_dirty else GameManager.clean_money
			if cost > available:
				result = {"ok": false, "message": "Saldo insuficiente para pagar o silêncio."}
			else:
				if from_dirty:
					GameManager.dirty_money -= cost
				else:
					GameManager.clean_money -= cost
				member["delation"] = -1
				member["stress"] = 30.0
				member["loyalty"] = minf(100.0, float(member["loyalty"]) + 25.0)
				result = {"ok": true, "message": "%s recuou da delação." % member_name}
		"exile":
			if not Portfolio.spend_crypto(exile_cost(member)):
				result = {"ok": false, "message": "Cripto insuficiente para o exílio."}
			else:
				roster.erase(member)
				result = {"ok": true, "message": "%s embarcou para o exterior." % member_name}
		"discard":
			var company_id: String = str(member["company"])
			GameManager.clean_money -= discard_loss(member)
			if GameManager.companies.has(company_id):
				GameManager.companies[company_id]["blocked"] = B.DELATION_DISCARD_BLOCK
			roster.erase(member)
			GameManager.add_suspicion(B.DELATION_DISCARD_SUSPICION)
			result = {"ok": true, "message": "%s foi descartado. A empresa fica parada por %d dias." % [member_name, B.DELATION_DISCARD_BLOCK]}
	GameManager.touch()
	GameManager.end_batch()
	return result

## Opções de intervenção, já com custo e se estão liberadas (popup e aba usam as mesmas).
func delation_options(member: Dictionary) -> Array:
	var staff_id: int = int(member["id"])
	var silence: float = silence_cost(member)
	var exile: float = exile_cost(member)
	var company_name: String = "a empresa"
	if GameManager.companies.has(str(member["company"])):
		company_name = str(GameManager.companies[str(member["company"])]["name"])
	return [
		{
			"label": "PAGAR SILÊNCIO (LIMPO)",
			"detail": "%s do saldo limpo. Ele volta ao trabalho, mais leal." % GameManager.format_money(silence),
			"enabled": GameManager.clean_money >= silence,
			"action": func() -> Dictionary: return resolve_delation(staff_id, "silence_clean")
		},
		{
			"label": "PAGAR SILÊNCIO (SUJO)",
			"detail": "%s do saldo sujo. Mesmo efeito, sem tocar no limpo." % GameManager.format_money(silence),
			"enabled": GameManager.dirty_money >= silence,
			"action": func() -> Dictionary: return resolve_delation(staff_id, "silence_dirty")
		},
		{
			"label": "EXILAR",
			"detail": "%s em cripto. Ele some do país e a vaga fica livre." % GameManager.format_money(exile),
			"enabled": Portfolio.crypto_value() >= exile,
			"action": func() -> Dictionary: return resolve_delation(staff_id, "exile")
		},
		{
			"label": "DESCARTAR",
			"detail": "Sem custo direto: perde %s retidos, %s para por %d dias e a suspeita sobe %d pontos." % [GameManager.format_money(discard_loss(member)), company_name, B.DELATION_DISCARD_BLOCK, int(B.DELATION_DISCARD_SUSPICION)],
			"enabled": true,
			"danger": true,
			"action": func() -> Dictionary: return resolve_delation(staff_id, "discard")
		}
	]

func _delation_event(member: Dictionary) -> Dictionary:
	var options: Array = delation_options(member)
	options.append({
		"label": "DECIDIR DEPOIS",
		"detail": "Você tem %d noite(s). A decisão fica na aba Laranjas." % int(member["delation"]),
		"enabled": true,
		"quiet": true,
		"action": func() -> Dictionary: return {"ok": true, "message": ""}
	})
	return {
		"style": "official",
		"kicker": "POLÍCIA FEDERAL / DELAÇÃO PREMIADA",
		"title": "%s procurou a PF" % str(member["name"]),
		"body": "O estresse passou do limite. %s, %s na sua operação, começou a negociar um acordo de delação premiada. Se o acordo fechar, a campanha termina com você preso." % [str(member["name"]), str(member["title"]).to_lower()],
		"options": options
	}

# ---------------------------------------------------------
# Virada do dia
# ---------------------------------------------------------

func daily_tick() -> Dictionary:
	var report: Dictionary = {"wages": 0.0, "unpaid": 0}
	if Campaign.escape_active:
		return report
	var suspicion: float = GameManager.suspicion
	for member_v: Variant in roster.duplicate():
		var member: Dictionary = member_v as Dictionary

		# Acordo em andamento: uma noite a menos. Se zerar, a campanha acaba.
		if int(member["delation"]) >= 0:
			member["delation"] = int(member["delation"]) - 1
			if int(member["delation"]) <= 0:
				Campaign.trigger_ending("preso", "%s fechou o acordo de delação premiada e entregou a operação inteira." % str(member["name"]))
				return report
			continue

		# Diária: sai do limpo; se faltar, do sujo. Sem nenhum dos dois, fica devendo.
		var cost: float = float(member["cost"])
		var paid: bool = true
		if GameManager.clean_money >= cost:
			GameManager.clean_money -= cost
		elif GameManager.dirty_money >= cost:
			GameManager.dirty_money -= cost
		else:
			paid = false
		if paid:
			report["wages"] = float(report["wages"]) + cost
		else:
			report["unpaid"] = int(report["unpaid"]) + 1
			member["stress"] = float(member["stress"]) + B.STAFF_UNPAID_STRESS
			member["loyalty"] = maxf(0.0, float(member["loyalty"]) - B.STAFF_UNPAID_LOYALTY)

		# Estresse: sobe com a suspeita alta, alivia com a suspeita baixa.
		if suspicion > B.STAFF_STRESS_LEVEL:
			member["stress"] = float(member["stress"]) + maxf(1.0, B.STAFF_STRESS_BASE + (suspicion - B.STAFF_STRESS_LEVEL) / 5.0 - float(member["loyalty"]) / 25.0)
		else:
			member["stress"] = float(member["stress"]) - B.STAFF_STRESS_RELIEF
		member["stress"] = clampf(float(member["stress"]), 0.0, 100.0)

		if float(member["stress"]) >= 100.0:
			member["delation"] = B.DELATION_DEADLINE
			GameManager.add_news("URGENTE", "%s negocia delação premiada" % str(member["name"]), "Um dos seus laranjas procurou a Polícia Federal. Há %d noites para intervir." % B.DELATION_DEADLINE, "Decisão pendente na aba Laranjas")
			Campaign.push_event(_delation_event(member))
	refresh_candidates()
	GameManager.touch()
	return report

# ---------------------------------------------------------
# Save / load
# ---------------------------------------------------------

func to_dict() -> Dictionary:
	return {"roster": roster, "candidates": candidates, "next_id": _next_id}

func _clean_member(raw: Dictionary) -> Dictionary:
	return {
		"id": int(raw.get("id", 0)),
		"name": str(raw.get("name", "?")),
		"tier": int(raw.get("tier", 1)),
		"title": str(raw.get("title", "Laranja")),
		"capacity": float(raw.get("capacity", 0.0)),
		"cost": float(raw.get("cost", 0.0)),
		"loyalty": float(raw.get("loyalty", 50.0)),
		"stress": float(raw.get("stress", 0.0)),
		"company": str(raw.get("company", "")),
		"delation": int(raw.get("delation", -1))
	}

func from_dict(data: Dictionary) -> void:
	reset()
	for raw_v: Variant in GameManager.as_list(data.get("roster")):
		if typeof(raw_v) == TYPE_DICTIONARY:
			roster.append(_clean_member(raw_v))
	for raw_v: Variant in GameManager.as_list(data.get("candidates")):
		if typeof(raw_v) == TYPE_DICTIONARY:
			candidates.append(_clean_member(raw_v))
	_next_id = int(data.get("next_id", roster.size() + candidates.size() + 1))
