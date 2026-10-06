extends SceneTree

var failures := 0

func _init() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("UI FAIL: ", message)

func layout(ui, parent: Node = null) -> void:
	for child in (parent if parent else ui.surface).get_children():
		if child is Label or child is Button:
			check(child.get_theme_font("font").get_font_name() == "Pixelify Sans", "all interface text uses the readable font: "+child.text)
			if child.has_meta("text_box"):
				check(child.get_theme_font_size("font_size") >= 10, "text never shrinks below the readable minimum: "+child.text)
		if child is Control and child.has_meta("text_box"):
			check(StoryStyle.text_within_box(child), "text remains inside its assigned box: "+child.text)
		layout(ui, child)

func audio() -> void:
	var sound = root.get_node("Sound")
	for cue in sound.COMBAT_CUES:
		var stream: AudioStreamWAV = sound.streams[cue]
		check(stream != null and stream.mix_rate == 22050 and stream.get_length() >= 0.08 and stream.data.size() > 300, "real combat audio loaded: "+cue)
	for id in GameCatalog.ARMY_IDS:
		var requests: Dictionary = sound.combat_requests([{"kind":"attack", "card_id":id}])
		check(requests.size() == 1 and sound.streams.has(requests.keys()[0]), "each army attack has an available sound: "+id)
	var burst: Array = []
	for index in range(144):
		burst.append({"kind":"hit", "absorbed":0.0})
	check(sound.combat_requests(burst).size() == 1, "crowded hit events are coalesced")
	check(sound.combat_requests([{"kind":"hit", "absorbed":5.0}]).has("shield_hit"), "shield absorption has its own sound")
	check(sound.combat_requests([{"kind":"defeat"}, {"kind":"heal"}, {"kind":"splash", "set_id":"earth"}]).size() == 3, "defeats, healing and siege impacts are audible events")

func _run() -> void:
	var ui = load("res://scenes/main.tscn").instantiate()
	root.add_child(ui)
	await create_timer(0.4).timeout
	audio()
	for symbol in ["→", "←", "·", "…"]:
		check(StoryStyle.TEXT_FONT.has_char(symbol.unicode_at(0)), "pixel font has an explicit fallback for interface symbols: "+symbol)
	layout(ui)
	check(ui.screen=="menu", "loading leads to menu")
	var arrow_label: Label = ui._label("2 → 4 units",Rect2(0,0,99,16),10)
	await process_frame
	check(StoryStyle.text_within_box(arrow_label),"reinforcement arrows fit without missing glyphs or growing the box")
	for realm in GameCatalog.REALMS:
		ui._compendium_tab(realm)
		check(ui.screen=="compendium" and ui.compendium_realm==realm, "each realm's compendium opens")
		layout(ui)
	ui.settings_return = "menu"
	ui.show_settings()
	check(ui.screen=="settings", "settings open")
	layout(ui)
	ui.show_commander()
	for id in GameCatalog.COMMANDER_IDS:
		ui._select_commander(id)
		check(ui.selected_commander_id==id, "all three commanders can be selected")
		layout(ui)
	ui.show_warband()
	layout(ui)
	ui._preset("clear")
	ui.new_match()
	check(ui.screen=="warband" and ui.state==null, "incomplete loadout cannot start")
	for id in ["water_mage","water_melee","earth_tank","earth_siege"]:
		ui._toggle_card(id)
	ui._toggle_card("fire_tank")
	check(ui.selected_warband.size()==4 and not ui.selected_warband.has("fire_tank"), "builder prevents a fifth card")
	ui._toggle_card("water_mage")
	check(ui.selected_warband.size()==3, "selected card can be removed")
	ui._toggle_card("water_mage")
	ui.rival_realm="water"
	ui.new_match()
	check(ui.state.bond==null and ui.state.commander.id=="earth_commander", "mixed cards work under independent commander")
	check(ui.state.commander_for(1).id=="water_commander" and ui.state.warband_for(1)==GameCatalog.WATER_IDS, "rival selector supplies independent opposing realm")
	check(ui.screen=="battle" and ui.offer_buttons.size()==3, "three draft offers rendered")
	layout(ui)
	check(ui.battlefield.position == Vector2(20,64) and CombatSimulation.ARENA_SIZE == Vector2(600,202), "compact HUD leaves a larger battlefield")
	check(ui.offer_buttons[0].size.y == 64 and ui.spell_button.size.y <= 36 and ui.battle_button.size.y <= 22, "battle controls retain their compact sizes")
	var before: String = JSON.stringify(ui.state.sides[0].offers)
	ui.prepare_spell()
	check(ui.state.sides[0].points==2 and ui.state.sides[0].spell, "spell UI spends one point")
	check(before==JSON.stringify(ui.state.sides[0].offers), "spell UI preserves offer objects")
	ui._pick(0)
	ui._pick(0)
	check(ui.state.total_units(0)>0, "UI summons real persistent armies")
	ui.begin_battle()
	check(ui.simulation!=null and ui.state.phase=="combat", "UI launches real combat")
	check(ui.battlefield.preview_units.size() == ui.simulation.units.size(), "all preview creatures are present at combat start")
	for index in range(ui.simulation.units.size()):
		check(ui.battlefield.preview_units[index].position == ui.simulation.units[index].position, "preview and real spawn positions match")
	# Resolve the same simulation synchronously, then invoke its result flow.
	while not ui.simulation.finished and ui.simulation.tick<4500:
		ui.simulation.step()
	ui._round_over()
	check(ui.modal_kind=="round_result", "round result dialog opens")
	layout(ui)
	ui.next_round()
	check(ui.state.round_number==2 and ui.state.phase=="command", "next round resumes command phase")
	ui.state.sides[1].hearts=1
	ui.state.phase="combat"
	ui.simulation = CombatSimulation.new(ui.state)
	ui.simulation.result={"winner":0,"seconds":1.0,"reason":"UI fixture","survivors":[1,0]}
	ui._round_over()
	check(ui.screen=="results" and ui.state.winner==0, "victory opens results screen")
	layout(ui)
	ui.new_match()
	check(ui.state.round_number==1 and ui.state.sides[0].hearts==4, "Rematch starts a fresh match")
	ui.state.sides[0].hearts=1
	ui.state.phase="combat"
	ui.simulation = CombatSimulation.new(ui.state)
	ui.simulation.result={"winner":1,"seconds":1.0,"reason":"UI fixture","survivors":[0,1]}
	ui._round_over()
	check(ui.screen=="results" and ui.state.winner==1 and ui.state.sides[0].hearts==0, "defeat opens results at zero player Hearts")
	ui.new_match()
	check(ui.state.sides[0].hearts==4 and ui.state.sides[1].hearts==4, "Rematch resets a defeated match")
	ui.free()
	await process_frame
	await process_frame
	print("UI smoke: %d failures" % failures)
	quit.call_deferred(0 if failures==0 else 1)
