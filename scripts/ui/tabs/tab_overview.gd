extends "res://scripts/ui/tab_base.gd"
## Visão geral: os quatro números do turno, o volume por dia e a meta do ato.

func build() -> void:
	page_header("overview")
	var w: float = size.x
	var h: float = size.y
	var card_w: float = (w - UI.GAP * 3.0) / 4.0
	var stats: Array = [
		{"key": "dirty", "title": "SALDO SUJO", "value": GameManager.dirty_money, "fmt": UI.money, "color": UI.ORANGE, "icon": "money", "tip": "O que falta lavar. Chega uma remessa nova toda noite."},
		{"key": "clean", "title": "SALDO LIMPO", "value": GameManager.clean_money, "fmt": UI.money, "color": UI.GREEN, "icon": "clean", "tip": "O que você pode gastar agora."},
		{"key": "worth", "title": "PATRIMÔNIO", "value": GameManager.net_worth(), "fmt": UI.money, "color": UI.CYAN, "icon": "processed", "tip": "Saldo limpo + empresas + bens + carteira. É o que conta para a meta do ato."},
		{"key": "suspicion", "title": "SUSPEITA", "value": GameManager.suspicion, "fmt": UI.pct, "color": UI.risk_color(GameManager.suspicion), "icon": "risk", "tip": "No limite do ato, a campanha acaba."}
	]
	for i: int in range(stats.size()):
		_stat_card(stats[i] as Dictionary, Vector2(float(i) * (card_w + UI.GAP), UI.BODY_Y), Vector2(card_w, 112), i + 1)

	var row_y: float = UI.BODY_Y + 112.0 + UI.GAP
	var row_h: float = h - row_y
	var left_w: float = floorf((w - UI.GAP) * 0.60)
	var right_w: float = w - UI.GAP - left_w

	# Volume processado por dia, lido das transações reais.
	var chart_card: Panel = UI.card(self, Rect2(0, row_y, left_w, row_h), "Processado por turno", "Soma das operações de cada turno")
	UI.enter(chart_card, 5)
	var data: Dictionary = _daily_totals()
	if bool(data["any"]):
		var chart: W.BarChart = W.BarChart.new()
		chart.position = Vector2(UI.PAD, 66)
		chart.size = Vector2(left_w - UI.PAD * 2.0, row_h - 66.0 - 14.0)
		chart.values = data["values"]
		chart.labels = data["labels"]
		chart.texts = data["texts"]
		chart.highlight = (data["values"] as Array).size() - 1
		chart.bar_color = UI.CYAN
		chart.grid_color = Color("#302D28")
		chart.text_color = UI.WHITE
		chart.label_color = UI.MUTED
		chart.font = UI.font_mono
		chart_card.add_child(chart)
		if UI.can_anim():
			UI.tween_prop(chart, "progress", 0.0, 1.0, 0.9, 0.25)
	else:
		empty_state(chart_card, Rect2(0, 56, left_w, row_h - 56.0), "Nenhuma operação registrada ainda. O gráfico aparece depois da primeira.", "ABRIR EMPRESAS", "companies")

	if Campaign.escape_active:
		_escape_card(Rect2(left_w + UI.GAP, row_y, right_w, row_h))
		return
	_act_card(Rect2(left_w + UI.GAP, row_y, right_w, 178))
	_today_card(Rect2(left_w + UI.GAP, row_y + 178.0 + UI.GAP, right_w, row_h - 178.0 - UI.GAP))

func _stat_card(d: Dictionary, pos: Vector2, card_size: Vector2, order: int) -> void:
	var key: String = str(d["key"])
	var color: Color = d["color"]
	var fmt: Callable = d["fmt"]
	var value: float = float(d["value"])
	var card: Panel = UI.panel(self, pos, card_size)
	card.tooltip_text = str(d["tip"])
	UI.enter(card, order)
	card.add_child(UI.at(UI.caps(str(d["title"]), UI.MUTED), Vector2(UI.PAD, 14)))
	var icon: TextureRect = UI.icon_rect(str(d["icon"]), Vector2(card_size.x - UI.PAD - 18.0, 12), 18.0, Color(1, 1, 1, 0.7))
	if icon != null:
		card.add_child(icon)
	var value_label: Label = UI.mono("", 22, color)
	value_label.position = Vector2(UI.PAD, 32)
	card.add_child(value_label)
	UI.count(value_label, "ov_" + key, value, fmt)
	# Um ponto por dia da sessão, mais o valor de agora.
	var series: Array = (app.history[key] as Array).duplicate()
	series.append(value)
	UI.sparkline(card, Vector2(UI.PAD, 76), Vector2(card_size.x - UI.PAD * 2.0, 24), series, color)

