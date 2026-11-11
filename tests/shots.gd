extends Node
# Percorre as telas e salva um PNG de cada uma em tests/out/.
const B = preload("res://scripts/data/balance.gd")
const Audit = preload("res://tests/audit.gd")
const Keep = preload("res://tests/keep.gd")
var m: Control
var only: String = OS.get_environment("ONLY")

func _ready() -> void:
	var backup: Dictionary = Keep.take()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/out"))
	m = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(m)
	GameManager.rng.seed = 42
	await _wait(0.4)
	await _shot("01_menu", 1.2)
	m.show_tutorial(0); await _shot("02_manual_1", 0.9)
	m.show_tutorial(3); await _shot("03_manual_4", 0.7)
	m._start_new_game(); await _wait(0.2)
	m._begin_campaign(); await _shot("04_ato1_intro", 1.4)
	m.show_dashboard("overview"); await _shot("05_overview_vazio", 1.4)
	m.switch_tab("companies"); await _shot("06_empresas", 1.2)
	m.content._open_operation("lavanderia"); await _shot("07_modal_operar", 0.6)
	m.close_modal(true)
	GameManager.process_company("lavanderia", 18000.0)
	GameManager.process_company("bar", 20000.0)
	m.switch_tab("staff"); await _shot("08_laranjas_vazio", 1.0)
	m.content._open_hire(int(Staff.candidates[0]["id"])); await _shot("09_modal_contratar", 0.6)
	m.close_modal(true)
	Staff.hire(int(Staff.candidates[0]["id"]), "bar")
	Staff.hire(int(Staff.candidates[0]["id"]), "lavanderia")
	# alguns dias de jogo para gerar historico
	for d: int in range(6):
		for id: String in GameManager.owned_ids():
			GameManager.process_company(id, minf(GameManager.remaining_capacity(id), GameManager.dirty_money))
		GameManager.end_day(); Campaign.take_events(); GameManager.begin_day(); m._snapshot()
		Staff.ensure_candidates()
		for id: String in GameManager.owned_ids():
			if Staff.slots_free(id) > 0 and not Staff.candidates.is_empty():
				Staff.hire(int(Staff.candidates[0]["id"]), id)
	GameManager.clean_money += 900000.0
	GameManager.total_clean_generated += 900000.0
	Lifestyle.buy("relogio"); Lifestyle.buy("seda"); Lifestyle.buy("gravura")
	GameManager.process_company("bar", 20000.0)
	m.switch_tab("overview"); await _shot("10_overview", 1.6)
	Missions.make_offer()
	var accepted: Dictionary = Missions.make_offer()
	Missions.accept_contract(int(accepted["uid"]))
	m.switch_tab("missions"); await _shot("10b_missoes", 1.4)
	m.switch_tab("staff"); await _shot("11_laranjas", 1.2)
	m.content._open_member(int(Staff.roster[0]["id"])); await _shot("12_modal_laranja", 0.6)
	m.close_modal(true)
	m.switch_tab("lifestyle"); await _shot("13_bens", 1.3)
	m.content._open_declare(); await _shot("14_modal_declarar", 0.6)
	m.close_modal(true)
	Portfolio.buy_crypto(120000.0)
	m.switch_tab("wallet"); await _shot("15_carteira", 1.2)
	m.switch_tab("transactions"); await _shot("16_transacoes", 1.0)
	GameManager.apply_news(B.NEWS[1]); GameManager.apply_news(B.NEWS[2]); GameManager.wiretap_days = 4
	m.switch_tab("news"); await _shot("17_noticias", 1.0)
	m.switch_tab("risk"); await _shot("18_risco", 1.4)
	m.show_help("staff"); await _shot("19_ajuda", 0.6)
	m.close_modal(true)
	# popups
	PopupManager.show_event(Campaign._threat_event("fiscalizacao")); await _shot("20_popup_fiscalizacao", 0.6)
	PopupManager.clear_popup()
	PopupManager.show_event({"style": "news", "kicker": "BREAKING NEWS / URGENTE", "source": "CLEAN SLATE / NEWSWIRE", "title": str(B.NEWS[0]["title"]), "body": str(B.NEWS[0]["body"]), "impact": str(B.NEWS[0]["effect"]), "options": []}); await _shot("21_popup_noticia", 0.6)
	PopupManager.clear_popup()
	var victim: Dictionary = Staff.roster[0]
	victim["stress"] = 100.0; victim["delation"] = 2
	PopupManager.show_event(Staff._delation_event(victim)); await _shot("22_popup_delacao", 0.6)
	PopupManager.clear_popup()
	m.switch_tab("staff"); await _shot("23_laranjas_delacao", 1.0)
	Lifestyle.audits = 1
	PopupManager.show_event(Lifestyle._audit_event()); await _shot("24_popup_malha_fina", 0.6)
	PopupManager.clear_popup()
	Staff.resolve_delation(int(victim["id"]), "silence_dirty")
	PopupManager.show_event(Director._ev_investidor()); await _shot("25_popup_investidor", 0.6)
	PopupManager.clear_popup()
	PopupManager.show_event(Director._contract_popup(Missions.make_offer())); await _shot("26_popup_contrato", 0.6)
	PopupManager.clear_popup()
	PopupManager.show_event(Director._ev_concentracao("bar")); await _shot("27_popup_concentracao", 0.6)
	PopupManager.clear_popup()
	# troca de turno: quadros em varios momentos
	m.switch_tab("overview")
	GameManager.process_company("bar", 5000.0)
	m.end_turn()
	var last: float = 0.0
	for tt: float in [0.3, 0.9, 1.5, 2.2, 2.9, 3.6]:
		await _wait(tt - last); last = tt
		await _snap("30_turno_%.2f" % tt)
	await _wait(2.4)
	await _snap("30_turno_relatorio")
	var guard: int = 0
	while TurnManager.running and guard < 20:
		guard += 1
		for child: Node in m.get_children():
			if child.has_method("is_holding"):
				child.call("skip")
		await _wait(0.3)
	await _wait(1.5)
	await _snap("31_popup_da_noite")
	var popups: int = 0
	while (PopupManager.is_open() or m._flow_busy) and popups < 12:
		popups += 1
		PopupManager.clear_popup()
		await _wait(0.3)
	await _shot("31_depois_do_turno", 1.2)
	# ato 2
	GameManager.clean_money += 3000000.0
	Campaign._start_act(2); m.show_act_intro(); await _shot("40_ato2_intro", 1.5)
	GameManager.influence = 3
	m.show_dashboard("companies"); await _shot("41_empresas_ato2", 1.2)
	m.switch_tab("risk"); await _shot("42_risco_ato2", 1.2)
	PopupManager.show_event(Campaign._immunity_event()); await _shot("43_popup_imunidade", 0.6)
	PopupManager.clear_popup()
	# fuga
	Campaign._start_act(3); GameManager.clean_money += 40000000.0; GameManager.buy_company("boate")
	Campaign.goals_hit = 3
	Campaign.start_escape("meta"); m.show_escape_intro(); await _shot("50_fuga_intro", 1.4)
	m.show_dashboard("darkweb"); await _shot("51_darkweb", 1.3)
	Campaign.buy_passport("bom"); Campaign.buy_jet("executivo"); Portfolio.convert_to_monero()
	await _shot("52_darkweb_pronto", 0.9)
	m.switch_tab("overview"); await _shot("53_overview_fuga", 1.0)
	# finais
	for pair: Array in [["takeoff", [0.8, 2.3, 3.6, 5.6]], ["runway", [3.3, 4.6, 5.6]], ["arrest", [1.0, 2.0, 3.8, 5.6]], ["cartel", [1.0, 2.2, 3.0, 4.6]], ["congress", [0.8, 3.0]]]:
		var scene: Control = TurnManager.EndingScene.new()
		scene.set("kind", pair[0]); m.add_child(scene)
		last = 0.0
		for tt: float in pair[1]:
			await _wait(tt - last); last = tt
			await _snap("60_final_%s_%.1f" % [pair[0], tt])
		scene.queue_free()
	Campaign.escape_result = {"success": true, "flew": true, "chance": 23.0, "monero": Portfolio.monero}
	Campaign.trigger_ending("rei", "Três metas batidas, nenhum mandado.")
	await _wait(7.5)
	await _shot("70_tela_final", 1.4)
	Keep.give(backup)
	print("SHOTS: fim")
	get_tree().quit()

func _wait(s: float) -> void:
	await get_tree().create_timer(maxf(s, 0.01)).timeout

func _shot(label: String, settle: float) -> void:
	await _wait(settle)
	for issue: String in Audit.run(get_tree().root):
		print("   LAYOUT [", label, "] ", issue)
	await _snap(label)

func _snap(label: String) -> void:
	print("SHOT ", label)
	if only != "" and not label.contains(only):
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/out/%s.png" % label)
