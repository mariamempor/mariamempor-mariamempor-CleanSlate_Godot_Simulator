extends Node
## Som do apartamento: chuva no vidro, cidade, tensão que cresce com a
## suspeita, coração no limite, helicóptero e passos. Respeita o volume e o
## mudo das Configurações (AudioManager).

const Synth = preload("res://scripts/world/synth.gd")

var world
var rain_p: AudioStreamPlayer
var city_p: AudioStreamPlayer
var drone_p: AudioStreamPlayer
var heart_p: AudioStreamPlayer
var heli_p: AudioStreamPlayer
var step_p: AudioStreamPlayer
var _levels: Dictionary = {}

func _ready() -> void:
	rain_p = _loop(Synth.rain())
	city_p = _loop(Synth.city())
	drone_p = _loop(Synth.drone())
	heart_p = _loop(Synth.heartbeat())
	heli_p = _loop(Synth.helicopter())
	step_p = AudioStreamPlayer.new()
	step_p.stream = Synth.step()
	add_child(step_p)

func _loop(stream: AudioStreamWAV) -> AudioStreamPlayer:
	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = -80.0
	add_child(p)
	p.play()
	_levels[p] = 0.0
	return p

## Volume alvo de cada camada (0 a 1); a mistura anda devagar até ele.
func _mix(p: AudioStreamPlayer, target: float, delta: float, speed: float = 0.6) -> void:
	var level: float = move_toward(float(_levels[p]), target, delta * speed)
	_levels[p] = level
	var master: float = 0.0 if AudioManager.muted else AudioManager.master_volume
	p.volume_db = linear_to_db(maxf(0.0001, level * master))

func _process(delta: float) -> void:
	if world == null:
		return
	var apt = world.apartment
	var indoor: bool = str(world.get("_area")) == "room"
	var playing: bool = GameManager.state == GameManager.GameState.WORK or GameManager.state == GameManager.GameState.DAY_TRANSITION
	var susp: float = GameManager.suspicion
	_mix(rain_p, float(apt.rain) * (0.30 if indoor else 0.55), delta)
	_mix(city_p, 0.22 if indoor else 0.5, delta)
	var tension: float = clampf((susp - 45.0) / 45.0, 0.0, 1.0) if playing else 0.0
	_mix(drone_p, tension * 0.45, delta, 0.25)
	var critical: bool = playing and susp >= 85.0
	_mix(heart_p, 0.5 if critical else 0.0, delta, 0.5)
	var heli: float = float(apt.heli_level) * (0.35 if indoor else 0.6)
	_mix(heli_p, heli, delta, 0.4)

## Passo: pitch e volume variam um pouco para não soar como metrônomo.
func footstep(run: bool) -> void:
	if AudioManager.muted:
		return
	step_p.pitch_scale = randf_range(0.85, 1.15) * (1.08 if run else 1.0)
	step_p.volume_db = linear_to_db(maxf(0.0001, AudioManager.master_volume * randf_range(0.18, 0.26)))
	step_p.play()
