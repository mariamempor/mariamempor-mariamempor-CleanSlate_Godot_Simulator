extends Node3D
## A rua. Fica longe do apartamento (z de 14 a 46) e o jogador chega pela porta.
##
## As sete empresas viram prédios: acesos e abertos se são suas, com placa de
## "à venda" e preço se dá para comprar, escuros se ainda estão fora de alcance.
## A rua tem pedestres, carros e uma viatura da PF que aparece quando a
## suspeita sobe. Quem decide o que cada porta faz é o world_3d.gd.

const P = preload("res://scripts/world/prims.gd")
const B = preload("res://scripts/data/balance.gd")

const ROAD_Z: float = 30.0
const NORTH_FACADE: float = 22.0
const SOUTH_FACADE: float = 38.0
const LIMIT_X: float = 26.0
const WALK_Z_MIN: float = 22.8
const WALK_Z_MAX: float = 37.2
const ARRIVE_POS: Vector3 = Vector3(0.0, 0.0, 24.4)

## id: [x, lado (1 = norte, -1 = sul), largura, altura, cor]
const LAYOUT: Dictionary = {
	"lavanderia": [-15.0, 1, 6.0, 6.0, "#4FA3C7"],
	"bar": [-8.0, 1, 5.0, 5.5, "#E07A3F"],
	"boate": [8.0, 1, 6.0, 7.5, "#B04FD8"],
	"concessionaria": [15.5, 1, 7.0, 5.0, "#D84F6B"],
	"construtora": [-10.0, -1, 8.0, 12.0, "#D8B04F"],
	"galeria": [2.0, -1, 7.0, 8.5, "#6BD8A0"],
	"trading": [14.0, -1, 7.0, 15.0, "#4F6BD8"]
}

var world
var active: bool = false

var _buildings: Dictionary = {}     # id -> {win_mat, door_mat, sign, status, label_door}
var _cars: Array = []
var _peds: Array = []
var _police: Node3D
var _police_red: OmniLight3D
var _police_blue: OmniLight3D
var _police_lights: Array = []
var _t: float = 0.0

func build() -> void:
	_build_ground()
	for id: String in LAYOUT:
		_build_company(id)
	_build_home()
	_build_ends()
	_build_lamps()
	_build_trees()
	_build_cars()
	_build_peds()
	_build_police()
	visible = false

## Pontos de interação da rua: [id, posição, rótulo, câmera, olhar].
func spot_defs() -> Array:
	var defs: Array = []
	for id: String in LAYOUT:
		var entry: Array = LAYOUT[id]
		var side: float = float(int(entry[1]))
		var facade: float = NORTH_FACADE if side > 0.0 else SOUTH_FACADE
		var x: float = float(entry[0])
		defs.append(["st_" + id, Vector3(x, 1.2, facade + side * 0.3), str(B.COMPANIES[id]["name"]), Vector3(x, 1.7, facade + side * 5.5), Vector3(x, 1.5, facade), Vector3(0, 1.0, side * 1.2)])
	defs.append(["st_home", Vector3(0.0, 1.2, NORTH_FACADE + 0.3), "VOLTAR PARA CASA", Vector3.ZERO, Vector3.ZERO, Vector3(0, 1.0, 1.0)])
	return defs

# =========================================================
# CONSTRUÇÃO
# =========================================================

func _build_ground() -> void:
	P.box(self, Vector3(0, -0.1, 30.0), Vector3(120.0, 0.2, 60.0), P.mat("#222C37"))
	P.box(self, Vector3(0, 0.0, ROAD_Z), Vector3(120.0, 0.04, 8.0), P.mat("#1F2832", "", 0.0, 0.0, 1.0, 0.6))
	for sz: float in [24.0, 36.0]:
		P.box(self, Vector3(0, 0.05, sz), Vector3(120.0, 0.12, 4.0), P.mat("#3C4856"))
	var dash: StandardMaterial3D = P.mat("#E8D8A0", "#E8D8A0", 0.5)
	for i: int in range(-14, 15):
		P.box(self, Vector3(float(i) * 4.0, 0.03, ROAD_Z), Vector3(1.6, 0.01, 0.14), dash)
	var curb: StandardMaterial3D = P.mat("#3A4652")
	P.box(self, Vector3(0, 0.07, ROAD_Z - 4.0), Vector3(120.0, 0.16, 0.18), curb)
	P.box(self, Vector3(0, 0.07, ROAD_Z + 4.0), Vector3(120.0, 0.16, 0.18), curb)

