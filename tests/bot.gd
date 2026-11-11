extends RefCounted
# Decisões do bot, usadas pela simulação (sim.gd) e pelo teste de interface (play.gd).
#
# Estilos de jogador:
#   sensato       equilibrado: opera, contrata, compra empresas, cuida do risco, faz objetivos
#   operador      opera o máximo todo turno e quase não faz mais nada
#   empresas      prioriza comprar empresas; contrata pouco
#   funcionarios  prioriza contratar e cuidar dos laranjas
#   investidor    põe o excedente em fundos e cripto
#   cauteloso     mantém a suspeita baixa, mesmo lavando menos
#   ruim          decisões ruins: escolhas ao acaso, ignora ameaças, ostenta sem declarar
const B = preload("res://scripts/data/balance.gd")

const STYLES: Array = ["sensato", "operador", "empresas", "funcionarios", "investidor", "cauteloso", "ruim"]

static func _cap(style: String) -> float:
	var cap: float = {"sensato": 60.0, "operador": 78.0, "empresas": 62.0, "funcionarios": 58.0, "investidor": 60.0, "cauteloso": 42.0, "ruim": 95.0}.get(style, 60.0)
	if Campaign.act == 3:
		cap = minf(cap, 72.0 if style != "ruim" else 95.0)
	return cap

## Popups da noite: uma política por estilo.
static func events(style: String = "sensato") -> void:
	var guard: int = 0
	while not Campaign.events.is_empty() and Campaign.ending == "" and guard < 12:
		guard += 1
		for ev_v: Variant in Campaign.take_events():
			var ev: Dictionary = ev_v as Dictionary
			var options: Array = ev.get("options", [])
			if options.is_empty():
				continue
			var chosen: Dictionary = _choose(style, ev, options)
			if not chosen.is_empty():
				(chosen["action"] as Callable).call()
			if Campaign.ending != "":
				return

static func _choose(style: String, ev: Dictionary, options: Array) -> Dictionary:
	var enabled: Array = options.filter(func(o: Variant) -> bool: return bool((o as Dictionary).get("enabled", true)))
	if enabled.is_empty():
		return {}
	var title: String = str(ev.get("title", ""))
	if style == "ruim":
		return enabled[GameManager.rng.randi_range(0, enabled.size() - 1)]
	# Imunidade parlamentar: o estilo "empresas" aceita quando pode (testa o final Político).
	if title.begins_with("Uma cadeira"):
		return enabled[0] if style == "empresas" and enabled.size() > 1 else enabled[enabled.size() - 1]
	# Contratos: quem gosta de contratos aceita; os outros deixam passar.
	if str(ev.get("kicker", "")).begins_with("NOVO CONTRATO"):
		var offers: Array = Missions.offered_contracts()
		var wants: bool = style in ["sensato", "cauteloso", "investidor", "funcionarios"] and not offers.is_empty() and contract_ok(offers[0], style)
		return enabled[0] if wants else enabled[enabled.size() - 1]
	for o_v: Variant in enabled:
		var o: Dictionary = o_v
		if not bool(o.get("danger", false)):
			return o
	return enabled[0]

## O bot só aceita contratos que combinam com o próprio jeito de jogar.
static func contract_ok(c: Dictionary, style: String) -> bool:
	match str(c["metric"]):
		"quiet":
			return style == "cauteloso" or GameManager.suspicion > 55.0
		"calm":
			return GameManager.suspicion < float(c["param"]) - 8.0
		"donation":
			return Campaign.act >= 2 and GameManager.action_cooldown("doacao") == 0
	return true

static func _quiet_contract() -> bool:
	for c_v: Variant in Missions.active_contracts():
		if str((c_v as Dictionary)["metric"]) == "quiet":
			return true
	return false

