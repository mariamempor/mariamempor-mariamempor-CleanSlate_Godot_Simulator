extends "res://scripts/ui/tab_base.gd"
## Empresas: uma linha por empresa, em colunas, para comparar de relance.
## As que já são suas vêm primeiro; depois as à venda e as de atos futuros.

func build() -> void:
	page_header("companies")
	var w: float = size.x
	var ids: Array = B.COMPANY_ORDER.duplicate()
	ids.sort_custom(func(a: String, b: String) -> bool: return _rank(a) < _rank(b))

	var cols: Array = _columns(w)
	var captions: Array = ["EMPRESA", "CAPACIDADE DE HOJE", "CUSTO", "RISCO NO TETO", "LARANJAS"]
	var tips: Array = ["", "Quanto ainda dá para processar hoje. Volta ao total toda manhã.", "Fatia do valor que se perde na operação.", "Suspeita gerada se você usar 100% da capacidade do dia.", "Vagas ocupadas e capacidade que eles somam."]
	for i: int in range(captions.size()):
		var caption: Label = UI.caps(str(captions[i]), UI.MUTED)
		caption.position = Vector2(float(cols[i]), UI.BODY_Y + 2.0)
		caption.mouse_filter = Control.MOUSE_FILTER_STOP
		caption.tooltip_text = str(tips[i])
		add_child(caption)

	var top: float = UI.BODY_Y + 24.0
	var gap: float = 6.0
	var row_h: float = clampf((size.y - top - gap * float(ids.size() - 1)) / float(ids.size()), 50.0, 64.0)
	for i: int in range(ids.size()):
		_row(str(ids[i]), Vector2(0, top + float(i) * (row_h + gap)), Vector2(w, row_h), cols, i + 1)

## Posição x de cada coluna.
func _columns(w: float) -> Array:
	return [62.0, w * 0.30, w * 0.565, w * 0.650, w * 0.765]

func _rank(company_id: String) -> int:
	var order: int = B.COMPANY_ORDER.find(company_id)
	match GameManager.company_status(company_id):
		"owned": return order
		"sale": return 100 + order
		"prestige": return 200 + order
	return 300 + order