func _build_company(id: String) -> void:
	var entry: Array = LAYOUT[id]
	var x: float = float(entry[0])
	var side: float = float(int(entry[1]))
	var w: float = float(entry[2])
	var h: float = float(entry[3])
	var accent: Color = Color(str(entry[4]))
	var facade: float = NORTH_FACADE if side > 0.0 else SOUTH_FACADE
	var depth: float = 9.0
	var yaw: float = 0.0 if side > 0.0 else 180.0
	var body: StandardMaterial3D = P.mat(Color("#2C3A4C").lerp(accent, 0.30).to_html(false))
	P.box(self, Vector3(x, h * 0.5, facade + side * (depth * 0.5)), Vector3(w, h, depth), body)
	P.box(self, Vector3(x, h + 0.15, facade + side * (depth * 0.5)), Vector3(w + 0.3, 0.3, depth + 0.3), P.mat(accent.darkened(0.55).to_html(false)))
	P.box(self, Vector3(x, h * 0.5, facade + side * 0.02), Vector3(w + 0.1, 0.12, 0.05), P.mat(accent.to_html(false), accent.to_html(false), 1.2))
	P.box(self, Vector3(x - w * 0.5, h * 0.5, facade + side * 0.02), Vector3(0.1, h, 0.05), P.mat(accent.to_html(false), accent.to_html(false), 1.0))
	P.box(self, Vector3(x + w * 0.5, h * 0.5, facade + side * 0.02), Vector3(0.1, h, 0.05), P.mat(accent.to_html(false), accent.to_html(false), 1.0))
	var win_mat: StandardMaterial3D = P.mat("#101820", "#FFD58A", 0.0)
	var cols: int = int(w / 1.3)
	var rows: int = int((h - 4.0) / 1.4)
	for r: int in range(rows):
		for c: int in range(cols):
			var wx: float = x - w * 0.5 + (float(c) + 0.5) * (w / float(cols))
			P.box(self, Vector3(wx, 4.5 + float(r) * 1.4, facade + side * 0.03), Vector3(0.7, 0.8, 0.06), win_mat)
	# Porta, toldo e placa.
	var door_mat: StandardMaterial3D = P.mat("#161E27", "#62E3A2", 0.0)
	P.box(self, Vector3(x, 1.2, facade + side * 0.05), Vector3(1.5, 2.4, 0.1), door_mat)
	P.box(self, Vector3(x, 2.55, facade + side * 0.5), Vector3(2.4, 0.12, 1.0), P.mat(accent.to_html(false), accent.to_html(false), 0.5), Vector3(side * 12.0, 0.0, 0.0))
	var sign_root: Node3D = Node3D.new()
	sign_root.position = Vector3(x, 3.0, facade + side * 0.12)
	add_child(sign_root)
	P.box(sign_root, Vector3(0, 0.0, 0.0), Vector3(w - 0.3, 0.7, 0.08), P.mat("#0A1015"))
	var sign: Label3D = P.label(sign_root, str(B.COMPANIES[id]["name"]).to_upper(), Vector3(0, 0.0, side * 0.06), 44, accent, yaw, 0.0, true, 0.0085)
	var status: Label3D = P.label(self, "", Vector3(x, 2.85, facade + side * 0.12), 40, Color("#8399A9"), yaw, 0.0, true, 0.006)
	status.position.y = 3.7
	_buildings[id] = {"win": win_mat, "door": door_mat, "sign": sign, "status": status, "accent": accent}

