extends Node3D
## WORLD 3D — o apartamento do operador. O jogo inteiro acontece aqui dentro.
##
## Cada aba do jogo é um objeto do quarto:
##   computador = Visão geral      quadro de cortiça = Missões
##   maquete    = Empresas         quadro de pessoal = Laranjas
##   vitrine    = Bens             cofre             = Carteira
##   arquivo    = Transações       TV                = Notícias
##   painel     = Risco            notebook preto    = Dark Web (só na fuga)
##   cama       = finalizar turno  porta             = decolar (só na fuga)
##
## Modos:
##   WALK       primeira pessoa (WASD + mouse). Interface escondida.
##   FOCUS      a câmera voa até o objeto e a interface da aba abre por cima.
##              ESC levanta. V esconde a interface para ver o objeto.
##   CINEMATIC  menus, manual, passagem de ato e finais: câmera lenta no quarto.
##
## As regras do jogo continuam todas nos autoloads e em main.gd (cena irmã
## "../UI"). Este script só mostra o estado em objetos 3D e leva o jogador até
## a interface certa. Os objetos refletem o jogo: a maquete acende as empresas
## compradas, a vitrine mostra os bens, o painel mede a suspeita.

const B = preload("res://scripts/data/balance.gd")
const P = preload("res://scripts/world/prims.gd")
const City = preload("res://scripts/world/city.gd")
const Events = preload("res://scripts/world/events_3d.gd")
const Minigames = preload("res://scripts/ui/minigames.gd")
const Sets = preload("res://scripts/world/sets.gd")
const Cutscenes = preload("res://scripts/world/cutscenes.gd")
const Apartment = preload("res://scripts/world/apartment.gd")
const Phone = preload("res://scripts/world/phone.gd")
const Ambience = preload("res://scripts/world/ambience.gd")

enum Mode { CINEMATIC, WALK, FOCUS }

const ROOM_W: float = 4.5        # meia-largura (x)
const ROOM_D: float = 3.5        # meia-profundidade (z)
const ROOM_H: float = 3.2
const EYE: float = 1.65
const WALK_SPEED: float = 2.9
const MARGIN: float = 0.35
const MOUSE_SENS: float = 0.0022

const SPAWN_POS: Vector3 = Vector3(0.2, 0.0, 2.4)
const WAKE_POS: Vector3 = Vector3(1.9, 0.0, 1.0)
const CINE_POS: Vector3 = Vector3(3.4, 1.95, 2.7)
const CINE_LOOK: Vector3 = Vector3(-0.8, 0.95, -1.0)
const BED_VIEW_POS: Vector3 = Vector3(3.4, 0.9, 2.9)
const BED_VIEW_LOOK: Vector3 = Vector3(3.2, 2.6, 1.6)

const DX: float = -2.2           # x da mesa do computador
const MAQ: Vector3 = Vector3(0.2, 0.0, 0.3)   # centro da maquete

## Sem tipo de propósito: chamamos métodos do main.gd (end_turn, modal_open...),
## e tipar como Control geraria erro de parse por método desconhecido.
var ui

var mode: int = Mode.CINEMATIC
var camera: Camera3D
var sun: DirectionalLight3D
var lamp: OmniLight3D
var ceiling_light: Light3D
var monitor_light: OmniLight3D
var env_node: WorldEnvironment
var sky_mat: ProceduralSkyMaterial
var stars_root: Node3D

var hud: CanvasLayer
var shade_layer: CanvasLayer
var shade: ColorRect
var crosshair: ColorRect
var prompt_label: Label
var hint_label: Label
var notice_label: Label
var status_label: Label
var step_label: Label
var focus_label: Label

## Construção do quarto, luz e evolução por ato (world/apartment.gd).
var apartment
var phone
var ambience
# Controle em primeira pessoa: velocidade suavizada, balanço e passos.
var _vel: Vector3 = Vector3.ZERO
var _bob: float = 0.0
var _bob_amount: float = 0.0
var _step_side: int = 0

## Sem tipo de propósito (mesmo motivo de ui): chamamos métodos dos scripts filhos.
var city
var events
var _area: String = "room"         # "room" (apartamento) ou "street" (cidade)
var _traveling: bool = false
var _fade: ColorRect
var raid_label: Label
var _carry: float = 0.0            # valor do malote nas mãos (0 = nenhum)
var _case_value: float = 0.0
var _case_count: int = 0
var hidden_cases: int = 0          # malotes já guardados no cofre durante a batida
var _cases_root: Node3D
var _case_nodes: Array = []
var _carry_node: Node3D
var _maq_tops: Dictionary = {}     # id da empresa -> posição do prédio na maquete
var _done_today: Dictionary = {}   # minigames já feitos hoje
var _shred_mat: StandardMaterial3D

## Cenas em 3D (a noite e os finais): cutscenes.gd mexe nestas variáveis.
var sets
var cutscenes
var cutscene_active: bool = false
var ov_day: float = -1.0           # >= 0 força a luz do céu (0 noite, 1 dia)
var ov_lights: float = 1.0         # escala das luzes do quarto
var ov_monitor: float = 1.0        # brilho do monitor
var cam_rate: float = 5.0          # suavização da câmera de cena
var snap_pending: bool = false     # o próximo cam_to pula direto, sem voar
var fade_rect: ColorRect
var moon: MeshInstance3D
var alarm_label: Label3D
var zzz_label: Label3D
var door_mesh: MeshInstance3D

var _obstacles: Array = []       # Vector4(min_x, min_z, max_x, max_z)
var _spots: Dictionary = {}      # id -> {pos, r, label, cam, look, tag, label3d}
var _active_id: String = ""
var _guide_id: String = ""
var _focus_tab: String = ""
var _peek: bool = false
var _slept: bool = false
var _overlay_only: bool = false
var _watching: bool = false

var _player: Vector3 = SPAWN_POS
var _yaw: float = 0.0
var _pitch: float = 0.0
var _cam_pos_t: Vector3 = Vector3.ZERO
var _cam_q_t: Quaternion = Quaternion.IDENTITY
var _blend: float = 0.0

var _t: float = 0.0
var _notice_t: float = 0.0
var _hud_t: float = 0.0
var _displays_dirty: bool = true
var _day: float = 0.0

# Objetos que mudam com o jogo.
var _mon_mat: StandardMaterial3D
var _clock_label: Label3D
var _risk_mats: Array = []
var _risk_label: Label3D
var _risk_state: Label3D
var _maq_buildings: Dictionary = {}   # id -> {mat, top_mat, label}
var _good_nodes: Dictionary = {}      # id do bem -> Node3D
var _safe_label: Label3D
var _safe_stacks: Array = []
var _cork_root: Node3D
var _staff_root: Node3D
var _tv_mat: StandardMaterial3D
var _file_label: Label3D
var _dark_mat: StandardMaterial3D
var _dark_label: Label3D
var _door_mat: StandardMaterial3D
var _door_label: Label3D

func _ready() -> void:
	ui = get_node("../UI")
	ui.set("world", self)
	_build_camera()
	apartment = Apartment.new()
	apartment.world = self
	add_child(apartment)
	apartment.build()
	phone = Phone.new()
	phone.world = self
	add_child(phone)
	phone.build(Vector3(DX + 0.38, 0.79, -2.98))
	Director.phone_enabled = true
	ambience = Ambience.new()
	ambience.world = self
	add_child(ambience)
	city = City.new()
	city.world = self
	add_child(city)
	city.build()
	events = Events.new()
	events.world = self
	add_child(events)
	events.setup()
	sets = Sets.new()
	sets.world = self
	add_child(sets)
	sets.build()
	cutscenes = Cutscenes.new()
	cutscenes.world = self
	cutscenes.sets = sets
	add_child(cutscenes)
	_add_spots()
	_build_hud()
	GameManager.stats_changed.connect(_mark_dirty)
	GameManager.day_changed.connect(_on_day_changed)
	_set_look_at(Vector3(0.2, 1.0, -1.0))
	_refresh_displays()
	camera.position = CINE_POS
	camera.quaternion = _look_q(CINE_POS, CINE_LOOK)

