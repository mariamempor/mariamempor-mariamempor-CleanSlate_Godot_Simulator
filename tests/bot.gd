extends RefCounted
# Decisoes do bot, usadas pela simulacao (sim.gd) e pelo teste de interface (play.gd).
const B = preload("res://scripts/data/balance.gd")

static func events() -> void:
	for ev_v: Variant in Campaign.take_events():
		var ev: Dictionary = ev_v as Dictionary
		var options: Array = ev.get("options", [])
		if options.is_empty():
			continue
		# politica: primeira opcao habilitada que nao seja "perigosa"; imunidade: sempre seguir
		var chosen: Dictionary = {}
		if str(ev["title"]).begins_with("Uma cadeira"):
			chosen = options[1]
		else:
			for o_v: Variant in options:
				var o: Dictionary = o_v as Dictionary
				if bool(o.get("enabled", true)) and not bool(o.get("danger", false)) and not bool(o.get("quiet", false)):
					chosen = o
					break
			if chosen.is_empty():
				chosen = options[options.size() - 1]
				for o_v: Variant in options:
					if bool((o_v as Dictionary).get("enabled", true)):
						chosen = o_v
						break
		(chosen["action"] as Callable).call()

static func day(style: String) -> void:
	var cap: float = {"sensato": 58.0, "agressivo": 74.0, "cauteloso": 44.0}[style]
	if Campaign.act == 3:
		cap = minf(cap, 70.0)
	# 1. delacoes pendentes
	for m_v: Variant in Staff.delating():
		var m: Dictionary = m_v as Dictionary
		for choice: String in ["silence_dirty", "silence_clean", "exile", "discard"]:
			if bool(Staff.resolve_delation(int(m["id"]), choice)["ok"]):
				break
	# 2. acoes de risco
	if GameManager.suspicion > cap - 18.0:
		for a_v: Variant in B.RISK_ACTIONS:
			var a: Dictionary = a_v as Dictionary
			if float(a["reduce"]) > 0.0 and GameManager.action_cost(a) < GameManager.clean_money * 0.35:
				GameManager.reduce_risk(str(a["id"]))
	if GameManager.wiretap_days > 0:
		GameManager.reduce_risk("varredura")
	# 3. comprar empresas
	for id: String in B.COMPANY_ORDER:
		if GameManager.company_status(id) == "sale" and float(GameManager.companies[id]["price"]) < GameManager.clean_money * 0.92:
			GameManager.buy_company(id)
	# 4. contratar: melhor candidato para a maior empresa com vaga
	Staff.ensure_candidates()
	var owned: Array = GameManager.owned_ids()
	owned.reverse()
	for id: String in owned:
		while Staff.slots_free(id) > 0:
			var best: Dictionary = {}
			for c_v: Variant in Staff.candidates:
				var c: Dictionary = c_v as Dictionary
				if int(c["tier"]) < Campaign.act and float(GameManager.companies[id]["capacity"]) > 100000.0:
					continue
				if Staff.hire_fee(c) < GameManager.clean_money * 0.5 and (best.is_empty() or float(c["capacity"]) / float(c["cost"]) > float(best["capacity"]) / float(best["cost"])):
					best = c
			if best.is_empty():
				break
			Staff.hire(int(best["id"]), id)
	# 5. agrados quando o estresse passa de 70
	for m_v: Variant in Staff.roster:
		var m: Dictionary = m_v as Dictionary
		if float(m["stress"]) > 70.0 and int(m["delation"]) < 0:
			Staff.give_bonus(int(m["id"]))
	# 6. processar: empresas por limpo gerado por ponto de suspeita
	var ids: Array = GameManager.owned_ids()
	ids.sort_custom(func(x: String, y: String) -> bool:
		return GameManager.capacity_of(x) * (1.0 - GameManager.loss_of(x)) / GameManager.risk_of(x) > GameManager.capacity_of(y) * (1.0 - GameManager.loss_of(y)) / GameManager.risk_of(y))
	for id: String in ids:
		var room: float = GameManager.remaining_capacity(id)
		if room < B.MIN_OPERATION:
			continue
		var budget: float = cap - GameManager.suspicion
		if budget <= 0.2:
			break
		var by_risk: float = GameManager.capacity_of(id) * budget / GameManager.risk_of(id)
		var amount: float = floorf(minf(minf(room, GameManager.dirty_money), by_risk) / 1000.0) * 1000.0
		if amount >= B.MIN_OPERATION:
			GameManager.process_company(id, amount)
	# 7. bens: compra quando sobra bastante, e declara renda para cobrir
	if style != "cauteloso" or Campaign.act >= 2:
		for g_v: Variant in B.GOODS:
			var g: Dictionary = g_v as Dictionary
			if Lifestyle.buy_block(g) == "" and float(g["price"]) < GameManager.clean_money * 0.3:
				Lifestyle.buy(str(g["id"]))
		if Lifestyle.excess() > 0.0:
			Lifestyle.declare(Lifestyle.declare_needed())
	# 8. doacoes para influencia no ato 2
	if Campaign.act == 2 and GameManager.influence < 6:
		GameManager.reduce_risk("doacao")

static func escape() -> void:
	# passaporte e jato intermediarios, liquida tudo o que der, converte e decola
	for id: String in GameManager.owned_ids():
		if float(GameManager.companies[id]["value"]) >= Campaign.escape_start_worth * 0.02:
			Campaign.liquidate_company(id)
	Portfolio.liquidate_all()
	for good_id: String in Lifestyle.owned.duplicate():
		if float(B.good_data(good_id)["price"]) >= Campaign.escape_start_worth * 0.02 and Campaign.escape_hours > 30.0:
			Lifestyle.sell(good_id)
	if Campaign.ending == "":
		for pid: String in ["bom", "comum"]:
			if bool(Campaign.buy_passport(pid)["ok"]):
				break
		for jid: String in ["executivo", "turbo"]:
			if bool(Campaign.buy_jet(jid)["ok"]):
				break
	while Campaign.ending == "" and Campaign.escape_hours >= B.ESCAPE_HOURS_CONVERT and Portfolio.monero_batch() >= 1000.0:
		Portfolio.convert_to_monero()
	if Campaign.ending == "":
		if Campaign.ready_to_fly():
			Campaign.takeoff()
		else:
			Campaign.escape_spend(Campaign.escape_hours)
