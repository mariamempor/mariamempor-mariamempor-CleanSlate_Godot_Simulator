extends "res://scripts/ui/tab_base.gd"
## Risco: o nível de suspeita, o limite do ato e as ações pagas para reduzi-la.

func build() -> void:
	page_header("risk")
	var w: float = size.x
	var body_h: float = size.y - UI.BODY_Y
	var left_w: float = floorf((w - UI.GAP) * 0.54)
	var right_w: float = w - UI.GAP - left_w
	_level_card(Rect2(0, UI.BODY_Y, left_w, body_h))
	_actions_card(Rect2(left_w + UI.GAP, UI.BODY_Y, right_w, body_h))

func _level_card(rect: Rect2) -> void:
	var suspicion: float = GameManager.suspicion
	var zone: int = UI.zone_index(suspicion)
	var limit: float = Campaign.limit()
	var w: float = rect.size.x
	var card: Panel = UI.card(self, rect, "Nível atual", "Perde %d%% do valor por noite neste ato: hoje, -%s%s" % [int(round(Campaign.decay_rate() * 100.0)), UI.num(Campaign.decay()), " (com %s da influência)" % UI.num(float(GameManager.influence) * B.INFLUENCE_DECAY) if GameManager.influence > 0 else ""])
	UI.enter(card, 1)

	var gauge_size: Vector2 = Vector2(300, 158)
	var gauge_x: float = (w - gauge_size.x) * 0.5
	var gauge: W.Gauge = W.Gauge.new()
	gauge.position = Vector2(gauge_x, 54)
	gauge.size = gauge_size
	gauge.zone_colors = UI.zone_colors()
	gauge.track = UI.TRACK
	gauge.danger = UI.RED
	gauge.limit = limit
	card.add_child(gauge)
	UI.tween_prop(gauge, "value", float(UI.shown.get("rk_gauge", 0.0)), suspicion, 0.8, 0.1)
	UI.shown["rk_gauge"] = suspicion
	var value: Label = UI.mono("", 38, UI.WHITE)
	value.position = Vector2(gauge_x, 138)
	value.size = Vector2(gauge_size.x, 48)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(value)
	UI.count(value, "rk_susp", suspicion, UI.pct)
	var zone_label: Label = UI.caps("ZONA: " + UI.zone_name(suspicion).to_upper(), UI.zone_color(zone), 12)
	zone_label.position = Vector2(gauge_x, 190)
	zone_label.size = Vector2(gauge_size.x, 16)
	zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(zone_label)

	# Os três números que definem o perigo neste ato.
	var facts: HBoxContainer = HBoxContainer.new()
	facts.position = Vector2(UI.PAD, 226)
	facts.size = Vector2(w - UI.PAD * 2.0, 64)
	facts.add_theme_constant_override("separation", 10)
	card.add_child(facts)
	facts.add_child(UI.tile("LIMITE DO ATO", "%d%%" % int(limit), UI.RED, "Se a suspeita chegar aqui, a campanha acaba." if Campaign.act < 3 else "No Ato 3, o cartel age antes de a polícia chegar.", 18))
	if Campaign.act >= 2:
		var mandado_text: String = "%d%% por %d noites" % [int(B.MANDADO_LEVEL), B.MANDADO_DAYS]
		if Campaign.mandado:
			mandado_text = "EXPEDIDO"
		elif Campaign.mandado_streak > 0:
			mandado_text = "em %d noite(s)" % (B.MANDADO_DAYS - Campaign.mandado_streak)
		facts.add_child(UI.tile("MANDADO DE PRISÃO", mandado_text, UI.RED if Campaign.mandado or Campaign.mandado_streak > 0 else UI.ORANGE, "Suspeita acima de %d%% por %d noites seguidas gera um mandado e inicia a fuga." % [int(B.MANDADO_LEVEL), B.MANDADO_DAYS], 18))
	facts.add_child(UI.tile("ESTRESSE DOS LARANJAS", "acima de %d%%" % int(B.STAFF_STRESS_LEVEL), UI.RED if suspicion > B.STAFF_STRESS_LEVEL else UI.WHITE, "Com a suspeita acima deste nível, os laranjas se estressam toda noite.", 18))

	var y: float = 308.0
	if GameManager.wiretap_days > 0 and y + 40.0 < rect.size.y:
		var tap: Label = UI.paragraph("Grampo ativo por mais %d dia(s): cada operação gera %d%% mais suspeita. A Varredura eletrônica remove." % [GameManager.wiretap_days, int(B.WIRETAP_RISK * 100.0)], 13, UI.RED, w - UI.PAD * 2.0)
		tap.position = Vector2(UI.PAD, y)
		card.add_child(tap)
		y += 46.0

	# De onde veio a suspeita: as operações com maior impacto.
	var heavy: Array = GameManager.transactions.duplicate()
	heavy.sort_custom(func(a: Variant, b: Variant) -> bool: return float(a.get("risk", 0.0)) > float(b.get("risk", 0.0)))
	if not heavy.is_empty() and y + 56.0 < rect.size.y:
		card.add_child(UI.at(UI.caps("OPERAÇÕES QUE MAIS PESARAM", UI.MUTED), Vector2(UI.PAD, y)))
		for i: int in range(mini(4, heavy.size())):
			var row_y: float = y + 22.0 + float(i) * 34.0
			if row_y + 30.0 > rect.size.y:
				break
			var tx: Dictionary = heavy[i] as Dictionary
			UI.kv_row(card, row_y, w, "%s, dia %02d" % [str(tx.get("company", "")), int(tx.get("day", 0))], UI.signed(float(tx.get("risk", 0.0))), UI.RED)