func walking() -> bool:
	return mode == Mode.WALK

## Há uma confirmação (dormir, decolar) aberta com o jogador em pé.
func overlay_active() -> bool:
	return _overlay_only

func _mark_dirty() -> void:
	_displays_dirty = true

func _on_day_changed(_day_number: int) -> void:
	_displays_dirty = true
	_carry = 0.0
	_done_today.clear()
	phone.new_day()

func cutscene_begin(kind: String) -> void:
	cutscene_active = true
	cutscenes.begin(kind)

func cutscene_end() -> void:
	cutscene_active = false
	cutscenes.end()

## Câmera das cenas: vai (suavizada) para a posição e olha para o ponto.
func cam_to(pos: Vector3, look: Vector3) -> void:
	_cam_pos_t = pos
	_cam_q_t = _look_q(pos, look)
	if snap_pending:
		snap_pending = false
		camera.position = pos
		camera.quaternion = _cam_q_t

func cutscene_reset_camera() -> void:
	_to_room_instant()
	camera.position = CINE_POS
	camera.quaternion = _look_q(CINE_POS, CINE_LOOK)

func mark_dirty() -> void:
	_displays_dirty = true

func notice(text: String) -> void:
	_notice(text)

## Malotes que ainda não estão no cofre (os que estão à vista, mais o das mãos).
func cases_remaining() -> int:
	return maxi(0, _case_count - hidden_cases)

func add_spot(id: String, pos: Vector3, reach: float, label: String, tag: Vector3, when: String = "always", min_dot: float = 0.88, hidden: bool = false) -> void:
	_spot_def(id, pos, reach, label, Vector3.ZERO, Vector3.ZERO, tag, "room", when, min_dot, hidden)

func remove_spot(id: String) -> void:
	if not _spots.has(id):
		return
	((_spots[id] as Dictionary)["label3d"] as Label3D).queue_free()
	_spots.erase(id)
	if _active_id == id:
		_active_id = ""

func set_spot_label(id: String, text: String) -> void:
	if not _spots.has(id):
		return
	var spot: Dictionary = _spots[id]
	spot["label"] = text
	(spot["label3d"] as Label3D).text = text

# =========================================================
# LOOP PRINCIPAL
# =========================================================

func _process(delta: float) -> void:
	_t += delta
	_update_mode()
	_sync_ui()
	_apply_mouse()
	if mode == Mode.WALK and not cutscene_active:
		_move(delta)
		_scan_spots()
	elif mode == Mode.FOCUS:
		_follow_tab()
	_drive_camera(delta)
	_update_light()
	_animate(delta)
	if _displays_dirty:
		_displays_dirty = false
		_refresh_displays()
	_hud_t -= delta
	if _hud_t <= 0.0:
		_hud_t = 0.3
		_refresh_hud()
	if _notice_t > 0.0:
		_notice_t -= delta
		if _notice_t <= 0.0:
			notice_label.text = ""

# =========================================================
# MODOS
# =========================================================

func _update_mode() -> void:
	var screen: String = str(ui.get("_screen"))
	var state: int = GameManager.state
	if state == GameManager.GameState.DAY_TRANSITION:
		_slept = true
	if cutscene_active:
		return
	if screen != "dashboard":
		_set_mode(Mode.CINEMATIC)
		return
	var busy: bool = state == GameManager.GameState.DAY_TRANSITION or PopupManager.is_open() or bool(ui.get("_flow_busy"))
	var working: bool = state == GameManager.GameState.WORK
	if mode == Mode.CINEMATIC:
		if busy or not working:
			return
		if _slept:
			_slept = false
			_enter_walk(WAKE_POS)
			events.try_raid()
		else:
			_to_room_instant()
			_focus(str(ui.get("current_tab")), false)
		return
	if busy and mode == Mode.WALK and not _overlay_only:
		_focus_view(BED_VIEW_POS, BED_VIEW_LOOK)
	elif not busy and _slept and working and mode == Mode.FOCUS:
		_slept = false
		_enter_walk(WAKE_POS)
		events.try_raid()

func _set_mode(new_mode: int) -> void:
	if new_mode == mode:
		return
	mode = new_mode
	_peek = false
	if mode == Mode.WALK:
		_blend = 0.7
	for id: String in _spots:
		(_spots[id]["label3d"] as Label3D).visible = false
	if mode == Mode.CINEMATIC and _area != "room":
		_to_room_instant()
		camera.position = CINE_POS

## Volta ao apartamento sem animação (menus, final, acordar).
func _to_room_instant() -> void:
	_area = "room"
	_active_id = ""
	city.visible = false
	city.active = false

func _enter_walk(pos: Vector3) -> void:
	_to_room_instant()
	_player = pos
	_set_look_at(Vector3(0.0, 1.0, -1.0))
	_set_mode(Mode.WALK)
	_blend = 0.9
	_notice("Siga o marcador amarelo. E usa o objeto que você está olhando.")

func _set_look_at(target: Vector3) -> void:
	var d: Vector3 = (target - (_player + Vector3(0, EYE, 0))).normalized()
	_yaw = atan2(-d.x, -d.z)
	_pitch = clampf(asin(d.y), -1.4, 1.4)

## Voa até o objeto da aba e abre a interface.
func _focus(tab: String, animate: bool = true, spot_id: String = "") -> void:
	var spot: Dictionary = _spots.get(spot_id if spot_id != "" else tab, {})
	if spot.is_empty() or not spot.has("cam"):
		return
	_set_mode(Mode.FOCUS)
	_focus_tab = tab
	_cam_pos_t = spot["cam"]
	_cam_q_t = _look_q(_cam_pos_t, spot["look"])
	if animate and str(ui.get("current_tab")) != tab:
		ui.switch_tab(tab)
	elif animate:
		ui.show_dashboard(tab)

func _focus_view(cam_pos: Vector3, look: Vector3) -> void:
	_set_mode(Mode.FOCUS)
	_focus_tab = ""
	_cam_pos_t = cam_pos
	_cam_q_t = _look_q(cam_pos, look)

## Quando o jogador troca de aba pelo menu lateral, a câmera vai junto.
func _follow_tab() -> void:
	if _focus_tab == "" or _area != "room":
		return
	var tab: String = str(ui.get("current_tab"))
	if tab != _focus_tab and _spots.has(tab) and (_spots[tab] as Dictionary).has("cam"):
		_focus_tab = tab
		var spot: Dictionary = _spots[tab]
		_cam_pos_t = spot["cam"]
		_cam_q_t = _look_q(_cam_pos_t, spot["look"])

func _look_q(from: Vector3, to: Vector3) -> Quaternion:
	return Transform3D(Basis.IDENTITY, from).looking_at(to, Vector3.UP).basis.get_rotation_quaternion()

func _drive_camera(delta: float) -> void:
	if cutscene_active:
		var wc: float = 1.0 - exp(-cam_rate * delta)
		camera.position = camera.position.lerp(_cam_pos_t, wc)
		camera.quaternion = camera.quaternion.slerp(_cam_q_t, wc)
		return
	match mode:
		Mode.WALK:
			var bob: Vector3 = Vector3(cos(_bob * 0.5) * 0.018, absf(sin(_bob)) * 0.032 - 0.016, 0.0) * _bob_amount
			var p: Vector3 = _player + Vector3(0, EYE, 0) + Quaternion.from_euler(Vector3(0, _yaw, 0)) * bob
			var q: Quaternion = Quaternion.from_euler(Vector3(_pitch, _yaw, 0.0))
			if _blend > 0.0:
				_blend -= delta
				var w: float = 1.0 - exp(-9.0 * delta)
				camera.position = camera.position.lerp(p, w)
				camera.quaternion = camera.quaternion.slerp(q, w)
			else:
				camera.position = p
				camera.quaternion = q
		Mode.FOCUS:
			var wf: float = 1.0 - exp(-5.0 * delta)
			camera.position = camera.position.lerp(_cam_pos_t, wf)
			camera.quaternion = camera.quaternion.slerp(_cam_q_t, wf)
		_:
			var wc: float = 1.0 - exp(-1.6 * delta)
			var target: Vector3 = CINE_POS + Vector3(0.45 * sin(_t * 0.11), 0.10 * sin(_t * 0.07), 0.30 * cos(_t * 0.09))
			camera.position = camera.position.lerp(target, wc)
			camera.quaternion = camera.quaternion.slerp(_look_q(camera.position, CINE_LOOK), wc)

