extends Node3D
## Cenários das cenas em 3D: a pista de pouso, o plenário do Congresso e os
## adereços extras do quarto (porta iluminada, agentes, farol do carro do cartel).
## Ficam escondidos e longe do apartamento; quem os mostra e anima é cutscenes.gd.

const P = preload("res://scripts/world/prims.gd")

const AIR: Vector3 = Vector3(90.0, 0.0, 0.0)
const HALL: Vector3 = Vector3(0.0, 0.0, -90.0)

var world
var air_root: Node3D
var hall_root: Node3D
var room_root: Node3D

var jet: Node3D
var jet_nav: Array = []             # [material vermelho, verde, estroboscópica]
var jet_glow: Array = []
var strip_cars: Array = []          # {node, red, blue}
var strip_agents: Array = []
var crowd: Array = []
var confetti: Array = []
var door_flood: MeshInstance3D
var door_red: OmniLight3D
var door_blue: OmniLight3D
var room_agents: Array = []
var cartel_spot: SpotLight3D
var laser_dot: MeshInstance3D

func build() -> void:
	air_root = Node3D.new()
	add_child(air_root)
	_build_airstrip()
	hall_root = Node3D.new()
	add_child(hall_root)
	_build_hall()
	room_root = Node3D.new()
	add_child(room_root)
	_build_room_props()
	hide_all()

func hide_all() -> void:
	air_root.visible = false
	hall_root.visible = false
	room_root.visible = false

# =========================================================
# PESSOAS E VEÍCULOS
# =========================================================

func person(parent: Node, pos: Vector3, shirt: String, trousers: String = "#1A2430", seated: bool = false, hat: String = "", skin: String = "#E0B898") -> Node3D:
	var node: Node3D = Node3D.new()
	node.position = pos
	parent.add_child(node)
	if seated:
		P.box(node, Vector3(0, 0.4, 0.1), Vector3(0.42, 0.14, 0.5), P.mat(trousers))
		P.box(node, Vector3(0, 0.24, 0.32), Vector3(0.3, 0.46, 0.14), P.mat(trousers))
		P.capsule(node, Vector3(0, 0.82, 0.0), 0.2, 0.7, P.mat(shirt))
		P.sph(node, Vector3(0, 1.3, 0.0), 0.16, P.mat(skin))
	else:
		P.box(node, Vector3(0, 0.38, 0), Vector3(0.32, 0.76, 0.2), P.mat(trousers))
		P.capsule(node, Vector3(0, 1.1, 0), 0.22, 0.8, P.mat(shirt))
		P.sph(node, Vector3(0, 1.64, 0), 0.17, P.mat(skin))
		if hat != "":
			P.box(node, Vector3(0, 1.8, 0), Vector3(0.34, 0.08, 0.34), P.mat(hat))
	return node

func agent(parent: Node, pos: Vector3, yaw: float) -> Node3D:
	var node: Node3D = person(parent, pos, "#0C1118", "#0C1118", false, "#0C1118", "#C09A80")
	node.rotation_degrees.y = yaw
	var badge: Label3D = P.label(node, "PF", Vector3(0, 1.18, 0.23), 70, Color("#F2C94C"), 0.0, 0.0, true, 0.002)
	badge.double_sided = true
	return node

func police_car(parent: Node, pos: Vector3, yaw: float) -> Dictionary:
	var car: Node3D = Node3D.new()
	car.position = pos
	car.rotation_degrees.y = yaw
	parent.add_child(car)
	P.box(car, Vector3(0, 0.5, 0), Vector3(4.2, 0.75, 1.8), P.mat("#E8E8EE", "", 0.0, 0.4, 1.0, 0.35))
	P.box(car, Vector3(0, 0.5, 0), Vector3(4.24, 0.3, 1.84), P.mat("#0A0E14"))
	P.box(car, Vector3(-0.2, 1.1, 0), Vector3(2.2, 0.6, 1.6), P.mat("#10181F", "", 0.0, 0.6, 1.0, 0.2))
	for wx: float in [-1.3, 1.3]:
		for wz: float in [-0.9, 0.9]:
			P.cyl(car, Vector3(wx, 0.3, wz), 0.3, 0.24, P.mat("#0A0A0A"), Vector3(90, 0, 0))
	P.box(car, Vector3(2.12, 0.55, -0.55), Vector3(0.06, 0.2, 0.34), P.mat("#FFF8D0", "#FFF8D0", 3.0))
	P.box(car, Vector3(2.12, 0.55, 0.55), Vector3(0.06, 0.2, 0.34), P.mat("#FFF8D0", "#FFF8D0", 3.0))
	P.box(car, Vector3(0.0, 1.5, -0.4), Vector3(0.4, 0.14, 0.5), P.mat("#FF2020", "#FF2020", 3.0))
	P.box(car, Vector3(0.0, 1.5, 0.4), Vector3(0.4, 0.14, 0.5), P.mat("#2060FF", "#2060FF", 3.0))
	var red: OmniLight3D = P.light(car, Vector3(0, 1.8, -0.5), "#FF2020", 0.0, 10.0, false)
	var blue: OmniLight3D = P.light(car, Vector3(0, 1.8, 0.5), "#2060FF", 0.0, 10.0, false)
	return {"node": car, "red": red, "blue": blue}

