extends Node
## Lifestyle — bens de luxo, prestígio, ostentação e malha fina.
##
## Bens compram prestígio (desconto bancário e acesso a negócios maiores) e
## continuam valendo como patrimônio. O preço é a ostentação: se ela passar de
## metade da renda declarada, a Receita pode abrir uma malha fina a cada noite.
## Declarar renda custa imposto, e é isso que "compra" espaço para ostentar.

const B = preload("res://scripts/data/balance.gd")

var owned: Array = []               # ids dos bens comprados
var declared_income: float = 0.0
var audits: int = 0                 # malhas finas já sofridas
var audit_cooldown: int = 0

func reset() -> void:
	owned = []
	declared_income = 0.0
	audits = 0
	audit_cooldown = 0

# ---------------------------------------------------------
# Consultas
# ---------------------------------------------------------

func has(good_id: String) -> bool:
	return owned.has(good_id)

func goods_value() -> float:
	var total: float = 0.0
	for good_id: String in owned:
		total += float(B.good_data(good_id).get("price", 0.0))
	return total

func prestige() -> int:
	var total: int = 0
	for good_id: String in owned:
		total += int(B.good_data(good_id).get("prestige", 0))
	return total

## Nível de prestígio, de 0 a 4.
func prestige_tier() -> int:
	var points: int = prestige()
	var tier: int = 0
	for threshold_v: Variant in B.PRESTIGE_TIERS:
		if points >= int(threshold_v):
			tier += 1
	return tier

func prestige_name() -> String:
	return str(B.PRESTIGE_NAMES[prestige_tier()])

## Pontos que faltam para o próximo nível (0 no nível máximo).
func next_tier_gap() -> int:
	var tier: int = prestige_tier()
	if tier >= B.PRESTIGE_TIERS.size():
		return 0
	return int(B.PRESTIGE_TIERS[tier]) - prestige()

func loss_discount() -> float:
	return float(prestige_tier()) * B.PRESTIGE_LOSS_DISCOUNT

func ostentation() -> float:
	var total: float = 0.0
	for good_id: String in owned:
		var good: Dictionary = B.good_data(good_id)
		total += float(good.get("price", 0.0)) * float(good.get("weight", 1.0))
	return total

func ostentation_of(good: Dictionary) -> float:
	return float(good["price"]) * float(good["weight"])

## Ostentação que a renda declarada justifica.
func coverage() -> float:
	return declared_income * B.OSTENTATION_COVER

func excess() -> float:
	return maxf(0.0, ostentation() - coverage())

## Chance de malha fina por noite, de 0 a 1.
func audit_chance() -> float:
	var total: float = ostentation()
	var over: float = excess()
	if over <= 0.0 or total <= 0.0:
		return 0.0
	return clampf(over / total * 0.5, B.AUDIT_MIN_CHANCE, B.AUDIT_MAX_CHANCE)

## Renda que ainda dá para declarar: não se declara mais do que já foi lavado.
func declarable() -> float:
	return maxf(0.0, GameManager.total_clean_generated - declared_income)

## Quanto falta declarar para cobrir toda a ostentação atual.
func declare_needed() -> float:
	return excess() / B.OSTENTATION_COVER

func sale_value(good: Dictionary) -> float:
	var share: float = B.ESCAPE_GOODS_SALE if Campaign.escape_active else B.GOODS_RESALE
	return float(good["price"]) * share

## "" se pode comprar; senão, o motivo.
func buy_block(good: Dictionary) -> String:
	if has(str(good["id"])):
		return "Já é seu."
	if int(good["act"]) > Campaign.act:
		return "Disponível no Ato %d." % int(good["act"])
	if Campaign.escape_active:
		return "Não é hora de comprar."
	if float(good["price"]) > GameManager.clean_money:
		return "Faltam %s." % GameManager.format_money(float(good["price"]) - GameManager.clean_money)
	return ""

# ---------------------------------------------------------
# Ações do jogador
# ---------------------------------------------------------

func buy(good_id: String) -> Dictionary:
	var good: Dictionary = B.good_data(good_id)
	if good.is_empty() or GameManager.state != GameManager.GameState.WORK:
		return {"ok": false, "message": "Compra indisponível."}
	var block: String = buy_block(good)
	if block != "":
		return {"ok": false, "message": block}
	GameManager.clean_money -= float(good["price"])
	owned.append(good_id)
	GameManager.touch()
	return {"ok": true, "message": "%s comprado." % str(good["name"])}

func sell(good_id: String) -> Dictionary:
	var good: Dictionary = B.good_data(good_id)
	if good.is_empty() or not has(good_id) or GameManager.state != GameManager.GameState.WORK:
		return {"ok": false, "message": "Venda indisponível."}
	if Campaign.escape_active and not Campaign.escape_can_spend(B.ESCAPE_HOURS_GOOD):
		return {"ok": false, "message": "Não há tempo para esta venda."}
	var value: float = sale_value(good)
	GameManager.begin_batch()
	owned.erase(good_id)
	GameManager.clean_money += value
	GameManager.touch()
	if Campaign.escape_active:
		Campaign.escape_spend(B.ESCAPE_HOURS_GOOD)
	GameManager.end_batch()
	return {"ok": true, "message": "%s vendido por %s." % [str(good["name"]), GameManager.format_money(value)]}

func declare(amount: float) -> Dictionary:
	if GameManager.state != GameManager.GameState.WORK or Campaign.escape_active:
		return {"ok": false, "message": "Declaração indisponível agora."}
	amount = minf(amount, declarable())
	if amount < 1000.0:
		return {"ok": false, "message": "Não há renda para declarar."}
	var tax: float = amount * B.INCOME_TAX
	if tax > GameManager.clean_money:
		return {"ok": false, "message": "Saldo limpo insuficiente para o imposto."}
	GameManager.clean_money -= tax
	declared_income += amount
	GameManager.touch()
	return {"ok": true, "message": "Renda declarada. Imposto pago: %s." % GameManager.format_money(tax)}