func _build_home() -> void:
	var w: float = 6.0
	var h: float = 9.0
	var depth: float = 9.0
	P.box(self, Vector3(0, h * 0.5, NORTH_FACADE - depth * 0.5), Vector3(w, h, depth), P.mat("#3E5068"))
	P.box(self, Vector3(0, h + 0.15, NORTH_FACADE - depth * 0.5), Vector3(w + 0.3, 0.3, depth + 0.3), P.mat("#10171F"))
	var win: StandardMaterial3D = P.mat("#101820", "#FFD58A", 1.1)
	for r: int in range(4):
		for c: int in range(4):
			if (r * 3 + c) % 5 == 0:
				continue
			P.box(self, Vector3(-2.2 + float(c) * 1.45, 3.6 + float(r) * 1.4, NORTH_FACADE + 0.03), Vector3(0.7, 0.8, 0.06), win)
	P.box(self, Vector3(0.0, 1.2, NORTH_FACADE + 0.05), Vector3(1.5, 2.4, 0.1), P.mat("#3A2A20"))
	P.box(self, Vector3(0.0, 2.6, NORTH_FACADE + 0.1), Vector3(2.2, 0.12, 0.6), P.mat("#10171F"))
	P.label(self, "APTO 3B", Vector3(0.0, 2.95, NORTH_FACADE + 0.14), 50, Color("#8399A9"), 0.0, 0.0, true, 0.006)
	P.box(self, Vector3(0.0, 0.1, NORTH_FACADE + 0.9), Vector3(2.2, 0.2, 1.4), P.mat("#2A333D"))

func _build_ends() -> void:
	for sx: float in [-LIMIT_X - 4.0, LIMIT_X + 4.0]:
		P.box(self, Vector3(sx, 9.0, 30.0), Vector3(8.0, 18.0, 22.0), P.mat("#2A394A"))
		var warm: StandardMaterial3D = P.mat("#101820", "#FFD58A", 0.9)
		for r: int in range(6):
			P.box(self, Vector3(sx - signf(sx) * 4.02, 3.0 + float(r) * 2.4, 25.0 + float(r % 3) * 3.0), Vector3(0.06, 0.9, 0.9), warm)

func _build_lamps() -> void:
	var pole: StandardMaterial3D = P.mat("#1B242C", "", 0.0, 0.8, 1.0, 0.4)
	var lamp: StandardMaterial3D = P.mat("#FFF0C8", "#FFD58A", 3.0)
	var count: int = 0
	for i: int in range(-3, 4):
		for sz: float in [24.4, 35.6]:
			var x: float = float(i) * 8.0 + (4.0 if sz > 30.0 else 0.0)
			P.cyl(self, Vector3(x, 2.1, sz), 0.05, 4.2, pole)
			P.box(self, Vector3(x, 4.25, sz), Vector3(0.5, 0.1, 0.3), lamp)
			count += 1
			P.light(self, Vector3(x, 4.0, sz), "#FFD58A", 1.8, 11.0, false)

func _build_trees() -> void:
	var trunk: StandardMaterial3D = P.mat("#3A2A20")
	var leaf: StandardMaterial3D = P.mat("#2E6A44")
	var leaf_b: StandardMaterial3D = P.mat("#3C8556")
	for x: float in [-20.0, -4.0, 4.0, 20.0]:
		P.cyl(self, Vector3(x, 0.8, 23.4), 0.12, 1.6, trunk)
		P.sph(self, Vector3(x, 2.3, 23.4), 0.9, leaf)
		P.sph(self, Vector3(x + 0.4, 2.8, 23.4), 0.6, leaf_b)
	for x: float in [-18.0, 6.0, 20.0]:
		P.cyl(self, Vector3(x, 0.8, 36.6), 0.12, 1.6, trunk)
		P.sph(self, Vector3(x, 2.3, 36.6), 0.9, leaf_b)
	# Bancos.
	for x: float in [-12.0, 11.0]:
		P.box(self, Vector3(x, 0.45, 24.9), Vector3(1.6, 0.1, 0.5), P.mat("#6A4A30"))
		P.box(self, Vector3(x, 0.8, 25.1), Vector3(1.6, 0.4, 0.08), P.mat("#6A4A30"))

