extends SceneTree
# Imprime o tamanho (AABB) de cada modelo em assets/models.
func _init() -> void:
	var dir: DirAccess = DirAccess.open("res://assets/models")
	for name: String in dir.get_directories():
		var scene: PackedScene = load("res://assets/models/%s/%s.gltf" % [name, name])
		var node: Node3D = scene.instantiate()
		var box: AABB = AABB()
		var first: bool = true
		for mi: Node in node.find_children("*", "MeshInstance3D", true, false):
			var m: MeshInstance3D = mi
			var t: Transform3D = Transform3D.IDENTITY
			var p: Node = m
			while p != node:
				t = (p as Node3D).transform * t
				p = p.get_parent()
			var b: AABB = t * m.get_aabb()
			box = b if first else box.merge(b)
			first = false
		print("%-28s size=(%.2f, %.2f, %.2f) min=(%.2f, %.2f, %.2f)" % [name, box.size.x, box.size.y, box.size.z, box.position.x, box.position.y, box.position.z])
		node.free()
	quit()
