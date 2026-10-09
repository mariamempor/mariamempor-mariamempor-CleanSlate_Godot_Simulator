extends "res://scripts/ui/tab_base.gd"
## Dark Web: a tela da Operação Fuga. Três colunas, na ordem em que as coisas
## precisam acontecer: garantir a saída, liquidar, converter em Monero.

func build() -> void:
	page_header("darkweb", UI.VIOLET)
	var w: float = size.x
	var body_h: float = size.y - UI.BODY_Y
	var col_w: float = (w - UI.GAP * 2.0) / 3.0
	_exit_card(Rect2(0, UI.BODY_Y, col_w, body_h))
	_liquidate_card(Rect2(col_w + UI.GAP, UI.BODY_Y, col_w, body_h))
	_monero_card(Rect2((col_w + UI.GAP) * 2.0, UI.BODY_Y, col_w, body_h))

func _hours(hours: float) -> String:
	return "%d h" % int(hours)

# ---------- 1. saída: passaporte e avião ----------

func _exit_card(rect: Rect2) -> void:
	var card: Panel = UI.card(self, rect, "1. Garantir a saída", "Sem passaporte e avião, não há fuga")
	UI.enter(card, 1)
	var w: float = rect.size.x
	var half: float = (rect.size.y - 62.0) * 0.5
	_exit_group(card, 60.0, w, half, "PASSAPORTE", B.PASSPORTS, Campaign.passport, B.ESCAPE_HOURS_PASSPORT, true)
	_exit_group(card, 60.0 + half, w, half, "AVIÃO", B.JETS, Campaign.jet, B.ESCAPE_HOURS_JET, false)

func _exit_group(card: Panel, top: float, w: float, height: float, title: String, items: Array, chosen: String, hours: float, is_passport: bool) -> void:
	var done: bool = chosen != ""
	card.add_child(UI.at(UI.caps(title + ("  /  GARANTIDO" if done else "  /  %s CADA" % _hours(hours).to_upper()), UI.GREEN if done else UI.VIOLET), Vector2(UI.PAD, top)))
	var row_h: float = clampf((height - 22.0) / float(items.size()), 44.0, 60.0)
	for i: int in range(items.size()):
		var item: Dictionary = items[i]
		var item_id: String = str(item["id"])
		var y: float = top + 20.0 + float(i) * row_h
		var cost: float = Campaign.escape_item_cost(item)
		var mine: bool = chosen == item_id
		var ink: Color = UI.WHITE if (not done or mine) else UI.DIM
		var name_label: Label = UI.bold(str(item["name"]), 13, UI.GREEN if mine else ink)
		UI.clip(name_label, Vector2(UI.PAD, y), Vector2(w - UI.PAD * 2.0 - 104.0, 18))
		name_label.mouse_filter = Control.MOUSE_FILTER_STOP
		name_label.tooltip_text = str(item["about"])
		card.add_child(name_label)
		var bonus: float = float(item["bonus"])
		card.add_child(UI.at(UI.caps("%s  /  %s" % [UI.short_money(cost).to_upper(), "INTERCEPTAÇÃO -%d%%" % int(bonus) if bonus > 0.0 else "SEM BÔNUS"], UI.MUTED if (not done or mine) else UI.DIM, 9), Vector2(UI.PAD, y + 21.0)))
		if mine:
			var chip: PanelContainer = UI.chip("SEU", UI.GREEN)
			chip.position = Vector2(w - UI.PAD - 44.0, y + 6.0)
			card.add_child(chip)
			continue
		if done:
			continue
		var buy: Button = UI.button_at(card, Vector2(w - UI.PAD - 96.0, y + 1.0), Vector2(96, 34), "COMPRAR", func() -> void: _buy_exit(item_id, is_passport), true)
		if cost > GameManager.clean_money:
			UI.disable(buy, "Faltam %s de saldo limpo. Liquide algo primeiro." % UI.money(cost - GameManager.clean_money))
		elif not Campaign.escape_can_spend(hours):
			UI.disable(buy, "Não há tempo: isto leva %s." % _hours(hours))

func _buy_exit(item_id: String, is_passport: bool) -> void:
	report(Campaign.buy_passport(item_id) if is_passport else Campaign.buy_jet(item_id))

# ---------- 2. liquidar ----------