# =========================================================
# PISTA DE POUSO
# =========================================================

func _build_jet(parent: Node) -> Node3D:
	var j: Node3D = Node3D.new()
	parent.add_child(j)
	var body: StandardMaterial3D = P.mat("#E8ECF0", "", 0.0, 0.3, 1.0, 0.4)
	var dark: StandardMaterial3D = P.mat("#2A323A", "", 0.0, 0.5, 1.0, 0.4)
	P.cyl(j, Vector3(0, 0, 0), 0.95, 9.0, body, Vector3(0, 0, 90))
	P.cyl(j, Vector3(5.7, -0.05, 0), 0.95, 2.4, body, Vector3(0, 0, -90), 0.14)
	P.cyl(j, Vector3(-5.8, 0.15, 0), 0.95, 2.6, body, Vector3(0, 0, 90), 0.3)
	P.box(j, Vector3(0.4, -0.2, 0), Vector3(2.8, 0.12, 12.4), body)
	P.box(j, Vector3(-5.3, 1.6, 0), Vector3(1.9, 2.3, 0.14), body, Vector3(0, 0, 14))
	P.box(j, Vector3(-5.6, 0.6, 0), Vector3(1.3, 0.1, 4.0), body)
	P.box(j, Vector3(0.4, -0.2, 0), Vector3(2.9, 0.05, 12.5), P.mat("#1F5FA8"))
	P.box(j, Vector3(0, 0.1, 0), Vector3(9.2, 0.14, 1.92), P.mat("#1F5FA8"))
	for side: float in [-1.0, 1.0]:
		P.cyl(j, Vector3(-4.2, 0.5, side * 1.3), 0.4, 2.2, dark, Vector3(0, 0, 90))
		var glow: StandardMaterial3D = P.mat("#FF9040", "#FF7020", 0.0)
		P.cyl(j, Vector3(-5.32, 0.5, side * 1.3), 0.3, 0.06, glow, Vector3(0, 0, 90))
		jet_glow.append(glow)
		for i: int in range(6):
			P.box(j, Vector3(-2.6 + float(i) * 0.95, 0.35, side * 0.95), Vector3(0.42, 0.24, 0.03), P.mat("#10202A", "#9FD8F0", 1.0))
	P.box(j, Vector3(4.4, 0.4, 0), Vector3(1.3, 0.3, 1.5), P.mat("#10202A", "#7AA8C0", 0.6, 0.5, 1.0, 0.1))
	var red: StandardMaterial3D = P.mat("#FF2020", "#FF2020", 3.0)
	var green: StandardMaterial3D = P.mat("#20FF50", "#20FF50", 3.0)
	var strobe: StandardMaterial3D = P.mat("#FFFFFF", "#FFFFFF", 3.0)
	P.box(j, Vector3(0.4, -0.2, -6.3), Vector3(0.3, 0.2, 0.2), red)
	P.box(j, Vector3(0.4, -0.2, 6.3), Vector3(0.3, 0.2, 0.2), green)
	P.box(j, Vector3(-5.9, 2.7, 0), Vector3(0.2, 0.15, 0.2), strobe)
	jet_nav = [red, green, strobe]
	P.box(j, Vector3(6.9, -0.25, 0), Vector3(0.1, 0.2, 0.3), P.mat("#FFFFFF", "#FFFFFF", 3.5))
	for w: Array in [[2.8, 0.0], [-1.2, -0.7], [-1.2, 0.7]]:
		P.box(j, Vector3(float(w[0]), -0.95, float(w[1])), Vector3(0.07, 0.5, 0.07), dark)
		P.cyl(j, Vector3(float(w[0]), -1.2, float(w[1])), 0.22, 0.18, P.mat("#0A0A0A"), Vector3(90, 0, 0))
	return j