## Mostra e esconde as camadas da interface conforme o modo.
func _sync_ui() -> void:
	var backdrop: Control = ui.get("backdrop") as Control
	if backdrop != null:
		backdrop.visible = false
	var crt: Control = ui.get("crt_overlay") as Control
	if crt != null:
		crt.visible = false
	var main_layer: Control = ui.get("main_layer") as Control
	var modal_layer: Control = ui.get("modal_layer") as Control
	if _peek and ui.modal_open():
		_peek = false
	if main_layer != null:
		main_layer.visible = mode != Mode.WALK and not (mode == Mode.FOCUS and _peek) and not cutscene_active
		main_layer.modulate.a = 0.985 if mode == Mode.FOCUS else 1.0
	if modal_layer != null:
		modal_layer.visible = (mode != Mode.WALK or _overlay_only) and not cutscene_active
	var walk_hud: bool = mode == Mode.WALK and not _overlay_only and not cutscene_active
	crosshair.visible = walk_hud
	prompt_label.visible = walk_hud
	hint_label.visible = walk_hud
	status_label.visible = walk_hud
	step_label.visible = walk_hud
	focus_label.visible = mode == Mode.FOCUS and not ui.modal_open() and not cutscene_active
	shade.visible = mode == Mode.CINEMATIC and not cutscene_active

func _apply_mouse() -> void:
	var want: int = Input.MOUSE_MODE_CAPTURED if (mode == Mode.WALK and not _overlay_only and not cutscene_active) else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != want:
		Input.mouse_mode = want

# =========================================================
# ENTRADA: ANDAR, OLHAR, INTERAGIR
# =========================================================

func _input(event: InputEvent) -> void:
	if mode != Mode.WALK or _overlay_only or _traveling or cutscene_active:
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_yaw -= motion.relative.x * MOUSE_SENS
			_pitch = clampf(_pitch - motion.relative.y * MOUSE_SENS, -1.45, 1.45)
		return
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if (key.keycode == KEY_E or key.keycode == KEY_F or key.keycode == KEY_ENTER) and _active_id != "":
		_interact(_active_id)
	elif key.keycode == KEY_ESCAPE:
		if _area == "room":
			_focus("overview")
		else:
			_notice("O computador fica em casa. Volte pela porta do prédio.")

func _unhandled_input(event: InputEvent) -> void:
	if mode != Mode.FOCUS:
		return
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if ui.modal_open() or PopupManager.is_open() or bool(ui.get("_flow_busy")):
		return
	if key.keycode == KEY_ESCAPE:
		_set_mode(Mode.WALK)
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_V:
		_peek = not _peek
		get_viewport().set_input_as_handled()

func _move(delta: float) -> void:
	var dir: Vector3 = Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		dir.z -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		dir.z += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	var running: bool = Input.is_physical_key_pressed(KEY_SHIFT)
	var speed: float = WALK_SPEED * (1.6 if running else 1.0)
	var want: Vector3 = Vector3.ZERO if (dir == Vector3.ZERO or _traveling) else dir.normalized().rotated(Vector3.UP, _yaw) * speed
	# Arranca e para com um pouco de inércia: o corpo tem peso.
	_vel = _vel.lerp(want, 1.0 - exp(-(10.0 if want != Vector3.ZERO else 14.0) * delta))
	var moving: float = clampf(_vel.length() / WALK_SPEED, 0.0, 1.6)
	_bob_amount = lerpf(_bob_amount, moving, 1.0 - exp(-8.0 * delta))
	if moving > 0.2:
		var before: float = _bob
		_bob += delta * (7.2 + 3.0 * float(running))
		# Um passo a cada meia volta do balanço.
		if int(before / PI) != int(_bob / PI):
			ambience.footstep(running)
	camera.fov = lerpf(camera.fov, 70.0 + (5.0 if running and moving > 1.1 else 0.0), 1.0 - exp(-6.0 * delta))
	if _vel.length() < 0.01:
		return
	var pos: Vector3 = _player + _vel * delta
	if _area == "street":
		pos.x = clampf(pos.x, -City.LIMIT_X, City.LIMIT_X)
		pos.z = clampf(pos.z, City.WALK_Z_MIN, City.WALK_Z_MAX)
		_player = pos
		return
	pos.x = clampf(pos.x, -ROOM_W + MARGIN, ROOM_W - MARGIN)
	pos.z = clampf(pos.z, -ROOM_D + MARGIN, ROOM_D - MARGIN)
	for obs_v: Variant in _obstacles:
		var o: Vector4 = obs_v as Vector4
		if pos.x > o.x and pos.x < o.z and pos.z > o.y and pos.z < o.w:
			var to_left: float = pos.x - o.x
			var to_right: float = o.z - pos.x
			var to_back: float = pos.z - o.y
			var to_front: float = o.w - pos.z
			var smallest: float = minf(minf(to_left, to_right), minf(to_back, to_front))
			if smallest == to_left:
				pos.x = o.x
			elif smallest == to_right:
				pos.x = o.z
			elif smallest == to_back:
				pos.z = o.y
			else:
				pos.z = o.w
	_player = pos

## Qual objeto está sob a mira, e atualiza os rótulos flutuantes.
func _scan_spots() -> void:
	var forward: Vector3 = -camera.global_transform.basis.z
	var best_dot: float = -1.0
	var best_id: String = ""
	var carrying: bool = _carry > 0.0
	for id: String in _spots:
		var spot: Dictionary = _spots[id]
		var label: Label3D = spot["label3d"]
		var allowed: bool = _spot_allowed(id, spot, carrying)
		label.visible = allowed
		if not allowed:
			continue
		var to: Vector3 = (spot["pos"] as Vector3) - camera.global_position
		var dist: float = to.length()
		var near: float = clampf(1.5 - dist / 4.5, 0.0, 1.0)
		if bool(spot["hidden"]):
			near = clampf(2.0 - dist, 0.0, 1.0)
		var guide: bool = id == _guide_id
		var color: Color = Color(1.0, 0.86, 0.32, maxf(near, 0.75)) if guide else Color(0.72, 0.92, 1.0, near * 0.85)
		label.modulate = color
		if dist > float(spot["r"]):
			continue
		var d: float = to.normalized().dot(forward)
		if d > float(spot["min_dot"]) and d > best_dot:
			best_dot = d
			best_id = id
	if best_id != _active_id:
		if _active_id != "" and _spots.has(_active_id):
			((_spots[_active_id] as Dictionary)["label3d"] as Label3D).font_size = 30
		_active_id = best_id
		if _active_id != "":
			((_spots[_active_id] as Dictionary)["label3d"] as Label3D).font_size = 44
			AudioManager.play_hover()
	if _active_id != "":
		prompt_label.text = "[E]  " + str((_spots[_active_id] as Dictionary)["label"])
	else:
		prompt_label.text = ""

func _spot_allowed(id: String, spot: Dictionary, carrying: bool) -> bool:
	if str(spot["area"]) != _area:
		return false
	if str(spot["when"]) == "carry":
		return carrying and GameManager.owns(id.substr(3))
	return true

func _interact(id: String) -> void:
	if GameManager.state != GameManager.GameState.WORK:
		return
	if id.begins_with("co_"):
		_deliver(id.substr(3), (_spots[id] as Dictionary)["pos"])
		return
	if id.begins_with("st_"):
		_street_door(id.substr(3))
		return
	if id.begins_with("bug_"):
		events.remove_bug(id)
		return
	match id:
		"bed":
			_sleep()
		"door":
			_door()
		"window":
			_look_outside()
		"phone":
			phone.answer()
		"cases":
			_toggle_case()
		"shred":
			_start_minigame("shred")
		"wallet":
			if events.raid_active and _carry > 0.0:
				_hide_case()
			else:
				_open_tab("wallet")
		"darkweb":
			if Campaign.escape_active:
				_open_tab("darkweb")
			else:
				_start_minigame("hack")
		_:
			_open_tab(id)

