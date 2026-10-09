extends Node

var click_player: AudioStreamPlayer
var hover_player: AudioStreamPlayer
var confirm_player: AudioStreamPlayer
var warning_player: AudioStreamPlayer
var transition_player: AudioStreamPlayer
var ambient_player: AudioStreamPlayer

var muted: bool = false
var master_volume: float = 0.7

func _ready() -> void:
	click_player = _make_player("click.wav")
	hover_player = _make_player("hover.wav")
	confirm_player = _make_player("confirm.wav")
	warning_player = _make_player("warning.wav")
	transition_player = _make_player("transition.wav")
	ambient_player = _make_player("ambient.wav")

func _make_player(file_name: String) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	var stream: AudioStream = load("res://assets/audio/%s" % file_name) as AudioStream
	if stream != null:
		player.stream = stream
	add_child(player)
	return player

func set_volume(value: float) -> void:
	master_volume = clamp(value, 0.0, 1.0)
	for child: Node in get_children():
		var player: AudioStreamPlayer = child as AudioStreamPlayer
		if player != null:
			player.volume_db = linear_to_db(max(0.001, master_volume))

func set_muted(value: bool) -> void:
	muted = value
	var db: float = -80.0 if muted else linear_to_db(max(0.001, master_volume))
	for child: Node in get_children():
		var player: AudioStreamPlayer = child as AudioStreamPlayer
		if player != null:
			player.volume_db = db

func _play(player: AudioStreamPlayer, volume_scale: float = 1.0) -> void:
	if muted or player == null or player.stream == null:
		return
	player.volume_db = linear_to_db(max(0.001, master_volume * volume_scale))
	player.play()

func play_click() -> void:
	_play(click_player, 0.75)

func play_hover() -> void:
	_play(hover_player, 0.35)

func play_confirm() -> void:
	_play(confirm_player, 0.8)

func play_warning() -> void:
	_play(warning_player, 0.85)

func play_transition() -> void:
	_play(transition_player, 0.9)

func play_ambient() -> void:
	if muted or ambient_player == null or ambient_player.stream == null:
		return
	if not ambient_player.playing:
		ambient_player.volume_db = linear_to_db(max(0.001, master_volume * 0.22))
		ambient_player.play()