func _build_airstrip() -> void:
	var r: Node3D = air_root
	P.box(r, AIR + Vector3(0, -0.1, 0), Vector3(220, 0.2, 130), P.mat("#2A352C"))
	P.box(r, AIR + Vector3(0, 0.02, 0), Vector3(160, 0.06, 9.0), P.mat("#171B21", "", 0.0, 0.0, 1.0, 0.6))
	for i: int in range(-13, 14):
		P.box(r, AIR + Vector3(float(i) * 5.5, 0.07, 0), Vector3(2.4, 0.02, 0.22), P.mat("#E8E8E8", "#E8E8E8", 0.4))
	for i: int in range(-15, 16):
		for sz: float in [-4.9, 4.9]:
			var lamp: StandardMaterial3D = P.mat("#FFFFFF", "#FFE8B0" if sz > 0.0 else "#7090FF", 3.0)
			P.box(r, AIR + Vector3(float(i) * 5.0, 0.12, sz), Vector3(0.2, 0.2, 0.2), lamp)
	P.box(r, AIR + Vector3(-18, 3.5, -22), Vector3(24, 7.0, 12), P.mat("#34414D"))
	P.box(r, AIR + Vector3(-18, 7.2, -22), Vector3(24.6, 0.5, 12.6), P.mat("#222C35"))
	P.box(r, AIR + Vector3(-18, 2.4, -15.9), Vector3(10, 4.6, 0.1), P.mat("#1A2229", "#FFB060", 0.5))
	P.cyl(r, AIR + Vector3(14, 5, -26), 1.2, 10.0, P.mat("#3A4854"))
	P.box(r, AIR + Vector3(14, 10.6, -26), Vector3(5, 2.2, 5), P.mat("#10202A", "#FFE0A0", 0.9))
	P.box(r, AIR + Vector3(14, 11.9, -26), Vector3(5.6, 0.3, 5.6), P.mat("#222C35"))
	var leaf: StandardMaterial3D = P.mat("#2E6A44")
	for i: int in range(18):
		var tx: float = -70.0 + float(i) * 8.5
		P.cyl(r, AIR + Vector3(tx, 1.0, -44.0 - float(i % 3) * 4.0), 0.2, 2.0, P.mat("#3A2A20"))
		P.sph(r, AIR + Vector3(tx, 3.2, -44.0 - float(i % 3) * 4.0), 2.0, leaf)
		P.cyl(r, AIR + Vector3(tx, 1.0, 44.0 + float(i % 3) * 4.0), 0.2, 2.0, P.mat("#3A2A20"))
		P.sph(r, AIR + Vector3(tx, 3.2, 44.0 + float(i % 3) * 4.0), 2.0, leaf)
	P.light(r, AIR + Vector3(0, 12, 6), "#FFE2B8", 1.4, 70.0, false)
	P.light(r, AIR + Vector3(30, 12, 6), "#FFE2B8", 1.0, 60.0, false)
	jet = _build_jet(r)
	jet.position = AIR + Vector3(-34, 1.25, 0)
	var spots: Array = [Vector3(20, 0, -3.2), Vector3(20.5, 0, 0.4), Vector3(20, 0, 3.8)]
	for pos: Vector3 in spots:
		strip_cars.append(police_car(r, AIR + pos, 180.0 + (pos.z * 3.0)))
	for i: int in range(4):
		strip_agents.append(agent(r, AIR + Vector3(17.0, 0.0, -4.0 + float(i) * 2.6), 90.0))

# =========================================================
# PLENÁRIO
# =========================================================

