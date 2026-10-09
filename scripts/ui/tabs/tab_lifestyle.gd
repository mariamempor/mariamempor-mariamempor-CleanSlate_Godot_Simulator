extends "res://scripts/ui/tab_base.gd"
## Bens e estilo de vida: prestígio, ostentação, renda declarada e o catálogo.

func build() -> void:
	page_header("lifestyle")
	var w: float = size.x
	var card_w: float = (w - UI.GAP * 2.0) / 3.0
	_prestige_card(Rect2(0, UI.BODY_Y, card_w, 104))
	_ostentation_card(Rect2(card_w + UI.GAP, UI.BODY_Y, card_w, 104))
	_income_card(Rect2((card_w + UI.GAP) * 2.0, UI.BODY_Y, card_w, 104))
	_catalog(UI.BODY_Y + 104.0 + UI.GAP)

func _prestige_card(rect: Rect2) -> void:
	var card: Panel = UI.panel(self, rect.position, rect.size)
	UI.enter(card, 1)
	var w: float = rect.size.x
	var tier: int = Lifestyle.prestige_tier()
	var points: int = Lifestyle.prestige()
	card.tooltip_text = "Cada nível reduz o custo de todas as empresas em %s ponto e abre negócios maiores." % UI.num(B.PRESTIGE_LOSS_DISCOUNT * 100.0)
	card.add_child(UI.at(UI.caps("PRESTÍGIO", UI.MUTED), Vector2(UI.PAD, 12)))
	card.add_child(UI.right(UI.caps("%d PONTOS" % points, UI.MUTED), Vector2(UI.PAD, 12), w - UI.PAD * 2.0))
	if tier > 0:
		card.add_child(UI.right(UI.label("custo das empresas -%s pt" % UI.num(Lifestyle.loss_discount() * 100.0), 12, UI.GREEN), Vector2(UI.PAD, 36), w - UI.PAD * 2.0))
	card.add_child(UI.at(UI.mono(Lifestyle.prestige_name().to_upper(), 22, UI.CYAN), Vector2(UI.PAD, 28)))
	var gap: int = Lifestyle.next_tier_gap()
	var ratio: float = 1.0
	var note: String = "Nível máximo."
	if gap > 0:
		var base: int = 0 if tier == 0 else int(B.PRESTIGE_TIERS[tier - 1])
		var next: int = int(B.PRESTIGE_TIERS[tier])
		ratio = float(points - base) / float(maxi(next - base, 1))
		note = "Faltam %d pontos para %s." % [gap, str(B.PRESTIGE_NAMES[tier + 1])]
	UI.bar(card, Vector2(UI.PAD, 64), w - UI.PAD * 2.0, ratio, UI.CYAN, "bar_ls_prestige", 6.0)
	card.add_child(UI.at(UI.label(note, 12, UI.MUTED), Vector2(UI.PAD, 76)))

func _ostentation_card(rect: Rect2) -> void:
	var card: Panel = UI.panel(self, rect.position, rect.size)
	UI.enter(card, 2)
	var w: float = rect.size.x
	var total: float = Lifestyle.ostentation()
	var cover: float = Lifestyle.coverage()
	var chance: float = Lifestyle.audit_chance()
	card.tooltip_text = "O quanto os seus bens aparecem. A renda declarada justifica metade do seu valor em ostentação."
	card.add_child(UI.at(UI.caps("OSTENTAÇÃO", UI.MUTED), Vector2(UI.PAD, 12)))
	card.add_child(UI.right(UI.caps("COBERTA ATÉ " + UI.short_money(cover).to_upper(), UI.MUTED), Vector2(UI.PAD, 12), w - UI.PAD * 2.0))
	card.add_child(UI.at(UI.mono(UI.money(total), 22, UI.ORANGE if chance > 0.0 else UI.WHITE), Vector2(UI.PAD, 28)))
	# A barra mostra a ostentação contra a cobertura: passou do traço, há risco.
	var bar_w: float = w - UI.PAD * 2.0
	var top: float = maxf(maxf(total, cover) * 1.15, 1.0)
	UI.bar(card, Vector2(UI.PAD, 64), bar_w, total / top, UI.ORANGE if chance > 0.0 else UI.GREEN, "bar_ls_ost", 6.0)
	if cover > 0.0:
		UI.rule(card, Vector2(UI.PAD + bar_w * cover / top, 60), 14.0, UI.WHITE, true)
	var note: Label = UI.label("Sem risco de malha fina." if chance <= 0.0 else "Malha fina: %d%% de chance por noite." % int(round(chance * 100.0)), 12, UI.GREEN if chance <= 0.0 else UI.RED)
	note.position = Vector2(UI.PAD, 76)
	card.add_child(note)

