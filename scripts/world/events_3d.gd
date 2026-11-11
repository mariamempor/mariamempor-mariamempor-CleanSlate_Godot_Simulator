extends Node3D
## Eventos físicos no apartamento.
##
##   Grampos   Com um grampo ativo (wiretap_days > 0), aparelhos com um LED
##             vermelho piscando surgem escondidos pelo quarto. Chegue perto e
##             remova todos para acabar com o grampo, sem pagar a varredura.
##   Batida    Ao acordar, com suspeita alta, a PF bate na porta. Há alguns
##             segundos para levar os malotes até o cofre. Se sobrar dinheiro
##             sujo à vista, parte é apreendida e a suspeita sobe.
##
## As regras e os números moram em balance.gd; este script só conta o tempo,
## mostra os objetos e aplica o resultado.

const P = preload("res://scripts/world/prims.gd")
const B = preload("res://scripts/data/balance.gd")

## Onde um grampo pode estar escondido (todos dentro do quarto).
const BUG_PLACES: Array = [
	[Vector3(-2.5, 0.72, -3.05), "embaixo da mesa"],
	[Vector3(-2.4, 0.46, 2.1), "no sofá"],
	[Vector3(2.35, 0.64, 3.1), "no abajur"],
	[Vector3(1.9, 1.72, 3.2), "na estante"],
	[Vector3(-2.4, 0.52, 3.15), "atrás da TV"],
	[Vector3(0.5, 0.9, -3.4), "atrás do mural"],
	[Vector3(4.1, 1.0, 0.2), "perto do cofre"]
]

var world
var raid_active: bool = false
var raid_t: float = 0.0

var _bugs: Dictionary = {}          # id do spot -> Node3D
var _leds: Array = []
var _check_t: float = 0.0
var _last_raid_day: int = -99
var _warn_t: float = 0.0
var _red: OmniLight3D
var _blue: OmniLight3D
var _red2: OmniLight3D
var _t: float = 0.0

func setup() -> void:
	_red = P.light(self, Vector3(-3.7, 1.8, 0.2), "#FF2020", 0.0, 9.0, false)
	_blue = P.light(self, Vector3(-3.7, 1.8, 0.2), "#2060FF", 0.0, 9.0, false)
	_red2 = P.light(self, Vector3(0.5, 1.9, 2.9), "#FF2020", 0.0, 6.0, false)

func _process(delta: float) -> void:
	_t += delta
	for led_v: Variant in _leds:
		var led: StandardMaterial3D = led_v as StandardMaterial3D
		led.emission_energy_multiplier = 3.5 if int(floor(_t * 1.6)) % 2 == 0 else 0.2
	_check_t -= delta
	if _check_t <= 0.0:
		_check_t = 0.5
		_sync_bugs()
	if raid_active:
		_tick_raid(delta)

# ---------------------------------------------------------
# Grampos
# ---------------------------------------------------------

func bugs_left() -> int:
	return _bugs.size()

func _sync_bugs() -> void:
	var want: bool = GameManager.wiretap_days > 0 and GameManager.state == GameManager.GameState.WORK
	if want and _bugs.is_empty():
		_spawn_bugs()
	elif not want and not _bugs.is_empty():
		_clear_bugs()

func _spawn_bugs() -> void:
	var places: Array = BUG_PLACES.duplicate()
	places.shuffle()
	for i: int in range(mini(B.BUGS_COUNT, places.size())):
		var place: Array = places[i]
		var node: Node3D = Node3D.new()
		node.position = place[0]
		add_child(node)
		P.box(node, Vector3.ZERO, Vector3(0.08, 0.025, 0.05), P.mat("#0A0E12", "", 0.0, 0.5))
		var led: StandardMaterial3D = P.mat("#FF2020", "#FF2020", 3.0)
		P.sph(node, Vector3(0.025, 0.02, 0.0), 0.011, led)
		_leds.append(led)
		var id: String = "bug_%d" % i
		_bugs[id] = node
		world.add_spot(id, node.position, 2.0, "GRAMPO  ·  %s  ·  Remover" % str(place[1]), Vector3(0, 0.25, 0), "always", 0.9, true)
	world.notice("Grampo ativo: procure aparelhos com LED vermelho piscando pelo quarto.")

func _clear_bugs() -> void:
	for id: String in _bugs:
		(_bugs[id] as Node3D).queue_free()
		world.remove_spot(id)
	_bugs.clear()
	_leds.clear()

func remove_bug(id: String) -> void:
	if not _bugs.has(id):
		return
	(_bugs[id] as Node3D).queue_free()
	_bugs.erase(id)
	world.remove_spot(id)
	AudioManager.play_confirm()
	if _bugs.is_empty():
		GameManager.wiretap_days = 0
		GameManager.touch()
		world.ui.toast("Grampos removidos: a linha está limpa.", UI.GREEN)
		world.notice("Todos os grampos foram removidos.")
	else:
		world.notice("Grampo removido. Ainda restam %d." % _bugs.size())

# ---------------------------------------------------------
# Batida
# ---------------------------------------------------------

## Chamado ao acordar: sorteia a batida segundo a suspeita.
func try_raid() -> void:
	if raid_active or GameManager.day_total - _last_raid_day < B.RAID_COOLDOWN_DAYS:
		return
	if GameManager.dirty_money < B.RAID_MIN_DIRTY or Campaign.escape_active:
		return
	var chance: float = clampf((GameManager.suspicion - B.RAID_MIN_SUSPICION) * B.RAID_CHANCE_SLOPE, 0.0, B.RAID_CHANCE_MAX)
	if randf() <= chance:
		start_raid()

func start_raid() -> void:
	raid_active = true
	raid_t = B.RAID_SECONDS
	_warn_t = 0.0
	_last_raid_day = GameManager.day_total
	world.hidden_cases = 0
	world.mark_dirty()
	world.notice("BATIDA NA PORTA! Guarde os malotes no cofre antes que entrem.")

func _tick_raid(delta: float) -> void:
	if GameManager.state != GameManager.GameState.WORK or PopupManager.is_open():
		return
	raid_t -= delta
	var on_red: bool = int(floor(_t * 4.0)) % 2 == 0
	_red.light_energy = 4.0 if on_red else 0.0
	_red2.light_energy = 3.0 if on_red else 0.0
	_blue.light_energy = 0.0 if on_red else 4.0
	_warn_t -= delta
	if _warn_t <= 0.0:
		_warn_t = 1.3
		AudioManager.play_warning()
	if world.cases_remaining() <= 0:
		_end_raid(true)
	elif raid_t <= 0.0:
		_end_raid(false)

func _end_raid(success: bool) -> void:
	raid_active = false
	_red.light_energy = 0.0
	_blue.light_energy = 0.0
	_red2.light_energy = 0.0
	world.hidden_cases = 0
	if success:
		GameManager.add_suspicion(B.RAID_WIN_SUSPICION)
		world.ui.toast("Os agentes revistaram e saíram de mãos vazias.", UI.GREEN)
	else:
		var seized: float = GameManager.dirty_money * B.RAID_SEIZE
		GameManager.dirty_money = maxf(0.0, GameManager.dirty_money - seized)
		GameManager.add_suspicion(B.RAID_FAIL_SUSPICION)
		world.ui.toast("A PF levou %s em dinheiro sujo e a suspeita subiu." % UI.money(seized), UI.RED)
	GameManager.touch()
	world.mark_dirty()
