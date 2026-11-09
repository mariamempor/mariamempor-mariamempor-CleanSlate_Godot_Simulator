extends Node
## Direção das cenas em 3D: a noite entre dois turnos e os cinco finais.
##
## As cenas (ui/night_scene_3d.gd e ui/ending_scene_3d.gd) cuidam do relatório,
## das legendas e do tempo. Aqui mora só a câmera e o cenário: a cada quadro a
## cena chama night(t) ou ending(kind, t, duração) e este script posiciona a
## câmera, a luz e os objetos para aquele instante.
##
## Linha do tempo da noite (segundos): 0,5 desliga o PC; 1,15 apaga as luzes;
## 2,6 a noite passa; 4,8 o despertador toca; 6,25 o PC liga; 6,85 clarão.

const Sets = preload("res://scripts/world/sets.gd")

const PC_CAM: Vector3 = Vector3(-2.2, 1.32, -2.2)
const PC_LOOK: Vector3 = Vector3(-2.2, 1.2, -3.3)
const BED_CAM: Vector3 = Vector3(3.4, 0.9, 2.9)
const WINDOW_LOOK: Vector3 = Vector3(-4.5, 1.8, 0.2)
const WAKE_CAM: Vector3 = Vector3(3.0, 1.5, 2.0)
const WAKE_LOOK: Vector3 = Vector3(-1.0, 1.0, -1.5)
const MOON_HOME: Vector3 = Vector3(-32.0, 11.0, 6.0)

var world
var sets

var _kind: String = ""
var _eve: float = 0.0

func begin(kind: String) -> void:
	_kind = kind
	_eve = world._day
	sets.hide_all()
	world.cam_rate = 6.0
	world.fade_rect.color = Color(0, 0, 0, 0)
	match kind:
		"takeoff", "runway":
			sets.air_root.visible = true
		"congress":
			sets.hall_root.visible = true
		"arrest", "cartel":
			sets.room_root.visible = true
			sets.door_flood.visible = false
			for agent_v: Variant in sets.room_agents:
				(agent_v as Node3D).visible = false
			sets.laser_dot.visible = false
			sets.cartel_spot.light_energy = 0.0
			sets.door_red.light_energy = 0.0
			sets.door_blue.light_energy = 0.0
	world.snap_pending = kind != "night"

func end() -> void:
	sets.hide_all()
	world.ov_day = -1.0
	world.ov_lights = 1.0
	world.ov_monitor = 1.0
	world.cam_rate = 5.0
	world.fade_rect.color = Color(0, 0, 0, 0)
	world.moon.position = MOON_HOME
	world.zzz_label.visible = false
	world.door_mesh.visible = true
	world.door_mesh.position.x = 0.5
	sets.jet.position = Sets.AIR + Vector3(-34, 1.25, 0)
	sets.jet.rotation_degrees = Vector3.ZERO
	if _kind != "night":
		world.cutscene_reset_camera()
	_kind = ""

func _span(t: float, from: float, to: float) -> float:
	return clampf((t - from) / maxf(to - from, 0.0001), 0.0, 1.0)

func _fade(alpha: float, color: Color = Color(0, 0, 0)) -> void:
	world.fade_rect.color = Color(color.r, color.g, color.b, clampf(alpha, 0.0, 1.0))

# =========================================================
# NOITE
# =========================================================

