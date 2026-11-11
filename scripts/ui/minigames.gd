extends Control
## Minigames de tensão. Cada um dura uns 20 segundos e devolve um desempenho de
## 0 a 1 em finished(score). Score negativo = o jogador desistiu (ESC).
##
##   "hack"   Invasão. Repita as sequências de setas (ou WASD) antes do tempo
##            acabar. Três rodadas, cada vez mais longas.
##   "shred"  Triturador. Aperte ESPAÇO quando o marcador estiver na zona
##            verde. Quatro rodadas, zona cada vez menor.
##
## Quem recompensa o jogador é o world_3d.gd; aqui só mora a jogabilidade.

signal finished(score: float)

const KEYS: Array = [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]
const ALT_KEYS: Dictionary = {KEY_W: 0, KEY_S: 1, KEY_A: 2, KEY_D: 3}
const ARROWS: Array = ["↑", "↓", "←", "→"]
const HACK_LENGTHS: Array = [4, 5, 7]
const HACK_TIMES: Array = [6.0, 6.5, 8.0]
const SHRED_ZONES: Array = [150.0, 120.0, 92.0, 66.0]
const BAR_W: float = 560.0

var kind: String = "hack"

var _panel: Panel
var _title: Label
var _sub: Label
var _status: Label
var _round: int = 0
var _closing: bool = false
var _waiting: bool = false
var _scores: Array = []
var _accent: Color = UI.CYAN

var _seq: Array = []
var _idx: int = 0
var _time: float = 0.0
var _time_max: float = 1.0
var _seq_labels: Array = []
var _bar_fill: ColorRect

var _marker: float = 0.0
var _dir: float = 1.0
var _zone_x: float = 0.0
var _zone_w: float = 100.0
var _hits: int = 0
var _marker_rect: ColorRect
var _zone_rect: ColorRect
var _pips: Array = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 100
	_accent = UI.CYAN if kind == "hack" else UI.ORANGE
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.02, 0.05, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var view: Vector2 = get_viewport_rect().size
	var size_v: Vector2 = Vector2(700, 340)
	_panel = Panel.new()
	_panel.position = (view - size_v) * 0.5
	_panel.size = size_v
	_panel.add_theme_stylebox_override("panel", UI.flat(Color("#161412"), _accent, 10))
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	_title = UI.display("INVASÃO  ·  APAGAR RASTROS" if kind == "hack" else "TRITURADOR  ·  QUEIMAR ARQUIVOS", 26, _accent)
	_title.position = Vector2(70, 18)
	_panel.add_child(_title)
	_sub = UI.label("Repita as setas na ordem. Errar custa tempo." if kind == "hack" else "ESPAÇO quando o marcador estiver na zona verde.", 14, UI.INK_2)
	_sub.position = Vector2(70, 58)
	_panel.add_child(_sub)
	_status = UI.caps("", UI.MUTED, 12)
	_status.position = Vector2(70, 296)
	_panel.add_child(_status)
	var hint: Label = UI.caps("ESC DESISTE", UI.DIM, 11)
	hint.position = Vector2(size_v.x - 150.0, 296)
	_panel.add_child(hint)
	for i: int in range(3 if kind == "hack" else 4):
		var pip: ColorRect = ColorRect.new()
		pip.position = Vector2(70.0 + float(i) * 34.0, 98)
		pip.size = Vector2(26, 5)
		pip.color = UI.TRACK
		_panel.add_child(pip)
		_pips.append(pip)
	_start_round()

# ---------------------------------------------------------
# Rodadas
# ---------------------------------------------------------

func _start_round() -> void:
	_waiting = false
	if kind == "hack":
		_start_hack_round()
	else:
		_start_shred_round()

func _start_hack_round() -> void:
	for node_v: Variant in _seq_labels:
		(node_v as Node).queue_free()
	_seq_labels.clear()
	var length: int = int(HACK_LENGTHS[_round])
	_seq.clear()
	for i: int in range(length):
		_seq.append(randi() % 4)
	_idx = 0
	_time_max = float(HACK_TIMES[_round])
	_time = _time_max
	var gap: float = 64.0
	var start_x: float = (_panel.size.x - gap * float(length)) * 0.5 + 8.0
	for i: int in range(length):
		var cell: Label = UI.display(str(ARROWS[int(_seq[i])]), 54, UI.MUTED)
		cell.position = Vector2(start_x + float(i) * gap, 130)
		_panel.add_child(cell)
		_seq_labels.append(cell)
	if _bar_fill == null:
		var track: ColorRect = ColorRect.new()
		track.position = Vector2(70, 250)
		track.size = Vector2(BAR_W, 8)
		track.color = UI.TRACK
		_panel.add_child(track)
		_bar_fill = ColorRect.new()
		_bar_fill.position = Vector2(70, 250)
		_bar_fill.size = Vector2(BAR_W, 8)
		_bar_fill.color = _accent
		_panel.add_child(_bar_fill)
	_highlight()
	_status.text = "RODADA %d DE 3" % (_round + 1)