func _car(color: String) -> Node3D:
	var car: Node3D = Node3D.new()
	P.box(car, Vector3(0, 0.45, 0), Vector3(3.8, 0.7, 1.7), P.mat(color, "", 0.0, 0.4, 1.0, 0.35))
	P.box(car, Vector3(-0.2, 1.0, 0), Vector3(2.0, 0.55, 1.5), P.mat("#10181F", "", 0.0, 0.6, 1.0, 0.2))
	var wheel: StandardMaterial3D = P.mat("#0A0A0A")
	for wx: float in [-1.2, 1.2]:
		for wz: float in [-0.85, 0.85]:
			P.cyl(car, Vector3(wx, 0.28, wz), 0.28, 0.22, wheel, Vector3(90, 0, 0))
	P.box(car, Vector3(1.92, 0.5, -0.55), Vector3(0.06, 0.18, 0.3), P.mat("#FFF8D0", "#FFF8D0", 3.0))
	P.box(car, Vector3(1.92, 0.5, 0.55), Vector3(0.06, 0.18, 0.3), P.mat("#FFF8D0", "#FFF8D0", 3.0))
	P.box(car, Vector3(-1.92, 0.5, -0.55), Vector3(0.06, 0.16, 0.3), P.mat("#FF3030", "#FF3030", 2.0))
	P.box(car, Vector3(-1.92, 0.5, 0.55), Vector3(0.06, 0.16, 0.3), P.mat("#FF3030", "#FF3030", 2.0))
	add_child(car)
	return car

func _build_cars() -> void:
	var colors: Array = ["#D84F6B", "#4F9AD8", "#E8D8A0", "#6BD8A0", "#B04FD8", "#D8803F"]
	for i: int in range(6):
		var car: Node3D = _car(str(colors[i]))
		var dir: float = 1.0 if i % 2 == 0 else -1.0
		car.position = Vector3(-40.0 + float(i) * 14.0, 0.0, ROAD_Z - 2.0 * dir)
		car.rotation_degrees.y = 0.0 if dir > 0.0 else 180.0
		_cars.append({"node": car, "dir": dir, "speed": 4.5 + float(i % 3) * 1.8})

func _build_peds() -> void:
	var shirts: Array = ["#D84F6B", "#4F9AD8", "#E8B04A", "#6BD8A0", "#B04FD8", "#D8D8E0", "#E07A3F", "#4FD8C8"]
	for i: int in range(10):
		var ped: Node3D = Node3D.new()
		var shirt: String = str(shirts[i % shirts.size()])
		P.capsule(ped, Vector3(0, 0.85, 0), 0.2, 1.1, P.mat(shirt))
		P.box(ped, Vector3(0, 0.34, 0), Vector3(0.3, 0.6, 0.2), P.mat("#1A2430"))
		P.sph(ped, Vector3(0, 1.58, 0), 0.17, P.mat("#E0B898" if i % 3 != 0 else "#8A5A3A"))
		P.box(ped, Vector3(0, 1.74, 0), Vector3(0.3, 0.08, 0.3), P.mat("#10161D"))
		var north: bool = i % 2 == 0
		var dir: float = 1.0 if i % 4 < 2 else -1.0
		ped.position = Vector3(-22.0 + float(i) * 4.4, 0.1, 24.6 if north else 35.4)
		add_child(ped)
		_peds.append({"node": ped, "dir": dir, "speed": 0.9 + float(i % 4) * 0.25, "phase": float(i)})