## Meta e prazo do ato atual.
func _act_card(rect: Rect2) -> void:
	var data: Dictionary = Campaign.data()
	var card: Panel = UI.card(self, rect, "Ato %d" % Campaign.act, str(data["name"]))
	UI.enter(card, 6)
	var w: float = rect.size.x
	var ratio: float = Campaign.progress()
	var pct: Label = UI.mono("", 28, UI.GREEN)
	pct.position = Vector2(UI.PAD, 60)
	card.add_child(pct)
	UI.count(pct, "ov_goal", ratio * 100.0, func(v: float) -> String: return "%d%%" % int(v))
	card.add_child(UI.right(UI.label("%s de %s" % [UI.short_money(GameManager.net_worth()), UI.short_money(Campaign.goal())], 12, UI.MUTED), Vector2(UI.PAD, 72), w - UI.PAD * 2.0))
	UI.bar(card, Vector2(UI.PAD, 106), w - UI.PAD * 2.0, ratio, UI.GREEN, "bar_ov_goal", 10.0)
	var missing: float = maxf(0.0, Campaign.goal() - GameManager.net_worth())
	var left: int = Campaign.days_left() + 1
	var note: String = "Meta batida. Finalize o turno para avançar de ato."
	var note_color: Color = UI.GREEN
	if missing > 0.0:
		note = "Faltam %s e %s." % [UI.short_money(missing), "este é o último turno" if left <= 1 else "%d turnos" % left]
		note_color = UI.MUTED
		if left <= 3:
			note_color = UI.ORANGE
		note += " Ritmo: %s por turno." % UI.short_money(missing / float(maxi(1, left)))
	var note_label: Label = UI.label(note, 12, note_color)
	UI.clip(note_label, Vector2(UI.PAD, 126), Vector2(w - UI.PAD * 2.0, 18))
	card.add_child(note_label)
	card.add_child(UI.at(UI.caps("AMEAÇA: " + str(data["threat"]).to_upper(), UI.RED), Vector2(UI.PAD, 150)))
	if not Missions.objectives.is_empty():
		var objectives: Label = UI.caps("OBJETIVOS %d / %d" % [Missions.objectives_done(), Missions.objectives.size()], UI.CYAN)
		card.add_child(UI.right(objectives, Vector2(UI.PAD, 150), w - UI.PAD * 2.0))

## Números do dia: o que entra à noite, o que ainda dá para processar, o que custa.
func _today_card(rect: Rect2) -> void:
	var card: Panel = UI.card(self, rect, "Hoje")
	UI.enter(card, 7)
	var capacity: float = 0.0
	var room: float = 0.0
	for company_id: String in GameManager.owned_ids():
		capacity += GameManager.capacity_of(company_id)
		room += GameManager.remaining_capacity(company_id)
	var rows: Array = [
		["Remessa desta noite", "+ " + UI.short_money(Campaign.remessa()), UI.ORANGE],
		["Capacidade restante", "%s de %s" % [UI.short_money(room), UI.short_money(capacity)], UI.CYAN],
		["Folha dos laranjas", "- " + UI.short_money(Staff.daily_cost()), UI.WHITE],
		["Prestígio", Lifestyle.prestige_name(), UI.WHITE]
	]
	if Campaign.act >= 2:
		rows.append(["Influência política", "%d de %d" % [GameManager.influence, B.INFLUENCE_MAX], UI.WHITE])
	# Em janelas baixas, o cartão encolhe: as linhas se aproximam e, se preciso, as últimas somem.
	var row_step: float = clampf((rect.size.y - 52.0) / float(rows.size()), 30.0, 36.0)
	var last_y: float = 46.0
	for i: int in range(rows.size()):
		var line_y: float = 46.0 + float(i) * row_step
		if line_y + 30.0 > rect.size.y:
			break
		UI.kv_row(card, line_y, rect.size.x, str(rows[i][0]), str(rows[i][1]), rows[i][2])
		last_y = line_y

	# Plano do turno: as pendências do dia, na ordem em que costumam ser resolvidas.
	var plan_y: float = last_y + row_step + 6.0
	if plan_y + 24.0 <= rect.size.y:
		card.add_child(UI.at(UI.caps("PLANO DO TURNO", UI.MUTED), Vector2(UI.PAD, plan_y - 6.0)))
		var step_y: float = plan_y + 14.0
		for step_v: Variant in _turn_plan():
			if step_y + 20.0 > rect.size.y:
				break
			var step: Dictionary = step_v as Dictionary
			var done: bool = bool(step["done"])
			var mark: String = "✓" if done else "→"
			var color: Color = UI.DIM if done else (UI.RED if bool(step.get("urgent", false)) else UI.CYAN)
			card.add_child(UI.at(UI.caps(mark, color, 12), Vector2(UI.PAD, step_y)))
			var label: Label = UI.label(str(step["text"]), 12, UI.MUTED if done else UI.WHITE)
			UI.clip(label, Vector2(UI.PAD + 22.0, step_y - 2.0), Vector2(rect.size.x - UI.PAD * 2.0 - 22.0, 18))
			card.add_child(label)
			step_y += 20.0

