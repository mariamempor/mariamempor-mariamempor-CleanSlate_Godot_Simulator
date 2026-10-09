extends "res://scripts/ui/tab_base.gd"
## Carteira: cripto (preço que oscila) e fundos (rendimento por noite).

func build() -> void:
	page_header("wallet")
	var w: float = size.x
	var body_h: float = size.y - UI.BODY_Y
	var left_w: float = floorf((w - UI.GAP) * 0.50)
	var right_w: float = w - UI.GAP - left_w
	_crypto_card(Rect2(0, UI.BODY_Y, left_w, body_h))
	_funds_card(Rect2(left_w + UI.GAP, UI.BODY_Y, right_w, body_h))

func _crypto_card(rect: Rect2) -> void:
	var card: Panel = UI.card(self, rect, "Cripto", "Não gera ostentação e paga o exílio de laranjas")
	UI.enter(card, 1)
	var w: float = rect.size.x
	var change: float = Portfolio.crypto_change()
	var change_color: Color = UI.GREEN if change >= 0.0 else UI.RED
	card.add_child(UI.at(UI.caps("PREÇO DE UMA UNIDADE", UI.MUTED), Vector2(UI.PAD, 66)))
	card.add_child(UI.at(UI.mono(UI.money(Portfolio.crypto_price), 26, UI.WHITE), Vector2(UI.PAD, 82)))
	card.add_child(UI.right(UI.caps("ÚLTIMA NOITE", UI.MUTED), Vector2(UI.PAD, 66), w - UI.PAD * 2.0))
	card.add_child(UI.right(UI.mono(UI.signed(change * 100.0) + "%", 20, change_color), Vector2(UI.PAD, 86), w - UI.PAD * 2.0))
	# Histórico do preço: um ponto por noite.
	var chart_h: float = clampf(rect.size.y - 330.0, 60.0, 150.0)
	UI.sparkline(card, Vector2(UI.PAD, 128), Vector2(w - UI.PAD * 2.0, chart_h), Portfolio.price_history, UI.CYAN)

	var y: float = 128.0 + chart_h + 22.0
	UI.rule(card, Vector2(UI.PAD, y - 10.0), w - UI.PAD * 2.0, Color("#1A2B36"))
	card.add_child(UI.at(UI.caps("SUA POSIÇÃO", UI.MUTED), Vector2(UI.PAD, y)))
	var value: Label = UI.mono("", 24, UI.CYAN)
	value.position = Vector2(UI.PAD, y + 16.0)
	card.add_child(value)
	UI.count(value, "wl_crypto", Portfolio.crypto_value(), UI.money)
	card.add_child(UI.right(UI.caps(UI.num(Portfolio.crypto_units, 4) + " UNIDADES", UI.MUTED), Vector2(UI.PAD, y + 26.0), w - UI.PAD * 2.0))

	var buy: Button = UI.button_at(card, Vector2(UI.PAD, y + 62.0), Vector2(150, 42), "COMPRAR", func() -> void: _open_crypto(true), true, "crypto")
	if GameManager.clean_money < 1000.0:
		UI.disable(buy, "Saldo limpo insuficiente.")
	var sell: Button = UI.button_at(card, Vector2(UI.PAD + 162.0, y + 62.0), Vector2(150, 42), "VENDER", func() -> void: _open_crypto(false))
	if Portfolio.crypto_value() < 1.0:
		UI.disable(sell, "Você não tem cripto para vender.")
	var note: Label = UI.paragraph("Taxa de %s em cada compra ou venda. O preço muda toda noite, para cima ou para baixo." % UI.pct_short(B.CRYPTO_FEE * 100.0), 12, UI.MUTED, w - UI.PAD * 2.0)
	note.position = Vector2(UI.PAD, y + 116.0)
	if y + 150.0 < rect.size.y:
		card.add_child(note)

func _open_crypto(buying: bool) -> void:
	var fee: float = B.CRYPTO_FEE
	var price: float = Portfolio.crypto_price
	var limit: float = floorf(GameManager.clean_money) if buying else floorf(Portfolio.crypto_value())
	var preview: Callable = func(v: float) -> Array:
		if buying:
			return [
				["Sai do saldo limpo", UI.money(v), UI.ORANGE],
				["Taxa", "- " + UI.money(v * fee), UI.MUTED],
				["Entra na carteira", UI.num(v * (1.0 - fee) / price, 4) + " unidades", UI.CYAN]
			]
		return [
			["Sai da carteira", UI.num(v / price, 4) + " unidades", UI.CYAN],
			["Taxa", "- " + UI.money(v * fee), UI.MUTED],
			["Entra no saldo limpo", UI.money(v * (1.0 - fee)), UI.GREEN]
		]
	app.amount_modal({
		"kicker": "CARTEIRA CRIPTO",
		"title": "Comprar cripto" if buying else "Vender cripto",
		"text": "A cripto conta como patrimônio, não aparece para a Receita e é a única forma de pagar o exílio de um laranja." if buying else "A venda devolve o valor para o saldo limpo, descontada a taxa.",
		"tiles": [
			["PREÇO", UI.short_money(price), UI.WHITE, ""],
			["SUA POSIÇÃO", UI.short_money(Portfolio.crypto_value()), UI.CYAN, ""]
		],
		"field": "VALOR EM REAIS",
		"max": limit,
		"value": floorf(limit * 0.25 / 1000.0) * 1000.0 if buying else limit,
		"minimum": 1000.0 if buying else minf(1000.0, limit),
		"preview": preview,
		"confirm": "COMPRAR" if buying else "VENDER",
		"icon": "crypto",
		"on_confirm": func(v: float) -> Dictionary: return Portfolio.buy_crypto(v) if buying else Portfolio.sell_crypto(v)
	})