func _actions_card(rect: Rect2) -> void:
	var w: float = rect.size.x
	var card: Panel = UI.card(self, rect, "Ações de controle", "Pagas com saldo limpo: %s disponíveis" % UI.money(GameManager.clean_money))
	UI.enter(card, 2)
	var actions: Array = []
	for action_v: Variant in B.RISK_ACTIONS:
		if int((action_v as Dictionary)["act"]) <= Campaign.act:
			actions.append(action_v)
	# A ação com o menor custo por ponto de suspeita ganha uma etiqueta.
	var best_rate: float = INF
	var best_id: String = ""
	for action_v: Variant in actions:
		var reduce: float = float(action_v["reduce"])
		if reduce > 0.0 and GameManager.action_cost(action_v) / reduce < best_rate - 0.001:
			best_rate = GameManager.action_cost(action_v) / reduce
			best_id = str(action_v["id"])

	var top: float = 62.0
	var show_influence: bool = Campaign.act >= 2
	var avail: float = rect.size.y - top - (58.0 if show_influence else 8.0)
	var row_h: float = clampf(avail / float(actions.size()), 58.0, 78.0)
	for i: int in range(actions.size()):
		var action: Dictionary = actions[i]
		var action_id: String = str(action["id"])
		var y: float = top + float(i) * row_h
		if y + row_h > rect.size.y - (50.0 if show_influence else 0.0):
			break
		var cost: float = GameManager.action_cost(action)
		var reduce: float = float(action["reduce"])
		var wait: int = GameManager.action_cooldown(action_id)
		var clears: bool = bool(action.get("clears_wiretap", false))
		if i > 0:
			UI.rule(card, Vector2(UI.PAD, y - 4.0), w - UI.PAD * 2.0, Color("#1A2B36"))
		var name_label: Label = UI.bold(str(action["name"]), 15, UI.WHITE)
		name_label.position = Vector2(UI.PAD, y + 4.0)
		name_label.mouse_filter = Control.MOUSE_FILTER_STOP
		name_label.tooltip_text = str(action["about"])
		card.add_child(name_label)
		var effect: String = "remove o grampo" if clears else "-%.0f pts" % reduce
		if int(action.get("influence", 0)) > 0:
			effect += "  +%d influência" % int(action["influence"])
		card.add_child(UI.at(UI.mono("%s   %s" % [effect, UI.money(cost)], 13, UI.INK_2), Vector2(UI.PAD, y + 27.0)))
		var foot: String = "ESPERA DE %d DIA(S) ENTRE USOS" % int(action["cooldown"]) if int(action["cooldown"]) > 0 else "SEM ESPERA"
		if reduce > 0.0:
			foot = "%s POR PONTO  /  %s" % [UI.short_money(cost / reduce).to_upper(), foot]
		var foot_label: Label = UI.caps(foot, UI.MUTED, 9)
		foot_label.position = Vector2(UI.PAD, y + 48.0)
		if row_h >= 64.0:
			card.add_child(foot_label)
		if action_id == best_id and actions.size() > 1:
			var chip: PanelContainer = UI.chip("MELHOR CUSTO", UI.GREEN)
			chip.position = Vector2(UI.PAD + UI.text_width(name_label) + 10.0, y + 6.0)
			card.add_child(chip)

		var apply: Button = UI.button_at(card, Vector2(w - UI.PAD - 116.0, y + 10.0), Vector2(116, 38), "APLICAR", func() -> void: report(GameManager.reduce_risk(action_id)), true, "risk")
		if wait > 0:
			apply.text = "EM %d DIA(S)" % wait
			apply.icon = null
			UI.disable(apply, "Disponível de novo em %d dia(s)." % wait)
		elif clears and GameManager.wiretap_days <= 0:
			UI.disable(apply, "Não há grampo ativo.")
		elif cost > GameManager.clean_money:
			UI.disable(apply, "Faltam %s de saldo limpo." % UI.money(cost - GameManager.clean_money))
		else:
			apply.tooltip_text = str(action["about"])

	if show_influence:
		var y: float = rect.size.y - 50.0
		UI.rule(card, Vector2(UI.PAD, y - 6.0), w - UI.PAD * 2.0, UI.LINE)
		var influence: int = GameManager.influence
		var cap: Label = UI.caps("INFLUÊNCIA POLÍTICA  %d / %d" % [influence, B.INFLUENCE_MAX], UI.CYAN)
		cap.position = Vector2(UI.PAD, y + 2.0)
		cap.mouse_filter = Control.MOUSE_FILTER_STOP
		cap.tooltip_text = "Cada ponto faz a suspeita cair %s a mais por noite. Com %d pontos, a imunidade parlamentar fica à venda no fim do Ato 2." % [UI.num(B.INFLUENCE_DECAY), B.IMMUNITY_INFLUENCE]
		card.add_child(cap)
		card.add_child(UI.right(UI.caps("-%s DE SUSPEITA POR NOITE" % UI.num(float(influence) * B.INFLUENCE_DECAY), UI.GREEN if influence > 0 else UI.MUTED), Vector2(UI.PAD, y + 2.0), w - UI.PAD * 2.0))
		UI.bar(card, Vector2(UI.PAD, y + 24.0), w - UI.PAD * 2.0, float(influence) / float(B.INFLUENCE_MAX), UI.CYAN, "bar_rk_influence", 6.0)
