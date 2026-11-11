extends RefCounted
## Construtores 3D compartilhados pelo quarto, pela cidade e pelos eventos.
## Tudo é estático: Prims.box(parent, pos, size, Prims.mat("#223344")).

static func mat(color: String, emission: String = "", energy: float = 0.0, metallic: float = 0.0, alpha: float = 1.0, rough: float = 0.88) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color(color)
	if alpha < 1.0:
		m.albedo_color.a = alpha
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = rough
	m.metallic = metallic
	if emission != "":
		m.emission_enabled = true
		m.emission = Color(emission)
		m.emission_energy_multiplier = energy
	return m

static func box(parent: Node, pos: Vector3, size: Vector3, material: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var shape: BoxMesh = BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.position = pos
	mesh.rotation_degrees = rot
	mesh.material_override = material
	parent.add_child(mesh)
	return mesh

static func cyl(parent: Node, pos: Vector3, radius: float, height: float, material: Material, rot: Vector3 = Vector3.ZERO, top_radius: float = -1.0) -> MeshInstance3D:
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var shape: CylinderMesh = CylinderMesh.new()
	shape.bottom_radius = radius
	shape.top_radius = radius if top_radius < 0.0 else top_radius
	shape.height = height
	shape.radial_segments = 14
	mesh.mesh = shape
	mesh.position = pos
	mesh.rotation_degrees = rot
	mesh.material_override = material
	parent.add_child(mesh)
	return mesh

static func sph(parent: Node, pos: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var shape: SphereMesh = SphereMesh.new()
	shape.radius = radius
	shape.height = radius * 2.0
	shape.radial_segments = 12
	shape.rings = 6
	mesh.mesh = shape
	mesh.position = pos
	mesh.material_override = material
	parent.add_child(mesh)
	return mesh

static func capsule(parent: Node, pos: Vector3, radius: float, height: float, material: Material) -> MeshInstance3D:
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var shape: CapsuleMesh = CapsuleMesh.new()
	shape.radius = radius
	shape.height = height
	shape.radial_segments = 10
	shape.rings = 4
	mesh.mesh = shape
	mesh.position = pos
	mesh.material_override = material
	parent.add_child(mesh)
	return mesh

static func label(parent: Node, text: String, pos: Vector3, size: int, color: Color, yaw_deg: float = 0.0, width: float = 0.0, mono: bool = true, pixel: float = 0.001) -> Label3D:
	var node: Label3D = Label3D.new()
	node.text = text
	node.font_size = size
	node.pixel_size = pixel
	node.modulate = color
	node.outline_size = 0
	node.shaded = false
	node.double_sided = false
	node.position = pos
	node.rotation_degrees.y = yaw_deg
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if width > 0.0:
		node.width = width
		node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var font: Font = UI.font_mono if mono else UI.font_bold
	if font != null:
		node.font = font
	parent.add_child(node)
	return node

static func light(parent: Node, pos: Vector3, color: String, energy: float, range_m: float, shadows: bool = false) -> OmniLight3D:
	var node: OmniLight3D = OmniLight3D.new()
	node.position = pos
	node.light_color = Color(color)
	node.light_energy = energy
	node.omni_range = range_m
	node.shadow_enabled = shadows
	parent.add_child(node)
	return node