func night(t: float) -> void:
	var n: float = _span(t, 2.6, 4.8)
	var dawn: float = smoothstep(0.6, 1.0, n)
	# Câmera: no PC, deita na cama olhando a janela, senta, volta ao PC.
	if t < 1.1:
		world.cam_to(PC_CAM, PC_LOOK)
	elif t < 4.9:
		var sway: Vector3 = Vector3(0.03 * sin(t * 1.3), 0.02 * sin(t * 0.9), 0.0)
		world.cam_to(BED_CAM + sway, WINDOW_LOOK)
	elif t < 5.9:
		world.cam_to(WAKE_CAM, WAKE_LOOK)
	else:
		world.cam_to(PC_CAM, PC_LOOK)
	# Luz do céu: anoitece, a noite passa, amanhece.
	var day: float = -1.0
	if t >= 1.15:
		if t < 2.6:
			day = lerpf(_eve, 0.0, _span(t, 1.0, 2.6))
		elif t < 4.8:
			day = 0.7 * dawn
		else:
			day = 0.7 + 0.3 * _span(t, 4.8, 6.5)
	world.ov_day = day
	world.ov_lights = clampf(1.0 - _span(t, 1.0, 1.3) + _span(t, 5.4, 6.0), 0.0, 1.0)
	# Monitor: desliga, fica preto, liga de manhã.
	var power: float = 1.0
	if t >= 0.5 and t < 6.25:
		power = 1.0 - _span(t, 0.5, 1.0)
	elif t >= 6.25:
		power = _span(t, 6.25, 6.85)
	world.ov_monitor = power
	# Lua cruzando a janela e Zzz sobre a cama.
	var moon_f: float = clampf(n / 0.85, 0.0, 1.0)
	world.moon.position = Vector3(-32.0, 5.5 + sin(moon_f * PI) * 2.2, lerpf(-1.5, -12.5, moon_f))
	world.zzz_label.visible = t > 2.9 and t < 4.6
	world.zzz_label.position = Vector3(3.35, 1.15 + 0.08 * sin(t * 2.0), 2.95)
	# Relógio e despertador.
	var minutes: int = int(23 * 60 + 10 + n * float(7 * 60 + 50)) % (24 * 60)
	var text: String = "%02d:%02d" % [minutes / 60, minutes % 60]
	world.alarm_label.text = text
	world._clock_label.text = text
	var ringing: bool = t >= 4.8 and t < 5.3
	world.alarm_label.visible = not (ringing and int(floor(t * 8.0)) % 2 == 0)
	# Clarão do monitor no fim.
	var flash: float = _span(t, 6.85, 7.15)
	_fade(flash * 0.9, Color(0.62, 0.95, 1.0))
	world.alarm_label.modulate = Color("#FF5A4A")

# =========================================================
# FINAIS
# =========================================================

func ending(kind: String, t: float, dur: float) -> void:
	var u: float = clampf(t / maxf(dur, 0.001), 0.0, 1.0)
	match kind:
		"takeoff": _takeoff(u, t)
		"runway": _runway(u, t)
		"congress": _congress(u, t)
		"cartel": _cartel(u, t)
		_: _arrest(u, t)

func _edge_fade(u: float, fade_in: float = 0.08, fade_out_from: float = 0.9) -> void:
	_fade(maxf(1.0 - _span(u, 0.0, fade_in), _span(u, fade_out_from, 1.0)))

func _strobe(red: OmniLight3D, blue: OmniLight3D, t: float, energy: float) -> void:
	var on_red: bool = int(floor(t * 6.0)) % 2 == 0
	red.light_energy = energy if on_red else 0.0
	blue.light_energy = 0.0 if on_red else energy

func _jet_lights(t: float, engines: float) -> void:
	var blink: bool = int(floor(t * 1.8)) % 2 == 0
	(sets.jet_nav[2] as StandardMaterial3D).emission_energy_multiplier = 4.0 if blink else 0.1
	for glow_v: Variant in sets.jet_glow:
		(glow_v as StandardMaterial3D).emission_energy_multiplier = engines

func _takeoff(u: float, t: float) -> void:
	var a: Vector3 = Sets.AIR
	world.ov_day = 0.35 + 0.25 * u
	var lift: float = _span(u, 0.55, 1.0)
	var run: float = pow(u, 2.1)
	var jet: Node3D = sets.jet
	jet.position = a + Vector3(-34.0 + 86.0 * run, 1.25 + 30.0 * lift * lift, 0.0)
	jet.rotation_degrees = Vector3(0, 0, 15.0 * lift)
	_jet_lights(t, 4.0)
	var look: Vector3 = jet.position + Vector3(2.0, 0.4, 0.0)
	if u < 0.45:
		world.cam_to(a + Vector3(-8.0, 1.7, 13.0), look)
	else:
		world.cam_to(a + Vector3(lerpf(-8.0, 14.0, _span(u, 0.45, 1.0)), lerpf(1.7, 3.0, _span(u, 0.45, 1.0)), 15.0), look)
	_edge_fade(u)