func _open_tab(id: String) -> void:
	if (ui.visible_tabs() as Array).has(id):
		_focus(id)
	else:
		_notice("Durante a fuga só dá para usar o computador, a TV, o painel de risco e o notebook.")

# ---------------------------------------------------------
# Malotes: lavar dinheiro com as mãos
# ---------------------------------------------------------

func _toggle_case() -> void:
	if _carry > 0.0:
		_carry = 0.0
		_notice("Malote devolvido ao canto.")
		_displays_dirty = true
		return
	if _case_count - hidden_cases <= 0:
		_notice("Não há malotes à vista. A próxima remessa chega à noite.")
		return
	_carry = _case_value
	AudioManager.play_click()
	_notice("Malote de %s nas mãos. Leve a uma empresa: maquete ou rua." % UI.short_money(_carry))
	_displays_dirty = true

func _hide_case() -> void:
	hidden_cases += 1
	_carry = 0.0
	AudioManager.play_confirm()
	_float_text(Vector3(4.0, 1.2, 0.9), "Guardado", Color("#7FD1AE"))
	_displays_dirty = true

## Entrega o malote que está nas mãos em uma empresa. O valor vira uma operação
## normal do jogo: mesma perda, mesma suspeita, mesma capacidade do dia.
func _deliver(company_id: String, at: Vector3) -> void:
	if _carry <= 0.0:
		return
	var name_text: String = str(GameManager.companies[company_id]["name"])
	var amount: float = floorf(minf(_carry, GameManager.remaining_capacity(company_id)) / 100.0) * 100.0
	if amount < B.MIN_OPERATION:
		AudioManager.play_warning()
		_notice("%s não aguenta mais hoje. Tente outra empresa." % name_text)
		return
	var result: Dictionary = GameManager.process_company(company_id, amount)
	if not bool(result.get("ok", false)):
		AudioManager.play_warning()
		_notice(str(result.get("message", "")))
		return
	AudioManager.play_confirm()
	var tx: Dictionary = result.get("transaction", {})
	_float_text(at + Vector3(0, 0.4, 0), "+%s limpo" % UI.short_money(float(tx.get("clean", 0.0))), Color("#7FD1AE"))
	_carry -= amount
	if _carry < B.MIN_OPERATION:
		_carry = 0.0
	_notice("%s lavados em %s. Suspeita +%.1f." % [UI.short_money(amount), name_text, float(tx.get("risk", 0.0))])
	_displays_dirty = true

## Texto que sobe e some: feedback de uma entrega ou de um malote guardado.
func _float_text(pos: Vector3, text: String, color: Color) -> void:
	var node: Label3D = P.label(self, text, pos, 64, color, 0.0, 0.0, true)
	node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	node.no_depth_test = true
	node.outline_size = 12
	node.outline_modulate = Color(0, 0, 0, 0.9)
	var tw: Tween = node.create_tween().set_parallel(true)
	tw.tween_property(node, "position:y", pos.y + 1.0, 1.4)
	tw.tween_property(node, "modulate:a", 0.0, 1.4).set_delay(0.5)
	tw.chain().tween_callback(node.queue_free)

# ---------------------------------------------------------
# Rua
# ---------------------------------------------------------

func _street_door(key: String) -> void:
	if key == "home":
		_travel("room")
		return
	var status: String = GameManager.company_status(key)
	match status:
		"owned":
			if _carry > 0.0:
				_deliver(key, (_spots["st_" + key] as Dictionary)["pos"])
			else:
				GameManager.selected_company = key
				_focus("companies", true, "st_" + key)
		"sale":
			GameManager.selected_company = key
			_focus("companies", true, "st_" + key)
		_:
			_notice("%s ainda está fora do seu alcance." % str(GameManager.companies[key]["name"]))

## Atravessa a porta entre o apartamento e a rua, com fade.
func _travel(target: String) -> void:
	if _traveling:
		return
	_traveling = true
	var out: Tween = create_tween()
	out.tween_property(_fade, "color:a", 1.0, 0.3)
	await out.finished
	_area = target
	_active_id = ""
	if target == "street":
		_player = City.ARRIVE_POS
		_set_look_at(Vector3(0.0, 1.2, 32.0))
		city.refresh()
	else:
		_player = Vector3(0.5, 0.0, 2.6)
		_set_look_at(Vector3(0.0, 1.0, -1.0))
	city.visible = target == "street"
	city.active = target == "street"
	_blend = 0.0
	camera.position = _player + Vector3(0, EYE, 0)
	camera.quaternion = Quaternion.from_euler(Vector3(_pitch, _yaw, 0.0))
	await get_tree().create_timer(0.15).timeout
	var back: Tween = create_tween()
	back.tween_property(_fade, "color:a", 0.0, 0.35)
	await back.finished
	_traveling = false

# ---------------------------------------------------------
# Minigames
# ---------------------------------------------------------

func _start_minigame(kind: String) -> void:
	if _overlay_only:
		return
	if bool(_done_today.get(kind, false)):
		_notice("Você já fez isso hoje. Volte amanhã.")
		return
	var game: Control = Minigames.new()
	game.set("kind", kind)
	game.connect("finished", _on_minigame_done.bind(kind))
	hud.add_child(game)
	_overlay_only = true

func _on_minigame_done(score: float, kind: String) -> void:
	_overlay_only = false
	if score < 0.0:
		_notice("Você desistiu.")
		return
	_done_today[kind] = true
	if kind == "hack":
		var reduce: float = (B.HACK_SUSPICION_BASE + B.HACK_SUSPICION_BONUS * score) if score > 0.0 else 0.0
		_spend_minutes(B.HACK_MINUTES)
		if reduce > 0.0:
			GameManager.add_suspicion(-reduce)
			ui.toast("Rastros digitais apagados: suspeita -%.1f." % reduce, UI.GREEN)
		else:
			ui.toast("A invasão falhou e não apagou nada.", UI.RED)
	else:
		var hits: int = int(round(score * 4.0))
		_spend_minutes(B.SHRED_MINUTES)
		if hits > 0:
			var cut: float = B.SHRED_RISK_PER_HIT * float(hits)
			GameManager.modifiers.append({"target": "*", "stat": "risk", "value": -cut, "days": B.SHRED_DAYS, "label": "Arquivos triturados: %d%% menos suspeita por %d turnos" % [int(cut * 100.0), B.SHRED_DAYS]})
			ui.toast("%d arquivos destruídos: operações geram %d%% menos suspeita por %d turnos." % [hits, int(cut * 100.0), B.SHRED_DAYS], UI.GREEN)
		else:
			ui.toast("Nenhum arquivo foi destruído a tempo.", UI.RED)
	GameManager.touch()
	_displays_dirty = true

func _spend_minutes(minutes: int) -> void:
	GameManager.current_time_minutes = mini(GameManager.current_time_minutes + minutes, 23 * 60 + 59)

func _sleep() -> void:
	if Campaign.escape_active:
		_notice("Sem tempo para dormir. Cada hora conta.")
		return
	var room: float = 0.0
	for company_id: String in GameManager.owned_ids():
		room += GameManager.remaining_capacity(company_id)
	var safe: bool = GameManager.operations_today() > 0 or GameManager.dirty_money < B.MIN_OPERATION or room < B.MIN_OPERATION
	if safe:
		ui.end_turn()
	else:
		_ask(ui.request_end_turn)

func _door() -> void:
	if Campaign.escape_active:
		if Campaign.ready_to_fly():
			_ask(ui.request_takeoff)
		else:
			_notice("Faltam o passaporte e o avião. Use o notebook (Dark Web).")
	elif events.raid_active:
		_notice("A PF está do outro lado da porta. Não abra!")
	else:
		_travel("street")

## Abre uma confirmação do main.gd por cima do quarto, com o mouse livre.
func _ask(action: Callable) -> void:
	_overlay_only = true
	action.call()
	_watch_overlay()

