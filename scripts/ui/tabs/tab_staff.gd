extends "res://scripts/ui/tab_base.gd"
## Laranjas e operadores: a rede contratada, os candidatos do dia e as delações.

func build() -> void:
	page_header("staff")
	Staff.ensure_candidates()
	var w: float = size.x
	var h: float = size.y
	var suspicion: float = GameManager.suspicion
	var stressed: bool = suspicion > B.STAFF_STRESS_LEVEL

	var capacity: float = 0.0
	var free_slots: int = 0
	for company_id: String in GameManager.owned_ids():
		capacity += Staff.capacity_bonus(company_id)
		free_slots += Staff.slots_free(company_id)
	var tiles: HBoxContainer = HBoxContainer.new()
	tiles.position = Vector2(0, UI.BODY_Y)
	tiles.size = Vector2(w, 66)
	tiles.add_theme_constant_override("separation", int(UI.GAP))
	add_child(tiles)
	UI.enter(tiles, 1)
	tiles.add_child(UI.tile("NA REDE", "%d  (%d vagas livres)" % [Staff.roster.size(), free_slots], UI.WHITE, "Laranjas contratados e vagas ainda abertas nas suas empresas.", 18))
	tiles.add_child(UI.tile("FOLHA POR NOITE", UI.money(Staff.daily_cost()), UI.ORANGE, "Sai do saldo limpo toda noite. Se faltar, sai do sujo.", 18))
	tiles.add_child(UI.tile("CAPACIDADE SOMADA", "+ " + UI.short_money(capacity) + " por dia", UI.CYAN, "O quanto a rede aumenta o teto diário das empresas.", 18))
	tiles.add_child(UI.tile("ESTRESSE DA REDE", "SUBINDO" if stressed else "ALIVIANDO", UI.RED if stressed else UI.GREEN, "Com a suspeita acima de %d%%, o estresse sobe toda noite. Hoje ela está em %s." % [int(B.STAFF_STRESS_LEVEL), UI.pct(suspicion)], 18))

	var top: float = UI.BODY_Y + 66.0 + UI.GAP
	var body_h: float = h - top
	var left_w: float = floorf((w - UI.GAP) * 0.61)
	var right_w: float = w - UI.GAP - left_w
	_roster_card(Rect2(0, top, left_w, body_h))
	_candidates_card(Rect2(left_w + UI.GAP, top, right_w, body_h))

# ---------- rede contratada ----------

func _roster_card(rect: Rect2) -> void:
	var card: Panel = UI.card(self, rect, "Sua rede", "Quem empresta o nome, e o quanto cada um aguenta")
	UI.enter(card, 2)
	if Staff.roster.is_empty():
		empty_state(card, Rect2(0, 56, rect.size.x, rect.size.y - 56.0), "Ninguém na rede ainda. Um laranja aumenta a capacidade de uma empresa sem aumentar o risco no teto.")
		return
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.position = Vector2(1, 58)
	scroll.size = Vector2(rect.size.x - 2.0, rect.size.y - 62.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card.add_child(scroll)
	var list: VBoxContainer = VBoxContainer.new()
	list.add_theme_constant_override("separation", 0)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	# Quem está delatando aparece primeiro; depois, do mais estressado ao mais calmo.
	var members: Array = Staff.roster.duplicate()
	members.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if (int(a["delation"]) >= 0) != (int(b["delation"]) >= 0):
			return int(a["delation"]) >= 0
		return float(a["stress"]) > float(b["stress"]))
	for i: int in range(members.size()):
		var row: Control = _member_row(members[i] as Dictionary, rect.size.x - 14.0)
		list.add_child(row)
		if i < 10:
			UI.fade(row, i + 3)

