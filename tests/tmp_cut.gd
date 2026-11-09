extends Node

var w: Node
var ui: Node

func _ready() -> void:
	var root: Node = (load("res://scenes/world.tscn") as PackedScene).instantiate()
	add_child(root)
	w = root.get_node("World")
	ui = root.get_node("UI")
	_run.call_deferred()

func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/out/%s.png" % name)

func _run() -> void:
	await _wait(0.5)
	GameManager.new_game()
	GameManager.begin_work()
	ui.show_dashboard("overview")
	await _wait(0.5)
	w._set_mode(w.Mode.WALK)
	await _wait(0.5)
	UI.full_night = true
	GameManager.process_company("lavanderia", 30000.0)
	ui.end_turn()
	var marks: Array = [0.2, 1.8, 3.4, 4.6, 5.6, 6.5]
	var last: float = 0.0
	for i in range(marks.size()):
		await _wait(float(marks[i]) - last)
		last = float(marks[i])
		await _shot("night_%d" % i)
	await _wait(2.5)
	var guard: int = 0
	while (TurnManager.running or PopupManager.is_open()) and guard < 100:
		guard += 1
		if PopupManager.is_open():
			PopupManager.clear_popup()
		await _wait(0.3)
	print("night done cutscene_active=", w.cutscene_active, " mode ", w.mode)
	Campaign.escape_result = {"flew": true}
	for kind in [["rei", "takeoff"], ["preso", "runway"], ["politico", "congress"], ["queima", "cartel"]]:
		Campaign.escape_result = {"flew": kind[1] == "runway"}
		TurnManager.play_ending(ui, kind[0])
		for j in range(3):
			await _wait(1.6 if j == 0 else 1.6)
			await _shot("end_%s_%d" % [kind[1], j])
		await _wait(3.5)
		guard = 0
		while TurnManager.running and guard < 60:
			guard += 1
			await _wait(0.3)
	Campaign.escape_result = {"flew": false}
	TurnManager.play_ending(ui, "preso")
	for j in range(3):
		await _wait(1.6)
		await _shot("end_arrest_%d" % j)
	await _wait(3.5)
	get_tree().quit()
