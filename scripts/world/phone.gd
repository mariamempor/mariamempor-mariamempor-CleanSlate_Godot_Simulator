extends Node3D
## CELULAR DE TRABALHO — fica na mesa e, às vezes, toca durante o dia.
##
## Quem decide se há ligação é o Director (phone_call). Aqui ficam o objeto,
## o toque (vibra, acende, chacoalha na mesa, ouve-se de qualquer canto do
## quarto) e o atendimento: o acontecimento abre como ligação, com o nome de
## quem está do outro lado. Sem atender, a ligação vira decisão da noite.

const Synth = preload("res://scripts/world/synth.gd")
const P = preload("res://scripts/world/prims.gd")

var world
var ringing: bool = false
var _wait: float = -1.0           # segundos até tocar (-1 = sem ligação)
var _ring_t: float = 0.0
var _screen_mat: StandardMaterial3D
var _caller: Label3D
var _body: Node3D
var _light: OmniLight3D
var _audio: AudioStreamPlayer3D
var _home: Vector3
var _told: bool = false

func build(pos: Vector3) -> void:
	position = pos
	_home = pos
	_body = Node3D.new()
	add_child(_body)
	_body.rotation_degrees.y = -18.0
	P.box(_body, Vector3(0, 0.004, 0), Vector3(0.078, 0.008, 0.158), P.mat("#0C0C0D", "", 0.0, 0.5, 1.0, 0.25))
	_screen_mat = P.mat("#020203", "#E8D8B8", 0.0, 0.0, 1.0, 0.2)
	P.box(_body, Vector3(0, 0.0085, 0), Vector3(0.07, 0.001, 0.146), _screen_mat)
	_caller = Label3D.new()
	_caller.font_size = 28
	_caller.pixel_size = 0.0006
	_caller.modulate = Color("#F2E6CC")
	_caller.outline_size = 0
	_caller.shaded = false
	_caller.rotation_degrees = Vector3(-90, 0, 0)
	_caller.position = Vector3(0, 0.0095, -0.02)
	_caller.width = 110
	_caller.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if UI.font_mono != null:
		_caller.font = UI.font_mono
	_caller.visible = false
	_body.add_child(_caller)
	_light = OmniLight3D.new()
	_light.light_color = Color("#E8D8B8")
	_light.omni_range = 0.9
	_light.light_energy = 0.0
	_light.position = Vector3(0, 0.08, 0)
	add_child(_light)
	_audio = AudioStreamPlayer3D.new()
	_audio.stream = Synth.phone_buzz()
	_audio.unit_size = 3.0
	_audio.max_db = 2.0
	add_child(_audio)

## Chamado a cada novo dia de trabalho.
func new_day() -> void:
	ringing = false
	_told = false
	_audio.stop()
	_wait = randf_range(18.0, 40.0) if not Director.phone_call.is_empty() else -1.0

func _process(delta: float) -> void:
	if world == null:
		return
	var working: bool = GameManager.state == GameManager.GameState.WORK and not world.cutscene_active
	if not ringing:
		_screen_mat.emission_energy_multiplier = 0.0
		_caller.visible = false
		_light.light_energy = 0.0
		if _wait >= 0.0 and working and not PopupManager.is_open() and not bool(world.ui.get("_flow_busy")):
			_wait -= delta
			if _wait < 0.0 and not Director.phone_call.is_empty():
				_start_ring()
		return
	if not working or Director.phone_call.is_empty():
		_stop()
		return
	_ring_t += delta
	var on: bool = fmod(_ring_t, 1.4) < 0.8
	_screen_mat.emission_energy_multiplier = 1.8
	_light.light_energy = 0.6 if on else 0.25
	_caller.visible = true
	# Vibração: o aparelho anda alguns milímetros na mesa a cada toque.
	if on:
		_body.position = Vector3(randf_range(-0.0015, 0.0015), 0.0, randf_range(-0.0015, 0.0015))
		_body.rotation_degrees.y = -18.0 + sin(_ring_t * 60.0) * 1.2
		position = position.move_toward(_home + Vector3(0.012, 0, 0.006), delta * 0.004)
	var master: float = 0.0 if AudioManager.muted else AudioManager.master_volume
	_audio.volume_db = linear_to_db(maxf(0.0001, master * 0.9))
	if not _audio.playing:
		_audio.play()
	# Com a interface aberta, avisa uma vez por toque.
	if world.mode == world.Mode.FOCUS and not _told:
		_told = true
		world.ui.toast("O celular está tocando na mesa: %s. ESC para levantar e atender." % str(Director.phone_call.get("caller_name", "")), UI.YELLOW)

func _start_ring() -> void:
	ringing = true
	_ring_t = 0.0
	_caller.text = "%s\nchamando..." % str(Director.phone_call.get("caller_name", "Desconhecido"))
	world.notice("O celular está tocando.")

func _stop() -> void:
	ringing = false
	_audio.stop()
	_body.position = Vector3.ZERO

## Atender: a ligação abre como decisão, com o mouse livre e o jogador em pé.
func answer() -> void:
	if not ringing:
		world.notice("Nenhuma ligação. Por enquanto." if Director.phone_call.is_empty() else "O celular está mudo. Por enquanto.")
		return
	_stop()
	position = _home
	AudioManager.play_click()
	var call: Dictionary = Director.take_phone_call()
	if call.is_empty():
		return
	world.set("_overlay_only", true)
	var message: String = await PopupManager.show_event(call)
	world.set("_overlay_only", false)
	if message != "":
		world.ui.toast(message, UI.CYAN)
	GameManager.touch()