func _member_row(member: Dictionary, width: float) -> Control:
	var staff_id: int = int(member["id"])
	var delating: bool = int(member["delation"]) >= 0
	var stress: float = float(member["stress"])
	var row: Control = Control.new()
	row.custom_minimum_size = Vector2(0, 66)
	if delating:
		var alert: ColorRect = ColorRect.new()
		alert.size = Vector2(width + 12.0, 65)
		alert.color = Color(UI.RED, 0.10)
		alert.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(alert)
	UI.rule(row, Vector2(UI.PAD, 65), width - UI.PAD, Color("#1A2B36"))

	var company_name: String = "sem empresa"
	if GameManager.companies.has(str(member["company"])):
		company_name = str(GameManager.companies[str(member["company"])]["name"])
	var name_label: Label = UI.bold(str(member["name"]), 14, UI.WHITE)
	UI.clip(name_label, Vector2(UI.PAD, 10), Vector2(width * 0.34, 20))
	row.add_child(name_label)
	var role: Label = UI.caps("%s / %s" % [str(member["title"]).to_upper(), company_name.to_upper()], UI.MUTED)
	UI.clip(role, Vector2(UI.PAD, 34), Vector2(width * 0.36, 14))
	row.add_child(role)

	var x: float = width * 0.38
	row.add_child(UI.at(UI.mono("+" + UI.short_money(float(member["capacity"])), 13, UI.CYAN if not delating else UI.MUTED), Vector2(x, 10)))
	row.add_child(UI.at(UI.caps(UI.money(float(member["cost"])) + " / NOITE", UI.MUTED), Vector2(x, 34)))

	if delating:
		var nights: int = int(member["delation"])
		var warning: Label = UI.mono("DELAÇÃO: ACORDO EM %d NOITE(S)" % nights, 12, UI.RED)
		warning.position = Vector2(width * 0.56, 12)
		row.add_child(warning)
		UI.pulse(warning, 0.5, 1.0)
		row.add_child(UI.at(UI.caps("SEM INTERVENÇÃO, VOCÊ É PRESO", UI.RED), Vector2(width * 0.56, 34)))
		var act: Button = UI.button_at(row, Vector2(width - 96.0, 14), Vector2(96, 36), "INTERVIR", func() -> void: _open_member(staff_id), true)
		UI.style_button(act, "danger")
		return row

	var meter_w: float = width * 0.14
	var lx: float = width * 0.56
	row.add_child(UI.at(UI.caps("LEALDADE %d" % int(float(member["loyalty"])), UI.MUTED), Vector2(lx, 11)))
	UI.bar(row, Vector2(lx, 30), meter_w, float(member["loyalty"]) / 100.0, UI.CYAN, "", 5.0)
	var sx: float = lx + meter_w + 16.0
	var stress_color: Color = UI.GREEN if stress < 50.0 else (UI.ORANGE if stress < 80.0 else UI.RED)
	row.add_child(UI.at(UI.caps("ESTRESSE %d" % int(stress), stress_color), Vector2(sx, 11)))
	UI.bar(row, Vector2(sx, 30), meter_w, stress / 100.0, stress_color, "", 5.0)
	var forecast: float = Staff.stress_forecast(member)
	row.add_child(UI.at(UI.caps("%+d POR NOITE" % int(round(forecast)), UI.RED if forecast > 0.0 else UI.GREEN, 9), Vector2(sx, 42)))
	UI.button_at(row, Vector2(width - 84.0, 14), Vector2(84, 36), "GERIR", func() -> void: _open_member(staff_id))
	return row