## Um turno inteiro de decisões.
static func day(style: String) -> void:
	var cap: float = _cap(style)
	# 1. Delações pendentes
	for m_v: Variant in Staff.delating():
		var m: Dictionary = m_v as Dictionary
		for choice: String in ["silence_dirty", "silence_clean", "exile", "discard"]:
			if style == "ruim":
				choice = "discard"
			if bool(Staff.resolve_delation(int(m["id"]), choice)["ok"]):
				break
	# 2. Ações de risco
	var risk_margin: float = {"cauteloso": 10.0, "operador": 8.0, "ruim": -10.0}.get(style, 16.0)
	if GameManager.suspicion > cap - risk_margin and style != "ruim":
		for a_v: Variant in B.RISK_ACTIONS:
			var a: Dictionary = a_v as Dictionary
			if float(a["reduce"]) > 0.0 and GameManager.action_cost(a) < GameManager.clean_money * 0.35:
				GameManager.reduce_risk(str(a["id"]))
	if GameManager.wiretap_days > 0 and style != "ruim" and style != "operador":
		GameManager.reduce_risk("varredura")
	# 3. Comprar empresas
	var buy_share: float = {"empresas": 0.98, "operador": 0.5, "ruim": 0.6, "funcionarios": 0.7}.get(style, 0.9)
	for id: String in B.COMPANY_ORDER:
		if GameManager.company_status(id) == "sale" and GameManager.price_of(id) < GameManager.clean_money * buy_share:
			GameManager.buy_company(id)
	# 4. Contratar: melhor candidato para a maior empresa com vaga
	if style != "operador" and style != "ruim":
		Staff.ensure_candidates()
		var fee_share: float = 0.7 if style == "funcionarios" else (0.25 if style == "empresas" else 0.5)
		var owned: Array = GameManager.owned_ids()
		owned.reverse()
		for id: String in owned:
			while Staff.slots_free(id) > 0:
				var best: Dictionary = {}
				for c_v: Variant in Staff.candidates:
					var c: Dictionary = c_v as Dictionary
					if Staff.hire_fee(c) < GameManager.clean_money * fee_share and (best.is_empty() or _hire_score(c, style) > _hire_score(best, style)):
						best = c
				if best.is_empty():
					break
				Staff.hire(int(best["id"]), id)
	# 5. Agrados quando o estresse sobe
	var care_level: float = 50.0 if style == "funcionarios" else 70.0
	if style != "ruim" and style != "operador":
		for m_v: Variant in Staff.roster:
			var m: Dictionary = m_v as Dictionary
			if float(m["stress"]) > care_level and int(m["delation"]) < 0:
				Staff.give_bonus(int(m["id"]))
	# 6. Processar: empresas por limpo gerado por ponto de suspeita
	var ids: Array = GameManager.owned_ids()
	ids.sort_custom(func(x: String, y: String) -> bool:
		return GameManager.capacity_of(x) * (1.0 - GameManager.loss_of(x)) / GameManager.risk_of(x) > GameManager.capacity_of(y) * (1.0 - GameManager.loss_of(y)) / GameManager.risk_of(y))
	if _quiet_contract():
		ids = []
	for id: String in ids:
		var room: float = GameManager.remaining_capacity(id)
		if room < B.MIN_OPERATION:
			continue
		var budget: float = cap - GameManager.suspicion
		if budget <= 0.2:
			break
		var by_risk: float = GameManager.capacity_of(id) * budget / GameManager.risk_of(id)
		var amount: float = minf(minf(room, GameManager.dirty_money), by_risk)
		if style == "ruim":
			amount = minf(room, GameManager.dirty_money) * GameManager.rng.randf_range(0.3, 1.0)
		amount = floorf(amount / 1000.0) * 1000.0
		if amount >= B.MIN_OPERATION:
			GameManager.process_company(id, amount)
	# 7. Bens: compra quando sobra bastante, e declara renda para cobrir
	var goods_share: float = {"ruim": 0.6, "operador": 0.0, "cauteloso": 0.15}.get(style, 0.3)
	if goods_share > 0.0:
		for g_v: Variant in B.GOODS:
			var g: Dictionary = g_v as Dictionary
			if Lifestyle.buy_block(g) == "" and float(g["price"]) < GameManager.clean_money * goods_share:
				Lifestyle.buy(str(g["id"]))
	if Lifestyle.excess() > 0.0 and style != "ruim":
		Lifestyle.declare(Lifestyle.declare_needed())
	# 8. Influência no Ato 2
	var favor: bool = Missions.active_contracts().any(func(c: Variant) -> bool: return str((c as Dictionary)["metric"]) == "donation")
	if (favor or (Campaign.act == 2 and GameManager.influence < 6)) and style in ["sensato", "empresas", "funcionarios", "cauteloso", "investidor"]:
		GameManager.reduce_risk("doacao")
	# 9. Investimentos
	var invest_share: float = {"investidor": 0.35, "sensato": 0.10}.get(style, 0.0)
	if invest_share > 0.0 and GameManager.clean_money > 50000.0:
		var amount: float = floorf(GameManager.clean_money * invest_share / 1000.0) * 1000.0
		var fund: String = "offshore" if Campaign.act >= 3 else ("global" if Campaign.act >= 2 else "")
		if fund != "":
			Portfolio.deposit(fund, amount)
		elif style == "investidor":
			Portfolio.buy_crypto(amount * 0.5)
	# 10. Missões: contratos oferecidos e etapas da saída
	if style in ["sensato", "cauteloso", "investidor", "funcionarios"]:
		for c_v: Variant in Missions.offered_contracts():
			if contract_ok(c_v as Dictionary, style):
				Missions.accept_contract(int((c_v as Dictionary)["uid"]))
	if style != "ruim" and style != "operador":
		for obj_v: Variant in Missions.objectives:
			var mission: Dictionary = Missions.data(str((obj_v as Dictionary)["id"]))
			if mission.has("action") and str((obj_v as Dictionary)["state"]) != "done" and Missions.can_act(mission) == "":
				Missions.run_action(str(mission["id"]))

