extends Node
# Fotografa o apartamento 3D de pontos fixos, de dia e de noite, e salva em
# tests/out/room/<PREFIX>_*.png. Serve para comparar antes e depois de mudanças
# visuais.  Uso:  godot --path . res://tests/room_shots.tscn
#   PREFIX=antes  (padrão "agora")   ONLY=trecho   STAGE=1|2|3 (evolução do ato)
const Keep = preload("res://tests/keep.gd")

var w: Node
var ui: Node
var prefix: String = OS.get_environment("PREFIX")
var only: String = OS.get_environment("ONLY")

# nome, posição do olho (y já incluso), ponto para onde olha
const VIEWS: Array = [
	["porta", Vector3(0.5, 1.65, 2.9), Vector3(-1.0, 1.2, -3.0)],
	["mesa", Vector3(-1.2, 1.65, -0.9), Vector3(-2.4, 1.1, -3.4)],
	["janela", Vector3(1.5, 1.65, 0.6), Vector3(-4.5, 1.6, 0.2)],
	["vitrine", Vector3(0.6, 1.65, -1.2), Vector3(4.3, 1.0, 0.2)],
	["sofa_tv", Vector3(-1.0, 1.65, -0.4), Vector3(-2.4, 1.2, 3.5)],
	["mural", Vector3(1.2, 1.65, 0.8), Vector3(1.0, 1.6, -3.5)],
	["cama", Vector3(0.6, 1.65, -0.2), Vector3(3.6, 0.8, 2.6)],
	["planta", Vector3(-0.2, 3.12, 0.4), Vector3(-0.2, 0.0, 0.41)],
	["vista", Vector3(-3.6, 1.65, 0.2), Vector3(-30.0, 0.0, 0.2)],
]

func _ready() -> void:
	if prefix == "":
		prefix = "agora"
	var backup: Dictionary = Keep.take()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/out/room"))
	var root: Node = (load("res://scenes/world.tscn") as PackedScene).instantiate()
	add_child(root)
	w = root.get_node("World")
	ui = root.get_node("UI")
	await _run()
	Keep.give(backup)
	print("ROOM SHOTS: fim")
	get_tree().quit()

func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

func _run() -> void:
	await _wait(0.4)
	GameManager.rng.seed = 7
	GameManager.new_game()
	GameManager.begin_work()
	ui.show_dashboard("overview")
	await _wait(0.4)
	var stage: int = int(OS.get_environment("STAGE")) if OS.get_environment("STAGE") != "" else 1
	_setup_stage(stage)
	await _wait(0.3)
	w._set_mode(w.Mode.WALK)
	# Cenário de tensão: suspeita crítica, helicóptero, viaturas e o celular tocando.
	if OS.get_environment("SCENE") == "tensao":
		GameManager.suspicion = 88.0
		w.apartment.heli_level = 1.0
		var ev: Dictionary = Director._ev_investidor()
		ev["caller_name"] = "Dr. Henrique Lacerda"
		ev["kicker"] = "CELULAR  /  DR. HENRIQUE LACERDA  ·  INVESTIDOR DE OCASIÃO"
		Director.phone_call = ev
		w.phone.set("_wait", 0.05)
		GameManager.touch()
	if OS.get_environment("RAIN") != "":
		w.apartment.set("rain_override", float(OS.get_environment("RAIN")))
	for time_pair: Array in [["dia", 11 * 60], ["noite", 22 * 60]]:
		GameManager.current_time_minutes = int(time_pair[1])
		w.set("_day", 1.0 if time_pair[0] == "dia" else 0.0)
		GameManager.touch()
		for view: Array in VIEWS:
			var label: String = "%s_%s_%s" % [prefix, time_pair[0], view[0]]
			if only != "" and not label.contains(only):
				continue
			w.set("_player", (view[1] as Vector3) - Vector3(0, 1.65, 0))
			w.call("_set_look_at", view[2])
			w.set("_blend", 0.0)
			var cam: Camera3D = w.get("camera")
			cam.fov = 118.0 if view[0] == "planta" else 70.0
			await _wait(0.9)
			await _snap(label)
	# Visão de foco com a interface aberta (computador).
	if only == "" or "foco".contains(only) or only.contains("foco"):
		w.call("_focus", "overview", true)
		await _wait(1.6)
		await _snap("%s_foco_computador" % prefix)

## Simula o progresso da campanha para ver a evolução do apartamento.
func _setup_stage(stage: int) -> void:
	if stage <= 1:
		return
	GameManager.clean_money += 2500000.0 if stage == 2 else 12000000.0
	Campaign._start_act(stage)
	for id: String in ["boate", "concessionaria"]:
		GameManager.companies[id]["owned"] = true
	for good: String in ["relogio", "seda", "gravura"]:
		Lifestyle.buy(good)
	GameManager.touch()

func _snap(label: String) -> void:
	print("SHOT %s  |  %d fps  |  %d draw calls  |  %d k primitivas" % [label, Engine.get_frames_per_second(), int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0)])
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/out/room/%s.png" % label)