func _income_card(rect: Rect2) -> void:
	var card: Panel = UI.panel(self, rect.position, rect.size)
	UI.enter(card, 3)
	var w: float = rect.size.x
	card.tooltip_text = "Declarar renda custa %d%% de imposto. É o que justifica o seu padrão de vida para a Receita." % int(round(B.INCOME_TAX * 100.0))
	card.add_child(UI.at(UI.caps("RENDA DECLARADA", UI.MUTED), Vector2(UI.PAD, 12)))
	card.add_child(UI.at(UI.mono(UI.money(Lifestyle.declared_income), 22, UI.WHITE), Vector2(UI.PAD, 28)))
	var needed: float = Lifestyle.declare_needed()
	var note: String = "Imposto de %d%% sobre o valor declarado." % int(round(B.INCOME_TAX * 100.0))
	if needed > 0.0:
		note = "Faltam %s para cobrir os bens." % UI.short_money(needed)
	card.add_child(UI.at(UI.label(note, 12, UI.ORANGE if needed > 0.0 else UI.MUTED), Vector2(UI.PAD, 76)))
	var declare: Button = UI.button_at(card, Vector2(w - UI.PAD - 150.0, 28), Vector2(150, 38), "DECLARAR RENDA", _open_declare, needed > 0.0)
	if Lifestyle.declarable() < 1000.0:
		UI.disable(declare, "Você só pode declarar o que já lavou. Não há renda nova para declarar.")

func _open_declare() -> void:
	var tax: float = B.INCOME_TAX
	var needed: float = Lifestyle.declare_needed()
	# O teto é o menor entre o que ainda pode ser declarado e o que o saldo paga de imposto.
	var limit: float = floorf(minf(Lifestyle.declarable(), GameManager.clean_money / tax))
	var preview: Callable = func(v: float) -> Array:
		var cover: float = (Lifestyle.declared_income + v) * B.OSTENTATION_COVER
		var over: float = maxf(0.0, Lifestyle.ostentation() - cover)
		return [
			["Imposto a pagar", "- " + UI.money(v * tax), UI.ORANGE],
			["Ostentação coberta", UI.money(cover), UI.WHITE],
			["Ostentação sem cobertura", UI.money(over), UI.RED if over > 0.0 else UI.GREEN]
		]
	app.amount_modal({
		"kicker": "RECEITA FEDERAL",
		"title": "Declarar renda",
		"text": "Você paga %d%% de imposto sobre o valor declarado. Em troca, a Receita aceita que você ostente até metade desse valor em bens." % int(round(tax * 100.0)),
		"tiles": [
			["JÁ DECLARADO", UI.short_money(Lifestyle.declared_income), UI.WHITE, ""],
			["OSTENTAÇÃO ATUAL", UI.short_money(Lifestyle.ostentation()), UI.ORANGE, ""],
			["FALTA DECLARAR", UI.short_money(needed), UI.RED if needed > 0.0 else UI.GREEN, "Para cobrir todos os bens que você tem hoje."]
		],
		"field": "VALOR A DECLARAR",
		"max": limit,
		"value": minf(limit, snappedf(needed + 500.0, 1000.0)) if needed > 0.0 else limit,
		"preview": preview,
		"note": "Só é possível declarar o que já foi lavado, e o imposto sai do saldo limpo.",
		"confirm": "DECLARAR",
		"on_confirm": func(v: float) -> Dictionary: return Lifestyle.declare(v)
	})

func _catalog(top: float) -> void:
	var w: float = size.x
	var goods: Array = B.GOODS
	var columns: int = 4
	var gap: float = 10.0
	var rows: int = int(ceil(float(goods.size()) / float(columns)))
	var card_w: float = (w - gap * float(columns - 1)) / float(columns)
	var card_h: float = minf(96.0, (size.y - top - gap * float(rows - 1)) / float(rows))
	for i: int in range(goods.size()):
		@warning_ignore("integer_division")
		var pos: Vector2 = Vector2(float(i % columns) * (card_w + gap), top + float(i / columns) * (card_h + gap))
		_good_card(goods[i] as Dictionary, pos, Vector2(card_w, card_h), i + 4)