func _build_police() -> void:
	_police = _car("#E8E8EE")
	_police.position = Vector3(-4.0, 0.0, ROAD_Z - 2.9)
	P.box(_police, Vector3(0.0, 0.45, 0.0), Vector3(3.84, 0.3, 1.72), P.mat("#0A0E14"))
	var red: StandardMaterial3D = P.mat("#FF2020", "#FF2020", 3.0)
	var blue: StandardMaterial3D = P.mat("#2060FF", "#2060FF", 3.0)
	_police_lights = [P.box(_police, Vector3(0.1, 1.38, -0.4), Vector3(0.3, 0.14, 0.4), red), P.box(_police, Vector3(0.1, 1.38, 0.4), Vector3(0.3, 0.14, 0.4), blue)]
	_police_red = P.light(_police, Vector3(0.1, 1.6, -0.5), "#FF2020", 0.0, 8.0, false)
	_police_blue = P.light(_police, Vector3(0.1, 1.6, 0.5), "#2060FF", 0.0, 8.0, false)
	P.label(_police, "POLÍCIA FEDERAL", Vector3(0.0, 0.8, 0.88), 44, Color("#0A0E14"), 0.0, 0.0, true, 0.003)
	_police.visible = false

# =========================================================
# ESTADO E ANIMAÇÃO
# =========================================================

## Atualiza placas, portas e janelas com o estado das empresas.
func refresh() -> void:
	for id: String in _buildings:
		var entry: Dictionary = _buildings[id]
		var status: String = GameManager.company_status(id)
		var win: StandardMaterial3D = entry["win"]
		var door: StandardMaterial3D = entry["door"]
		var sign: Label3D = entry["sign"]
		var text: Label3D = entry["status"]
		var accent: Color = entry["accent"]
		var label_text: String = str(GameManager.companies[id]["name"])
		match status:
			"owned":
				win.emission_energy_multiplier = 1.5
				door.emission = Color("#62E3A2")
				door.emission_energy_multiplier = 1.4
				sign.modulate = accent
				text.text = "ABERTO  ·  SUA"
				text.modulate = Color("#62E3A2")
				label_text += "  ·  OPERAR"
			"sale":
				win.emission_energy_multiplier = 0.5
				door.emission = Color("#FF9950")
				door.emission_energy_multiplier = 1.0
				sign.modulate = accent.darkened(0.2)
				text.text = "À VENDA  ·  %s" % UI.short_money(GameManager.price_of(id))
				text.modulate = Color("#FF9950")
				label_text += "  ·  À VENDA %s" % UI.short_money(GameManager.price_of(id))
			_:
				win.emission_energy_multiplier = 0.25
				door.emission_energy_multiplier = 0.0
				sign.modulate = accent.darkened(0.45)
				text.text = "FECHADO"
				text.modulate = Color("#52646F")
				label_text += "  ·  FECHADO"
		world.set_spot_label("st_" + id, label_text)
	_police.visible = GameManager.suspicion >= 50.0 or Campaign.mandado

func _process(delta: float) -> void:
	if not active:
		return
	_t += delta
	for car_v: Variant in _cars:
		var car: Dictionary = car_v as Dictionary
		var node: Node3D = car["node"]
		node.position.x += float(car["dir"]) * float(car["speed"]) * delta
		if node.position.x > 46.0:
			node.position.x = -46.0
		elif node.position.x < -46.0:
			node.position.x = 46.0
	for ped_v: Variant in _peds:
		var ped: Dictionary = ped_v as Dictionary
		var node2: Node3D = ped["node"]
		node2.position.x += float(ped["dir"]) * float(ped["speed"]) * delta
		if absf(node2.position.x) > 24.0:
			ped["dir"] = -float(ped["dir"])
		node2.position.y = 0.1 + absf(sin(_t * 6.0 * float(ped["speed"]) + float(ped["phase"]))) * 0.05
		node2.rotation_degrees.y = -90.0 * float(ped["dir"])
	if _police.visible:
		var on_red: bool = int(floor(_t * 5.0)) % 2 == 0
		_police_red.light_energy = 3.0 if on_red else 0.0
		_police_blue.light_energy = 0.0 if on_red else 3.0