## Operação Fuga: passaporte e jato intermediários, liquida, converte e decola.
static func escape(style: String = "sensato") -> void:
	for id: String in GameManager.owned_ids():
		if float(GameManager.companies[id]["value"]) >= Campaign.escape_start_worth * 0.02:
			Campaign.liquidate_company(id)
	Portfolio.liquidate_all()
	for good_id: String in Lifestyle.owned.duplicate():
		if float(B.good_data(good_id)["price"]) >= Campaign.escape_start_worth * 0.02 and Campaign.escape_hours > 30.0:
			Lifestyle.sell(good_id)
	if Campaign.ending == "":
		var passports: Array = ["comum"] if style == "ruim" else ["bom", "comum"]
		for pid: String in passports:
			if bool(Campaign.buy_passport(pid)["ok"]):
				break
		var jets: Array = ["turbo"] if style == "ruim" else ["executivo", "turbo"]
		for jid: String in jets:
			if bool(Campaign.buy_jet(jid)["ok"]):
				break
	while Campaign.ending == "" and Campaign.escape_hours >= B.ESCAPE_HOURS_CONVERT and Portfolio.monero_batch() >= 1000.0:
		Portfolio.convert_to_monero()
	if Campaign.ending == "":
		if Campaign.ready_to_fly():
			Campaign.takeoff()
		else:
			Campaign.escape_spend(Campaign.escape_hours)

## Valor de um candidato: capacidade por real de diária, descontando o traço
## como um jogador atento descontaria (quem fala demais custa suspeita; quem é
## nervoso pesa quando a suspeita está alta). O estilo "ruim" não lê o traço.
static func _hire_score(c: Dictionary, style: String) -> float:
	var score: float = float(c["capacity"]) / maxf(1.0, float(c["cost"]))
	if style == "ruim":
		return score
	match str(c.get("trait", "")):
		"falastrao":
			score *= 0.6
		"nervoso":
			score *= 0.8 if GameManager.suspicion > 40.0 else 1.0
		"leal":
			score *= 1.1
	return score