func _good_card(good: Dictionary, pos: Vector2, card_size: Vector2, order: int) -> void:
	var good_id: String = str(good["id"])
	var owned: bool = Lifestyle.has(good_id)
	var locked: bool = int(good["act"]) > Campaign.act
	var w: float = card_size.x
	var h: float = card_size.y
	var card: Panel = UI.panel(self, pos, card_size, Color(UI.GREEN, 0.07) if owned else (UI.SURFACE if locked else UI.PANEL), Color(UI.GREEN, 0.5) if owned else UI.LINE)
	UI.enter(card, mini(order, 12))
	var ink: Color = UI.DIM if locked else UI.WHITE
	var name_label: Label = UI.bold(str(good["name"]), 14, ink)
	UI.clip(name_label, Vector2(12, 8), Vector2(w - 24.0, 20))
	card.add_child(name_label)
	card.add_child(UI.at(UI.caps("%s  /  +%d PRESTÍGIO" % [str(good["cat"]).to_upper(), int(good["prestige"])], UI.DIM if locked else UI.MUTED), Vector2(12, 31)))
	card.add_child(UI.at(UI.mono(UI.money(float(good["price"])), 15, UI.DIM if locked else (UI.GREEN if owned else UI.WHITE)), Vector2(12, h - 44.0)))
	var ostentation_label: Label = UI.caps("OSTENTA " + UI.short_money(Lifestyle.ostentation_of(good)).to_upper(), UI.DIM if locked else UI.MUTED, 9)
	ostentation_label.position = Vector2(12, h - 21.0)
	card.add_child(ostentation_label)

	var button_pos: Vector2 = Vector2(w - 106.0, h - 42.0)
	var button_size: Vector2 = Vector2(94, 32)
	if locked:
		var lock: Label = UI.caps("ATO %d" % int(good["act"]), UI.DIM)
		lock.position = button_pos
		lock.size = button_size
		lock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		card.add_child(lock)
	elif owned:
		UI.button_at(card, button_pos, button_size, "VENDER", func() -> void: _confirm_sell(good_id))
	else:
		var buy: Button = UI.button_at(card, button_pos, button_size, "COMPRAR", func() -> void: _confirm_buy(good_id), true)
		var block: String = Lifestyle.buy_block(good)
		if block != "":
			UI.disable(buy, block)

func _confirm_buy(good_id: String) -> void:
	var good: Dictionary = B.good_data(good_id)
	var after: float = Lifestyle.ostentation() + Lifestyle.ostentation_of(good)
	var over: float = maxf(0.0, after - Lifestyle.coverage())
	var risk_text: String = "Sua renda declarada cobre a ostentação depois da compra."
	if over > 0.0:
		risk_text = "Depois da compra, %s em ostentação ficam sem cobertura, com %d%% de chance de malha fina por noite. Declarar mais renda resolve." % [UI.money(over), int(round(clampf(over / after * 0.5, B.AUDIT_MIN_CHANCE, B.AUDIT_MAX_CHANCE) * 100.0))]
	app.confirm_modal({
		"kicker": str(good["cat"]).to_upper(),
		"title": str(good["name"]),
		"text": "Preço: %s do saldo limpo. Rende +%d de prestígio e continua contando como patrimônio.\n\n%s" % [UI.money(float(good["price"])), int(good["prestige"]), risk_text],
		"confirm": "COMPRAR",
		"on_confirm": func() -> void: report(Lifestyle.buy(good_id))
	})

func _confirm_sell(good_id: String) -> void:
	var good: Dictionary = B.good_data(good_id)
	app.confirm_modal({
		"kicker": "VENDA",
		"title": str(good["name"]),
		"text": "Você recebe %s (%d%% do preço) em saldo limpo e perde %d de prestígio." % [UI.money(Lifestyle.sale_value(good)), int(round(B.GOODS_RESALE * 100.0)), int(good["prestige"])],
		"confirm": "VENDER",
		"danger": true,
		"on_confirm": func() -> void: report(Lifestyle.sell(good_id))
	})