func _runway(u: float, t: float) -> void:
	var a: Vector3 = Sets.AIR
	world.ov_day = 0.3 + 0.1 * u
	var brake: float = _span(u, 0.0, 0.62)
	var jet: Node3D = sets.jet
	jet.position = a + Vector3(-30.0 + 34.0 * (1.0 - pow(1.0 - brake, 2.0)), 1.25, 0.0)
	jet.rotation_degrees = Vector3.ZERO
	_jet_lights(t, 2.0)
	for car_v: Variant in sets.strip_cars:
		var car: Dictionary = car_v as Dictionary
		_strobe(car["red"], car["blue"], t, 5.0)
	for i: int in range(sets.strip_agents.size()):
		var agent: Node3D = sets.strip_agents[i]
		var k: float = _span(u, 0.62 + 0.03 * float(i), 0.95)
		agent.position = a + Vector3(lerpf(17.0, 7.5, k), 0.0, -4.0 + float(i) * 2.6)
	world.cam_to(a + Vector3(10.0, 1.5, 11.0), jet.position + Vector3(3.5, 1.2, 0.0))
	_edge_fade(u)

func _congress(u: float, t: float) -> void:
	var h: Vector3 = Sets.HALL
	world.ov_day = 1.0
	var move: float = smoothstep(0.0, 1.0, u)
	world.cam_to(h + Vector3(0.0, lerpf(3.4, 1.9, move), lerpf(14.0, -6.0, move)), h + Vector3(0.0, 2.0, -16.4))
	for i: int in range(sets.crowd.size()):
		var person: Node3D = sets.crowd[i]
		person.position.y = (0.06 * absf(sin(t * 5.0 + float(i)))) if u > 0.35 else 0.0
	for piece_v: Variant in sets.confetti:
		var piece: Dictionary = piece_v as Dictionary
		var node: MeshInstance3D = piece["node"]
		node.visible = u > 0.5
		if u > 0.5:
			var fall: float = fposmod((t - 0.5 * 6.0 * 0.5) * float(piece["speed"]), 8.0)
			node.position = Vector3(float(piece["x0"]) + 0.4 * sin(t * 2.0 + fall), Sets.HALL.y + 8.0 - fall, float(piece["z0"]))
			node.rotation = Vector3(t * float(piece["spin"]), t * float(piece["spin"]) * 0.7, 0.0)
	_edge_fade(u, 0.1, 0.92)

func _arrest(u: float, t: float) -> void:
	world.ov_day = 0.25 + 0.2 * u
	world.ov_monitor = 0.0
	var knock: bool = u < 0.28
	world.door_mesh.visible = knock
	world.door_mesh.position.x = 0.5 + (0.012 * sin(t * 70.0) if knock else 0.0)
	sets.door_flood.visible = not knock
	if not knock:
		_strobe(sets.door_red, sets.door_blue, t, 4.5)
	for i: int in range(sets.room_agents.size()):
		var agent: Node3D = sets.room_agents[i]
		agent.visible = not knock
		var k: float = _span(u, 0.30 + 0.05 * float(i), 0.72)
		agent.position = Vector3(0.1 + float(i) * 0.45 - 0.2 * k * float(i - 1), 0.0, 3.2 - 2.3 * k)
	world.cam_to(Vector3(lerpf(3.6, 2.7, u), 1.55, lerpf(0.2, 0.9, u)), Vector3(0.5, 1.1, 2.8))
	_edge_fade(u, 0.08, 0.88)

func _cartel(u: float, t: float) -> void:
	world.ov_day = 0.0
	var alive: bool = u < 0.7
	world.ov_lights = 1.0 if alive else 0.0
	world.ov_monitor = 1.0 if alive else 0.0
	sets.cartel_spot.light_energy = (12.0 * _span(u, 0.1, 0.45)) if alive else 0.0
	sets.laser_dot.visible = u > 0.45 and alive
	var k: float = _span(u, 0.45, 0.7)
	sets.laser_dot.position = Vector3(lerpf(-0.5, -2.2, k), 1.35 - 0.05 * sin(t * 4.0), -3.42)
	var look: Vector3 = WINDOW_LOOK.lerp(Vector3(-2.2, 1.3, -3.3), _span(u, 0.4, 0.7))
	world.cam_to(Vector3(lerpf(2.4, 0.8, u), 1.45, lerpf(1.8, 1.0, u)), look)
	_fade(1.0 if u >= 0.78 else maxf(1.0 - _span(u, 0.0, 0.08), 0.0))