# ---------------------------------------------------------
# Malha fina
# ---------------------------------------------------------

func daily_tick() -> void:
	if Campaign.escape_active:
		return
	if audit_cooldown > 0:
		audit_cooldown -= 1
		return
	var chance: float = audit_chance()
	if chance > 0.0 and GameManager.rng.randf() < chance:
		audits += 1
		audit_cooldown = 4
		GameManager.add_news("URGENTE", "Receita Federal abre malha fina sobre o seu patrimônio", "O padrão de vida não fecha com a renda declarada. O Fisco quer saber de onde veio o dinheiro.", "Decisão exigida")
		Campaign.push_event(_audit_event())

## Bens levados em um confisco: os mais caros primeiro, até a conta fechar.
func seize_list() -> Array:
	var goods: Array = []
	for good_id: String in owned:
		goods.append(B.good_data(good_id))
	goods.sort_custom(func(a: Variant, b: Variant) -> bool: return float(a["price"]) > float(b["price"]))
	var out: Array = []
	var remaining: float = excess()
	for good_v: Variant in goods:
		if remaining <= 0.0 and not out.is_empty():
			break
		out.append(good_v)
		remaining -= ostentation_of(good_v)
	return out

func _seize() -> String:
	var names: Array[String] = []
	for good_v: Variant in seize_list():
		var good: Dictionary = good_v as Dictionary
		owned.erase(str(good["id"]))
		names.append(str(good["name"]))
	GameManager.suspicion = clampf(GameManager.suspicion + B.AUDIT_SEIZE_SUSPICION, 0.0, GameManager.max_suspicion)
	GameManager.touch()
	return ", ".join(names)

## choice: "pay", "seize" ou "contest".
func resolve_audit(choice: String, fine: float, contest_cost: float) -> Dictionary:
	GameManager.begin_batch()
	var result: Dictionary = {"ok": true, "message": ""}
	match choice:
		"pay":
			GameManager.clean_money = maxf(0.0, GameManager.clean_money - fine)
			result["message"] = "Multa de %s paga." % GameManager.format_money(fine)
		"seize":
			result["message"] = "Confiscado: %s." % _seize()
		"contest":
			GameManager.clean_money = maxf(0.0, GameManager.clean_money - contest_cost)
			if GameManager.rng.randf() < B.AUDIT_CONTEST_ODDS:
				result["message"] = "O contador venceu: auditoria arquivada."
			else:
				var heavy: float = excess() * B.AUDIT_CONTEST_FINE
				if heavy <= GameManager.clean_money:
					GameManager.clean_money -= heavy
					result["message"] = "Contestação negada. Multa agravada de %s." % GameManager.format_money(heavy)
				else:
					GameManager.clean_money = 0.0
					result["message"] = "Contestação negada. O saldo foi bloqueado e houve confisco: %s." % _seize()
	GameManager.touch()
	GameManager.end_batch()
	Campaign.check_limits()
	return result

func _audit_event() -> Dictionary:
	var over: float = excess()
	var fine: float = over * B.AUDIT_FINE
	var contest_cost: float = over * B.AUDIT_CONTEST_COST
	var seized: Array[String] = []
	for good_v: Variant in seize_list():
		seized.append(str((good_v as Dictionary)["name"]))
	return {
		"style": "official",
		"kicker": "RECEITA FEDERAL / MALHA FINA",
		"title": "Seu patrimônio não fecha com a renda declarada",
		"body": "Você ostenta %s em bens, mas a renda declarada só justifica %s. A diferença de %s está sem origem comprovada." % [GameManager.format_money(ostentation()), GameManager.format_money(coverage()), GameManager.format_money(over)],
		"options": [
			{
				"label": "PAGAR A MULTA",
				"detail": "%s do saldo limpo. Os bens ficam com você." % GameManager.format_money(fine),
				"enabled": GameManager.clean_money >= fine,
				"action": func() -> Dictionary: return resolve_audit("pay", fine, contest_cost)
			},
			{
				"label": "ENTREGAR OS BENS",
				"detail": "Confisco de: %s. Suspeita +%d." % [", ".join(seized), int(B.AUDIT_SEIZE_SUSPICION)],
				"enabled": true,
				"danger": true,
				"action": func() -> Dictionary: return resolve_audit("seize", fine, contest_cost)
			},
			{
				"label": "CONTESTAR",
				"detail": "%s para o contador. %d%% de chance de arquivar; se perder, a multa sobe 50%%." % [GameManager.format_money(contest_cost), int(B.AUDIT_CONTEST_ODDS * 100.0)],
				"enabled": GameManager.clean_money >= contest_cost,
				"action": func() -> Dictionary: return resolve_audit("contest", fine, contest_cost)
			}
		]
	}

# ---------------------------------------------------------
# Save / load
# ---------------------------------------------------------

func to_dict() -> Dictionary:
	return {"owned": owned, "declared_income": declared_income, "audits": audits, "audit_cooldown": audit_cooldown}

func from_dict(data: Dictionary) -> void:
	reset()
	for good_id_v: Variant in GameManager.as_list(data.get("owned")):
		if not B.good_data(str(good_id_v)).is_empty():
			owned.append(str(good_id_v))
	declared_income = float(data.get("declared_income", 0.0))
	audits = int(data.get("audits", 0))
	audit_cooldown = int(data.get("audit_cooldown", 0))
