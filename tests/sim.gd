extends Node
# Bot que joga a campanha inteira sem interface, para calibrar o balanceamento
# e o ritmo. Para cada estilo de jogador, mede: em que turno cada ato termina,
# os finais, quantos acontecimentos por turno, quantas noites sem nenhuma
# decisão (e a maior sequência delas), objetivos e contratos cumpridos.
#
#   RUNS=30 STYLES=sensato,ruim VERBOSE=1 TRACE=1  (variáveis de ambiente)
const B = preload("res://scripts/data/balance.gd")
const Bot = preload("res://tests/bot.gd")
const Keep = preload("res://tests/keep.gd")

var style: String = "sensato"
var verbose: bool = false

func _ready() -> void:
	var backup: Dictionary = Keep.take()
	var runs: int = int(OS.get_environment("RUNS")) if OS.get_environment("RUNS") != "" else 20
	verbose = OS.get_environment("VERBOSE") == "1"
	var styles: PackedStringArray = OS.get_environment("STYLES").split(",") if OS.get_environment("STYLES") != "" else PackedStringArray(Bot.STYLES)
	print("estilo        | finais                                   | ato1  ato2  ato3 (turnos) | turnos | eventos/turno | noites sem decisão | maior seq. | objetivos | contratos ok/falha")
	for s: String in styles:
		style = s
		var endings: Dictionary = {}
		var act_days: Array = [[], [], []]
		var reached: Array = [0, 0, 0]
		var totals: Dictionary = {"turns": 0.0, "events": 0.0, "quiet": 0.0, "nights": 0.0, "objectives": 0.0, "slots": 0.0, "c_ok": 0.0, "c_fail": 0.0, "max_quiet": 0}
		for run: int in range(runs):
			GameManager.rng.seed = (int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 1000) + run
			var r: Dictionary = _play()
			endings[r["ending"]] = int(endings.get(r["ending"], 0)) + 1
			for a: int in range(3):
				if int(r["act_days"][a]) > 0:
					act_days[a].append(r["act_days"][a])
					reached[a] += 1
			for key: String in ["turns", "events", "quiet", "nights", "objectives", "slots", "c_ok", "c_fail"]:
				totals[key] = float(totals[key]) + float(r[key])
			totals["max_quiet"] = maxi(int(totals["max_quiet"]), int(r["max_quiet"]))
			if verbose:
				print("   run %d -> %s | atos %s | turnos %d | %s" % [run, r["ending"], str(r["act_days"]), r["turns"], r["reason"]])
		var acts: String = ""
		for a: int in range(3):
			acts += "%4s%s " % [_avg(act_days[a]), "" if reached[a] == runs else "*"]
		print("%-13s | %-40s | %-25s | %6.1f | %13.2f | %17.0f%% | %10d | %9.0f%% | %.1f / %.1f" % [style, _endings(endings), acts,
			float(totals["turns"]) / runs, float(totals["events"]) / maxf(1.0, float(totals["nights"])),
			100.0 * float(totals["quiet"]) / maxf(1.0, float(totals["nights"])), int(totals["max_quiet"]),
			100.0 * float(totals["objectives"]) / maxf(1.0, float(totals["slots"])), float(totals["c_ok"]) / runs, float(totals["c_fail"]) / runs])
		for a: int in range(3):
			if reached[a] < runs:
				print("      ato %d batido em %d de %d partidas (* na tabela)" % [a + 1, reached[a], runs])
	print("prazos: ato 1 = %d, ato 2 = %d, ato 3 = %d turnos" % [int(B.ACTS[0]["days"]), int(B.ACTS[1]["days"]), int(B.ACTS[2]["days"])])
	Keep.give(backup)
	get_tree().quit()

func _endings(endings: Dictionary) -> String:
	var parts: Array[String] = []
	for key: String in B.ENDING_ORDER:
		if endings.has(key):
			parts.append("%s %d" % [key, int(endings[key])])
	for key: String in endings:
		if not B.ENDINGS.has(key):
			parts.append("%s %d" % [key, int(endings[key])])
	return ", ".join(parts)

func _avg(a: Array) -> String:
	if a.is_empty():
		return "-"
	var t: float = 0.0
	for v: Variant in a:
		t += float(v)
	return "%.1f" % (t / a.size())

func _play() -> Dictionary:
	GameManager.new_game()
	GameManager.begin_work()
	var act_days: Array = [0, 0, 0]
	var guard: int = 0
	var quiet: int = 0
	var max_quiet: int = 0
	var quiet_nights: int = 0
	var nights: int = 0
	var objectives: int = 0
	var slots: int = 0
	var last_act: int = 1
	var popups: int = 0
	while Campaign.ending == "" and guard < 200:
		guard += 1
		if Campaign.escape_active:
			Bot.escape(style)
			break
		Bot.day(style)
		var act_before: int = Campaign.act
		var day_before: int = GameManager.current_day
		var done_before: int = Missions.objectives_done()
		var slots_before: int = Missions.objectives.size()
		GameManager.end_day()
		nights += 1
		popups += Campaign.events.size()
		# Uma noite "vazia" é a que não trouxe nenhuma decisão para o jogador.
		if Campaign.events.is_empty():
			quiet += 1
			quiet_nights += 1
			max_quiet = maxi(max_quiet, quiet)
		else:
			quiet = 0
		GameManager.begin_day()
		Bot.events(style)
		if Campaign.act != act_before or (Campaign.escape_active and Campaign.escape_reason == "meta") or Campaign.ending == "politico":
			act_days[act_before - 1] = day_before
			objectives += done_before
			slots += slots_before
		last_act = Campaign.act
		if verbose and OS.get_environment("TRACE") == "1":
			print("      A%d T%02d  sujo %s limpo %s patr %s susp %.1f  laranjas %d  obj %d/%d" % [Campaign.act, GameManager.current_day, GameManager.format_money(GameManager.dirty_money), GameManager.format_money(GameManager.clean_money), GameManager.format_money(GameManager.net_worth()), GameManager.suspicion, Staff.roster.size(), Missions.objectives_done(), Missions.objectives.size()])
	if Campaign.ending != "" and last_act >= 1 and act_days[last_act - 1] == 0:
		objectives += Missions.objectives_done()
		slots += Missions.objectives.size()
	var c_ok: int = 0
	var c_fail: int = 0
	for c_v: Variant in Missions.contracts:
		match str((c_v as Dictionary)["state"]):
			"done": c_ok += 1
			"failed": c_fail += 1
	return {"ending": Campaign.ending if Campaign.ending != "" else "timeout", "reason": Campaign.ending_reason, "act_days": act_days,
		"turns": GameManager.day_total, "events": popups,
		"nights": nights, "quiet": quiet_nights, "max_quiet": max_quiet, "objectives": objectives, "slots": slots, "c_ok": c_ok, "c_fail": c_fail}
