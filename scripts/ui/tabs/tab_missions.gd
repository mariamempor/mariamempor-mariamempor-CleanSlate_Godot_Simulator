extends "res://scripts/ui/tab_base.gd"
## Missões: o objetivo principal do ato, os objetivos secundários e os
## contratos do cliente, com progresso, recompensa e estado.

const MD = preload("res://scripts/data/missions_data.gd")

func build() -> void:
	page_header("missions")
	var w: float = size.x
	var h: float = size.y
	_main_goal(Rect2(0, UI.BODY_Y, w, 92))
	var top: float = UI.BODY_Y + 92.0 + UI.GAP
	var left_w: float = floorf((w - UI.GAP) * 0.57)
	_objectives_card(Rect2(0, top, left_w, h - top))
	_contracts_card(Rect2(left_w + UI.GAP, top, w - UI.GAP - left_w, h - top))

# ---------- objetivo principal e progresso da campanha ----------

func _main_goal(rect: Rect2) -> void:
	var panel: Panel = UI.panel(self, rect.position, rect.size)
	UI.enter(panel, 1)
	var w: float = rect.size.x
	var data: Dictionary = Campaign.data()
	panel.add_child(UI.at(UI.caps("OBJETIVO PRINCIPAL  /  ATO %d" % Campaign.act, UI.CYAN), Vector2(UI.PAD, 14)))
	panel.add_child(UI.at(UI.bold("Chegar a %s de patrimônio" % UI.money(Campaign.goal()), 17, UI.WHITE), Vector2(UI.PAD, 32)))
	var worth: float = GameManager.net_worth()
	var share: float = Campaign.progress()
	var bar_w: float = w * 0.46
	UI.bar(panel, Vector2(UI.PAD, 64), bar_w, share, UI.GREEN if share >= 1.0 else UI.CYAN, "bar_ms_goal", 8.0)
	panel.add_child(UI.right(UI.mono("%s  /  %d%%" % [UI.short_money(worth), int(share * 100.0)], 13, UI.INK_2), Vector2(UI.PAD, 34), bar_w))
	var turn_text: String = "Turno %d de %d" % [GameManager.current_day, GameManager.total_days]
	if Campaign.escape_active:
		turn_text = "Operação Fuga"
	panel.add_child(UI.at(UI.caps(turn_text.to_upper() + "  /  O ATO ACABA ASSIM QUE A META FOR BATIDA", UI.MUTED, 9), Vector2(UI.PAD + bar_w + 24.0, 18)))
	# Os três atos da campanha, com o atual em destaque.
	var x: float = UI.PAD + bar_w + 24.0
	var pill_w: float = (w - x - UI.PAD - 16.0) / 3.0
	for i: int in range(B.ACTS.size()):
		var act_n: int = i + 1
		var done: bool = act_n < Campaign.act or (act_n == Campaign.act and Campaign.escape_active)
		var current: bool = act_n == Campaign.act and not Campaign.escape_active
		var color: Color = UI.GREEN if done else (UI.CYAN if current else UI.DIM)
		var pill: Panel = UI.panel(panel, Vector2(x + float(i) * (pill_w + 8.0), 38), Vector2(pill_w, 44), Color(color, 0.10) if done or current else UI.SURFACE, Color(color, 0.6) if done or current else UI.LINE)
		pill.add_child(UI.at(UI.caps("ATO %d%s" % [act_n, "  /  FEITO" if done else ("  /  AGORA" if current else "")], color, 9), Vector2(10, 6)))
		var name_label: Label = UI.bold(str(B.ACTS[i]["name"]), 11, UI.WHITE if done or current else UI.MUTED)
		pill.add_child(UI.clip(name_label, Vector2(10, 20), Vector2(pill_w - 20.0, 16)))
	panel.tooltip_text = str(data["identity"])

# ---------- objetivos do ato ----------

func _objectives_card(rect: Rect2) -> void:
	var done: int = Missions.objectives_done()
	var total: int = Missions.objectives.size()
	var card: Panel = UI.card(self, rect, "Objetivos do ato", "%d de %d concluídos  /  sorteados para esta partida" % [done, total])
	UI.enter(card, 2)
	var w: float = rect.size.x
	if Missions.objectives.is_empty():
		empty_state(card, Rect2(0, 56, w, rect.size.y - 56.0), "Os objetivos do ato aparecem quando a campanha começa.")
		return
	var footer_h: float = 34.0
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.position = Vector2(1, 58)
	scroll.size = Vector2(w - 2.0, rect.size.y - 62.0 - footer_h)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card.add_child(scroll)
	var list: VBoxContainer = VBoxContainer.new()
	list.add_theme_constant_override("separation", 0)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for i: int in range(Missions.objectives.size()):
		var obj: Dictionary = Missions.objectives[i]
		var row: Control = _objective_row(Missions.data(str(obj["id"])), str(obj["state"]) == "done", w - 14.0)
		list.add_child(row)
		if i < 6:
			UI.fade(row, i + 3)
	# Rodapé: o bônus de completar tudo.
	var perfect: bool = bool(Missions.counters.get("perfect", false))
	var foot: Label = UI.paragraph(("ATO IMPECÁVEL CONQUISTADO: " if perfect else "CONCLUA TODOS PARA O ATO IMPECÁVEL: ") + Missions.reward_text(MD.PERFECT_BONUS).to_upper(), 9, UI.GREEN if perfect else UI.MUTED, w - UI.PAD * 2.0)
	foot.position = Vector2(UI.PAD, rect.size.y - footer_h + 4.0)
	card.add_child(foot)