func _funds_card(rect: Rect2) -> void:
	var card: Panel = UI.card(self, rect, "Fundos", "Aplicações que rendem toda noite")
	UI.enter(card, 2)
	var w: float = rect.size.x
	var count: int = B.FUNDS.size()
	var gap: float = 10.0
	var item_h: float = minf(138.0, (rect.size.y - 62.0 - gap * float(count - 1) - 10.0) / float(count))
	for i: int in range(count):
		var fund: Dictionary = B.FUNDS[i]
		var fund_id: String = str(fund["id"])
		var locked: bool = int(fund["act"]) > Campaign.act
		var balance: float = Portfolio.fund_balance(fund_id)
		var iw: float = w - UI.PAD * 2.0
		var item: Panel = UI.panel(card, Vector2(UI.PAD, 60.0 + float(i) * (item_h + gap)), Vector2(iw, item_h), UI.SURFACE, UI.LINE)
		var ink: Color = UI.DIM if locked else UI.WHITE
		item.add_child(UI.at(UI.bold(str(fund["name"]), 15, ink), Vector2(14, 10)))
		item.add_child(UI.at(UI.label(str(fund["about"]), 12, UI.DIM if locked else UI.MUTED), Vector2(14, 33)))
		item.add_child(UI.right(UI.caps("RENDE POR NOITE", UI.MUTED), Vector2(14, 10), iw - 28.0))
		item.add_child(UI.right(UI.mono("+" + UI.pct(float(fund["yield"]) * 100.0), 16, UI.DIM if locked else UI.GREEN), Vector2(14, 26), iw - 28.0))
		if locked:
			item.add_child(UI.at(UI.caps("DISPONÍVEL NO ATO %d" % int(fund["act"]), UI.DIM), Vector2(14, item_h - 30.0)))
			continue
		if bool(fund["exposed"]):
			var chip: PanelContainer = UI.chip("NA MIRA DA INTERPOL", UI.RED)
			chip.position = Vector2(14, 56)
			item.add_child(chip)
		item.add_child(UI.at(UI.caps("APLICADO", UI.MUTED), Vector2(14, item_h - 52.0)))
		var value: Label = UI.mono("", 18, UI.CYAN if balance > 0.0 else UI.MUTED)
		value.position = Vector2(14, item_h - 36.0)
		item.add_child(value)
		UI.count(value, "wl_fund_" + fund_id, balance, UI.money)
		var deposit: Button = UI.button_at(item, Vector2(iw - 226.0, item_h - 46.0), Vector2(104, 34), "APLICAR", func() -> void: _open_fund(fund_id, true), true)
		if GameManager.clean_money < 1000.0:
			UI.disable(deposit, "Saldo limpo insuficiente.")
		var withdraw: Button = UI.button_at(item, Vector2(iw - 114.0, item_h - 46.0), Vector2(100, 34), "RESGATAR", func() -> void: _open_fund(fund_id, false))
		if balance < 1.0:
			UI.disable(withdraw, "Não há saldo neste fundo.")

func _open_fund(fund_id: String, depositing: bool) -> void:
	var fund: Dictionary = B.fund_data(fund_id)
	var balance: float = Portfolio.fund_balance(fund_id)
	var limit: float = floorf(GameManager.clean_money) if depositing else floorf(balance)
	var preview: Callable = func(v: float) -> Array:
		if depositing:
			var applied: float = v * (1.0 - B.FUND_FEE)
			return [
				["Sai do saldo limpo", UI.money(v), UI.ORANGE],
				["Taxa de entrada", "- " + UI.money(v * B.FUND_FEE), UI.MUTED],
				["Rendimento médio por noite", "+ " + UI.money((balance + applied) * float(fund["yield"])), UI.GREEN]
			]
		return [
			["Sai do fundo", UI.money(v), UI.CYAN],
			["Entra no saldo limpo", UI.money(v), UI.GREEN],
			["Fica aplicado", UI.money(balance - v), UI.WHITE]
		]
	app.amount_modal({
		"kicker": "FUNDO DE INVESTIMENTO",
		"title": str(fund["name"]),
		"text": str(fund["about"]) + (" Pode ser congelado em uma auditoria da Interpol." if bool(fund["exposed"]) else ""),
		"tiles": [
			["APLICADO", UI.short_money(balance), UI.CYAN, ""],
			["RENDE POR NOITE", "+" + UI.pct(float(fund["yield"]) * 100.0), UI.GREEN, "Rendimento médio. Alguns fundos oscilam."]
		],
		"field": "VALOR A APLICAR" if depositing else "VALOR A RESGATAR",
		"max": limit,
		"value": floorf(limit * 0.5 / 1000.0) * 1000.0 if depositing else limit,
		"minimum": 1000.0 if depositing else minf(1000.0, limit),
		"preview": preview,
		"confirm": "APLICAR" if depositing else "RESGATAR",
		"on_confirm": func(v: float) -> Dictionary: return Portfolio.deposit(fund_id, v) if depositing else Portfolio.withdraw(fund_id, v)
	})