func _highlight() -> void:
	for i: int in range(_seq_labels.size()):
		var cell: Label = _seq_labels[i]
		var color: Color = UI.GREEN if i < _idx else (UI.WHITE if i == _idx else UI.MUTED)
		cell.add_theme_color_override("font_color", color)

func _start_shred_round() -> void:
	if _zone_rect == null:
		var track: ColorRect = ColorRect.new()
		track.position = Vector2(70, 170)
		track.size = Vector2(BAR_W, 40)
		track.color = UI.TRACK
		_panel.add_child(track)
		_zone_rect = ColorRect.new()
		_zone_rect.position = Vector2(70, 170)
		_zone_rect.size = Vector2(100, 40)
		_zone_rect.color = Color(UI.GREEN, 0.55)
		_panel.add_child(_zone_rect)
		_marker_rect = ColorRect.new()
		_marker_rect.position = Vector2(70, 160)
		_marker_rect.size = Vector2(6, 60)
		_marker_rect.color = UI.WHITE
		_panel.add_child(_marker_rect)
	_zone_w = float(SHRED_ZONES[_round])
	_zone_x = randf_range(40.0, BAR_W - _zone_w - 40.0)
	_zone_rect.position.x = 70.0 + _zone_x
	_zone_rect.size.x = _zone_w
	_marker = 0.0
	_dir = 1.0
	_status.text = "RODADA %d DE 4   ·   ACERTOS %d" % [_round + 1, _hits]

func _process(delta: float) -> void:
	if _closing or _waiting:
		return
	if kind == "hack":
		_time -= delta
		_bar_fill.size.x = BAR_W * clampf(_time / _time_max, 0.0, 1.0)
		_bar_fill.color = _accent if _time > _time_max * 0.3 else UI.RED
		if _time <= 0.0:
			_end_round(false)
	else:
		_marker += _dir * (430.0 + 130.0 * float(_round)) * delta
		if _marker >= BAR_W:
			_marker = BAR_W
			_dir = -1.0
		elif _marker <= 0.0:
			_marker = 0.0
			_dir = 1.0
		_marker_rect.position.x = 70.0 + _marker - 3.0

func _input(event: InputEvent) -> void:
	if _closing:
		return
	var key: InputEventKey = event as InputEventKey
	var click: InputEventMouseButton = event as InputEventMouseButton
	if key == null and click == null:
		return
	get_viewport().set_input_as_handled()
	if _waiting:
		return
	if key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		_finish(-1.0)
		return
	if kind == "hack":
		if key == null or not key.pressed or key.echo:
			return
		var which: int = KEYS.find(key.keycode)
		if which < 0 and ALT_KEYS.has(key.keycode):
			which = int(ALT_KEYS[key.keycode])
		if which < 0:
			return
		if which == int(_seq[_idx]):
			AudioManager.play_click()
			_idx += 1
			_highlight()
			if _idx >= _seq.size():
				_end_round(true)
		else:
			AudioManager.play_warning()
			_time = maxf(0.0, _time - 0.8)
			(_seq_labels[_idx] as Label).add_theme_color_override("font_color", UI.RED)
	else:
		var pressed: bool = (key != null and key.pressed and not key.echo and (key.keycode == KEY_SPACE or key.keycode == KEY_ENTER)) or (click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT)
		if not pressed:
			return
		var hit: bool = _marker >= _zone_x and _marker <= _zone_x + _zone_w
		_end_round(hit)

func _end_round(success: bool) -> void:
	_waiting = true
	if kind == "hack":
		var frac: float = clampf(_time / _time_max, 0.0, 1.0)
		_scores.append(0.6 + 0.4 * frac if success else 0.0)
	else:
		_scores.append(1.0 if success else 0.0)
		if success:
			_hits += 1
	(_pips[_round] as ColorRect).color = UI.GREEN if success else UI.RED
	if success:
		AudioManager.play_confirm()
	else:
		AudioManager.play_warning()
	_round += 1
	var total: int = 3 if kind == "hack" else 4
	await get_tree().create_timer(0.55).timeout
	if _closing:
		return
	if _round >= total or (kind == "hack" and not success):
		_show_result()
	else:
		_start_round()

func _show_result() -> void:
	var total: float = 3.0 if kind == "hack" else 4.0
	var sum: float = 0.0
	for s_v: Variant in _scores:
		sum += float(s_v)
	var score: float = clampf(sum / total, 0.0, 1.0)
	_waiting = true
	if kind == "hack":
		_status.text = ("ACESSO CONCEDIDO  ·  RASTROS APAGADOS %d%%" % int(score * 100.0)) if score > 0.0 else "ACESSO NEGADO  ·  NADA APAGADO"
	else:
		_status.text = "%d DE 4 ARQUIVOS DESTRUÍDOS" % _hits
	_status.add_theme_color_override("font_color", UI.GREEN if score > 0.0 else UI.RED)
	await get_tree().create_timer(1.4).timeout
	_finish(score)

func _finish(score: float) -> void:
	if _closing:
		return
	_closing = true
	finished.emit(score)
	queue_free()
