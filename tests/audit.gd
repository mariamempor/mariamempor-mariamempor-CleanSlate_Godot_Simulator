extends RefCounted
# Auditoria de layout: procura texto vazando do painel ou da tela e textos
# sobrepostos. É o tipo de defeito do popup de notícias antigo.

const VIEW: Rect2 = Rect2(-1, -1, 1368, 770)

static func run(root: Node) -> Array:
	var items: Array = []
	_collect(root, items, false)
	var out: Array = []
	for item_v: Variant in items:
		var item: Dictionary = item_v
		var rect: Rect2 = item["rect"]
		var name: String = str(item["text"]).left(46).replace("\n", " / ")
		if not VIEW.encloses(rect):
			out.append("fora da tela: '%s' %s" % [name, str(rect)])
		var box: Rect2 = item["box"]
		if box.size.x > 0.0 and not box.grow(2.0).encloses(rect):
			out.append("fora do painel: '%s' texto %s painel %s" % [name, str(rect), str(box)])
	for i: int in range(items.size()):
		for j: int in range(i + 1, items.size()):
			var a: Dictionary = items[i]
			var b: Dictionary = items[j]
			if a["parent"] != b["parent"]:
				continue
			var cut: Rect2 = (a["rect"] as Rect2).intersection(b["rect"])
			if cut.size.x > 3.0 and cut.size.y > 3.0:
				out.append("sobrepostos: '%s' x '%s'" % [str(a["text"]).left(30).replace("\n", " / "), str(b["text"]).left(30).replace("\n", " / ")])
	return out

static func _collect(node: Node, items: Array, clipped: bool) -> void:
	for child: Node in node.get_children():
		var control: Control = child as Control
		if control != null and (not control.is_visible_in_tree() or control.modulate.a < 0.05):
			continue
		var child_clipped: bool = clipped or child is ScrollContainer or (control != null and control.clip_contents)
		if control != null and not clipped:
			var text: String = ""
			var rect: Rect2 = control.get_global_rect()
			if child is Label:
				var label: Label = child
				text = label.text
				if label.autowrap_mode == TextServer.AUTOWRAP_OFF and not label.clip_text:
					rect = _text_rect(label)
			elif child is Button:
				text = (child as Button).text
			if text.strip_edges() != "":
				items.append({"text": text, "rect": rect, "parent": control.get_parent(), "box": _panel_of(control)})
		_collect(child, items, child_clipped)

## Retângulo que o texto ocupa de fato dentro da caixa do Label.
static func _text_rect(label: Label) -> Rect2:
	var box: Rect2 = label.get_global_rect()
	var need: Vector2 = label.get_minimum_size()
	var x: float = box.position.x
	if label.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT:
		x = box.end.x - need.x
	elif label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER:
		x = box.position.x + (box.size.x - need.x) * 0.5
	var y: float = box.position.y
	if label.vertical_alignment == VERTICAL_ALIGNMENT_BOTTOM:
		y = box.end.y - need.y
	elif label.vertical_alignment == VERTICAL_ALIGNMENT_CENTER:
		y = box.position.y + (box.size.y - need.y) * 0.5
	return Rect2(x, y, need.x, need.y)

static func _panel_of(control: Control) -> Rect2:
	var p: Node = control.get_parent()
	while p != null:
		if p is Panel or p is PanelContainer:
			return (p as Control).get_global_rect()
		p = p.get_parent()
	return Rect2()