func _build_hall() -> void:
	var r: Node3D = hall_root
	var h: Vector3 = HALL
	P.box(r, h + Vector3(0, -0.1, 0), Vector3(40, 0.2, 46), P.mat("#2E3440", "", 0.0, 0.1, 1.0, 0.3))
	P.box(r, h + Vector3(0, 0.02, 2), Vector3(5, 0.03, 30), P.mat("#7A1F2E"))
	P.box(r, h + Vector3(0, 5, -21), Vector3(40, 10, 0.6), P.mat("#C9C2B0"))
	for sx: float in [-20.0, 20.0]:
		P.box(r, h + Vector3(sx, 5, 0), Vector3(0.6, 10, 46), P.mat("#B8B2A2"))
	P.box(r, h + Vector3(0, 10.2, 0), Vector3(40, 0.4, 46), P.mat("#8A8578"))
	for x: float in [-13.0, -6.5, 6.5, 13.0]:
		P.cyl(r, h + Vector3(x, 4.5, -19.4), 0.65, 9.0, P.mat("#E8E2D0"))
	P.box(r, h + Vector3(0, 5.2, -20.6), Vector3(12, 7.4, 0.1), P.mat("#1E8A4C"))
	P.box(r, h + Vector3(0, 5.2, -20.5), Vector3(5.8, 5.8, 0.12), P.mat("#F4D03F"), Vector3(0, 0, 45))
	P.cyl(r, h + Vector3(0, 5.2, -20.4), 1.75, 0.14, P.mat("#1F3F9A"), Vector3(90, 0, 0))
	P.label(r, "PLENÁRIO", h + Vector3(0, 9.0, -20.5), 90, Color("#2A2418"), 0.0, 0.0, false, 0.012)
	P.box(r, h + Vector3(0, 0.15, -15), Vector3(14, 0.3, 7), P.mat("#5A4636"))
	P.box(r, h + Vector3(0, 0.9, -16.4), Vector3(2.4, 1.3, 1.1), P.mat("#4A3426"))
	P.box(r, h + Vector3(0, 1.58, -16.4), Vector3(2.6, 0.08, 1.2), P.mat("#6A4A34"))
	P.cyl(r, h + Vector3(0, 1.95, -16.3), 0.02, 0.7, P.mat("#9AA9B4", "", 0.0, 0.9))
	P.box(r, h + Vector3(0, 2.3, -16.2), Vector3(0.08, 0.08, 0.2), P.mat("#10161D"))
	var shirts: Array = ["#D84F6B", "#4F9AD8", "#E8B04A", "#6BD8A0", "#B04FD8", "#D8D8E0", "#E07A3F", "#4FD8C8", "#3A4A5A", "#8A6A5A"]
	for row: int in range(5):
		for col: int in range(11):
			var x: float = (float(col) - 5.0) * 1.8
			x += 0.5 if x > 0.0 else (-0.5 if x < 0.0 else 0.0)
			if absf(x) < 0.5:
				continue
			var dress: String = str(shirts[(row * 3 + col) % shirts.size()])
			var p: Node3D = person(r, h + Vector3(x, 0.0, -9.0 + float(row) * 2.4), dress, "#1A2430", true)
			p.rotation_degrees.y = 180.0
			crowd.append(p)
	var speaker: Node3D = person(r, h + Vector3(0, 0.3, -17.4), "#1D2733", "#1D2733")
	P.box(speaker, Vector3(0, 1.3, 0.2), Vector3(0.07, 0.4, 0.02), P.mat("#C23B3B"))
	var spot: SpotLight3D = SpotLight3D.new()
	spot.light_color = Color("#FFE8C0")
	spot.light_energy = 6.0
	spot.spot_range = 30.0
	spot.spot_angle = 24.0
	r.add_child(spot)
	spot.look_at_from_position(h + Vector3(0, 10, -6), h + Vector3(0, 1.5, -16.4), Vector3.UP)
	P.light(r, h + Vector3(0, 8.5, -4), "#FFE2B8", 2.2, 40.0, false)
	P.light(r, h + Vector3(0, 6.0, 8), "#FFF0D8", 1.4, 30.0, false)
	var palette: Array = ["#F2C94C", "#D84F6B", "#4F9AD8", "#6BD8A0", "#FFFFFF"]
	for i: int in range(60):
		var piece: MeshInstance3D = P.box(r, h + Vector3(randf_range(-10.0, 10.0), 8.0, randf_range(-14.0, 6.0)), Vector3(0.12, 0.02, 0.18), P.mat(str(palette[i % palette.size()]), str(palette[i % palette.size()]), 1.0))
		confetti.append({"node": piece, "speed": randf_range(1.2, 2.8), "spin": randf_range(2.0, 8.0), "x0": piece.position.x, "z0": piece.position.z})

# =========================================================
# ADEREÇOS DO QUARTO
# =========================================================

func _build_room_props() -> void:
	var r: Node3D = room_root
	door_flood = P.box(r, Vector3(0.5, 1.05, 3.46), Vector3(0.94, 2.08, 0.02), P.mat("#FFFFFF", "#FFF4D8", 3.0))
	door_red = P.light(r, Vector3(0.5, 1.8, 2.6), "#FF2020", 0.0, 9.0, false)
	door_blue = P.light(r, Vector3(0.5, 1.8, 2.6), "#2060FF", 0.0, 9.0, false)
	for i: int in range(3):
		room_agents.append(agent(r, Vector3(0.1 + float(i) * 0.4, 0.0, 3.2), 180.0))
	cartel_spot = SpotLight3D.new()
	cartel_spot.light_color = Color("#FFF8E0")
	cartel_spot.light_energy = 0.0
	cartel_spot.spot_range = 40.0
	cartel_spot.spot_angle = 26.0
	r.add_child(cartel_spot)
	cartel_spot.look_at_from_position(Vector3(-16, 1.4, 0.2), Vector3(0, 1.3, 0.2), Vector3.UP)
	laser_dot = P.sph(r, Vector3(-1.0, 1.35, -3.42), 0.035, P.mat("#FF2020", "#FF2020", 5.0))
	laser_dot.visible = false
