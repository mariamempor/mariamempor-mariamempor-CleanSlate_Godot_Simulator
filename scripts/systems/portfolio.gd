extends Node
## Portfolio — carteira de cripto, fundos de investimento e Monero.
##
## Cripto: compra e venda com taxa; o preço oscila toda noite. Não conta como
## ostentação e paga o exílio de laranjas.
## Fundos: aplicação que rende por dia (liberados a partir do Ato 2).
## Monero: só existe na Operação Fuga. É o que o jogador leva embora.

const B = preload("res://scripts/data/balance.gd")

var crypto_units: float = 0.0
var crypto_price: float = B.CRYPTO_START_PRICE
var price_history: Array = []
var funds: Dictionary = {}          # {id do fundo: saldo}
var monero: float = 0.0

func reset() -> void:
	crypto_units = 0.0
	crypto_price = B.CRYPTO_START_PRICE
	price_history = [crypto_price]
	funds = {}
	monero = 0.0

# ---------------------------------------------------------
# Consultas
# ---------------------------------------------------------

func crypto_value() -> float:
	return crypto_units * crypto_price

func fund_balance(fund_id: String) -> float:
	return float(funds.get(fund_id, 0.0))

func funds_value() -> float:
	var total: float = 0.0
	for fund_id: String in funds:
		total += float(funds[fund_id])
	return total

func total_value() -> float:
	return crypto_value() + funds_value() + monero

## Variação do preço da cripto na última noite, em fração (0.03 = +3%).
func crypto_change() -> float:
	if price_history.size() < 2:
		return 0.0
	var before: float = float(price_history[price_history.size() - 2])
	return (crypto_price - before) / maxf(before, 1.0)

# ---------------------------------------------------------
# Cripto
# ---------------------------------------------------------

func buy_crypto(amount: float) -> Dictionary:
	if GameManager.state != GameManager.GameState.WORK or Campaign.escape_active:
		return {"ok": false, "message": "Compra indisponível agora."}
	if amount < 1000.0 or amount > GameManager.clean_money:
		return {"ok": false, "message": "Saldo limpo insuficiente."}
	GameManager.clean_money -= amount
	crypto_units += amount * (1.0 - B.CRYPTO_FEE) / crypto_price
	GameManager.touch()
	return {"ok": true, "message": "Compra de cripto registrada."}

func sell_crypto(amount: float) -> Dictionary:
	if GameManager.state != GameManager.GameState.WORK or Campaign.escape_active:
		return {"ok": false, "message": "Venda indisponível agora."}
	amount = minf(amount, crypto_value())
	if amount < 1.0:
		return {"ok": false, "message": "Não há cripto para vender."}
	crypto_units = maxf(0.0, crypto_units - amount / crypto_price)
	GameManager.clean_money += amount * (1.0 - B.CRYPTO_FEE)
	GameManager.touch()
	return {"ok": true, "message": "Venda de cripto registrada."}

## Paga um custo direto em cripto (exílio de laranja).
func spend_crypto(value: float) -> bool:
	if value > crypto_value() + 0.01:
		return false
	crypto_units = maxf(0.0, crypto_units - value / crypto_price)
	GameManager.touch()
	return true

# ---------------------------------------------------------
# Fundos
# ---------------------------------------------------------

func deposit(fund_id: String, amount: float) -> Dictionary:
	var fund: Dictionary = B.fund_data(fund_id)
	if fund.is_empty() or int(fund["act"]) > Campaign.act or Campaign.escape_active:
		return {"ok": false, "message": "Fundo indisponível."}
	if GameManager.state != GameManager.GameState.WORK or amount < 1000.0 or amount > GameManager.clean_money:
		return {"ok": false, "message": "Saldo limpo insuficiente."}
	GameManager.clean_money -= amount
	funds[fund_id] = fund_balance(fund_id) + amount * (1.0 - B.FUND_FEE)
	GameManager.touch()
	return {"ok": true, "message": "Aplicação registrada em %s." % str(fund["name"])}

func withdraw(fund_id: String, amount: float) -> Dictionary:
	if GameManager.state != GameManager.GameState.WORK or Campaign.escape_active:
		return {"ok": false, "message": "Resgate indisponível agora."}
	amount = minf(amount, fund_balance(fund_id))
	if amount < 1.0:
		return {"ok": false, "message": "Não há saldo neste fundo."}
	funds[fund_id] = fund_balance(fund_id) - amount
	GameManager.clean_money += amount
	GameManager.touch()
	return {"ok": true, "message": "Resgate registrado."}

