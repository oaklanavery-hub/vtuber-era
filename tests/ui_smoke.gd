extends SceneTree

var failures := 0

func _init() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("UI FAIL: ", message)

func _run() -> void:
	var ui = load("res://scenes/main.tscn").instantiate()
	root.add_child(ui)
	await create_timer(0.4).timeout
	check(ui.screen=="menu", "loading leads to menu")
	ui.show_compendium()
	check(ui.screen=="compendium", "compendium opens")
	ui.settings_return = "menu"
	ui.show_settings()
	check(ui.screen=="settings", "settings open")
	ui.show_commander()
	ui.show_warband()
	ui.new_match()
	check(ui.screen=="battle" and ui.offer_buttons.size()==3, "three draft offers rendered")
	var before: String = JSON.stringify(ui.state.sides[0].offers)
	ui.prepare_spell()
	check(ui.state.sides[0].points==2 and ui.state.sides[0].spell, "spell UI spends one point")
	check(before==JSON.stringify(ui.state.sides[0].offers), "spell UI preserves offer objects")
	ui._pick(0)
	ui._pick(0)
	check(ui.state.total_units(0)>0, "UI summons real persistent armies")
	ui.begin_battle()
	check(ui.simulation!=null and ui.state.phase=="combat", "UI launches real combat")
	# Resolve the same simulation synchronously, then invoke its result flow.
	while not ui.simulation.finished and ui.simulation.tick<4500:
		ui.simulation.step()
	ui._round_over()
	check(ui.modal_kind=="round_result", "round result dialog opens")
	ui.next_round()
	check(ui.state.round_number==2 and ui.state.phase=="command", "next round resumes command phase")
	ui.state.sides[1].hearts=1
	ui.state.phase="combat"
	ui.simulation = CombatSimulation.new(ui.state)
	ui.simulation.result={"winner":0,"seconds":1.0,"reason":"UI fixture","survivors":[1,0]}
	ui._round_over()
	check(ui.screen=="results" and ui.state.winner==0, "victory opens results screen")
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
