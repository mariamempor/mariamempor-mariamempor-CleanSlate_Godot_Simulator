extends Node3D
## APARTAMENTO — construção do quarto, da vista e da iluminação.
##
## Direção de arte "Concreto & Latão": noir de arranha-céu. Grafite e concreto
## nas superfícies, âmbar de tungstênio nas luzes práticas, latão no que é
## dinheiro, oxblood no couro e no tapete, e o frio da cidade entrando pela
## janela. Toda luz tem uma fonte visível no quarto.
##
## O quarto evolui com a campanha (apply_stage): no Ato 1 é um escritório
## improvisado, com caixas de mudança e um monitor; no Ato 2 ganha arte, poltrona,
## bar e mais telas; no Ato 3 vira um bunker de luxo, com câmeras de segurança.
##
## world_3d.gd continua dono das regras de interação; este script só cria os
## nós e entrega a ele as referências que os mostradores usam.

const P = preload("res://scripts/world/prims.gd")
const ScreenUI = preload("res://scripts/world/screen_ui.gd")

const W: float = 4.5           # meia-largura do quarto (x)
const D: float = 3.5           # meia-profundidade (z)
const H: float = 3.2
const DX: float = -2.2         # mesa do computador
const MAQ: Vector3 = Vector3(0.2, 0.0, 0.3)
const WIN_Z0: float = -1.3     # janela na parede oeste
const WIN_Z1: float = 1.7
const WIN_Y0: float = 0.35
const WIN_Y1: float = 2.95
const CITY_Y: float = -34.0    # o apartamento fica no 12º andar

# Paleta (as mesmas cores aparecem na interface, em ui_kit.gd).
const C_TUNGSTEN: Color = Color("#FFB46B")
const C_AMBER: Color = Color("#E8A55A")
const C_BRASS: Color = Color("#C9A35B")
const C_OXBLOOD: Color = Color("#5A1E1E")
const C_TEAL: Color = Color("#5FC4B8")
const C_CITY: Color = Color("#7FA2C8")
const C_RED: Color = Color("#E5484D")

var world

var _models: Dictionary = {}
var _tex: Dictionary = {}
var _stage_nodes: Array = []          # [[node, primeiro ato, último ato]]
var stage: int = 0

# Luzes e materiais animados.
var desk_lamp: SpotLight3D
var pendant: SpotLight3D
var floor_lamp: OmniLight3D
var window_fill: SpotLight3D
var neon_light: SpotLight3D
var neon_mat: StandardMaterial3D
var police_red: SpotLight3D
var police_blue: SpotLight3D
var heli_spot: SpotLight3D
var heli_level: float = 0.0          # 0 a 1: helicóptero da PF sobre o prédio
var hall_mat: StandardMaterial3D
var glass_mat: ShaderMaterial
var facade_mats: Array = []
var aviation_mats: Array = []
var fan_blades: Node3D
var car_lights: Array = []
var screens: Array = []               # {ui, mat, mesh}
var cam_leds: Array = []
var shade_lamps: Array = []           # materiais emissivos das cúpulas
var probe: ReflectionProbe
var rain: float = 1.0
var rain_override: float = -1.0    # testes de captura forçam o tempo
var _t: float = 0.0

# =========================================================
# CARREGAMENTO DE ASSETS
# =========================================================

func model(name: String) -> Node3D:
	if not _models.has(name):
		_models[name] = load("res://assets/models/%s/%s.gltf" % [name, name])
	var scene: PackedScene = _models[name]
	return scene.instantiate() as Node3D

## Só as malhas cujo nome contém `keep`, deslocadas para o centro `shift`.
func part(name: String, keep: String, shift: Vector3 = Vector3.ZERO) -> Node3D:
	var root: Node3D = model(name)
	for mi: Node in root.find_children("*", "MeshInstance3D", true, false):
		if not str(mi.name).contains(keep):
			mi.get_parent().remove_child(mi)
			mi.free()
	var holder: Node3D = Node3D.new()
	holder.add_child(root)
	root.position = -shift
	return holder

func place(node: Node3D, pos: Vector3, yaw: float = 0.0, scale_f: float = 1.0, parent: Node = null) -> Node3D:
	(parent if parent != null else self).add_child(node)
	node.position = pos
	node.rotation_degrees.y = yaw
	node.scale = Vector3.ONE * scale_f
	return node