func _row(company_id: String, pos: Vector2, row_size: Vector2, cols: Array, order: int) -> void:
	var d: Dictionary = GameManager.companies[company_id]
	var status: String = GameManager.company_status(company_id)
	var owned: bool = status == "owned"
	var blocked: int = int(d["blocked"])
	var w: float = row_size.x
	var h: float = row_size.y
	var mid: float = h * 0.5
	var panel: Panel = UI.panel(self, pos, row_size, UI.PANEL if owned else UI.SURFACE, UI.LINE)
	UI.enter(panel, order)
	var ink: Color = UI.WHITE if owned else UI.MUTED

	var tile: Panel = UI.panel(panel, Vector2(12, mid - 19.0), Vector2(38, 38), UI.SURFACE, UI.LINE)
	var icon: TextureRect = UI.icon_rect(company_id, Vector2(7, 7), 24.0, Color(1, 1, 1, 1.0 if owned else 0.45))
	if icon != null:
		tile.add_child(icon)
	var name_label: Label = UI.bold(str(d["name"]), 15, ink)
	UI.clip(name_label, Vector2(float(cols[0]), mid - 21.0), Vector2(float(cols[1]) - float(cols[0]) - 12.0, 22))
	panel.add_child(name_label)
	panel.add_child(UI.at(UI.caps(str(d["tag"]).to_upper(), UI.MUTED), Vector2(float(cols[0]), mid + 4.0)))

	# Capacidade: barra do que já foi usado hoje (ou o preço, se ainda não é sua).
	var capacity: float = GameManager.capacity_of(company_id)
	var cap_w: float = float(cols[2]) - float(cols[1]) - 28.0
	if owned and blocked > 0:
		panel.add_child(UI.at(UI.mono("PARADA POR %d DIA(S)" % blocked, 13, UI.RED), Vector2(float(cols[1]), mid - 9.0)))
	elif owned:
		var room: float = GameManager.remaining_capacity(company_id)
		panel.add_child(UI.at(UI.mono("%s de %s" % [UI.short_money(room), UI.short_money(capacity)], 13, UI.CYAN if room >= B.MIN_OPERATION else UI.MUTED), Vector2(float(cols[1]), mid - 20.0)))
		UI.bar(panel, Vector2(float(cols[1]), mid + 8.0), cap_w, room / maxf(capacity, 1.0), UI.CYAN, "", 6.0)
	else:
		panel.add_child(UI.at(UI.mono(UI.short_money(capacity) + " por dia", 13, UI.MUTED), Vector2(float(cols[1]), mid - 20.0)))
		panel.add_child(UI.at(UI.caps("PREÇO: " + UI.money(float(d["price"])), UI.INK_2), Vector2(float(cols[1]), mid + 5.0)))

	# Custo (com o desconto de prestígio já aplicado) e risco no teto.
	var loss: float = GameManager.loss_of(company_id)
	var discounted: bool = loss < float(d["loss"]) - 0.0001
	var loss_label: Label = UI.mono(UI.pct_short(loss * 100.0), 15, UI.GREEN if discounted and owned else (UI.ORANGE if owned else UI.MUTED))
	loss_label.position = Vector2(float(cols[2]), mid - 11.0)
	if discounted:
		loss_label.mouse_filter = Control.MOUSE_FILTER_STOP
		loss_label.tooltip_text = "Custo base de %d%%, reduzido pelo seu prestígio." % int(round(float(d["loss"]) * 100.0))
	panel.add_child(loss_label)
	var risk: float = GameManager.risk_of(company_id)
	var risk_label: Label = UI.mono(UI.signed(risk), 15, UI.RED if owned else UI.MUTED)
	risk_label.position = Vector2(float(cols[3]), mid - 11.0)
	if GameManager.wiretap_days > 0:
		risk_label.mouse_filter = Control.MOUSE_FILTER_STOP
		risk_label.tooltip_text = "Com o grampo ativo, toda operação gera 50% mais suspeita."
	panel.add_child(risk_label)

	var slots: int = int(d["slots"])
	var used: int = Staff.members_of(company_id).size()
	panel.add_child(UI.at(UI.mono("%d/%d" % [used, slots], 15, ink), Vector2(float(cols[4]), mid - 20.0)))
	var bonus: float = Staff.capacity_bonus(company_id)
	panel.add_child(UI.at(UI.caps("+" + UI.short_money(bonus) if bonus > 0.0 else ("VAGA LIVRE" if owned and used < slots else "-"), UI.GREEN if bonus > 0.0 else UI.MUTED), Vector2(float(cols[4]), mid + 5.0)))

	# Ação da linha.
	var button_size: Vector2 = Vector2(150, minf(40.0, h - 16.0))
	var button_pos: Vector2 = Vector2(w - button_size.x - 12.0, mid - button_size.y * 0.5)
	match status:
		"owned":
			var operate: Button = UI.button_at(panel, button_pos, button_size, "OPERAR", func() -> void: _open_operation(company_id), true, "play")
			if blocked > 0:
				UI.disable(operate, "Empresa parada por mais %d dia(s)." % blocked)
			elif GameManager.remaining_capacity(company_id) < B.MIN_OPERATION:
				UI.disable(operate, "A capacidade de hoje acabou. Volta amanhã.")
			elif GameManager.dirty_money < B.MIN_OPERATION:
				UI.disable(operate, "Não há saldo sujo para processar.")
		"sale":
			var buy: Button = UI.button_at(panel, button_pos, button_size, "COMPRAR", func() -> void: _confirm_buy(company_id), true, "money")
			var missing: float = float(d["price"]) - GameManager.clean_money
			if missing > 0.0:
				UI.disable(buy, "Faltam %s de saldo limpo." % UI.money(missing))
		"prestige":
			var need: String = str(B.PRESTIGE_NAMES[int(d["prestige"])])
			panel.add_child(_lock_label("EXIGE PRESTÍGIO\n" + need.to_upper(), button_pos, button_size, UI.ORANGE, "Compre bens na aba Bens para subir de nível."))
		_:
			panel.add_child(_lock_label("DISPONÍVEL NO\nATO %d" % int(d["act"]), button_pos, button_size, UI.DIM, "Este negócio aparece em um ato futuro."))

