extends Node3D
# Mostra todos os modelos de assets/models em grade e salva tests/out/catalog.png.
func _ready() -> void:
	var env: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.25, 0.27, 0.3)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.8, 0.8, 0.8)
	env.environment = e
	add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)
	var dir: DirAccess = DirAccess.open("res://assets/models")
	var names: PackedStringArray = dir.get_directories()
	var i: int = 0
	for n: String in names:
		var node: Node3D = (load("res://assets/models/%s/%s.gltf" % [n, n]) as PackedScene).instantiate()
		var col: int = i % 6
		var row: int = i / 6
		node.position = Vector3(col * 3.2, 0, row * 3.2)
		add_child(node)
		var l: Label3D = Label3D.new()
		l.text = n
		l.font_size = 64
		l.position = node.position + Vector3(0, -0.2, 1.3)
		l.rotation_degrees.x = -50
		add_child(l)
		i += 1
	var cam: Camera3D = Camera3D.new()
	add_child(cam)
	cam.position = Vector3(8.0, 13.0, 18.0)
	cam.look_at(Vector3(8.0, 0, 6.0))
	cam.current = true
	await get_tree().create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/out/catalog.png")
	get_tree().quit()
