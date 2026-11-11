extends SceneTree
func _init() -> void:
	for n: String in ["vintage_suitcase", "anthurium_botany_01", "wine_bottles_01", "binder_notebook", "office_notepads", "stationery_supplies", "brass_goblets", "throw_pillows_01", "sofa_03", "ceiling_fan", "desk_lamp_arm_01", "classic_laptop", "metal_office_desk", "security_camera_01"]:
		var node: Node = (load("res://assets/models/%s/%s.gltf" % [n, n]) as PackedScene).instantiate()
		print("== ", n)
		for c: Node in node.find_children("*", "MeshInstance3D", true, false):
			var m: MeshInstance3D = c
			var b: AABB = m.get_aabb()
			var mats: PackedStringArray = []
			for s: int in m.mesh.get_surface_count():
				var mt: Material = m.mesh.surface_get_material(s)
				mats.append(mt.resource_name if mt else "-")
			print("  %s pos=%s size=%s mats=%s" % [node.get_path_to(m), (m as Node3D).position, b.size, mats])
		node.free()
	quit()