func shadows_off(node: Node) -> void:
	for mi: Node in node.find_children("*", "GeometryInstance3D", true, false):
		(mi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func tex(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(path)
	return _tex[path]

## Material PBR a partir de uma textura do Poly Haven, projetado no mundo
## (triplanar), para não depender de UV das caixas.
func pbr(name: String, tint: Color, tile: float, rough_scale: float = 1.0, metallic: float = 0.0) -> StandardMaterial3D:
	var base: String = "res://assets/textures/%s/%s_%%s_1k.jpg" % [name, name]
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_texture = tex(base % "diff")
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = tex(base % "nor_gl")
	m.normal_scale = 0.8
	m.roughness_texture = tex(base % "rough")
	m.roughness = rough_scale
	m.metallic = metallic
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * tile
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m

func mat(color: Color, rough: float = 0.8, metallic: float = 0.0) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metallic
	return m

func glow(color: Color, energy: float, albedo: Color = Color.BLACK) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = albedo
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m

func box(pos: Vector3, size: Vector3, m: Material, parent: Node = null, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	return P.box(parent if parent != null else self, pos, size, m, rot)

## Peça que só existe em alguns atos (a evolução do apartamento).
func staged(node: Node3D, first: int, last: int = 9) -> Node3D:
	_stage_nodes.append([node, first, last])
	return node

func group(pos: Vector3 = Vector3.ZERO, yaw: float = 0.0) -> Node3D:
	var g: Node3D = Node3D.new()
	add_child(g)
	g.position = pos
	g.rotation_degrees.y = yaw
	return g

# =========================================================
# CONSTRUÇÃO
# =========================================================

func build() -> void:
	_build_environment()
	_build_shell()
	_build_window()
	_build_city()
	_build_desk()
	_build_corkboard()
	_build_risk_panel()
	_build_filing()
	_build_shredder()
	_build_staff_board()
	_build_living()
	_build_tv()
	_build_vitrine()
	_build_safe()
	_build_bed()
	_build_maquette()
	_build_darkweb()
	_build_door()
	_build_props()
	_build_cases()
	apply_stage(1)
	UI.quality_changed.connect(apply_quality)
	apply_quality()

## Alta: SSIL, SSR e névoa volumétrica. Média: só SSAO e névoa comum (a luz
## volumétrica some, mas a composição continua a mesma).
func apply_quality() -> void:
	var env: Environment = (world.env_node as WorldEnvironment).environment
	var high: bool = UI.quality != "media"
	env.ssil_enabled = high
	env.ssr_enabled = high
	env.volumetric_fog_enabled = high
	env.fog_density = 0.006 if high else 0.012
	(world.lamp as Light3D).shadow_enabled = high
	get_viewport().msaa_3d = Viewport.MSAA_2X if high else Viewport.MSAA_DISABLED
	get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED if high else Viewport.SCREEN_SPACE_AA_FXAA

func _build_environment() -> void:
	var sky_mat: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_mat.sky_curve = 0.12
	sky_mat.ground_curve = 0.04
	sky_mat.sun_angle_max = 8.0
	var sky: Sky = Sky.new()
	sky.sky_material = sky_mat
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#141B22")
	env.ambient_light_energy = 0.5
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	# AgX mantém o tom das luzes quentes sem estourar em amarelo-neon.
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.25
	env.tonemap_agx_contrast = 1.35
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.ssao_enabled = true
	env.ssao_radius = 0.9
	env.ssao_intensity = 1.6
	env.ssao_power = 1.4
	env.ssil_enabled = true
	env.ssil_radius = 3.0
	env.ssil_intensity = 1.2
	env.ssr_enabled = true
	env.ssr_max_steps = 48
	env.ssr_fade_in = 0.2
	env.ssr_fade_out = 1.5
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_density = 0.006
	env.fog_sky_affect = 0.35
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.018
	env.volumetric_fog_albedo = Color("#C8C2B8")
	env.volumetric_fog_length = 24.0
	env.volumetric_fog_ambient_inject = 0.0
	env.volumetric_fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.04
	env.adjustment_saturation = 0.92
	var env_node: WorldEnvironment = WorldEnvironment.new()
	env_node.environment = env
	add_child(env_node)
	world.env_node = env_node
	world.sky_mat = sky_mat

	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 22.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.shadow_blur = 1.5
	sun.light_volumetric_fog_energy = 1.6
	sun.rotation_degrees = Vector3(-30, -98, 0)
	add_child(sun)
	world.sun = sun

	# Estrelas quase não existem no céu de uma metrópole: poucas e fracas.
	var stars: Node3D = Node3D.new()
	add_child(stars)
	world.stars_root = stars
	var star_mat: StandardMaterial3D = glow(Color("#CFE3FF"), 1.2)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	for i: int in range(40):
		box(Vector3(rng.randf_range(-90.0, -60.0), rng.randf_range(18.0, 50.0), rng.randf_range(-50.0, 50.0)), Vector3.ONE * 0.18, star_mat, stars)
	world.moon = P.sph(self, Vector3(-32.0, 11.0, 6.0), 1.3, glow(Color("#E6ECF4"), 2.2, Color("#E6ECF4")))

	probe = ReflectionProbe.new()
	probe.size = Vector3(W * 2.0, H, D * 2.0)
	probe.position = Vector3(0, H * 0.5, 0)
	probe.box_projection = true
	probe.interior = true
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	probe.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
	add_child(probe)

func _build_shell() -> void:
	var floor_mat: StandardMaterial3D = pbr("rectangular_parquet", Color("#8C7362"), 0.45, 0.9)
	var wall: StandardMaterial3D = pbr("plastered_wall_04", Color("#6E6A64"), 0.35)
	var concrete: StandardMaterial3D = pbr("precast_concrete_wall", Color("#8A8782"), 0.28)
	var ceil_mat: StandardMaterial3D = pbr("plastered_wall_04", Color("#3A3936"), 0.35)
	var trim: StandardMaterial3D = mat(Color("#121315"), 0.6)
	var t: float = 0.15
	box(Vector3(0, -0.05, 0), Vector3(W * 2.0, 0.1, D * 2.0), floor_mat)
	box(Vector3(0, H + 0.05, 0), Vector3(W * 2.0, 0.1, D * 2.0), ceil_mat)
	# Parede norte em concreto aparente: o fundo do "escritório".
	box(Vector3(0, H * 0.5, -D - 0.07), Vector3(W * 2.0 + 0.3, H, t), concrete)
	box(Vector3(0, H * 0.5, D + 0.07), Vector3(W * 2.0 + 0.3, H, t), wall)
	box(Vector3(W + 0.07, H * 0.5, 0), Vector3(t, H, D * 2.0), wall)
	# Parede oeste com a janela grande.
	var wx: float = -W - 0.07
	box(Vector3(wx, WIN_Y0 * 0.5, 0), Vector3(t, WIN_Y0, D * 2.0), wall)
	box(Vector3(wx, (WIN_Y1 + H) * 0.5, 0), Vector3(t, H - WIN_Y1, D * 2.0), wall)
	box(Vector3(wx, H * 0.5, (-D + WIN_Z0) * 0.5), Vector3(t, H, WIN_Z0 + D), wall)
	box(Vector3(wx, H * 0.5, (WIN_Z1 + D) * 0.5), Vector3(t, H, D - WIN_Z1), wall)
	# Rodapés e sanca escura.
	for z: float in [-D + 0.02, D - 0.02]:
		box(Vector3(0, 0.06, z), Vector3(W * 2.0, 0.12, 0.03), trim)
	box(Vector3(W - 0.02, 0.06, 0), Vector3(0.03, 0.12, D * 2.0), trim)
	box(Vector3(-W + 0.02, 0.06, -2.4), Vector3(0.03, 0.12, 2.2), trim)
	box(Vector3(-W + 0.02, 0.06, 2.6), Vector3(0.03, 0.12, 1.8), trim)
	# Sanca com fita de LED âmbar escondida (só a partir do Ato 2).
	var cove: MeshInstance3D = box(Vector3(0, H - 0.2, -D + 0.06), Vector3(W * 2.0, 0.015, 0.015), glow(C_AMBER, 2.5))
	staged(cove, 2)
	staged(box(Vector3(0, H - 0.22, -D + 0.16), Vector3(W * 2.0, 0.03, 0.2), mat(Color("#1A1A1A"), 0.7)), 2)
	staged(box(Vector3(0, H - 0.16, -D + 0.255), Vector3(W * 2.0, 0.1, 0.012), mat(Color("#1A1A1A"), 0.7)), 2)
	var cove_light: SpotLight3D = _spotlight(Vector3(0, H - 0.1, -D + 0.25), Vector3(0, 0.5, -D + 0.1), C_AMBER, 0.0, 4.0, 80.0, false)
	cove_light.spot_attenuation = 0.6
	staged(cove_light, 2)
	cove_light.set_meta("energy", 1.2)

func _build_window() -> void:
	var frame: StandardMaterial3D = mat(Color("#1A1C1F"), 0.35, 0.6)
	var x: float = -W + 0.02
	var zc: float = (WIN_Z0 + WIN_Z1) * 0.5
	var zw: float = WIN_Z1 - WIN_Z0
	var yc: float = (WIN_Y0 + WIN_Y1) * 0.5
	var yh: float = WIN_Y1 - WIN_Y0
	box(Vector3(x, WIN_Y0, zc), Vector3(0.16, 0.06, zw + 0.1), frame)
	box(Vector3(x, WIN_Y1, zc), Vector3(0.16, 0.06, zw + 0.1), frame)
	box(Vector3(x, 2.28, zc), Vector3(0.10, 0.04, zw), frame)
	for z: float in [WIN_Z0, -0.3, 0.7, WIN_Z1]:
		box(Vector3(x, yc, z), Vector3(0.14, yh, 0.05), frame)
	# Peitoril de pedra escura.
	box(Vector3(-W + 0.16, WIN_Y0 - 0.02, zc), Vector3(0.36, 0.05, zw + 0.3), pbr("precast_concrete_wall", Color("#4A4846"), 0.6, 0.6))
	var glass: MeshInstance3D = MeshInstance3D.new()
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(zw, yh)
	glass.mesh = quad
	glass_mat = ShaderMaterial.new()
	glass_mat.shader = load("res://assets/shaders/rain_glass.gdshader")
	glass.material_override = glass_mat
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glass)
	glass.position = Vector3(-W - 0.03, yc, zc)
	glass.rotation_degrees.y = 90.0
	# Cortinas leves nas laterais (voal), que deixam a luz da cidade passar.
	var voile: StandardMaterial3D = mat(Color(0.78, 0.76, 0.72, 0.55), 1.0)
	voile.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	voile.cull_mode = BaseMaterial3D.CULL_DISABLED
	for z: float in [WIN_Z0 - 0.15, WIN_Z1 + 0.15]:
		for k: int in range(5):
			var fold: MeshInstance3D = box(Vector3(-W + 0.16 + 0.02 * float(k % 2), 1.55, z - 0.16 + float(k) * 0.08), Vector3(0.01, 2.95, 0.09), voile, null, Vector3(0, 25.0 * (1.0 if k % 2 == 0 else -1.0), 0))
			fold.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	P.cyl(self, Vector3(-W + 0.18, 3.05, 0.2), 0.012, 4.6, mat(C_BRASS, 0.3, 0.9), Vector3(90, 0, 0))
	# Luz fria da cidade que entra pela janela (de noite é ela que desenha o chão).
	window_fill = _spotlight(Vector3(-9.0, 3.6, zc), Vector3(0.0, 0.0, zc), C_CITY, 1.0, 16.0, 22.0, false)
	window_fill.light_volumetric_fog_energy = 2.5
	window_fill.spot_attenuation = 0.4

func _spotlight(pos: Vector3, target: Vector3, color: Color, energy: float, range_m: float, angle: float, shadows: bool) -> SpotLight3D:
	var l: SpotLight3D = SpotLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.spot_range = range_m
	l.spot_angle = angle
	l.shadow_enabled = shadows
	l.shadow_blur = 1.5
	add_child(l)
	l.look_at_from_position(pos, target, Vector3.UP if absf((target - pos).normalized().y) < 0.98 else Vector3.FORWARD)
	return l

func _omni(pos: Vector3, color: Color, energy: float, range_m: float, shadows: bool = false) -> OmniLight3D:
	var l: OmniLight3D = OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = range_m
	l.omni_attenuation = 1.4
	l.shadow_enabled = shadows
	add_child(l)
	return l

# ---------------------------------------------------------
# Vista: a cidade do 12º andar
# ---------------------------------------------------------

func _build_city() -> void:
	var shader: Shader = load("res://assets/shaders/city_facade.gdshader")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 20261009
	var city: Node3D = Node3D.new()
	add_child(city)
	# Três camadas: prédios vizinhos abaixo da linha dos olhos, um miolo de
	# altura média e o skyline de torres ao fundo, recortado contra o céu.
	var layers: Array = [
		{"x": -16.0, "depth": 16.0, "h": Vector2(14.0, 31.0), "w": Vector2(7.0, 12.0), "lit": 0.30, "glow": 2.6, "cell": Vector2(1.2, 3.2), "base": Color("#0D1014")},
		{"x": -45.0, "depth": 26.0, "h": Vector2(22.0, 44.0), "w": Vector2(9.0, 16.0), "lit": 0.24, "glow": 2.4, "cell": Vector2(1.6, 3.4), "base": Color("#0B0E12")},
		{"x": -110.0, "depth": 40.0, "h": Vector2(28.0, 62.0), "w": Vector2(10.0, 22.0), "lit": 0.20, "glow": 2.2, "cell": Vector2(2.2, 3.8), "base": Color("#0A0C10")},
	]
	for layer: Dictionary in layers:
		var m: ShaderMaterial = ShaderMaterial.new()
		m.shader = shader
		m.set_shader_parameter("lit_ratio", layer["lit"])
		m.set_shader_parameter("glow", layer["glow"])
		m.set_shader_parameter("base_color", layer["base"])
		m.set_shader_parameter("cell", layer["cell"])
		facade_mats.append(m)
		# Uma camada inteira é um desenho só (MultiMesh): o shader usa a posição
		# no mundo, então cada prédio escalado mantém janelas do tamanho certo.
		var transforms: Array = []
		var span: float = 60.0 + absf(float(layer["x"])) * 0.9
		var z: float = -span
		while z < span:
			var hv: Vector2 = layer["h"]
			var wv: Vector2 = layer["w"]
			var w: float = rng.randf_range(wv.x, wv.y)
			var d: float = rng.randf_range(8.0, float(layer["depth"]))
			var h: float = rng.randf_range(hv.x, hv.y)
			# Recuo aleatório: a rua não é uma parede contínua.
			var bx: float = float(layer["x"]) - d * 0.5 - rng.randf_range(0.0, 10.0)
			transforms.append(Transform3D(Basis.from_scale(Vector3(d, h, w)), Vector3(bx, CITY_Y + h * 0.5, z + w * 0.5)))
			if h > 38.0 and rng.randf() < 0.6:
				if aviation_mats.is_empty():
					aviation_mats.append(glow(C_RED, 4.0, Color("#330000")))
				var dot: MeshInstance3D = P.sph(city, Vector3(bx, CITY_Y + h + 0.8, z + w * 0.5), 0.45, aviation_mats[0])
				dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			z += w + rng.randf_range(2.0, 9.0)
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = BoxMesh.new()
		mm.instance_count = transforms.size()
		for i: int in range(transforms.size()):
			mm.set_instance_transform(i, transforms[i])
		var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = m
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		city.add_child(mmi)
	# Rua lá embaixo: faixa escura e faróis correndo.
	box(Vector3(-11.0, CITY_Y + 0.05, 0), Vector3(6.0, 0.1, 160.0), mat(Color("#0B0C0E"), 0.4), city)
	for i: int in range(18):
		var red: bool = i % 2 == 0
		var car: MeshInstance3D = box(Vector3(-12.2 if red else -9.8, CITY_Y + 0.4, rng.randf_range(-55.0, 55.0)), Vector3(0.35, 0.12, 0.9), glow(Color("#FF3B30") if red else Color("#FFE6B8"), 6.0), city)
		car.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		car_lights.append([car, (1.0 if red else -1.0) * rng.randf_range(7.0, 12.0)])
	# Letreiro vermelho do hotel do outro lado da rua: a luz que pulsa no quarto.
	var sign_root: Node3D = group(Vector3(-13.5, -3.0, -3.5))
	box(Vector3(0.4, 3.0, 0), Vector3(0.4, 9.0, 1.4), mat(Color("#121212")), sign_root)
	neon_mat = glow(Color("#FF3A3A"), 5.0, Color("#220000"))
	var letters: String = "HOTEL"
	for i: int in range(letters.length()):
		var l: Label3D = Label3D.new()
		l.text = letters[i]
		l.font_size = 240
		l.pixel_size = 0.006
		l.modulate = Color(4.0, 0.5, 0.45)
		l.shaded = false
		l.outline_size = 0
		if UI.font_bold != null:
			l.font = UI.font_bold
		sign_root.add_child(l)
		l.position = Vector3(0.65, 6.6 - float(i) * 1.55, 0)
		l.rotation_degrees.y = 90.0
	neon_light = _spotlight(Vector3(-10.0, 1.2, -3.0), Vector3(0.0, 0.6, 1.0), Color("#FF4A3A"), 0.6, 16.0, 20.0, false)
	neon_light.light_volumetric_fog_energy = 1.5
	# Viaturas: só aparecem com suspeita alta, de noite.
	police_red = _spotlight(Vector3(-9.0, -1.5, -0.8), Vector3(0.0, 2.6, 0.6), Color("#FF2A2A"), 0.0, 18.0, 16.0, false)
	police_blue = _spotlight(Vector3(-9.0, -1.5, 1.2), Vector3(0.0, 2.6, -0.2), Color("#2A6BFF"), 0.0, 18.0, 16.0, false)
	# Holofote do helicóptero: varre o quarto pela janela quando a coisa aperta.
	heli_spot = _spotlight(Vector3(-16.0, 12.0, 0.2), Vector3(0.0, 0.0, 0.2), Color("#E8F0FF"), 0.0, 40.0, 7.0, true)
	heli_spot.light_volumetric_fog_energy = 3.0
	heli_spot.shadow_blur = 0.5

# ---------------------------------------------------------
# Mesa de trabalho (computador) — o coração do apartamento
# ---------------------------------------------------------

func _build_desk() -> void:
	var dz: float = -3.0
	var desk: Node3D = place(model("metal_office_desk"), Vector3(DX, 0, dz), 0.0)
	world._block(Vector3(DX, 0, dz), Vector3(2.0, 0, 0.92))
	place(model("modern_arm_chair_01"), Vector3(DX + 0.05, 0, -2.15), 168.0)
	var top: float = 0.79
	# Luminária articulada: a luz-chave do quarto.
	place(model("desk_lamp_arm_01"), Vector3(DX - 0.78, top, dz - 0.2), 150.0)
	desk_lamp = _spotlight(Vector3(DX - 0.62, 1.45, dz + 0.02), Vector3(DX - 0.15, top, dz + 0.05), C_TUNGSTEN, 4.0, 3.2, 48.0, true)
	desk_lamp.light_volumetric_fog_energy = 1.2
	desk_lamp.spot_attenuation = 0.9
	# Papelada, canetas, cigarreira e o porta-retratos de alguém que não liga mais.
	place(part("office_notepads", "yellow_pad", Vector3(0.15, 0, -0.175)), Vector3(DX + 0.55, top + 0.002, dz + 0.18), 12.0)
	place(part("office_notepads", "a4_stack", Vector3(-0.45, 0, -0.175)), Vector3(DX - 0.35, top + 0.002, dz + 0.2), -8.0)
	place(part("office_notepads", "sticky_stack", Vector3(0.45, 0, 0.085)), Vector3(DX + 0.32, top + 0.002, dz + 0.3), 20.0)
	place(model("stationery_supplies"), Vector3(DX + 0.82, top + 0.07, dz - 0.25), 90.0)
	place(part("binder_notebook", "closed", Vector3(0.26733, 0, 0)), Vector3(DX + 0.78, top, dz + 0.12), 75.0)
	place(model("cigarette_case"), Vector3(DX - 0.55, top, dz + 0.28), 35.0, 0.8)
	place(model("standing_picture_frame_01"), Vector3(DX - 0.88, top, dz + 0.1), 30.0)
	# Caneca de café com a borda gasta.
	var mug: Node3D = group(Vector3(DX + 0.62, top, dz - 0.05))
	P.cyl(mug, Vector3(0, 0.05, 0), 0.042, 0.1, mat(Color("#D9D3C7"), 0.35))
	P.cyl(mug, Vector3(0, 0.098, 0), 0.036, 0.004, mat(Color("#1B0F08"), 0.1))
	# Monitores: 1 no Ato 1, 2 no Ato 2, 3 no Ato 3.
	var bezel: StandardMaterial3D = mat(Color("#0B0C0E"), 0.35, 0.4)
	var main_screen: MeshInstance3D = _monitor(Vector3(DX, top, dz - 0.12), 0.0, Vector2(0.86, 0.49), "main", bezel)
	world._mon_mat = main_screen.material_override
	staged(_monitor(Vector3(DX + 0.86, top, dz - 0.02), -24.0, Vector2(0.6, 0.34), "ledger", bezel).get_parent() as Node3D, 2)
	staged(_monitor(Vector3(DX - 0.86, top, dz - 0.02), 24.0, Vector2(0.6, 0.34), "market", bezel).get_parent() as Node3D, 3)
	# Teclado e mouse.
	box(Vector3(DX, top + 0.012, dz + 0.24), Vector3(0.44, 0.022, 0.14), mat(Color("#141518"), 0.5))
	box(Vector3(DX + 0.32, top + 0.012, dz + 0.26), Vector3(0.06, 0.024, 0.1), mat(Color("#141518"), 0.4))
	world.monitor_light = _omni(Vector3(DX, 1.15, dz + 0.45), Color("#9FD8E8"), 0.6, 2.6)
	# Ato 1: caixas de mudança ainda fechadas ao lado da mesa.
	var boxes: Node3D = staged(group(Vector3(-3.9, 0, -1.9)), 1, 1)
	var cardboard: StandardMaterial3D = mat(Color("#8A6A45"), 0.95)
	box(Vector3(0, 0.22, 0), Vector3(0.6, 0.44, 0.45), cardboard, boxes)
	box(Vector3(0.05, 0.62, 0.02), Vector3(0.5, 0.36, 0.4), cardboard, boxes, Vector3(0, 8, 0))
	box(Vector3(0.05, 0.805, 0.02), Vector3(0.06, 0.005, 0.41), mat(Color("#C9B48A"), 0.6), boxes, Vector3(0, 8, 0))
	box(Vector3(0.0, 0.18, 0.62), Vector3(0.55, 0.36, 0.5), cardboard, boxes, Vector3(0, -12, 0))
	world._block(Vector3(-3.9, 0, -1.6), Vector3(0.7, 0, 1.2))
	if desk == null:
		return

## Monitor de braço fino com a tela desenhada por screen_ui.gd.
func _monitor(base: Vector3, yaw: float, screen: Vector2, kind: String, bezel: StandardMaterial3D) -> MeshInstance3D:
	var g: Node3D = group(base, yaw)
	box(Vector3(0, 0.005, 0.02), Vector3(0.22, 0.01, 0.16), bezel, g)
	box(Vector3(0, 0.17, 0.0), Vector3(0.04, 0.32, 0.03), bezel, g)
	var cy: float = 0.2 + screen.y * 0.5
	box(Vector3(0, cy, -0.01), Vector3(screen.x + 0.02, screen.y + 0.02, 0.025), bezel, g)
	var mesh: MeshInstance3D = _screen(g, Vector3(0, cy, 0.0035), screen, kind, Vector2i(int(screen.x * 900), int(screen.y * 900)))
	return mesh

## Uma tela viva: SubViewport com o conteúdo, aplicado como emissão.
func _screen(parent: Node3D, pos: Vector3, size_m: Vector2, kind: String, px: Vector2i) -> MeshInstance3D:
	var vp: SubViewport = SubViewport.new()
	vp.size = px
	vp.transparent_bg = false
	# Só redesenha quando o conteúdo muda (screen_ui.gd pede): cinco telas
	# renderizando todo quadro pesavam em placa integrada.
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.disable_3d = true
	add_child(vp)
	var ui: Control = ScreenUI.new()
	ui.set("kind", kind)
	ui.set("world", world)
	ui.set("viewport", vp)
	ui.size = Vector2(px)
	vp.add_child(ui)
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color.BLACK
	m.emission_enabled = true
	m.emission_texture = vp.get_texture()
	m.emission = Color.WHITE
	m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	m.emission_energy_multiplier = 1.6
	m.roughness = 0.55
	m.metallic_specular = 0.25
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var quad: QuadMesh = QuadMesh.new()
	quad.size = size_m
	mesh.mesh = quad
	mesh.material_override = m
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	mesh.position = pos
	screens.append({"ui": ui, "mat": m, "mesh": mesh, "vp": vp})
	return mesh

# ---------------------------------------------------------
# Parede norte: quadro de investigação, painel de risco, arquivo
# ---------------------------------------------------------

func _cork_board(pos: Vector3, size: Vector2, yaw: float) -> Node3D:
	var g: Node3D = group(pos, yaw)
	box(Vector3(0, 0, 0), Vector3(size.x + 0.08, size.y + 0.08, 0.04), mat(Color("#1E1712"), 0.6), g)
	var cork: StandardMaterial3D = mat(Color("#7A5636"), 1.0)
	cork.albedo_texture = tex("res://assets/textures/plastered_wall_04/plastered_wall_04_diff_1k.jpg")
	cork.albedo_color = Color("#9C7148")
	box(Vector3(0, 0, 0.022), Vector3(size.x, size.y, 0.01), cork, g)
	return g

func _build_corkboard() -> void:
	var z: float = -D + 0.03
	_cork_board(Vector3(0.3, 1.62, z), Vector2(1.9, 1.15), 0.0)
	var root: Node3D = Node3D.new()
	root.position = Vector3(0.3, 1.62, z + 0.05)
	add_child(root)
	world._cork_root = root
	var l: SpotLight3D = _spotlight(Vector3(0.3, 3.1, -2.5), Vector3(0.3, 1.55, z), C_TUNGSTEN, 2.2, 3.5, 30.0, false)
	l.spot_attenuation = 1.2
	_picture_lamp(Vector3(0.3, 2.32, z + 0.06), 1.0)

## Arandela de latão sobre quadros (dá motivo à luz que bate neles).
func _picture_lamp(pos: Vector3, width: float, yaw: float = 0.0) -> void:
	var g: Node3D = group(pos, yaw)
	box(Vector3(0, 0, 0), Vector3(0.05, 0.05, 0.04), mat(C_BRASS, 0.3, 0.9), g)
	P.cyl(g, Vector3(0, 0.0, 0.1), 0.012, 0.2, mat(C_BRASS, 0.3, 0.9), Vector3(90, 0, 0))
	P.cyl(g, Vector3(0, -0.01, 0.2), 0.035, width * 0.5, mat(C_BRASS, 0.3, 0.9), Vector3(0, 0, 90))
	var bulb: StandardMaterial3D = glow(C_TUNGSTEN, 3.0, Color("#FFE2B8"))
	shade_lamps.append(bulb)
	box(Vector3(0, -0.04, 0.2), Vector3(width * 0.45, 0.01, 0.03), bulb, g)

func _build_risk_panel() -> void:
	var cx: float = 2.35
	var z: float = -D + 0.04
	var case_mat: StandardMaterial3D = mat(Color("#1A1C1E"), 0.45, 0.5)
	box(Vector3(cx, 1.65, z), Vector3(1.5, 1.1, 0.07), case_mat)
	box(Vector3(cx, 1.65, z + 0.04), Vector3(1.42, 1.02, 0.01), mat(Color("#0A0B0C"), 0.25))
	# Parafusos nos cantos: equipamento, não pôster.
	for sx: float in [-0.69, 0.69]:
		for sy: float in [-0.49, 0.49]:
			P.cyl(self, Vector3(cx + sx, 1.65 + sy, z + 0.045), 0.012, 0.01, mat(Color("#55585C"), 0.3, 0.9), Vector3(90, 0, 0))
	world._lbl(self, "MONITOR DE SUSPEITA", Vector3(cx, 2.07, z + 0.05), 30, Color("#8E8A82"), 0.0, 0.0, true)
	for i: int in range(20):
		var m: StandardMaterial3D = P.mat("#121314", "#FFFFFF", 0.0)
		world._risk_mats.append(m)
		box(Vector3(cx - 0.62 + float(i) * 0.0654, 1.8, z + 0.05), Vector3(0.05, 0.2, 0.015), m)
	world._risk_label = world._lbl(self, "0%", Vector3(cx, 1.45, z + 0.055), 110, C_TEAL, 0.0, 0.0, true)
	world._risk_state = world._lbl(self, "", Vector3(cx, 1.19, z + 0.055), 30, Color("#8E8A82"), 0.0, 0.0, true)
	# Relógio de parede: dígitos âmbar num mostrador preto.
	P.cyl(self, Vector3(1.2, 2.72, z + 0.03), 0.24, 0.04, mat(Color("#141414"), 0.3, 0.6), Vector3(90, 0, 0))
	P.cyl(self, Vector3(1.2, 2.72, z + 0.05), 0.215, 0.01, mat(Color("#070707"), 0.2), Vector3(90, 0, 0))
	world._clock_label = world._lbl(self, "08:00", Vector3(1.2, 2.72, z + 0.065), 50, C_AMBER * 1.6, 0.0, 0.0, true)

func _build_filing() -> void:
	var x: float = 3.85
	var z: float = -3.2
	place(model("drawer_cabinet"), Vector3(x, 0, z), 0.0)
	world._block(Vector3(x, 0, z), Vector3(1.14, 0, 0.5))
	world._file_label = world._lbl(self, "", Vector3(x, 1.95, z + 0.1), 24, Color("#C9C1B2"), 0.0, 0.0, true)
	place(part("binder_notebook", "binder_notebook", Vector3.ZERO), Vector3(x - 0.2, 1.88, z), 0.0)
	staged(place(model("potted_plant_04"), Vector3(x + 0.3, 1.88, z), 0.0, 1.4) as Node3D, 1)

func _build_shredder() -> void:
	var x: float = 2.62
	var z: float = -3.22
	var steel: StandardMaterial3D = mat(Color("#2A2D30"), 0.4, 0.7)
	world._solid(Vector3(x, 0.36, z), Vector3(0.46, 0.72, 0.36), steel)
	box(Vector3(x, 0.75, z), Vector3(0.5, 0.06, 0.4), mat(Color("#121314"), 0.5, 0.4))
	world._shred_mat = P.mat("#000000", "#E8A55A", 0.6)
	box(Vector3(x, 0.785, z), Vector3(0.34, 0.012, 0.05), world._shred_mat)
	box(Vector3(x - 0.08, 0.84, z), Vector3(0.12, 0.1, 0.004), mat(Color("#E8E2D4"), 0.9), null, Vector3(0, 0, -8))
	box(Vector3(x + 0.08, 0.83, z), Vector3(0.12, 0.08, 0.004), mat(Color("#E8E2D4"), 0.9), null, Vector3(0, 0, 10))
	world._lbl(self, "TRITURADOR", Vector3(x, 0.6, z + 0.19), 20, C_AMBER, 0.0, 0.0, true)

func _build_staff_board() -> void:
	var x: float = -W + 0.03
	var z: float = -2.3
	_cork_board(Vector3(x, 1.65, z), Vector2(1.7, 1.2), 90.0)
	var root: Node3D = Node3D.new()
	root.position = Vector3(x + 0.04, 1.66, z)
	add_child(root)
	world._staff_root = root
	var l: SpotLight3D = _spotlight(Vector3(-3.2, 3.1, z), Vector3(x, 1.6, z), C_TUNGSTEN, 2.0, 3.5, 32.0, false)
	l.spot_attenuation = 1.2
	_picture_lamp(Vector3(x + 0.06, 2.35, z), 0.9, 90.0)

# ---------------------------------------------------------
# Sala: sofá, TV, poltrona perto da janela, bar
# ---------------------------------------------------------

func _build_living() -> void:
	# Tapete oxblood em espinha de peixe (Ato 2+).
	var rug: MeshInstance3D = box(Vector3(-2.3, 0.008, 1.95), Vector3(3.4, 0.016, 2.3), pbr("poly_wool_herringbone", Color("#7A3A34"), 1.6, 1.0))
	staged(rug, 2)
	var rug1: MeshInstance3D = box(Vector3(-2.3, 0.006, 2.0), Vector3(2.2, 0.012, 1.4), pbr("poly_wool_herringbone", Color("#5C5A55"), 1.6, 1.0))
	staged(rug1, 1, 1)
	place(model("sofa_03"), Vector3(-2.4, 0, 1.72), 0.0, 0.92)
	world._block(Vector3(-2.4, 0, 1.72), Vector3(2.5, 0, 0.85))
	staged(place(part("throw_pillows_01", "pillow01", Vector3(-0.266, 0, 0.111)), Vector3(-3.25, 0.5, 1.62), -20.0, 0.85) as Node3D, 2)
	staged(place(model("modern_coffee_table_01"), Vector3(-2.4, 0, 2.62), 90.0, 0.9) as Node3D, 2)
	world._block(Vector3(-2.4, 0, 2.62), Vector3(1.1, 0, 0.55))
	# Abajur de chão em arco, de latão, ao lado do sofá.
	var lamp_g: Node3D = group(Vector3(-4.05, 0, 1.75))
	var brass: StandardMaterial3D = mat(C_BRASS, 0.28, 0.95)
	P.cyl(lamp_g, Vector3(0, 0.02, 0), 0.16, 0.04, mat(Color("#1A1A1A"), 0.3, 0.6))
	P.cyl(lamp_g, Vector3(0, 0.8, 0), 0.014, 1.6, brass)
	P.cyl(lamp_g, Vector3(0, 1.6, 0.18), 0.012, 0.4, brass, Vector3(70, 0, 0))
	var shade: StandardMaterial3D = glow(C_TUNGSTEN, 0.9, Color("#E9DCC4"))
	shade_lamps.append(shade)
	P.cyl(lamp_g, Vector3(0, 1.62, 0.36), 0.15, 0.2, shade, Vector3.ZERO, 0.09)
	floor_lamp = _omni(Vector3(-4.05, 1.5, 2.1), C_TUNGSTEN, 1.6, 4.5, false)
	floor_lamp.light_volumetric_fog_energy = 0.6
	world._block(Vector3(-4.05, 0, 1.75), Vector3(0.35, 0, 0.35))
	# Ato 2: poltrona de leitura de frente para a janela, mesinha e uísque.
	staged(place(model("mid_century_lounge_chair"), Vector3(-3.55, 0, -0.35), -70.0), 2)
	world._block(Vector3(-3.6, 0, -0.3), Vector3(0.9, 0, 0.9))
	staged(place(model("side_table_tall_01"), Vector3(-3.95, 0, 0.55)), 2)
	staged(place(part("brass_goblets", "goblet_01", Vector3(0, 0, 0.12)), Vector3(-3.95, 0.76, 0.55), 0.0, 0.7), 2)
	# Ato 1: uma planta solitária na janela.
	staged(place(part("anthurium_botany_01", "01_b", Vector3.ZERO), Vector3(-4.0, 0.42, -0.2), 0.0, 0.9), 1)
	_planter(Vector3(-4.0, 0, -0.2), 1)
	# Plantas grandes nos cantos (Ato 2+).
	staged(place(part("anthurium_botany_01", "01_a", Vector3(-1.0, 0, 0)), Vector3(-0.85, 0.42, 3.05), 30.0, 0.95), 2)
	_planter(Vector3(-0.85, 0, 3.05), 2)
	# Arte sobre o sofá (Ato 2) e sobre a cama (Ato 3).
	staged(place(model("hanging_picture_frame_02"), Vector3(-2.4, 1.85, D - 0.02), 180.0, 1.6), 2)

func _planter(pos: Vector3, first: int) -> void:
	var g: Node3D = staged(group(pos), first)
	P.cyl(g, Vector3(0, 0.21, 0), 0.2, 0.42, pbr("precast_concrete_wall", Color("#6A6763"), 1.5), Vector3.ZERO, 0.24)
	P.cyl(g, Vector3(0, 0.415, 0), 0.215, 0.012, mat(Color("#20160F"), 1.0))
	world._block(pos, Vector3(0.45, 0, 0.45))

func _build_tv() -> void:
	var z: float = D - 0.08
	var x: float = -2.4
	var walnut: StandardMaterial3D = pbr("rectangular_parquet", Color("#6B4E3A"), 0.8, 0.7)
	world._solid(Vector3(x, 0.22, z - 0.22), Vector3(2.0, 0.44, 0.42), walnut)
	box(Vector3(x, 0.45, z - 0.22), Vector3(2.02, 0.02, 0.44), mat(Color("#121212"), 0.3, 0.3))
	var black: StandardMaterial3D = mat(Color("#060708"), 0.25, 0.5)
	box(Vector3(x, 1.5, z - 0.02), Vector3(1.66, 0.96, 0.04), black)
	var tv: MeshInstance3D = _screen(self, Vector3(x, 1.5, z - 0.045), Vector2(1.6, 0.9), "news", Vector2i(960, 540))
	tv.rotation_degrees.y = 180.0
	world._tv_mat = tv.material_override
	_omni(Vector3(x, 1.45, z - 0.7), Color("#9CC0DA"), 0.45, 3.0)
	# Vinho e taças no rack (Ato 2), busto de mármore (Ato 3).
	staged(place(part("wine_bottles_01", "bordeaux", Vector3(0.21, 0, 0)), Vector3(x + 0.75, 0.46, z - 0.25)), 2)
	staged(place(part("wine_bottles_01", "champagne", Vector3(0.6, 0, 0)), Vector3(x + 0.86, 0.46, z - 0.18)), 2)
	staged(place(model("marble_bust_01"), Vector3(x - 0.78, 0.46, z - 0.22), 200.0), 3)

# ---------------------------------------------------------
# Parede leste: vitrine, cofre, cama
# ---------------------------------------------------------

func _build_vitrine() -> void:
	var x: float = 4.2
	var z: float = -0.9
	var walnut: StandardMaterial3D = pbr("rectangular_parquet", Color("#4A3426"), 0.9, 0.6)
	var glass: StandardMaterial3D = mat(Color(0.8, 0.86, 0.9, 0.08), 0.03)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	world._block(Vector3(x, 0.0, z), Vector3(0.55, 0.0, 1.7))
	box(Vector3(x + 0.2, 1.05, z), Vector3(0.05, 2.1, 1.7), walnut)
	box(Vector3(x, 1.05, z - 0.82), Vector3(0.5, 2.1, 0.05), walnut)
	box(Vector3(x, 1.05, z + 0.82), Vector3(0.5, 2.1, 0.05), walnut)
	box(Vector3(x, 0.08, z), Vector3(0.5, 0.16, 1.7), walnut)
	box(Vector3(x, 2.08, z), Vector3(0.5, 0.05, 1.7), walnut)
	box(Vector3(x - 0.235, 1.1, z), Vector3(0.01, 1.9, 1.6), glass)
	box(Vector3(x - 0.24, 1.1, z - 0.8), Vector3(0.015, 1.92, 0.015), mat(C_BRASS, 0.3, 0.9))
	box(Vector3(x - 0.24, 1.1, z + 0.8), Vector3(0.015, 1.92, 0.015), mat(C_BRASS, 0.3, 0.9))
	var led: StandardMaterial3D = glow(Color("#FFE0B0"), 0.7, Color("#3A3020"))
	var shelf_mat: StandardMaterial3D = mat(Color(0.85, 0.9, 0.92, 0.25), 0.05)
	shelf_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for i: int in range(5):
		var sy: float = 0.32 + float(i) * 0.44
		box(Vector3(x, sy, z), Vector3(0.44, 0.012, 1.6), shelf_mat)
		box(Vector3(x + 0.15, sy + 0.42, z), Vector3(0.02, 0.008, 1.56), led)
	var inner: OmniLight3D = _omni(Vector3(x - 0.05, 1.3, z), Color("#FFD6A0"), 0.8, 1.8)
	inner.omni_attenuation = 2.0
	world._lbl(self, "COLEÇÃO", Vector3(x - 0.26, 2.22, z), 34, C_BRASS, -90.0, 0.0, true)
	world._build_goods(x, z)

func _build_safe() -> void:
	var x: float = 4.05
	var z: float = 0.9
	var steel: StandardMaterial3D = mat(Color("#2B2E31"), 0.35, 0.85)
	world._solid(Vector3(x, 0.45, z), Vector3(0.75, 0.9, 0.75), steel)
	box(Vector3(x - 0.39, 0.45, z), Vector3(0.03, 0.78, 0.64), mat(Color("#33373B"), 0.3, 0.85))
	P.cyl(self, Vector3(x - 0.42, 0.5, z), 0.11, 0.04, mat(C_BRASS, 0.25, 0.95), Vector3(0, 0, 90))
	P.cyl(self, Vector3(x - 0.45, 0.5, z), 0.03, 0.05, mat(Color("#111111"), 0.3, 0.6), Vector3(0, 0, 90))
	for k: int in range(3):
		box(Vector3(x - 0.42, 0.24 + float(k) * 0.05, z + 0.22), Vector3(0.03, 0.02, 0.12), mat(Color("#8A8F94"), 0.2, 0.95))
	box(Vector3(x - 0.42, 0.74, z), Vector3(0.012, 0.1, 0.32), P.mat("#020403", "#5FC4B8", 0.8))
	world._safe_label = world._lbl(self, "", Vector3(x - 0.43, 0.74, z), 22, Color("#CFF5EE"), -90.0, 0.0, true)
	world._lbl(self, "COFRE", Vector3(x - 0.3, 1.2, z), 34, Color("#8E8A82"), -90.0, 0.0, true)
	for i: int in range(5):
		var stack: Node3D = Node3D.new()
		stack.position = Vector3(x - 0.15 + float(i % 2) * 0.2, 0.9, z - 0.2 + float(i) * 0.1)
		add_child(stack)
		box(Vector3(0, 0.05, 0), Vector3(0.14, 0.1, 0.07), mat(Color("#5E7F5A"), 0.9), stack)
		box(Vector3(0, 0.05, 0), Vector3(0.145, 0.02, 0.075), mat(C_BRASS, 0.5, 0.3), stack)
		stack.visible = false
		world._safe_stacks.append(stack)

func _build_bed() -> void:
	var walnut: StandardMaterial3D = pbr("rectangular_parquet", Color("#3E2C21"), 0.9, 0.6)
	var sheet: StandardMaterial3D = mat(Color("#D8D2C6"), 0.95)
	var blanket: StandardMaterial3D = pbr("poly_wool_herringbone", Color("#3E4A52"), 2.0, 1.0)
	var leather: StandardMaterial3D = pbr("brown_leather", Color("#6A2A26"), 1.2, 0.8)
	world._solid(Vector3(3.4, 0.17, 2.3), Vector3(1.55, 0.34, 2.2), walnut)
	box(Vector3(3.4, 0.43, 2.3), Vector3(1.44, 0.2, 2.1), sheet)
	box(Vector3(3.4, 0.55, 2.0), Vector3(1.5, 0.08, 1.5), blanket, null, Vector3(-1.5, 0, 0))
	box(Vector3(3.4, 0.6, 1.27), Vector3(1.5, 0.06, 0.06), blanket)
	# Cabeceira estofada em couro (Ato 2+); no Ato 1, só a parede.
	staged(box(Vector3(3.4, 0.95, D - 0.07), Vector3(1.75, 1.1, 0.1), leather), 2)
	for px: float in [3.05, 3.75]:
		box(Vector3(px, 0.6, 3.0), Vector3(0.58, 0.14, 0.36), mat(Color("#ECE7DD"), 1.0), null, Vector3(-12, 0, 0))
	place(model("ClassicNightstand_01"), Vector3(2.32, 0, 3.15), 180.0, 0.9)
	world._block(Vector3(2.32, 0, 3.15), Vector3(0.52, 0, 0.4))
	# Abajur de cabeceira: a luz que fica acesa quando ele dorme.
	var g: Node3D = group(Vector3(2.32, 0.63, 3.18))
	P.cyl(g, Vector3(0, 0.12, 0), 0.06, 0.24, mat(Color("#2A2A2A"), 0.2, 0.4), Vector3.ZERO, 0.03)
	var shade: StandardMaterial3D = glow(C_TUNGSTEN, 1.0, Color("#EDE1CB"))
	shade_lamps.append(shade)
	P.cyl(g, Vector3(0, 0.34, 0), 0.14, 0.18, shade, Vector3.ZERO, 0.1)
	world.lamp = _omni(Vector3(2.32, 0.95, 3.12), C_TUNGSTEN, 1.6, 4.5, true)
	world.alarm_label = world._lbl(self, "08:00", Vector3(2.15, 0.68, 2.98), 26, Color("#FF5A4A"), 0.0, 0.0, true)
	world.alarm_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	world.alarm_label.pixel_size = 0.0007
	world.zzz_label = world._lbl(self, "Z  z  z", Vector3(3.35, 1.15, 2.95), 110, Color("#C9C1B2"), 0.0, 0.0, false)
	world.zzz_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	world.zzz_label.visible = false
	# Ventilador de teto girando devagar sobre a cama.
	var fan: Node3D = place(model("ceiling_fan"), Vector3(3.2, H, 1.9), 0.0, 0.9)
	shadows_off(fan)
	for mi: Node in fan.find_children("*blades*", "MeshInstance3D", true, false):
		fan_blades = mi as Node3D
	staged(place(model("fancy_picture_frame_01"), Vector3(W - 0.02, 1.95, 1.0), -90.0, 1.3), 3)

# ---------------------------------------------------------
# Centro: maquete das empresas sob o pendente
# ---------------------------------------------------------

func _build_maquette() -> void:
	var base_y: float = 0.85
	var walnut: StandardMaterial3D = pbr("rectangular_parquet", Color("#3A281C"), 0.9, 0.55)
	world._solid(Vector3(MAQ.x, 0.42, MAQ.z), Vector3(2.1, 0.84, 1.4), walnut)
	box(Vector3(MAQ.x, base_y + 0.02, MAQ.z), Vector3(2.0, 0.04, 1.3), mat(Color("#141516"), 0.5, 0.3))
	box(Vector3(MAQ.x, base_y + 0.045, MAQ.z), Vector3(1.9, 0.01, 1.2), mat(Color("#2B2C2D"), 0.9))
	for i: int in range(3):
		box(Vector3(MAQ.x - 0.55 + float(i) * 0.5, base_y + 0.052, MAQ.z), Vector3(0.05, 0.004, 1.2), mat(Color("#191A1B"), 0.6))
	box(Vector3(MAQ.x, base_y + 0.052, MAQ.z + 0.1), Vector3(1.9, 0.004, 0.05), mat(Color("#191A1B"), 0.6))
	var B = preload("res://scripts/data/balance.gd")
	var index: int = 0
	for id: String in B.COMPANY_ORDER:
		var cap: float = float(B.COMPANIES[id]["capacity"])
		var h: float = 0.10 + 0.07 * (log(cap / 40000.0) / log(2.0))
		var col: int = index % 4
		var rw: int = index / 4
		var px: float = MAQ.x - 0.7 + float(col) * 0.47
		var pz: float = MAQ.z - 0.28 + float(rw) * 0.52
		# Gesso com janelinhas: as empresas que são suas acendem (world_3d).
		var body: ShaderMaterial = ShaderMaterial.new()
		body.shader = load("res://assets/shaders/city_facade.gdshader")
		body.set_shader_parameter("cell", Vector2(0.035, 0.05))
		body.set_shader_parameter("night", 1.0)
		body.set_shader_parameter("glow", 2.4)
		body.set_shader_parameter("lit_ratio", 0.0)
		body.set_shader_parameter("base_color", Color("#2A2A2A"))
		var top: StandardMaterial3D = P.mat("#000000", "#E8A55A", 0.0)
		box(Vector3(px, base_y + 0.05 + h * 0.5, pz), Vector3(0.26, h, 0.26), body)
		box(Vector3(px, base_y + 0.05 + h + 0.008, pz), Vector3(0.27, 0.016, 0.27), top)
		var label: Label3D = world._lbl(self, "", Vector3(px, base_y + 0.2 + h, pz), 26, C_AMBER, 0.0, 0.0, false)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		world._maq_buildings[id] = {"mat": body, "top": top, "label": label}
		world._maq_tops[id] = Vector3(px, base_y + 0.05 + h + 0.12, pz)
		index += 1
	var tree: StandardMaterial3D = mat(Color("#3E4A3A"), 0.9)
	for tx: float in [-0.88, 0.9, 0.85]:
		P.sph(self, Vector3(MAQ.x + tx, base_y + 0.11, MAQ.z + 0.45), 0.05, tree)
	# Pendente sobre a maquete.
	place(model("modern_ceiling_lamp_01"), Vector3(MAQ.x, H - 1.17 * 0.7, MAQ.z), 0.0, 0.7)
	pendant = _spotlight(Vector3(MAQ.x, 2.55, MAQ.z), Vector3(MAQ.x, 0.0, MAQ.z + 0.01), C_TUNGSTEN, 3.5, 4.0, 42.0, true)
	pendant.light_volumetric_fog_energy = 1.4
	pendant.spot_attenuation = 0.8
	world.ceiling_light = pendant

func _build_darkweb() -> void:
	var x: float = -3.95
	var z: float = 2.85
	place(model("ClassicNightstand_01"), Vector3(x, 0, z), 90.0, 0.95)
	world._block(Vector3(x, 0, z), Vector3(0.45, 0, 0.6))
	var top: float = 0.67
	var laptop: Node3D = place(part("classic_laptop", "classic_laptop", Vector3.ZERO), Vector3(x, top, z), 90.0, 0.62)
	for mi: Node in laptop.find_children("*stand*", "MeshInstance3D", true, false):
		(mi as Node3D).visible = false
	var scr: MeshInstance3D = _screen(self, Vector3(x + 0.12, top + 0.17, z), Vector2(0.33, 0.24), "dark", Vector2i(400, 290))
	scr.rotation_degrees = Vector3(0, 90, 0)
	scr.rotate_object_local(Vector3.RIGHT, deg_to_rad(-12.0))
	world._dark_mat = scr.material_override
	world._dark_label = world._lbl(self, "", Vector3(x, top + 0.46, z), 22, Color("#C9B8FF"), 90.0, 0.0, true)
	world._dark_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_omni(Vector3(x + 0.35, top + 0.25, z), Color("#9C8CFF"), 0.25, 1.4)

func _build_door() -> void:
	var z: float = D - 0.04
	var door: StandardMaterial3D = pbr("rectangular_parquet", Color("#2E2520"), 0.6, 0.6)
	var frame: StandardMaterial3D = mat(Color("#121315"), 0.5, 0.3)
	world.door_mesh = box(Vector3(0.5, 1.05, z), Vector3(1.0, 2.1, 0.07), door)
	box(Vector3(0.5, 2.14, z - 0.01), Vector3(1.14, 0.08, 0.09), frame)
	box(Vector3(-0.08, 1.05, z - 0.01), Vector3(0.07, 2.1, 0.09), frame)
	box(Vector3(1.08, 1.05, z - 0.01), Vector3(0.07, 2.1, 0.09), frame)
	P.cyl(self, Vector3(0.12, 1.02, z - 0.07), 0.012, 0.12, mat(C_BRASS, 0.25, 0.95), Vector3(0, 0, 90))
	P.cyl(self, Vector3(0.5, 1.55, z - 0.04), 0.012, 0.02, mat(C_BRASS, 0.25, 0.95), Vector3(90, 0, 0))
	# Luz do corredor vazando por baixo da porta.
	hall_mat = glow(Color("#FFD9A0"), 2.0, Color("#FFE8C8"))
	box(Vector3(0.5, 0.008, z - 0.03), Vector3(0.92, 0.012, 0.04), hall_mat)
	var leak: SpotLight3D = _spotlight(Vector3(0.5, 0.05, z + 0.3), Vector3(0.5, 0.0, z - 1.4), Color("#FFD9A0"), 0.6, 2.0, 60.0, false)
	leak.set_meta("hall", true)
	world._door_mat = P.mat("#000000", "#B79CFF", 0.0)
	box(Vector3(0.5, 2.3, z - 0.05), Vector3(0.7, 0.06, 0.02), world._door_mat)
	world._door_label = world._lbl(self, "", Vector3(0.5, 2.6, z - 0.1), 40, Color("#C9B8FF"), 180.0, 700.0, true)
	# Estante baixa ao lado da porta, com livros.
	var shelf: Node3D = place(model("wooden_display_shelves_01"), Vector3(-0.72, 0, D - 0.2), 90.0)
	world._block(Vector3(-0.72, 0, D - 0.2), Vector3(1.08, 0, 0.37))
	var colors: Array = ["#3A3F45", "#5A2A26", "#2F4A44", "#6B5A3A", "#2A2A2A", "#7A6A58"]
	for s: int in range(3):
		for i: int in range(7):
			var bh: float = 0.2 + 0.05 * float((i * 5 + s * 3) % 3)
			box(Vector3(-1.1 + float(i) * 0.075, 0.42 + float(s) * 0.47 + bh * 0.5, D - 0.2), Vector3(0.06, bh, 0.2), mat(Color(str(colors[(i + s) % colors.size()])), 0.85))
	if shelf == null:
		return

func _build_props() -> void:
	# Câmeras de segurança nos cantos (Ato 3): paranoia de quem tem muito a perder.
	for spec: Array in [[Vector3(-W + 0.12, H - 0.08, -D + 0.12), 45.0], [Vector3(W - 0.12, H - 0.08, D - 0.12), -135.0]]:
		var cam: Node3D = staged(place(model("security_camera_01"), spec[0], spec[1]), 3)
		shadows_off(cam)
		var led: StandardMaterial3D = glow(C_RED, 3.0)
		cam_leds.append(led)
		P.sph(cam, Vector3(0, 0.0, 0.2), 0.012, led)
	# Arandelas industriais nas laterais da TV (Ato 2+).
	for x: float in [-3.4, -1.4]:
		var lamp: Node3D = staged(place(model("industrial_wall_lamp"), Vector3(x, 2.1, D - 0.02), 180.0), 2)
		shadows_off(lamp)
		var l: OmniLight3D = _omni(Vector3(x, 2.05, D - 0.25), C_TUNGSTEN, 0.0, 2.2)
		l.set_meta("energy", 0.7)
		staged(l, 2)

## Malotes (maletas de couro) perto da porta: é por onde o cliente entrega.
func _build_cases() -> void:
	var root: Node3D = Node3D.new()
	add_child(root)
	world._cases_root = root
	var spot: Vector3 = Vector3(1.75, 0.0, 2.55)
	box(spot + Vector3(0, 0.004, 0), Vector3(1.2, 0.008, 0.9), mat(Color("#1C1A18"), 1.0), root)
	world._lbl(root, "ENTREGA DO CLIENTE", spot + Vector3(0, 0.02, 0.0), 26, C_AMBER, 0.0, 0.0, true).rotation_degrees.x = -90.0
	var B = preload("res://scripts/data/balance.gd")
	for i: int in range(B.CASES_MAX):
		var col: int = i % 3
		var layer: int = i / 3
		var node: Node3D = _make_case(root, spot + Vector3(-0.38 + float(col) * 0.36, float(layer) * 0.0, -0.18 + float(layer) * 0.32), float((i * 37) % 23) - 11.0)
		world._case_nodes.append(node)
	var carry: Node3D = Node3D.new()
	world.camera.add_child(carry)
	carry.position = Vector3(0.32, -0.55, -0.62)
	carry.rotation_degrees = Vector3(4, -18, -3)
	carry.add_child(_suitcase())
	carry.visible = false
	world._carry_node = carry

func _suitcase() -> Node3D:
	var s: Node3D = part("vintage_suitcase", "suitcase_01", Vector3(0.4585, 0, 0))
	shadows_off(s)
	s.scale = Vector3.ONE * 0.75
	return s

func _make_case(parent: Node3D, pos: Vector3, yaw: float) -> Node3D:
	var node: Node3D = Node3D.new()
	parent.add_child(node)
	node.position = pos
	node.rotation_degrees.y = yaw
	var s: Node3D = part("vintage_suitcase", "suitcase_0%d" % (1 + int(absf(yaw)) % 2), Vector3(0.4585 if int(absf(yaw)) % 2 == 0 else -0.4559, 0, 0))
	s.scale = Vector3.ONE * 0.75
	node.add_child(s)
	return node

# =========================================================
# EVOLUÇÃO E ANIMAÇÃO
# =========================================================

## Mostra o que cada ato conquistou. Chamado ao abrir o dia e na troca de ato.
func apply_stage(new_stage: int) -> bool:
	new_stage = clampi(new_stage, 1, 3)
	if new_stage == stage:
		return false
	stage = new_stage
	for entry_v: Variant in _stage_nodes:
		var entry: Array = entry_v as Array
		var node: Node3D = entry[0]
		var on: bool = stage >= int(entry[1]) and stage <= int(entry[2])
		node.visible = on
		if node is Light3D and node.has_meta("energy"):
			(node as Light3D).light_energy = float(node.get_meta("energy")) if on else 0.0
	if probe != null:
		probe.update_mode = ReflectionProbe.UPDATE_ONCE
		probe.set_deferred("update_mode", ReflectionProbe.UPDATE_ONCE)
	return true

## Luz do dia/noite, chamada todo quadro por world_3d._update_light.
func apply_light(d: float, lights: float, monitor: float, street: bool) -> void:
	var sun: DirectionalLight3D = world.sun
	var dusk: float = clampf(1.0 - absf(d - 0.3) / 0.3, 0.0, 1.0)
	sun.light_energy = lerpf(0.05, 3.4, d)
	sun.light_color = Color("#9DB4D6").lerp(Color("#FFE4C0"), clampf(d * 1.5, 0.0, 1.0)).lerp(Color("#FF9A5C"), dusk * 0.6)
	# Sol de fim de tarde, baixo, atravessando o quarto pela janela oeste.
	sun.rotation_degrees = Vector3(lerpf(-8.0, -24.0, d), -104.0, 0.0)
	var night: float = 1.0 - d
	desk_lamp.light_energy = lerpf(4.5, 1.8, d) * lights
	pendant.light_energy = lerpf(3.4, 1.0, d) * lights
	floor_lamp.light_energy = lerpf(1.7, 0.3, d) * lights
	(world.lamp as OmniLight3D).light_energy = lerpf(1.4, 0.2, d) * lights
	(world.monitor_light as OmniLight3D).light_energy = lerpf(0.7, 0.25, d) * monitor
	window_fill.light_energy = lerpf(0.9, 2.6, d)
	window_fill.light_color = C_CITY.lerp(Color("#FFE9CC"), d)
	for m: Variant in shade_lamps:
		(m as StandardMaterial3D).emission_energy_multiplier = lerpf(2.2, 0.6, d) * lights
	for s: Variant in screens:
		((s as Dictionary)["mat"] as StandardMaterial3D).emission_energy_multiplier = lerpf(1.5, 1.1, d) * monitor
	for m: Variant in facade_mats:
		(m as ShaderMaterial).set_shader_parameter("night", night)
	var sky: ProceduralSkyMaterial = world.sky_mat
	sky.sky_top_color = Color("#06080C").lerp(Color("#5D7C9C"), d)
	sky.sky_horizon_color = Color("#3A2E26").lerp(Color("#C8C4B8"), d).lerp(Color("#D9875A"), dusk * 0.6)
	sky.ground_horizon_color = sky.sky_horizon_color
	sky.ground_bottom_color = Color("#0A0B0D").lerp(Color("#3A3E44"), d)
	sky.sky_energy_multiplier = lerpf(1.0, 1.3, d)
	var env: Environment = (world.env_node as WorldEnvironment).environment
	env.ambient_light_color = Color("#1E2630").lerp(Color("#5A6066"), d)
	env.ambient_light_energy = lerpf(0.9, 1.1, d)
	env.fog_light_color = sky.sky_horizon_color
	env.volumetric_fog_density = lerpf(0.02, 0.008, d)
	if street:
		env.ambient_light_energy = lerpf(2.2, 1.2, d)
		env.ambient_light_color = Color("#5F7A9A").lerp(Color("#94A8BC"), d)
	world.stars_root.visible = d < 0.3
	world.moon.visible = d < 0.5
	neon_mat.emission_energy_multiplier = lerpf(5.0, 0.6, d) * (0.82 + 0.18 * sin(_t * 2.1)) * (0.0 if fmod(_t, 11.0) > 10.6 else 1.0)
	neon_light.light_energy = neon_mat.emission_energy_multiplier * 0.14 * night
	glass_mat.set_shader_parameter("rain", rain)

## Tempo do dia: chove em uns 45% dos turnos (sempre na fuga). A chuva
## entra e sai devagar no vidro.
func weather_target() -> float:
	if rain_override >= 0.0:
		return rain_override
	if Campaign.escape_active:
		return 1.0
	var h: int = hash(GameManager.day_total * 7919 + 13) % 100
	return 1.0 if h < 45 else 0.0

func animate(delta: float, suspicion: float, raid: bool) -> void:
	_t += delta
	rain = move_toward(rain, weather_target(), delta * (5.0 if rain_override >= 0.0 else 0.2))
	if fan_blades != null:
		fan_blades.rotate_y(delta * 2.4)
	for car_v: Variant in car_lights:
		var car: Array = car_v as Array
		var node: Node3D = car[0]
		node.position.z += float(car[1]) * delta
		if node.position.z > 60.0:
			node.position.z = -60.0
		elif node.position.z < -60.0:
			node.position.z = 60.0
	var blink: float = 1.0 if fmod(_t, 1.6) < 0.25 else 0.15
	for m: Variant in aviation_mats:
		(m as StandardMaterial3D).emission_energy_multiplier = 5.0 * blink
	for m: Variant in cam_leds:
		(m as StandardMaterial3D).emission_energy_multiplier = 3.0 if fmod(_t, 2.0) < 1.0 else 0.4
	# Viaturas na rua: a partir de 60% de suspeita, ou durante a batida.
	var cops: float = clampf((suspicion - 60.0) / 20.0, 0.0, 1.0)
	if raid:
		cops = 1.0
	var phase: float = fmod(_t * 2.6, 2.0)
	police_red.light_energy = cops * (3.0 if phase < 1.0 else 0.0)
	police_blue.light_energy = cops * (0.0 if phase < 1.0 else 3.5)
	police_red.rotation.y = -PI * 0.5 + 0.25 * sin(_t * 1.3)
	police_blue.rotation.y = -PI * 0.5 + 0.25 * sin(_t * 1.1 + 1.0)
	# Helicóptero: de noite, com suspeita acima de 80% ou durante a batida.
	var night: float = 1.0 - float(world._day)
	var heli_on: bool = night > 0.5 and (suspicion >= 80.0 or raid) and GameManager.state == GameManager.GameState.WORK
	heli_level = move_toward(heli_level, 1.0 if heli_on else 0.0, delta * 0.15)
	if heli_level > 0.001:
		var sweep: Vector3 = Vector3(lerpf(-3.0, 2.5, 0.5 + 0.5 * sin(_t * 0.37)), 0.0, 1.6 * sin(_t * 0.53))
		var from: Vector3 = Vector3(-16.0, 12.0, 4.0 * sin(_t * 0.11))
		heli_spot.look_at_from_position(from, sweep, Vector3.UP)
	heli_spot.light_energy = heli_level * 14.0
	# A luz do corredor some quando alguém para do outro lado da porta.
	hall_mat.emission_energy_multiplier = (0.4 + 1.6 * absf(sin(_t * 9.0))) if raid else 2.0