## Modal de um laranja: agrado e dispensa, ou as saídas de uma delação.
func _open_member(staff_id: int) -> void:
	var member: Dictionary = Staff.find(staff_id)
	if member.is_empty():
		return
	var width: float = 600.0
	var delating: bool = int(member["delation"]) >= 0
	var col: VBoxContainer = app.open_modal(width + 52.0, UI.RED if delating else UI.CYAN)
	var company_name: String = "sem empresa"
	if GameManager.companies.has(str(member["company"])):
		company_name = str(GameManager.companies[str(member["company"])]["name"])
	app.modal_header(col, "%s / %s" % [str(member["title"]).to_upper(), company_name.to_upper()], str(member["name"]), UI.RED if delating else UI.CYAN)

	var tiles: HBoxContainer = HBoxContainer.new()
	tiles.add_theme_constant_override("separation", 10)
	col.add_child(tiles)
	tiles.add_child(UI.tile("CAPACIDADE", "+" + UI.short_money(float(member["capacity"])), UI.CYAN, "O que ele soma por dia à empresa."))
	tiles.add_child(UI.tile("DIÁRIA", UI.money(float(member["cost"])), UI.ORANGE, "Paga toda noite."))
	tiles.add_child(UI.tile("LEALDADE", str(int(float(member["loyalty"]))), UI.WHITE, "Quanto maior, mais devagar o estresse sobe."))
	tiles.add_child(UI.tile("ESTRESSE", str(int(float(member["stress"]))), UI.RED if float(member["stress"]) >= 80.0 else UI.WHITE, "Em 100, ele procura a Polícia Federal."))

	if delating:
		col.add_child(UI.paragraph("Ele está negociando com a Polícia Federal. O acordo fecha em %d noite(s). Enquanto isso, ele não trabalha." % int(member["delation"]), 14, UI.INK_2, width))
		for option_v: Variant in Staff.delation_options(member):
			col.add_child(_option_row(option_v as Dictionary, width))
		return

	var forecast: float = Staff.stress_forecast(member)
	var outlook: String = "Com a suspeita atual, o estresse dele sobe %d por noite." % int(round(forecast))
	if forecast <= 0.0:
		outlook = "Com a suspeita abaixo de %d%%, o estresse dele cai %d por noite." % [int(B.STAFF_STRESS_LEVEL), int(-forecast)]
	col.add_child(UI.paragraph(outlook, 14, UI.INK_2, width))
	var bonus_cost: float = Staff.bonus_cost(member)
	var dismiss_cost: float = Staff.dismiss_cost(member)
	col.add_child(_option_row({
		"label": "DAR UM AGRADO",
		"detail": "%s do saldo limpo. Estresse -%d, lealdade +%d." % [UI.money(bonus_cost), int(B.STAFF_BONUS_STRESS), int(B.STAFF_BONUS_LOYALTY)],
		"enabled": GameManager.clean_money >= bonus_cost,
		"action": func() -> Dictionary: return Staff.give_bonus(staff_id)
	}, width))
	col.add_child(_option_row({
		"label": "DISPENSAR",
		"detail": "%s de acerto. A vaga fica livre e a empresa perde a capacidade dele." % UI.money(dismiss_cost),
		"enabled": GameManager.clean_money >= dismiss_cost,
		"danger": true,
		"action": func() -> Dictionary: return Staff.dismiss(staff_id)
	}, width))

## Uma opção de decisão: botão à esquerda, consequência escrita à direita.
func _option_row(option: Dictionary, width: float) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var action: Callable = option["action"]
	var button: Button = UI.button(str(option["label"]), func() -> void:
		app.close_modal(true)
		report(action.call())
	, Vector2(230, 44), not bool(option.get("danger", false)))
	if bool(option.get("danger", false)):
		UI.style_button(button, "danger")
	if not bool(option.get("enabled", true)):
		UI.disable(button, "Você não tem o que esta opção exige.")
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(button)
	var detail: Label = UI.paragraph(str(option.get("detail", "")), 13, UI.INK_2 if bool(option.get("enabled", true)) else UI.DIM, width - 244.0)
	detail.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(detail)
	return row

# ---------- candidatos ----------