func _objective_row(mission: Dictionary, done: bool, width: float) -> Control:
	var row: Control = Control.new()
	var desc: Label = UI.paragraph(Missions.describe(mission), 12, UI.INK_2 if not done else UI.MUTED, width - UI.PAD * 2.0 - 150.0)
	var desc_h: float = maxf(16.0, UI.text_height(desc, width - UI.PAD * 2.0 - 150.0))
	var h: float = 64.0 + desc_h
	row.custom_minimum_size = Vector2(0, h)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.rule(row, Vector2(UI.PAD, h - 1.0), width - UI.PAD * 2.0, Color("#2C2924"))
	var chip: PanelContainer = UI.chip("CONCLUÍDA" if done else "EM ANDAMENTO", UI.GREEN if done else UI.CYAN)
	chip.position = Vector2(UI.PAD, 10)
	row.add_child(chip)
	var title: Label = UI.bold(str(mission["title"]), 14, UI.WHITE if not done else UI.MUTED)
	row.add_child(UI.clip(title, Vector2(UI.PAD + 118.0, 9), Vector2(width - UI.PAD * 2.0 - 118.0 - 150.0, 20)))
	desc.position = Vector2(UI.PAD, 32)
	row.add_child(desc)
	var target: float = float(mission["target"])
	var value: float = minf(Missions.progress_of(mission), target) if not done else target
	var money: bool = str(mission["text"]).contains("{target_money}")
	var y: float = 38.0 + desc_h
	UI.bar(row, Vector2(UI.PAD, y + 4.0), width * 0.34, value / maxf(target, 1.0), UI.GREEN if done else UI.CYAN, "", 5.0)
	var amount: String = ("%s / %s" % [UI.short_money(value), UI.short_money(target)]) if money else ("%d / %d" % [int(value), int(target)])
	row.add_child(UI.at(UI.mono(amount, 11, UI.INK_2), Vector2(UI.PAD + width * 0.34 + 10.0, y - 3.0)))
	var reward: Label = UI.caps("RECOMPENSA: " + Missions.reward_text(mission["reward"]).to_upper(), UI.GREEN if done else UI.ORANGE, 9)
	row.add_child(UI.clip(reward, Vector2(UI.PAD + width * 0.34 + 110.0, y - 1.0), Vector2(width - UI.PAD * 2.0 - width * 0.34 - 110.0, 14)))
	# Objetivo com ação própria (financiar uma etapa).
	if mission.has("action") and not done:
		var mission_id: String = str(mission["id"])
		var label: String = "%s  %s" % [str((mission["action"] as Dictionary)["label"]), UI.short_money(Missions.action_cost(mission))]
		var act_button: Button = UI.button_at(row, Vector2(width - UI.PAD - 140.0, 10), Vector2(140, 34), label, func() -> void: report(Missions.run_action(mission_id)), true)
		var block: String = Missions.can_act(mission)
		if block != "":
			UI.disable(act_button, block)
	return row

# ---------- contratos ----------

func _contracts_card(rect: Rect2) -> void:
	var offered: Array = Missions.offered_contracts()
	var active: Array = Missions.active_contracts()
	var card: Panel = UI.card(self, rect, "Contratos do cliente", "Pedidos avulsos, com prazo e recompensa")
	UI.enter(card, 3)
	var w: float = rect.size.x
	var perks_h: float = 74.0
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.position = Vector2(1, 58)
	scroll.size = Vector2(w - 2.0, rect.size.y - 62.0 - perks_h)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card.add_child(scroll)
	var list: VBoxContainer = VBoxContainer.new()
	list.add_theme_constant_override("separation", 0)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var shown: int = 0
	for c_v: Variant in active + offered:
		list.add_child(_contract_row(c_v as Dictionary, w - 14.0))
		shown += 1
	for c_v: Variant in Missions.contracts:
		var c: Dictionary = c_v as Dictionary
		if shown >= 5:
			break
		if str(c["state"]) == "done" or str(c["state"]) == "failed":
			list.add_child(_contract_row(c, w - 14.0))
			shown += 1
	if shown == 0:
		empty_state(card, Rect2(0, 56, w, rect.size.y - 56.0 - perks_h), "Nenhum contrato agora. O cliente oferece um a cada %d turnos, mais ou menos." % B.CONTRACT_INTERVAL)
	_perks(card, Rect2(0, rect.size.y - perks_h, w, perks_h))

