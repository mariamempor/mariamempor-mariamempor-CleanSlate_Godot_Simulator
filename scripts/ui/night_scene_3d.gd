extends "res://scripts/ui/night_scene.gd"
## A noite em 3D: mesma linha do tempo, mesmo relatório do turno, mas o cenário
## é o quarto de verdade. Esta cena fica transparente e só desenha o relatório;
## a câmera e a luz são do world_3d.gd (via cutscenes.gd).

var world

func _ready() -> void:
	super._ready()
	if world != null:
		world.cutscene_begin("night")

func _draw() -> void:
	pass

func _paint() -> void:
	pass

func _process(delta: float) -> void:
	super._process(delta)
	if world != null and not _reduced:
		world.cutscenes.night(t)

func _exit_tree() -> void:
	if world != null and is_instance_valid(world):
		world.cutscene_end()
