extends "res://scripts/ui/tab_base.gd"
## Central de notícias: o histórico da campanha e os efeitos que estão valendo.

func build() -> void:
	page_header("news")
	var w: float = size.x
	var body_h: float = size.y - UI.BODY_Y
	var left_w: float = floorf((w - UI.GAP) * 0.66)
	var right_w: float = w - UI.GAP - left_w
	_log_card(Rect2(0, UI.BODY_Y, left_w, body_h))
	_effects_card(Rect2(left_w + UI.GAP, UI.BODY_Y, right_w, body_h))

func _tag_color(tag: String) -> Color:
	match tag:
		"URGENTE": return UI.RED
		"CARTEL": return UI.RED
		"CAMPANHA": return UI.CYAN
		"POLÍTICA": return UI.GREEN
	return UI.ORANGE

func _log_card(rect: Rect2) -> void:
	var card: Panel = UI.card(self, rect, "Histórico", "Do mais recente ao mais antigo")
	UI.enter(card, 1)
	var w: float = rect.size.x
	var entries: Array = GameManager.news_log
	if entries.is_empty():
		empty_state(card, Rect2(0, 56, w, rect.size.y - 56.0), "Nada aconteceu ainda. As notícias aparecem aqui conforme os dias passam.")
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
	for i: int in range(entries.size()):
		var item: Dictionary = entries[i] as Dictionary
		var accent: Color = _tag_color(str(item.get("tag", "")))
		var row: Control = Control.new()
		row.custom_minimum_size = Vector2(0, 72)
		list.add_child(row)
		if i < 8:
			UI.fade(row, i + 2)
		var stripe: ColorRect = ColorRect.new()
		stripe.position = Vector2(UI.PAD - 8.0, 10)
		stripe.size = Vector2(3, 50)
		stripe.color = accent
		row.add_child(stripe)
		UI.rule(row, Vector2(UI.PAD, 71), row_w - UI.PAD, Color("#1A2B36"))
		var chip: PanelContainer = UI.chip(str(item.get("tag", "")), accent)
		chip.position = Vector2(UI.PAD + 4.0, 8)
		row.add_child(chip)
		row.add_child(UI.at(UI.caps("ATO %d  /  DIA %02d" % [int(item.get("act", 1)), int(item.get("day", 0))], UI.MUTED), Vector2(UI.PAD + 110.0, 11)))
		var title: Label = UI.bold(str(item.get("title", "")), 15, UI.WHITE)
		UI.clip(title, Vector2(UI.PAD + 4.0, 28), Vector2(row_w - UI.PAD - 120.0, 22))
		row.add_child(title)
		var effect: Label = UI.caps(str(item.get("effect", "")).to_upper(), accent)
		UI.clip(effect, Vector2(UI.PAD + 4.0, 51), Vector2(row_w - UI.PAD - 120.0, 14))
		row.add_child(effect)
		UI.button_at(row, Vector2(row_w - 92.0, 18), Vector2(92, 34), "ABRIR", func() -> void: _open(item), false, "news")

## Reabre a notícia no popup, só para leitura (o efeito já foi aplicado quando ela saiu).
func _open(item: Dictionary) -> void:
	PopupManager.show_event({
		"style": "news",
		"kicker": "NOTÍCIA  /  " + str(item.get("tag", "")),
		"source": "CLEAN SLATE / NEWSWIRE  /  ATO %d, DIA %02d" % [int(item.get("act", 1)), int(item.get("day", 0))],
		"title": str(item.get("title", "")),
		"body": str(item.get("body", "")),
		"impact": str(item.get("effect", "")),
		"options": []
	})

func _effects_card(rect: Rect2) -> void:
	var card: Panel = UI.card(self, rect, "Efeitos ativos", "O que está valendo agora")
	UI.enter(card, 2)
	var w: float = rect.size.x
	var lines: Array = []
	if GameManager.wiretap_days > 0:
		lines.append(["Grampo telefônico: operações geram %d%% mais suspeita" % int(B.WIRETAP_RISK * 100.0), GameManager.wiretap_days, UI.RED])
	for mod_v: Variant in GameManager.modifiers:
		var mod: Dictionary = mod_v as Dictionary
		var good: bool = (str(mod["stat"]) == "capacity" and float(mod["value"]) > 0.0) or (str(mod["stat"]) != "capacity" and float(mod["value"]) < 0.0)
		lines.append([str(mod.get("label", "")), int(mod["days"]), UI.GREEN if good else UI.ORANGE])
	for company_id: String in GameManager.companies:
		var blocked: int = int(GameManager.companies[company_id]["blocked"])
		if blocked > 0:
			lines.append(["%s parada" % str(GameManager.companies[company_id]["name"]), blocked, UI.RED])
	if lines.is_empty():
		empty_state(card, Rect2(0, 56, w, rect.size.y - 56.0), "Nenhum efeito ativo. O ambiente está neutro.")
		return
	var y: float = 62.0
	for line_v: Variant in lines:
		var line: Array = line_v as Array
		if y + 60.0 > rect.size.y:
			break
		var dot: ColorRect = ColorRect.new()
		dot.position = Vector2(UI.PAD, y + 6.0)
		dot.size = Vector2(7, 7)
		dot.color = line[2]
		card.add_child(dot)
		var text: Label = UI.paragraph(str(line[0]), 13, UI.INK_2, w - UI.PAD * 2.0 - 16.0)
		text.position = Vector2(UI.PAD + 16.0, y)
		card.add_child(text)
		y += maxf(20.0, UI.text_height(text, w - UI.PAD * 2.0 - 16.0)) + 2.0
		card.add_child(UI.at(UI.caps("MAIS %d DIA(S)" % int(line[1]), line[2]), Vector2(UI.PAD + 16.0, y)))
		y += 30.0