## Interpol: congela uma fatia da cripto e dos fundos expostos. Devolve o valor perdido.
func seize(share: float) -> float:
	var lost: float = crypto_value() * share
	crypto_units *= 1.0 - share
	for fund_v: Variant in B.FUNDS:
		var fund: Dictionary = fund_v as Dictionary
		var fund_id: String = str(fund["id"])
		if bool(fund["exposed"]) and funds.has(fund_id):
			lost += float(funds[fund_id]) * share
			funds[fund_id] = float(funds[fund_id]) * (1.0 - share)
	GameManager.touch()
	return lost

# ---------------------------------------------------------
# Operação Fuga
# ---------------------------------------------------------

## Vende toda a cripto e resgata todos os fundos de uma vez.
func liquidate_all() -> Dictionary:
	var value: float = crypto_value() + funds_value()
	if not Campaign.escape_active or value < 1.0:
		return {"ok": false, "message": "Não há carteira para liquidar."}
	if not Campaign.escape_can_spend(B.ESCAPE_HOURS_WALLET):
		return {"ok": false, "message": "Não há tempo para esta operação."}
	GameManager.begin_batch()
	GameManager.clean_money += crypto_value() * (1.0 - B.CRYPTO_FEE) + funds_value()
	crypto_units = 0.0
	funds = {}
	GameManager.touch()
	Campaign.escape_spend(B.ESCAPE_HOURS_WALLET)
	GameManager.end_batch()
	return {"ok": true, "message": "Carteira liquidada."}

## Tamanho máximo de um lote de conversão para Monero.
func monero_batch() -> float:
	return minf(GameManager.clean_money, Campaign.escape_start_worth * B.ESCAPE_BATCH_SHARE)

func convert_to_monero() -> Dictionary:
	var amount: float = monero_batch()
	if not Campaign.escape_active or amount < 1000.0:
		return {"ok": false, "message": "Não há saldo limpo para converter."}
	if not Campaign.escape_can_spend(B.ESCAPE_HOURS_CONVERT):
		return {"ok": false, "message": "Não há tempo para mais um lote."}
	GameManager.begin_batch()
	GameManager.clean_money -= amount
	monero += amount * (1.0 - B.ESCAPE_MONERO_FEE)
	GameManager.touch()
	Campaign.escape_spend(B.ESCAPE_HOURS_CONVERT)
	GameManager.end_batch()
	return {"ok": true, "message": "%s convertidos em Monero." % GameManager.format_money(amount)}

# ---------------------------------------------------------
# Virada do dia
# ---------------------------------------------------------

## Atualiza o preço da cripto e rende os fundos. Devolve o rendimento da noite.
func daily_tick() -> float:
	var rng: RandomNumberGenerator = GameManager.rng
	crypto_price = maxf(1000.0, crypto_price * (1.0 + B.CRYPTO_DRIFT + rng.randf_range(-B.CRYPTO_SWING, B.CRYPTO_SWING)))
	price_history.append(crypto_price)
	if price_history.size() > 20:
		price_history.pop_front()
	var earned: float = 0.0
	for fund_v: Variant in B.FUNDS:
		var fund: Dictionary = fund_v as Dictionary
		var fund_id: String = str(fund["id"])
		var balance: float = fund_balance(fund_id)
		if balance <= 0.0:
			continue
		var swing: float = float(fund["swing"])
		var gain: float = balance * (float(fund["yield"]) + rng.randf_range(-swing, swing))
		funds[fund_id] = balance + gain
		earned += gain
	return earned

# ---------------------------------------------------------
# Save / load
# ---------------------------------------------------------

func to_dict() -> Dictionary:
	return {"crypto_units": crypto_units, "crypto_price": crypto_price, "price_history": price_history, "funds": funds, "monero": monero}

func from_dict(data: Dictionary) -> void:
	reset()
	crypto_units = float(data.get("crypto_units", 0.0))
	crypto_price = float(data.get("crypto_price", B.CRYPTO_START_PRICE))
	price_history = []
	for price_v: Variant in GameManager.as_list(data.get("price_history"), [crypto_price]):
		price_history.append(float(price_v))
	var saved: Dictionary = GameManager.as_dict(data.get("funds"))
	for fund_id: String in saved:
		if not B.fund_data(fund_id).is_empty():
			funds[fund_id] = float(saved[fund_id])
	monero = float(data.get("monero", 0.0))
