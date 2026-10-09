extends "res://scripts/ui/tab_base.gd"
## Histórico de transações: totais no alto e a lista completa, com rolagem.

func build() -> void:
	page_header("transactions")
	var w: float = size.x
	var h: float = size.y
	var txs: Array = GameManager.transactions
	var total_amount: float = 0.0
	var total_fee: float = 0.0
	var total_risk: float = 0.0
	for tx_v: Variant in txs:
		var tx: Dictionary = tx_v as Dictionary
		total_amount += float(tx.get("amount", 0.0))
		total_fee += float(tx.get("fee", 0.0))
		total_risk += float(tx.get("risk", 0.0))

	var tiles: HBoxContainer = HBoxContainer.new()
	tiles.position = Vector2(0, UI.BODY_Y)
	tiles.size = Vector2(w, 66)
	tiles.add_theme_constant_override("separation", int(UI.GAP))
	add_child(tiles)
	UI.enter(tiles, 1)
	tiles.add_child(UI.tile("OPERAÇÕES", str(txs.size()), UI.WHITE, "Operações registradas (as %d mais recentes ficam guardadas)." % GameManager.MAX_TRANSACTIONS, 18))
	tiles.add_child(UI.tile("VOLUME", UI.money(total_amount), UI.ORANGE, "Soma do que saiu do saldo sujo.", 18))
	tiles.add_child(UI.tile("CUSTO TOTAL", UI.money(total_fee), UI.MUTED, "Soma do que se perdeu nas operações.", 18))
	tiles.add_child(UI.tile("IMPACTO ACUMULADO", UI.signed(total_risk), UI.RED, "Quanto de suspeita essas operações geraram.", 18))

	var table_y: float = UI.BODY_Y + 66.0 + UI.GAP
	var table_h: float = h - table_y
	var card: Panel = UI.panel(self, Vector2(0, table_y), Vector2(w, table_h))
	UI.enter(card, 2)
	var headers: Array[String] = ["DIA", "HORÁRIO", "ORIGEM", "VALOR", "CUSTO", "IMPACTO"]
	var xs: Array[float] = [UI.PAD, 84.0, 180.0, w * 0.50, w * 0.67, w * 0.84]
	for i: int in range(headers.size()):
		card.add_child(UI.at(UI.caps(headers[i], UI.MUTED), Vector2(xs[i], 15)))
	UI.rule(card, Vector2(0, 42), w)

	if txs.is_empty():
		empty_state(card, Rect2(0, 44, w, table_h - 44.0), "Ainda não existem transações. Execute uma operação em Empresas para criar o primeiro registro.", "ABRIR EMPRESAS", "companies")
		return

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.position = Vector2(1, 44)
	scroll.size = Vector2(w - 2.0, table_h - 46.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card.add_child(scroll)
	var list: VBoxContainer = VBoxContainer.new()
	list.add_theme_constant_override("separation", 0)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for i: int in range(txs.size()):
		var tx: Dictionary = txs[i] as Dictionary
		var row: Control = Control.new()
		row.custom_minimum_size = Vector2(0, 40)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		list.add_child(row)
		if i < 12:
			UI.fade(row, i + 2)
		if i % 2 == 1:
			var stripe: ColorRect = ColorRect.new()
			stripe.size = Vector2(w - 2.0, 40)
			stripe.color = Color(1, 1, 1, 0.018)
			row.add_child(stripe)
		var cells: Array = [
			UI.mono("%02d" % int(tx.get("day", 0)), 13, UI.WHITE),
			UI.mono(str(tx.get("time", "--:--")), 13, UI.MUTED),
			UI.label(str(tx.get("company", "")), 14, UI.WHITE),
			UI.mono(UI.money(float(tx.get("amount", 0.0))), 13, UI.ORANGE),
			UI.mono(UI.money(float(tx.get("fee", 0.0))), 13, UI.MUTED),
			UI.mono(UI.signed(float(tx.get("risk", 0.0))), 13, UI.RED)
		]
		for c: int in range(cells.size()):
			row.add_child(UI.at(cells[c], Vector2(xs[c], 10)))