func _liquidate_card(rect: Rect2) -> void:
	var card: Panel = UI.card(self, rect, "2. Liquidar", "Patrimônio vira saldo limpo, com deságio")
	UI.enter(card, 2)
	var w: float = rect.size.x
	# Tudo o que pode ser vendido, do mais valioso ao menos: [nome, valor, horas, ação].
	var entries: Array = []
	for company_id_v: Variant in GameManager.owned_ids():
		var company_id: String = str(company_id_v)
		var company: Dictionary = GameManager.companies[company_id]
		entries.append([str(company["name"]), float(company["value"]) * B.ESCAPE_COMPANY_SALE, B.ESCAPE_HOURS_COMPANY, func() -> Dictionary: return Campaign.liquidate_company(company_id)])
	for good_id_v: Variant in Lifestyle.owned:
		var good_id: String = str(good_id_v)
		var good: Dictionary = B.good_data(good_id)
		entries.append([str(good["name"]), Lifestyle.sale_value(good), B.ESCAPE_HOURS_GOOD, func() -> Dictionary: return Lifestyle.sell(good_id)])
	var wallet: float = Portfolio.crypto_value() * (1.0 - B.CRYPTO_FEE) + Portfolio.funds_value()
	if wallet >= 1.0:
		entries.append(["Carteira (cripto e fundos)", wallet, B.ESCAPE_HOURS_WALLET, func() -> Dictionary: return Portfolio.liquidate_all()])
	entries.sort_custom(func(a: Array, b: Array) -> bool: return float(a[1]) > float(b[1]))

	if entries.is_empty():
		empty_state(card, Rect2(0, 56, w, rect.size.y - 56.0), "Não há mais nada para vender. Converta o que tem e decole.")
		return
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.position = Vector2(1, 58)
	scroll.size = Vector2(w - 2.0, rect.size.y - 62.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card.add_child(scroll)
	var list: VBoxContainer = VBoxContainer.new()
	list.add_theme_constant_override("separation", 0)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var row_w: float = w - 14.0
	for entry_v: Variant in entries:
		var entry: Array = entry_v as Array
		var hours: float = float(entry[2])
		var action: Callable = entry[3]
		var row: Control = Control.new()
		row.custom_minimum_size = Vector2(0, 54)
		list.add_child(row)
		UI.rule(row, Vector2(UI.PAD, 53), row_w - UI.PAD, Color("#1A2B36"))
		var name_label: Label = UI.bold(str(entry[0]), 13, UI.WHITE)
		UI.clip(name_label, Vector2(UI.PAD, 7), Vector2(row_w - UI.PAD - 100.0, 18))
		row.add_child(name_label)
		row.add_child(UI.at(UI.caps("+%s  /  %s" % [UI.short_money(float(entry[1])).to_upper(), _hours(hours).to_upper()], UI.GREEN, 9), Vector2(UI.PAD, 29)))
		var sell: Button = UI.button_at(row, Vector2(row_w - 88.0, 9), Vector2(88, 34), "VENDER", func() -> void: report(action.call()))
		if not Campaign.escape_can_spend(hours):
			UI.disable(sell, "Não há tempo: isto leva %s." % _hours(hours))

# ---------- 3. converter e decolar ----------

func _monero_card(rect: Rect2) -> void:
	var card: Panel = UI.card(self, rect, "3. Converter em Monero", "É o único dinheiro que embarca")
	UI.enter(card, 3)
	var w: float = rect.size.x
	card.add_child(UI.at(UI.caps("MONERO NA CARTEIRA", UI.MUTED), Vector2(UI.PAD, 64)))
	var value: Label = UI.mono("", 24, UI.VIOLET)
	value.position = Vector2(UI.PAD, 80)
	card.add_child(value)
	UI.count(value, "dw_monero", Portfolio.monero, UI.money)

	var batch: float = Portfolio.monero_batch()
	UI.kv_row(card, 126, w, "Saldo limpo a converter", UI.short_money(GameManager.clean_money), UI.GREEN)
	UI.kv_row(card, 160, w, "Próximo lote", UI.short_money(batch), UI.WHITE)
	UI.kv_row(card, 194, w, "Taxa da conversão", "%d%%" % int(round(B.ESCAPE_MONERO_FEE * 100.0)), UI.ORANGE)
	UI.kv_row(card, 228, w, "Tempo por lote", _hours(B.ESCAPE_HOURS_CONVERT), UI.WHITE)
	var convert_button: Button = UI.button_at(card, Vector2(UI.PAD, 272), Vector2(w - UI.PAD * 2.0, 44), "CONVERTER UM LOTE", func() -> void: report(Portfolio.convert_to_monero()), true, "darkweb")
	if batch < 1000.0:
		UI.disable(convert_button, "Não há saldo limpo para converter. Liquide algo primeiro.")
	elif not Campaign.escape_can_spend(B.ESCAPE_HOURS_CONVERT):
		UI.disable(convert_button, "Não há tempo para mais um lote.")
	else:
		convert_button.tooltip_text = "Cada lote converte até %d%% do patrimônio que você tinha ao iniciar a fuga." % int(round(B.ESCAPE_BATCH_SHARE * 100.0))

	# A conta que decide a hora de ir embora.
	var y: float = 336.0
	if y + 110.0 > rect.size.y:
		return
	UI.rule(card, Vector2(UI.PAD, y), w - UI.PAD * 2.0, UI.LINE)
	card.add_child(UI.at(UI.caps("CHANCE DE INTERCEPTAÇÃO", UI.MUTED), Vector2(UI.PAD, y + 12.0)))
	var chance: float = Campaign.interception_chance()
	var chance_label: Label = UI.mono("", 30, UI.RED if chance >= 40.0 else (UI.ORANGE if chance >= 20.0 else UI.GREEN))
	chance_label.position = Vector2(UI.PAD, y + 28.0)
	card.add_child(chance_label)
	UI.count(chance_label, "dw_chance", chance, func(v: float) -> String: return "%d%%" % int(round(v)))
	var note: String = "Sobe com a suspeita e com cada hora gasta."
	if Campaign.mandado:
		note = "O mandado soma %d pontos. Sobe com cada hora gasta." % int(B.ESCAPE_CHANCE_MANDADO)
	var note_label: Label = UI.paragraph(note, 12, UI.MUTED, w - UI.PAD * 2.0 - 100.0)
	note_label.position = Vector2(UI.PAD + 100.0, y + 30.0)
	card.add_child(note_label)
	if y + 150.0 < rect.size.y:
		var fly: Button = UI.button_at(card, Vector2(UI.PAD, y + 86.0), Vector2(w - UI.PAD * 2.0, 46), "DECOLAR", func() -> void: app.request_takeoff(), true, "escape")
		if not Campaign.ready_to_fly():
			UI.disable(fly, "Faltam o passaporte e o avião.")