func _watch_overlay() -> void:
	if _watching:
		return
	_watching = true
	await get_tree().create_timer(0.25).timeout
	while _overlay_only and ui.modal_open():
		await get_tree().create_timer(0.1).timeout
	_overlay_only = false
	_watching = false

## Olhar pela janela: a rua conta como anda a suspeita, sem números.
func _look_outside() -> void:
	var susp: float = GameManager.suspicion
	var line: String = "Chuva fina, trânsito lento. Ninguém olhando para cima."
	if events.raid_active:
		line = "Duas viaturas paradas na frente do prédio. Não é coincidência."
	elif susp >= 80.0:
		line = "Um helicóptero circula o quarteirão. A mesma viatura passou três vezes."
	elif susp >= 60.0:
		line = "Uma viatura parada na esquina, faróis apagados. Está lá desde cedo."
	elif susp >= 40.0:
		line = "Um carro sem placa estacionado em frente. Pode não ser nada."
	elif Campaign.escape_active:
		line = "A cidade parece menor hoje. Cada hora conta."
	_notice(line)

func _notice(text: String) -> void:
	notice_label.text = text
	_notice_t = 3.5

# =========================================================
# LUZ, CÉU E ANIMAÇÕES
# =========================================================

func _update_light() -> void:
	var hour: float = float(GameManager.current_time_minutes) / 60.0
	var day: float = clampf(sin((hour - 6.5) / 13.0 * PI), 0.0, 1.0)
	if Campaign.escape_active:
		day = minf(day, 0.12)
	if ov_day >= 0.0:
		day = ov_day
	_day = lerpf(_day, day, 0.05 if ov_day < 0.0 else 0.25)
	apartment.apply_light(_day, ov_lights, ov_monitor, _area == "street")

func _animate(delta: float) -> void:
	apartment.animate(delta, GameManager.suspicion, events.raid_active)
	var pulse: float = 0.6 + 0.4 * sin(_t * 3.0)
	if Campaign.escape_active:
		_dark_mat.emission_energy_multiplier = 1.0 + 1.6 * pulse
		_door_mat.emission_energy_multiplier = (0.8 + 1.8 * pulse) if Campaign.ready_to_fly() else 0.3
	else:
		_dark_mat.emission_energy_multiplier = 0.1 if bool(_done_today.get("hack", false)) else 0.5 + 0.4 * pulse
		_door_mat.emission_energy_multiplier = 1.4 if events.raid_active else 0.0
	_shred_mat.emission_energy_multiplier = 0.2 if bool(_done_today.get("shred", false)) else 0.6 + 0.5 * pulse
	_carry_node.visible = _carry > 0.0 and mode == Mode.WALK
	raid_label.visible = events.raid_active and mode != Mode.CINEMATIC
	if events.raid_active:
		raid_label.text = "BATIDA NA PORTA!  guarde os malotes no cofre   %d s   ·   restam %d" % [int(ceil(events.raid_t)), cases_remaining()]
	if GameManager.suspicion >= 75.0:
		for mat_v: Variant in _risk_mats:
			var mat: StandardMaterial3D = mat_v as StandardMaterial3D
			if mat.emission_energy_multiplier > 0.5:
				mat.emission_energy_multiplier = 1.4 + 1.6 * pulse

# =========================================================
# MOSTRADORES: O JOGO REFLETIDO NOS OBJETOS
# =========================================================

func _refresh_displays() -> void:
	# O apartamento acompanha a campanha (Ato 1 improvisado, Ato 3 bunker de luxo).
	apartment.apply_stage(3 if Campaign.escape_active else Campaign.act)
	if not cutscene_active:
		_clock_label.text = GameManager.format_time(GameManager.current_time_minutes)
		alarm_label.text = GameManager.format_time(GameManager.current_time_minutes)

	# Painel de risco.
	var susp: float = GameManager.suspicion
	var lit: int = int(round(clampf(susp / maxf(Campaign.limit(), 1.0), 0.0, 1.0) * float(_risk_mats.size())))
	for i: int in range(_risk_mats.size()):
		var mat: StandardMaterial3D = _risk_mats[i]
		var f: float = float(i) / float(_risk_mats.size() - 1)
		var c: Color = UI.zone_color(UI.zone_index(f * Campaign.limit()))
		mat.albedo_color = c.darkened(0.7) if i >= lit else c
		mat.emission = c
		mat.emission_energy_multiplier = 1.4 if i < lit else 0.0
	_risk_label.text = "%d%%" % int(round(susp))
	_risk_label.modulate = UI.zone_color(UI.zone_index(susp))
	var state_text: String = UI.zone_name(susp).to_upper()
	if Campaign.mandado:
		state_text = "MANDADO EXPEDIDO"
	elif GameManager.wiretap_days > 0:
		state_text = "GRAMPO ATIVO"
	_risk_state.text = state_text

	# Maquete: uma construção por empresa.
	for id: String in B.COMPANY_ORDER:
		var entry: Dictionary = _maq_buildings[id]
		var status: String = GameManager.company_status(id)
		var body: ShaderMaterial = entry["mat"]
		var top: StandardMaterial3D = entry["top"]
		var label: Label3D = entry["label"]
		var name_text: String = str(GameManager.companies[id]["name"])
		# Maquete de arquiteto: as suas em gesso com janelas acesas e o topo em
		# âmbar; à venda em gesso apagado com o preço; fora de alcance, escuras.
		match status:
			"owned":
				body.set_shader_parameter("base_color", Color("#CFC8BA"))
				body.set_shader_parameter("lit_ratio", 0.55)
				top.emission_energy_multiplier = 2.2
				top.emission = Color("#E8A55A")
				label.modulate = Color("#F2C98A")
				label.text = name_text
			"sale":
				body.set_shader_parameter("base_color", Color("#8E887E"))
				body.set_shader_parameter("lit_ratio", 0.0)
				top.emission_energy_multiplier = 0.8
				top.emission = Color("#9A9389")
				label.modulate = Color("#BAB4AD")
				label.text = "%s
%s" % [name_text, UI.short_money(GameManager.price_of(id))]
			_:
				body.set_shader_parameter("base_color", Color("#1E1E1E"))
				body.set_shader_parameter("lit_ratio", 0.0)
				top.emission_energy_multiplier = 0.0
				label.modulate = Color(0.55, 0.55, 0.55, 0.6)
				label.text = ""

	# Vitrine: só os bens que já são seus.
	for good_id: String in _good_nodes:
		(_good_nodes[good_id] as Node3D).visible = Lifestyle.owned.has(good_id)

	# Cofre.
	_safe_label.text = "SALDO LIMPO\n%s" % UI.short_money(GameManager.clean_money)
	var clean: float = GameManager.clean_money
	var stack_count: int = 0
	for limit_value: float in [50000.0, 200000.0, 1000000.0, 5000000.0, 20000000.0]:
		if clean >= limit_value:
			stack_count += 1
	for i: int in range(_safe_stacks.size()):
		(_safe_stacks[i] as Node3D).visible = i < stack_count

	# A TV e os monitores se desenham sozinhos (world/screen_ui.gd).
	_file_label.text = "ARQUIVO\n%d operações" % GameManager.transactions.size()

	# Notebook, triturador e porta.
	_dark_label.text = "DARK WEB" if Campaign.escape_active else "APAGAR\nRASTROS"
	var hack_done: bool = bool(_done_today.get("hack", false))
	var shred_done: bool = bool(_done_today.get("shred", false))
	if Campaign.escape_active:
		set_spot_label("darkweb", "NOTEBOOK  ·  Dark Web")
	else:
		set_spot_label("darkweb", "NOTEBOOK  ·  Já usado hoje" if hack_done else "NOTEBOOK  ·  Invasão: apagar rastros")
	set_spot_label("shred", "TRITURADOR  ·  Já usado hoje" if shred_done else "TRITURADOR  ·  Queimar arquivos")
	if events.raid_active:
		_door_label.text = "ABRAM! POLÍCIA FEDERAL"
	elif Campaign.escape_active:
		_door_label.text = "DECOLAR" if Campaign.ready_to_fly() else "SAÍDA\nfaltam passaporte e avião"
	else:
		_door_label.text = "RUA"

	_refresh_cases()
	if city != null:
		city.refresh()

	_rebuild_cork()
	_rebuild_staff()

