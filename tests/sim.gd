extends Node
# Bot que joga a campanha inteira sem interface, para calibrar o balanceamento.
const B = preload("res://scripts/data/balance.gd")
const Bot = preload("res://tests/bot.gd")
const Keep = preload("res://tests/keep.gd")

var style: String = "sensato"   # sensato | agressivo | cauteloso
var verbose: bool = false

func _ready() -> void:
	var backup: Dictionary = Keep.take()
	var runs: int = int(OS.get_environment("RUNS")) if OS.get_environment("RUNS") != "" else 20
	verbose = OS.get_environment("VERBOSE") == "1"
	for s: String in (OS.get_environment("STYLES").split(",") if OS.get_environment("STYLES") != "" else PackedStringArray(["sensato", "agressivo", "cauteloso"])):
		style = s
		var endings: Dictionary = {}
		var act_days: Array = [[], [], []]
		var monero: Array = []
		var reached: Array = [0, 0, 0]
		for run: int in range(runs):
			GameManager.rng.seed = 1000 + run
			var r: Dictionary = _play()
			endings[r["ending"]] = int(endings.get(r["ending"], 0)) + 1
			for a: int in range(3):
				if r["act_days"][a] > 0:
					act_days[a].append(r["act_days"][a])
					reached[a] += 1
			if r["ending"] in ["rei", "foragido"]:
				monero.append(r["monero"])
			if verbose:
				print("   run %d -> %s | atos %s | dia total %d | %s" % [run, r["ending"], str(r["act_days"]), r["days"], r["reason"]])
		print("== %s (%d partidas) ==" % [style, runs])
		print("   finais: ", endings)
		for a: int in range(3):
			print("   ato %d batido em %d/%d partidas, media dia %s (prazo %d)" % [a + 1, reached[a], runs, _avg(act_days[a]), int(B.ACTS[a]["days"])])
		print("   monero medio na fuga: ", GameManager.format_money(float(_avg_f(monero))))
	Keep.give(backup)
	get_tree().quit()

func _avg(a: Array) -> String:
	if a.is_empty():
		return "-"
	var t: float = 0.0
	for v: Variant in a:
		t += float(v)
	return "%.1f" % (t / a.size())

func _avg_f(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var t: float = 0.0
	for v: Variant in a:
		t += float(v)
	return t / a.size()

func _play() -> Dictionary:
	GameManager.new_game()
	GameManager.begin_work()
	var act_days: Array = [0, 0, 0]
	var last_act: int = 1
	var guard: int = 0
	while Campaign.ending == "" and guard < 400:
		guard += 1
		if Campaign.escape_active:
			Bot.escape()
			break
		Bot.day(style)
		var act_before: int = Campaign.act
		var day_before: int = GameManager.current_day
		GameManager.end_day()
		Bot.events()
		GameManager.begin_day()
		if Campaign.act != act_before or (Campaign.escape_active and Campaign.escape_reason == "meta"):
			act_days[act_before - 1] = day_before
		last_act = Campaign.act
		if verbose and OS.get_environment("TRACE") == "1":
			print("      A%d D%02d  sujo %s limpo %s patr %s susp %.1f  laranjas %d" % [Campaign.act, GameManager.current_day, GameManager.format_money(GameManager.dirty_money), GameManager.format_money(GameManager.clean_money), GameManager.format_money(GameManager.net_worth()), GameManager.suspicion, Staff.roster.size()])
	return {"ending": Campaign.ending if Campaign.ending != "" else "timeout", "reason": Campaign.ending_reason, "act_days": act_days, "days": GameManager.day_total, "monero": Portfolio.monero}