## As pendências do dia, em ordem de prioridade. Cada item é {text, done, urgent}.
func _turn_plan() -> Array:
	var plan: Array = []
	var room: float = 0.0
	for company_id: String in GameManager.owned_ids():
		room += GameManager.remaining_capacity(company_id)
	var dirty_left: bool = GameManager.dirty_money >= B.MIN_OPERATION and room >= B.MIN_OPERATION
	plan.append({"text": "Processar %s de saldo sujo" % UI.short_money(minf(GameManager.dirty_money, room)), "done": not dirty_left, "urgent": dirty_left})
	if GameManager.suspicion >= B.STAFF_STRESS_LEVEL:
		plan.append({"text": "Baixar a suspeita (%d%%): laranjas estão se estressando" % int(GameManager.suspicion), "done": false, "urgent": true})
	else:
		plan.append({"text": "Suspeita sob controle (%d%%)" % int(GameManager.suspicion), "done": true})
	var offers: int = Missions.offered_contracts().size()
	var delating: int = Staff.delating().size()
	if delating > 0:
		plan.append({"text": "%d laranja(ns) negociando delação: intervenha" % delating, "done": false, "urgent": true})
	if offers > 0:
		plan.append({"text": "%d contrato(s) disponível(is) na aba Missões" % offers, "done": false})
	if Missions.objectives_done() < Missions.objectives.size():
		plan.append({"text": "Objetivos do ato: %d de %d concluídos" % [Missions.objectives_done(), Missions.objectives.size()], "done": false})
	if Campaign.goal_reached():
		plan.append({"text": "Meta do ato batida: finalize para avançar", "done": false, "urgent": true})
	plan.append({"text": "Finalizar o turno", "done": false})
	return plan

func _escape_card(rect: Rect2) -> void:
	var card: Panel = UI.card(self, rect, "Operação Fuga", "Só o Monero sai do país com você")
	UI.enter(card, 6)
	var rows: Array = [
		["Horas restantes", "%d h" % int(round(Campaign.escape_hours)), UI.VIOLET],
		["Monero convertido", UI.short_money(Portfolio.monero), UI.VIOLET],
		["Saldo limpo a converter", UI.short_money(GameManager.clean_money), UI.GREEN],
		["Passaporte", "garantido" if Campaign.passport != "" else "falta", UI.GREEN if Campaign.passport != "" else UI.RED],
		["Avião", "contratado" if Campaign.jet != "" else "falta", UI.GREEN if Campaign.jet != "" else UI.RED],
		["Chance de interceptação", "%d%%" % int(round(Campaign.interception_chance())), UI.RED]
	]
	for i: int in range(rows.size()):
		var line_y: float = 62.0 + float(i) * 36.0
		if line_y + 30.0 > rect.size.y:
			break
		UI.kv_row(card, line_y, rect.size.x, str(rows[i][0]), str(rows[i][1]), rows[i][2])

## Soma das transações por dia (últimos max_days dias de campanha).
func _daily_totals(max_days: int = 10) -> Dictionary:
	var by_day: Dictionary = {}
	for tx_v: Variant in GameManager.transactions:
		var tx: Dictionary = tx_v as Dictionary
		var day: int = int(tx.get("day", 0))
		by_day[day] = float(by_day.get(day, 0.0)) + float(tx.get("amount", 0.0))
	var last_day: int = maxi(GameManager.day_total, 1)
	var first_day: int = maxi(1, last_day - max_days + 1)
	var values: Array = []
	var labels: Array = []
	var texts: Array = []
	for day: int in range(first_day, last_day + 1):
		var total: float = float(by_day.get(day, 0.0))
		values.append(total)
		labels.append("D%02d" % day)
		texts.append(UI.short_number(total))
	return {"values": values, "labels": labels, "texts": texts, "any": not by_day.is_empty()}