## Malotes: o dinheiro sujo vira maletas à vista no canto do quarto.
func _refresh_cases() -> void:
	var dirty: float = GameManager.dirty_money
	var unit: float = maxf(B.MIN_OPERATION * 5.0, Campaign.remessa() * B.CASE_SHARE)
	_case_count = clampi(int(ceil(dirty / unit)), 0, B.CASES_MAX) if dirty >= B.MIN_OPERATION else 0
	_case_value = dirty / float(_case_count) if _case_count > 0 else 0.0
	if _carry > dirty:
		_carry = 0.0
	var shown: int = maxi(0, _case_count - hidden_cases - (1 if _carry > 0.0 else 0))
	for i: int in range(_case_nodes.size()):
		(_case_nodes[i] as Node3D).visible = i < shown
	set_spot_label("cases", "MALOTE NAS MÃOS  ·  Devolver" if _carry > 0.0 else ("MALOTES  ·  Pegar um (%s)" % UI.short_money(_case_value) if shown > 0 else "MALOTES  ·  Nenhum à vista"))

func _clear(node: Node) -> void:
	for child: Node in node.get_children():
		node.remove_child(child)
		child.queue_free()

func _rebuild_cork() -> void:
	_clear(_cork_root)
	var objectives: Array = Missions.objectives
	for i: int in range(mini(objectives.size(), 4)):
		var obj: Dictionary = objectives[i]
		var done: bool = str(obj["state"]) == "done"
		var x: float = -0.66 + float(i) * 0.44
		var paper: Color = Color("#6FD3A0") if done else Color("#F2E3A6")
		_box(_cork_root, Vector3(x, 0.12, 0.03), Vector3(0.38, 0.42, 0.012), _mat(paper.to_html(false)))
		_box(_cork_root, Vector3(x, 0.32, 0.045), Vector3(0.03, 0.03, 0.02), _mat("#C23B3B"))
		var title: String = str(Missions.data(str(obj["id"])).get("title", "Objetivo"))
		_lbl(_cork_root, ("OK  " if done else "") + title, Vector3(x, 0.10, 0.045), 22, Color("#1A2A22") if done else Color("#2A2418"), 0.0, 340.0, false)
	var row: int = 0
	var cards: Array = []
	for c_v: Variant in Missions.active_contracts():
		cards.append([c_v, true])
	for c_v: Variant in Missions.offered_contracts():
		cards.append([c_v, false])
	for i: int in range(mini(cards.size(), 4)):
		var contract: Dictionary = cards[i][0]
		var active: bool = bool(cards[i][1])
		var x2: float = -0.66 + float(i) * 0.44
		var paper2: Color = Color("#8FD8F2") if active else Color("#FFB878")
		_box(_cork_root, Vector3(x2, -0.30, 0.03), Vector3(0.38, 0.34, 0.012), _mat(paper2.to_html(false)))
		_box(_cork_root, Vector3(x2, -0.16, 0.045), Vector3(0.03, 0.03, 0.02), _mat("#C23B3B"))
		_lbl(_cork_root, ("EM CURSO  " if active else "NOVO  ") + str(contract.get("title", "Contrato")), Vector3(x2, -0.31, 0.045), 20, Color("#211E1B"), 0.0, 340.0, false)
		row += 1
	_lbl(_cork_root, "MISSÕES  %d/%d" % [Missions.objectives_done(), objectives.size()], Vector3(0.0, 0.50, 0.04), 40, Color("#F2E3A6"), 0.0, 0.0, true)

func _rebuild_staff() -> void:
	_clear(_staff_root)
	var roster: Array = Staff.roster
	_lbl(_staff_root, "PESSOAL  %d" % roster.size(), Vector3(0.04, 0.54, 0.0), 40, Color("#F2E3A6"), 90.0, 0.0, true)
	if roster.is_empty():
		_lbl(_staff_root, "NINGUÉM CONTRATADO\nlaranjas aumentam a capacidade", Vector3(0.04, 0.0, 0.0), 30, Color("#C9B98A"), 90.0, 700.0, false)
		return
	for i: int in range(mini(roster.size(), 6)):
		var member: Dictionary = roster[i]
		var col: int = i % 3
		var rw: int = i / 3
		var z: float = 0.52 - float(col) * 0.52
		var y: float = 0.22 - float(rw) * 0.52
		var stress: float = float(member["stress"])
		var delating: bool = int(member["delation"]) >= 0
		var tone: Color = Color("#6FD3A0")
		if delating or stress >= 75.0:
			tone = Color("#E5484D")
		elif stress >= 45.0:
			tone = Color("#E08A4A")
		_box(_staff_root, Vector3(0.03, y, z), Vector3(0.012, 0.44, 0.40), _mat("#E8E4D8"))
		_box(_staff_root, Vector3(0.04, y + 0.06, z), Vector3(0.012, 0.22, 0.30), _mat("#3A4752"))
		_box(_staff_root, Vector3(0.045, y - 0.18, z), Vector3(0.012, 0.05, 0.36), _mat(tone.to_html(false), tone.to_html(false), 1.2))
		_lbl(_staff_root, str(member["name"]).get_slice(" ", 0), Vector3(0.056, y - 0.07, z), 24, Color("#292623"), 90.0, 0.0, false)
		_lbl(_staff_root, "DELATANDO" if delating else "estresse %d" % int(stress), Vector3(0.056, y - 0.13, z), 18, tone.darkened(0.45), 90.0, 0.0, true)
		var trait_text: String = Staff.trait_name(member)
		if trait_text != "":
			_lbl(_staff_root, trait_text.to_upper(), Vector3(0.056, y + 0.2, z), 16, Color("#8A5A1E"), 90.0, 0.0, true)

# =========================================================
# CONSTRUÇÃO: MATERIAIS E PRIMITIVAS
# =========================================================

func _mat(color: String, emission: String = "", energy: float = 0.0, metallic: float = 0.0, alpha: float = 1.0, rough: float = 0.88) -> StandardMaterial3D:
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


