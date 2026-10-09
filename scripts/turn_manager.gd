extends Node
## TurnManager — as cenas em pixel art entre uma tela e outra.
##
## play_transition: a noite que separa dois turnos, com o fechamento do dia.
## play_ending:     a cena final da campanha.
## As duas são corrotinas: quem chama usa `await` e só continua quando a cena
## termina (ou quando o jogador pula com um clique ou com Espaço).

const NightScene = preload("res://scripts/ui/night_scene.gd")
const EndingScene = preload("res://scripts/ui/ending_scene.gd")

var running: bool = false

func play_transition(host: Control, report: Dictionary) -> void:
	if running:
		return
	running = true
	var scene: Control = NightScene.new()
	scene.set("report", report)
	host.add_child(scene)
	await scene.finished
	scene.queue_free()
	running = false

## Qual cena conta cada final.
func ending_kind(ending_id: String) -> String:
	var flew: bool = bool(Campaign.escape_result.get("flew", false))
	match ending_id:
		"rei", "foragido":
			return "takeoff"
		"politico":
			return "congress"
		"queima":
			return "cartel"
	return "runway" if flew else "arrest"

func play_ending(host: Control, ending_id: String) -> void:
	if running:
		return
	running = true
	var scene: Control = EndingScene.new()
	scene.set("ledger_enabled", false)
	scene.set("kind", ending_kind(ending_id))
	host.add_child(scene)
	if ending_id == "preso" or ending_id == "queima":
		AudioManager.play_warning()
	else:
		AudioManager.play_confirm()
	await scene.finished
	scene.queue_free()
	running = false