func _lock_label(text: String, pos: Vector2, label_size: Vector2, color: Color, tip: String) -> Label:
	var node: Label = UI.caps(text, color)
	node.position = pos
	node.size = label_size
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	node.mouse_filter = Control.MOUSE_FILTER_STOP
	node.tooltip_text = tip
	return node

func _open_operation(company_id: String) -> void:
	GameManager.selected_company = company_id
	var d: Dictionary = GameManager.companies[company_id]
	var capacity: float = GameManager.capacity_of(company_id)
	var room: float = GameManager.remaining_capacity(company_id)
	var loss: float = GameManager.loss_of(company_id)
	var risk: float = GameManager.risk_of(company_id)
	var limit: float = floorf(minf(room, GameManager.dirty_money))
	# As funções da prévia e da confirmação ficam em variáveis: uma lambda de
	# várias linhas não pode ser escrita dentro de um dicionário literal.
	var preview: Callable = func(v: float) -> Array:
		var gain: float = risk * v / maxf(capacity, 1.0)
		var after: float = GameManager.suspicion + gain
		return [
			["Sai do saldo sujo", UI.money(v), UI.ORANGE],
			["Custo da operação", "- " + UI.money(v * loss), UI.MUTED],
			["Entra no saldo limpo", UI.money(v * (1.0 - loss)), UI.GREEN],
			["Suspeita gerada", "%s  (vai a %s)" % [UI.signed(gain), UI.pct(after)], UI.RED if after >= Campaign.limit() - 10.0 else UI.risk_color(after)]
		]
	var confirm: Callable = func(v: float) -> Dictionary:
		var result: Dictionary = GameManager.process_company(company_id, v)
		if bool(result.get("ok", false)):
			result["message"] = "Operação registrada: %s limpos." % UI.money(float((result["transaction"] as Dictionary)["clean"]))
		return result
	app.amount_modal({
		"kicker": str(d["tag"]).to_upper(),
		"title": str(d["name"]),
		"text": str(d["description"]),
		"tiles": [
			["CAPACIDADE RESTANTE", UI.short_money(room), UI.CYAN, "Quanto esta empresa ainda processa hoje."],
			["CUSTO", UI.pct_short(loss * 100.0), UI.ORANGE, "A parte do valor que se perde."],
			["RISCO NO TETO", UI.signed(risk), UI.RED, "Suspeita ao usar 100% da capacidade do dia."]
		],
		"field": "VALOR DA OPERAÇÃO",
		"max": limit,
		"value": limit,
		"preview": preview,
		"note": "O limite é o menor entre a capacidade restante da empresa e o seu saldo sujo.",
		"confirm": "EXECUTAR OPERAÇÃO",
		"icon": "play",
		"on_confirm": confirm
	})

func _confirm_buy(company_id: String) -> void:
	var d: Dictionary = GameManager.companies[company_id]
	app.confirm_modal({
		"kicker": "COMPRA DE EMPRESA",
		"title": str(d["name"]),
		"text": "%s\n\nPreço: %s do saldo limpo. A empresa processa %s por dia, com custo de %d%% e risco no teto de %s. O valor pago continua contando como patrimônio." % [str(d["description"]), UI.money(float(d["price"])), UI.money(float(d["capacity"])), int(round(float(d["loss"]) * 100.0)), UI.signed(float(d["risk"]))],
		"confirm": "COMPRAR",
		"on_confirm": func() -> void: report(GameManager.buy_company(company_id))
	})