func _box(parent: Node, pos: Vector3, size: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var shape: BoxMesh = BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.position = pos
	mesh.rotation_degrees = rot
	mesh.material_override = mat
	parent.add_child(mesh)
	return mesh

func _cyl(parent: Node, pos: Vector3, radius: float, height: float, mat: Material, rot: Vector3 = Vector3.ZERO, top_radius: float = -1.0) -> MeshInstance3D:
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var shape: CylinderMesh = CylinderMesh.new()
	shape.bottom_radius = radius
	shape.top_radius = radius if top_radius < 0.0 else top_radius
	shape.height = height
	shape.radial_segments = 24
	mesh.mesh = shape
	mesh.position = pos
	mesh.rotation_degrees = rot
	mesh.material_override = mat
	parent.add_child(mesh)
	return mesh

func _sph(parent: Node, pos: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var shape: SphereMesh = SphereMesh.new()
	shape.radius = radius
	shape.height = radius * 2.0
	shape.radial_segments = 20
	shape.rings = 10
	mesh.mesh = shape
	mesh.position = pos
	mesh.material_override = mat
	parent.add_child(mesh)
	return mesh

## Móvel sólido: malha e caixa de colisão para o empurrão do jogador.
func _solid(pos: Vector3, size: Vector3, mat: Material, block: bool = true) -> MeshInstance3D:
	if block:
		_block(pos, size)
	return _box(self, pos, size, mat)

func _block(pos: Vector3, size: Vector3) -> void:
	_obstacles.append(Vector4(pos.x - size.x * 0.5 - 0.10, pos.z - size.z * 0.5 - 0.10, pos.x + size.x * 0.5 + 0.10, pos.z + size.z * 0.5 + 0.10))

func _lbl(parent: Node, text: String, pos: Vector3, size: int, color: Color, yaw_deg: float = 0.0, width: float = 0.0, mono: bool = true) -> Label3D:
	var label: Label3D = Label3D.new()
	label.text = text
	label.font_size = size
	label.pixel_size = 0.001
	label.modulate = color
	label.outline_size = 0
	label.shaded = false
	label.double_sided = false
	label.position = pos
	label.rotation_degrees.y = yaw_deg
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if width > 0.0:
		label.width = width
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var font: Font = UI.font_mono if mono else UI.font_bold
	if font != null:
		label.font = font
	parent.add_child(label)
	return label



# =========================================================
# VITRINE (o resto do quarto é construído em world/apartment.gd)
# =========================================================
## Miniaturas dos bens na vitrine: só aparecem os que já são seus.
func _build_goods(x: float, z: float) -> void:
	var palette: Array = ["#C9A24A", "#B8433F", "#3F7FB8", "#5A9A6A", "#8A6AB8", "#D8D8E0"]
	var index: int = 0
	for good_v: Variant in B.GOODS:
		var good: Dictionary = good_v as Dictionary
		var shelf: int = index / 3
		var slot: int = index % 3
		var node: Node3D = Node3D.new()
		node.position = Vector3(x, 0.34 + float(shelf) * 0.44, z - 0.5 + float(slot) * 0.5)
		add_child(node)
		_good_nodes[str(good["id"])] = node
		var color: String = str(palette[index % palette.size()])
		var body_mat: StandardMaterial3D = _mat(color, "", 0.0, 0.4, 1.0, 0.4)
		var scale_f: float = 0.8 + 0.1 * float(index % 4)
		match str(good["cat"]):
			"Relógios":
				_cyl(node, Vector3(0, 0.05, 0), 0.06 * scale_f, 0.03, body_mat)
				_cyl(node, Vector3(0, 0.05, 0), 0.04 * scale_f, 0.035, _mat("#10181F", "#8FD8F0", 0.6))
				_box(node, Vector3(0, 0.03, 0), Vector3(0.05, 0.05, 0.03), _mat("#2A2A2A"))
			"Arte":
				_box(node, Vector3(0, 0.15, 0), Vector3(0.03, 0.26 * scale_f, 0.20 * scale_f), _mat("#1A140E"))
				_box(node, Vector3(0.018, 0.15, 0), Vector3(0.008, 0.2 * scale_f, 0.15 * scale_f), body_mat)
			"Carros":
				_box(node, Vector3(0, 0.05, 0), Vector3(0.12 * scale_f, 0.05, 0.30 * scale_f), body_mat)
				_box(node, Vector3(0, 0.095, -0.02), Vector3(0.10 * scale_f, 0.04, 0.14 * scale_f), _mat("#10181F", "", 0.0, 0.6, 1.0, 0.2))
				for wx: float in [-0.06, 0.06]:
					for wz: float in [-0.09, 0.09]:
						_cyl(node, Vector3(wx * scale_f, 0.03, wz * scale_f), 0.03, 0.03, _mat("#0A0A0A"), Vector3(0, 0, 90))
			"Imóveis":
				_box(node, Vector3(0, 0.08, 0), Vector3(0.22 * scale_f, 0.14, 0.22 * scale_f), _mat("#D8D4C8"))
				var roof: MeshInstance3D = MeshInstance3D.new()
				var prism: PrismMesh = PrismMesh.new()
				prism.size = Vector3(0.26 * scale_f, 0.10, 0.26 * scale_f)
				roof.mesh = prism
				roof.position = Vector3(0, 0.20, 0)
				roof.material_override = body_mat
				node.add_child(roof)
			"Iates":
				_box(node, Vector3(0, 0.04, 0), Vector3(0.12 * scale_f, 0.06, 0.34 * scale_f), _mat("#F2F2F2", "", 0.0, 0.3, 1.0, 0.3))
				_box(node, Vector3(0, 0.10, 0.02), Vector3(0.09 * scale_f, 0.06, 0.16 * scale_f), body_mat)
				_cyl(node, Vector3(0, 0.20, -0.04), 0.008, 0.18, _mat("#C8C8C8"))
		node.visible = false
		index += 1

func _build_camera() -> void:
	camera = Camera3D.new()
	camera.fov = 70.0
	camera.near = 0.05
	camera.far = 160.0
	add_child(camera)
	camera.current = true

# =========================================================
# MARCADORES DE INTERAÇÃO
# =========================================================

func _add_spots() -> void:
	# id: aba do jogo (ou "bed", "door", "window").
	_spot_def("overview", Vector3(DX, 1.1, -3.1), 3.0, "COMPUTADOR  ·  Visão geral", Vector3(DX, 1.32, -2.2), Vector3(DX, 1.2, -3.3), Vector3(0, 0.62, 0.5))
	_spot_def("missions", Vector3(0.3, 1.6, -3.4), 3.8, "QUADRO DE MISSÕES", Vector3(0.3, 1.6, -1.5), Vector3(0.3, 1.6, -3.45), Vector3(0, 0.9, 0.4))
	_spot_def("risk", Vector3(2.35, 1.65, -3.4), 3.8, "PAINEL DE RISCO", Vector3(2.35, 1.65, -1.6), Vector3(2.35, 1.65, -3.45), Vector3(0, 0.9, 0.4))
	_spot_def("transactions", Vector3(3.85, 0.9, -3.1), 3.0, "ARQUIVO  ·  Transações", Vector3(3.5, 1.2, -1.7), Vector3(3.85, 0.9, -3.2), Vector3(0, 0.9, 0.4))
	_spot_def("lifestyle", Vector3(4.2, 1.1, -0.9), 3.4, "VITRINE  ·  Bens", Vector3(2.5, 1.35, -0.9), Vector3(4.2, 1.1, -0.9), Vector3(-0.5, 1.2, 0))
	_spot_def("wallet", Vector3(4.05, 0.6, 0.9), 3.0, "COFRE  ·  Carteira", Vector3(2.7, 1.1, 0.9), Vector3(4.05, 0.55, 0.9), Vector3(-0.5, 0.9, 0))
	_spot_def("news", Vector3(-2.4, 1.5, 3.3), 4.8, "TV  ·  Notícias", Vector3(-2.4, 1.45, 1.1), Vector3(-2.4, 1.5, 3.4), Vector3(0, 1.0, -0.5))
	_spot_def("staff", Vector3(-4.4, 1.6, -2.3), 3.6, "QUADRO DE LARANJAS", Vector3(-2.6, 1.6, -2.3), Vector3(-4.45, 1.6, -2.3), Vector3(0.5, 1.1, 0))
	_spot_def("companies", Vector3(0.2, 1.0, 0.3), 3.4, "MAQUETE  ·  Empresas", Vector3(0.2, 1.95, 1.7), Vector3(0.2, 0.9, 0.3), Vector3(0, 0.9, 0))
	_spot_def("darkweb", Vector3(-3.95, 0.7, 2.85), 3.0, "NOTEBOOK  ·  Dark Web", Vector3(-2.9, 1.2, 2.4), Vector3(-3.95, 0.7, 2.85), Vector3(0.3, 0.7, 0))
	_spot_def("bed", Vector3(3.4, 0.6, 2.3), 3.0, "CAMA  ·  Finalizar turno", Vector3.ZERO, Vector3.ZERO, Vector3(0, 1.0, 0))
	_spot_def("door", Vector3(0.5, 1.1, 3.35), 3.0, "PORTA  ·  Sair para a rua", Vector3.ZERO, Vector3.ZERO, Vector3(0, 1.3, -0.5))
	_spot_def("window", Vector3(-4.4, 1.7, 0.2), 3.0, "JANELA", Vector3.ZERO, Vector3.ZERO, Vector3(0.5, 1.0, 0))
	_spot_def("cases", Vector3(1.75, 0.35, 2.55), 3.2, "MALOTES", Vector3.ZERO, Vector3.ZERO, Vector3(0, 0.75, 0))
	_spot_def("phone", Vector3(DX + 0.38, 0.82, -2.98), 2.6, "CELULAR", Vector3.ZERO, Vector3.ZERO, Vector3(0, 0.35, 0.1), "room", "always", 0.93)
	_spot_def("shred", Vector3(2.62, 0.6, -3.2), 2.8, "TRITURADOR", Vector3.ZERO, Vector3.ZERO, Vector3(0, 0.7, 0.3))
	# Prédios da maquete: ponto de entrega do malote.
	for id: String in B.COMPANY_ORDER:
		_spot_def("co_" + id, _maq_tops[id], 3.2, "ENTREGAR  ·  %s" % str(B.COMPANIES[id]["name"]), Vector3.ZERO, Vector3.ZERO, Vector3(0, 0.45, 0), "room", "carry", 0.965)
	# Rua: portas das empresas e a volta para casa.
	for def_v: Variant in city.spot_defs():
		var def: Array = def_v as Array
		var cam: Vector3 = def[3]
		_spot_def(str(def[0]), def[1], 6.0, str(def[2]), cam, def[4], def[5], "street", "always", 0.9)

func _spot_def(id: String, pos: Vector3, reach: float, label: String, cam: Vector3, look: Vector3, tag: Vector3, area: String = "room", when: String = "always", min_dot: float = 0.88, hidden: bool = false) -> void:
	var tag_node: Label3D = _lbl(self, label, pos + tag, 30, Color(0.72, 0.92, 1.0, 0.0), 0.0, 0.0, true)
	tag_node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag_node.no_depth_test = true
	tag_node.outline_size = 10
	tag_node.outline_modulate = Color(0, 0, 0, 0.9)
	tag_node.visible = false
	var spot: Dictionary = {"pos": pos, "r": reach, "label": label, "label3d": tag_node, "area": area, "when": when, "min_dot": min_dot, "hidden": hidden}
	if cam != Vector3.ZERO:
		spot["cam"] = cam
		spot["look"] = look
	_spots[id] = spot

# =========================================================
# HUD
# =========================================================

func _build_hud() -> void:
	shade_layer = CanvasLayer.new()
	shade_layer.layer = -1
	add_child(shade_layer)
	shade = ColorRect.new()
	shade.color = Color(0.02, 0.015, 0.01, 0.42)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade_layer.add_child(shade)

	hud = CanvasLayer.new()
	hud.layer = 10
	add_child(hud)
	crosshair = ColorRect.new()
	crosshair.color = Color(1, 1, 1, 0.7)
	crosshair.size = Vector2(5, 5)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(crosshair)
	prompt_label = _hud_label(20, Color("#FFE9A8"), true)
	hint_label = _hud_label(12, Color(0.62, 0.78, 0.86, 0.6), false)
	hint_label.text = "WASD MOVER  ·  SHIFT CORRER  ·  MOUSE OLHAR  ·  E USAR  ·  ESC COMPUTADOR"
	notice_label = _hud_label(15, Color("#ECE6DA"), true)
	status_label = _hud_label(14, Color("#ECE6DA"), false)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	status_label.add_theme_stylebox_override("normal", _hud_box())
	step_label = _hud_label(14, Color("#ECE6DA"), false)
	step_label.add_theme_stylebox_override("normal", _hud_box())
	focus_label = _hud_label(11, Color(0.62, 0.78, 0.86, 0.75), false)
	focus_label.text = "V VER O OBJETO  ·  ESC LEVANTAR  ·  1-9 TROCAR DE OBJETO"
	raid_label = _hud_label(22, Color("#FF6A6A"), true)
	raid_label.add_theme_stylebox_override("normal", _hud_box())
	var fade_layer: CanvasLayer = CanvasLayer.new()
	fade_layer.layer = 50
	add_child(fade_layer)
	_fade = ColorRect.new()
	fade_rect = _fade
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_layer.add_child(_fade)
	_layout_hud()
	get_viewport().size_changed.connect(_layout_hud)

func _hud_box() -> StyleBoxFlat:
	var box: StyleBoxFlat = UI.flat(Color(0.06, 0.055, 0.05, 0.82), Color(UI.CYAN, 0.35), 2)
	box.content_margin_left = 14.0
	box.content_margin_right = 14.0
	box.content_margin_top = 8.0
	box.content_margin_bottom = 8.0
	return box

func _hud_label(size: int, color: Color, outline: bool) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	if outline:
		label.add_theme_constant_override("outline_size", 6)
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	if UI.font_mono != null:
		label.add_theme_font_override("font", UI.font_mono)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.visible = false
	hud.add_child(label)
	return label

func _layout_hud() -> void:
	var view: Vector2 = get_viewport().get_visible_rect().size
	crosshair.position = (view - crosshair.size) * 0.5
	prompt_label.position = Vector2(0, view.y * 0.58)
	prompt_label.size = Vector2(view.x, 30)
	notice_label.position = Vector2(0, view.y * 0.66)
	notice_label.size = Vector2(view.x, 26)
	hint_label.position = Vector2(0, view.y - 28.0)
	hint_label.size = Vector2(view.x, 20)
	status_label.position = Vector2(20, 20)
	step_label.position = Vector2(view.x * 0.5 - 360.0, view.y - 84.0)
	step_label.size = Vector2(720, 40)
	focus_label.position = Vector2(0, view.y - 16.0)
	focus_label.size = Vector2(view.x, 14)
	raid_label.position = Vector2(view.x * 0.5 - 420.0, 24.0)
	raid_label.size = Vector2(840, 44)

func _refresh_hud() -> void:
	if mode != Mode.WALK:
		return
	var lines: PackedStringArray = []
	if Campaign.escape_active:
		lines.append("OPERAÇÃO FUGA   %d h restantes" % int(round(Campaign.escape_hours)))
		lines.append("MONERO %s   INTERCEPTAÇÃO %d%%" % [UI.short_money(Portfolio.monero), int(round(Campaign.interception_chance()))])
	else:
		lines.append("ATO %d  ·  TURNO %02d/%02d  ·  %s" % [Campaign.act, GameManager.current_day, maxi(GameManager.total_days, 1), GameManager.format_time(GameManager.current_time_minutes)])
		lines.append("SUJO %s   LIMPO %s" % [UI.short_money(GameManager.dirty_money), UI.short_money(GameManager.clean_money)])
		lines.append("SUSPEITA %d%%   META %d%%" % [int(round(GameManager.suspicion)), int(Campaign.progress() * 100.0)])
	if _carry > 0.0:
		lines.append("MALOTE NAS MÃOS  %s" % UI.short_money(_carry))
	status_label.text = "\n".join(lines)
	var text: String = ""
	var color: Color = Color("#ECE6DA")
	var target: String = ""
	var best: String = _best_company()
	if phone.ringing and _area == "room" and not events.raid_active:
		target = "phone"
		text = "O celular está tocando: %s." % str(Director.phone_call.get("caller_name", ""))
		color = Color("#E8C25A")
	elif events.raid_active:
		target = "wallet" if _carry > 0.0 else "cases"
		text = "BATIDA! Leve os malotes ao cofre antes do tempo acabar."
		color = Color("#FF6A6A")
	elif _carry > 0.0:
		target = ("st_" if _area == "street" else "co_") + best if best != "" else "cases"
		text = "Entregue o malote em uma empresa sua." if best != "" else "Nenhuma empresa aguenta mais hoje. Devolva o malote."
	elif _area == "street":
		target = "st_home"
		text = "Na rua: leve malotes às empresas, compre novas, ou volte para casa."
	else:
		var step: Dictionary = ui.next_step()
		var tab: String = str(step.get("tab", ""))
		text = str(step.get("text", ""))
		color = step.get("color", color)
		if tab == "companies" and cases_remaining() > 0 and best != "":
			target = "cases"
			text = "Pegue um malote de dinheiro sujo e leve a uma empresa."
		else:
			target = tab if (tab != "" and _spots.has(tab)) else "bed"
	_guide_id = target if _spots.has(target) else ""
	var target_name: String = str((_spots[_guide_id] as Dictionary)["label"]) if _guide_id != "" else ""
	step_label.text = "%s\n▶ %s" % [text, target_name]
	step_label.add_theme_color_override("font_color", color)

## Empresa sua com mais capacidade livre hoje ("" se nenhuma aguenta um malote).
func _best_company() -> String:
	var best: String = ""
	var room: float = B.MIN_OPERATION
	for company_id: String in GameManager.owned_ids():
		var left: float = GameManager.remaining_capacity(company_id)
		if left >= room:
			room = left
			best = company_id
	return best