func _candidates_card(rect: Rect2) -> void:
	var card: Panel = UI.card(self, rect, "Candidatos de hoje", "A lista muda toda manhã")
	UI.enter(card, 3)
	var w: float = rect.size.x
	if Staff.candidates.is_empty():
		empty_state(card, Rect2(0, 56, w, rect.size.y - 56.0), "Todos os candidatos de hoje já foram contratados. Amanhã aparecem outros.")
		return
	var free_slots: int = 0
	for company_id: String in GameManager.owned_ids():
		free_slots += Staff.slots_free(company_id)
	var gap: float = 10.0
	var count: int = Staff.candidates.size()
	var item_h: float = minf(118.0, (rect.size.y - 62.0 - gap * float(count - 1) - 10.0) / float(count))
	for i: int in range(count):
		var candidate: Dictionary = Staff.candidates[i]
		var candidate_id: int = int(candidate["id"])
		var fee: float = Staff.hire_fee(candidate)
		var item: Panel = UI.panel(card, Vector2(UI.PAD, 60.0 + float(i) * (item_h + gap)), Vector2(w - UI.PAD * 2.0, item_h), UI.SURFACE, UI.LINE)
		var iw: float = w - UI.PAD * 2.0
		item.add_child(UI.at(UI.bold(str(candidate["name"]), 15, UI.WHITE), Vector2(14, 10)))
		var chip: PanelContainer = UI.chip(str(candidate["title"]).to_upper(), UI.CYAN if int(candidate["tier"]) >= Campaign.act else UI.MUTED)
		chip.position = Vector2(14, 36)
		item.add_child(chip)
		item.add_child(UI.right(UI.mono("+" + UI.short_money(float(candidate["capacity"])), 16, UI.CYAN), Vector2(14, 8), iw - 28.0))
		item.add_child(UI.right(UI.caps("POR DIA", UI.MUTED), Vector2(14, 32), iw - 28.0))
		var facts: Label = UI.caps("DIÁRIA %s  /  LEALDADE %d" % [UI.money(float(candidate["cost"])), int(float(candidate["loyalty"]))], UI.INK_2)
		facts.position = Vector2(14, item_h - 46.0)
		item.add_child(facts)
		item.add_child(UI.at(UI.caps("TAXA DE CONTRATAÇÃO: " + UI.money(fee), UI.MUTED), Vector2(14, item_h - 26.0)))
		var hire: Button = UI.button_at(item, Vector2(iw - 126.0, item_h - 46.0), Vector2(112, 34), "CONTRATAR", func() -> void: _open_hire(candidate_id), true)
		if free_slots <= 0:
			UI.disable(hire, "Não há vaga livre nas suas empresas.")
		elif fee > GameManager.clean_money:
			UI.disable(hire, "Faltam %s para a taxa de contratação." % UI.money(fee - GameManager.clean_money))

## Escolha da empresa onde o candidato vai trabalhar.
func _open_hire(candidate_id: int) -> void:
	var candidate: Dictionary = {}
	for candidate_v: Variant in Staff.candidates:
		if int((candidate_v as Dictionary)["id"]) == candidate_id:
			candidate = candidate_v
	if candidate.is_empty():
		return
	var width: float = 560.0
	var col: VBoxContainer = app.open_modal(width + 52.0)
	app.modal_header(col, "CONTRATAR " + str(candidate["title"]).to_upper(), str(candidate["name"]))
	col.add_child(UI.paragraph("Ele soma %s por dia à empresa escolhida, cobra %s por noite e a taxa de contratação é de %s. Onde ele vai trabalhar?" % [UI.money(float(candidate["capacity"])), UI.money(float(candidate["cost"])), UI.money(Staff.hire_fee(candidate))], 14, UI.INK_2, width))
	for company_id_v: Variant in GameManager.owned_ids():
		var company_id: String = str(company_id_v)
		var free: int = Staff.slots_free(company_id)
		var before: float = GameManager.capacity_of(company_id)
		var company: Dictionary = GameManager.companies[company_id]
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		col.add_child(row)
		var pick: Button = UI.button(str(company["name"]).to_upper(), func() -> void:
			app.close_modal(true)
			report(Staff.hire(candidate_id, company_id))
		, Vector2(250, 42), free > 0, company_id)
		if free <= 0:
			UI.disable(pick, "Todas as vagas desta empresa estão ocupadas.")
		row.add_child(pick)
		var detail: Label = UI.label("Sem vaga" if free <= 0 else "%s  >  %s por dia  /  %d vaga(s)" % [UI.short_money(before), UI.short_money(before + float(candidate["capacity"])), free], 13, UI.DIM if free <= 0 else UI.INK_2)
		detail.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(detail)
