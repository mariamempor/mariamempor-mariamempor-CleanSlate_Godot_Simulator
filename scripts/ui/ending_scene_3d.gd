extends "res://scripts/ui/ending_scene.gd"
## Os finais em 3D: a legenda e o tempo continuam os da cena em pixel art, mas o
## cenário é 3D (pista, plenário, o próprio quarto). Quem posiciona a câmera é o
## world_3d.gd, via cutscenes.gd.

var world

func _ready() -> void:
	super._ready()
	var view: Vector2 = get_viewport_rect().size
	var veil: ColorRect = ColorRect.new()
	veil.color = Color(0.0, 0.01, 0.03, 0.62)
	veil.position = Vector2(0, view.y - 190.0)
	veil.size = Vector2(view.x, 190.0)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)
	move_child(veil, 0)
	if world != null:
		world.cutscene_begin(kind)

func _draw() -> void:
	pass

func _paint() -> void:
	pass

func _process(delta: float) -> void:
	super._process(delta)
	if world != null:
		world.cutscenes.ending(kind, t, duration)

func _exit_tree() -> void:
	if world != null and is_instance_valid(world):
		world.cutscene_end()
