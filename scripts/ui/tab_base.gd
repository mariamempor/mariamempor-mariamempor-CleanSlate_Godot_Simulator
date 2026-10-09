extends Control
## Base das abas do dashboard.
##
## Cada aba é um Control que ocupa a área central e se monta em build().
## `app` é o main.gd: é por ele que a aba abre modais, mostra avisos e troca
## de aba. Para criar uma aba nova: um arquivo em scripts/ui/tabs/ que estende
## este, uma entrada em TABS (texts.gd) e outra em TAB_SCRIPTS (main.gd).

const B = preload("res://scripts/data/balance.gd")
const T = preload("res://scripts/data/texts.gd")
const W = preload("res://scripts/ui/widgets.gd")

## Sem tipo de propósito: main.gd carrega as abas, e tipar aqui criaria uma
## dependência circular entre os dois scripts.
var app

func build() -> void:
	pass

## Título da aba, uma linha dizendo para que ela serve e o botão de ajuda.
func page_header(tab_id: String, accent: Color = UI.WHITE) -> void:
	var info: Dictionary = T.HELP[tab_id]
	var title: Label = UI.display(str(info["title"]), 30, accent)
	title.position = Vector2(0, -6)
	add_child(title)
	UI.enter(title, 0, Vector2(-10, 0))
	var sub: Label = UI.label(T.fill(str(info["subtitle"])), 14, UI.MUTED)
	sub.position = Vector2(1, 34)
	add_child(sub)
	UI.enter(sub, 0, Vector2(-10, 0))
	var help: Button = UI.button_at(self, Vector2(size.x - 170.0, 4), Vector2(170, 38), "COMO FUNCIONA", func() -> void: app.show_help(tab_id), false, "manual")
	help.tooltip_text = "Explica esta tela (F1)"

## Mostra o resultado de uma ação ({ok, message}) como aviso, com som.
func report(result: Dictionary) -> void:
	app.result_toast(result)

## Estado vazio: um texto centralizado e, se fizer sentido, um botão que leva à ação.
func empty_state(host: Control, area: Rect2, text: String, button_text: String = "", target_tab: String = "") -> void:
	var width: float = minf(420.0, area.size.x - 40.0)
	var message: Label = UI.paragraph(text, 14, UI.MUTED, width)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.position = Vector2(area.position.x + (area.size.x - width) * 0.5, area.position.y + area.size.y * 0.5 - 48.0)
	host.add_child(message)
	if button_text != "":
		UI.button_at(host, Vector2(area.position.x + (area.size.x - 200.0) * 0.5, area.position.y + area.size.y * 0.5 + 14.0), Vector2(200, 40), button_text, func() -> void: app.switch_tab(target_tab), true, target_tab)
