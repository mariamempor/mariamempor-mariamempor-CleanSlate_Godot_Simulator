extends Node
# Mede FPS numa vista fixa do quarto ligando/desligando cada efeito.
# Uso: godot --path . res://tests/tools/perf.tscn
var w: Node
func _ready() -> void:
	var root: Node = (load("res://scenes/world.tscn") as PackedScene).instantiate()
	add_child(root)
	w = root.get_node("World")
	await get_tree().create_timer(0.5).timeout
	GameManager.new_game()
	GameManager.begin_work()
	root.get_node("UI").show_dashboard("overview")
	await get_tree().create_timer(0.5).timeout
	w._set_mode(w.Mode.WALK)
	GameManager.current_time_minutes = 22 * 60
	w.set("_player", Vector3(0.5, 0, 2.9))
	w.call("_set_look_at", Vector3(-1.0, 1.2, -3.0))
	var env: Environment = null
	if w.get("env_node") != null:
		env = (w.get("env_node") as WorldEnvironment).environment
	await get_tree().create_timer(6.0).timeout   # aquece shaders
	await _measure("tudo ligado")
	if env == null:
		get_tree().quit()
		return
	for prop: String in ["volumetric_fog_enabled", "ssil_enabled", "ssr_enabled", "ssao_enabled", "glow_enabled"]:
		if not prop in env:
			continue
		env.set(prop, false)
		await _measure("sem " + prop)
		env.set(prop, true)
	var lights: Array = w.find_children("*", "Light3D", true, false)
	for l: Node in lights:
		(l as Light3D).set_meta("sh", (l as Light3D).shadow_enabled)
		(l as Light3D).shadow_enabled = false
	await _measure("sem sombras")
	for l: Node in lights:
		(l as Light3D).shadow_enabled = bool((l as Light3D).get_meta("sh"))
	for prop: String in ["volumetric_fog_enabled", "ssil_enabled", "ssr_enabled"]:
		if prop in env:
			env.set(prop, false)
	await _measure("sem névoa vol., SSIL e SSR")
	for prop: String in ["volumetric_fog_enabled", "ssil_enabled", "ssr_enabled"]:
		if prop in env:
			env.set(prop, true)
	await _measure("tudo ligado (de novo)")
	get_tree().quit()

func _measure(label: String) -> void:
	await get_tree().create_timer(2.5).timeout
	var t0: int = Time.get_ticks_usec()
	var frames: int = 0
	while Time.get_ticks_usec() - t0 < 2000000:
		await get_tree().process_frame
		frames += 1
	print("PERF %-32s %5.1f fps" % [label, float(frames) / 2.0])