func _contract_row(c: Dictionary, width: float) -> Control:
	var state: String = str(c["state"])
	var row: Control = Control.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var compact: bool = state == "done" or state == "failed"
	var text_w: float = width - UI.PAD * 2.0
	var desc: Label = UI.paragraph(str(c["text"]), 12, UI.INK_2, text_w)
	var desc_h: float = 0.0 if compact else UI.text_height(desc, text_w)
	var h: float = (40.0 if compact else 92.0 + desc_h)
	row.custom_minimum_size = Vector2(0, h)
	UI.rule(row, Vector2(UI.PAD, h - 1.0), width - UI.PAD * 2.0, Color("#2C2924"))
	var labels: Dictionary = {"offered": ["DISPONÍVEL", UI.ORANGE], "active": ["EM ANDAMENTO", UI.CYAN], "done": ["CONCLUÍDA", UI.GREEN], "failed": ["FALHOU", UI.RED]}
	var tag: Array = labels.get(state, ["", UI.MUTED])
	var chip: PanelContainer = UI.chip(str(tag[0]), tag[1])
	chip.position = Vector2(UI.PAD, 10)
	row.add_child(chip)
	var title: Label = UI.bold(str(c["title"]), 14, UI.WHITE if not compact else UI.MUTED)
	row.add_child(UI.clip(title, Vector2(UI.PAD + 118.0, 9), Vector2(text_w - 118.0, 20)))
	if compact:
		return row
	desc.position = Vector2(UI.PAD, 34)
	row.add_child(desc)
	var y: float = 40.0 + desc_h
	var reward: Label = UI.caps("RECOMPENSA: " + Missions.reward_text(c["reward"]).to_upper(), UI.GREEN, 9)
	row.add_child(UI.clip(reward, Vector2(UI.PAD, y), Vector2(text_w, 14)))
	var penalty: Label = UI.caps("SE FALHAR: " + Missions.reward_text(c["penalty"]).to_upper(), UI.RED, 9)
	row.add_child(UI.clip(penalty, Vector2(UI.PAD, y + 15.0), Vector2(text_w, 14)))
	var uid: int = int(c["uid"])
	if state == "offered":
		row.add_child(UI.at(UI.caps("OFERTA VALE ATÉ O TURNO %d" % (int(c["offered_until"]) - GameManager.day_total + GameManager.current_day), UI.MUTED, 9), Vector2(UI.PAD, y + 40.0)))
		var accept: Button = UI.button_at(row, Vector2(width - UI.PAD - 196.0, y + 32.0), Vector2(100, 32), "ACEITAR", func() -> void: report(Missions.accept_contract(uid)), true)
		if not Missions.active_contracts().is_empty():
			UI.disable(accept, "Termine o contrato em andamento antes.")
		UI.button_at(row, Vector2(width - UI.PAD - 88.0, y + 32.0), Vector2(88, 32), "RECUSAR", func() -> void: report(Missions.decline_contract(uid)))
	else:
		var share: float = clampf(float(c["progress"]) / maxf(float(c["target"]), 1.0), 0.0, 1.0)
		UI.bar(row, Vector2(UI.PAD, y + 40.0), text_w * 0.55, share, UI.CYAN, "", 5.0)
		var left: int = int(c["deadline"]) - GameManager.day_total + 1
		row.add_child(UI.right(UI.caps("%d%%  /  %s" % [int(share * 100.0), "ÚLTIMO TURNO" if left <= 1 else "FALTAM %d TURNOS" % left], UI.ORANGE if left <= 1 else UI.INK_2, 9), Vector2(UI.PAD, y + 35.0), text_w))
	return row

func _perks(card: Panel, rect: Rect2) -> void:
	UI.rule(card, Vector2(UI.PAD, rect.position.y), rect.size.x - UI.PAD * 2.0, UI.LINE)
	card.add_child(UI.at(UI.caps("VANTAGENS CONQUISTADAS", UI.CYAN), Vector2(UI.PAD, rect.position.y + 10.0)))
	var parts: Array[String] = []
	for perk_id: String in Missions.perks:
		var text: String = Missions.perk_text({"id": perk_id, "value": Missions.perk(perk_id)})
		if text != "":
			parts.append(text)
	for company_id: String in Missions.unlocked:
		parts.append("%s liberada antes do ato" % str(GameManager.companies[company_id]["name"]))
	var line: Label = UI.paragraph("  /  ".join(parts) if not parts.is_empty() else "Nenhuma ainda. Objetivos com vantagem valem até o fim da campanha.", 11, UI.INK_2 if not parts.is_empty() else UI.MUTED, rect.size.x - UI.PAD * 2.0)
	line.position = Vector2(UI.PAD, rect.position.y + 28.0)
	card.add_child(line)
