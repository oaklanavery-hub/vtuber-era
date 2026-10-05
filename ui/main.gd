extends Control

const World = preload("res://scenes/world.gd")
const Battlefield = preload("res://scenes/battlefield.gd")
const Runes = preload("res://ui/command_runes.gd")
const Seal = preload("res://ui/wax_seal.gd")
const HEADING = preload("res://assets/fonts/storybook.ttf")

var world: Node2D
var battlefield: Node2D
var surface: Control
var screen: String = "loading"
var state: MatchState
var simulation: CombatSimulation
var accumulator: float = 0.0
var runes: Control
var phase_label: Label
var spell_label: Label
var clock_label: Label
var offer_buttons: Array = []
var spell_button: Button
var battle_button: Button
var modal: Control
var modal_kind: String = ""
var modal_action: Callable
var debug_ai: bool = false
var settings_return: String = "menu"
var qa_enabled: bool = false
var telemetry_time: float = 0.0
var last_seed: int = 0
var selected_commander_id: String = "fire_commander"
var selected_warband: Array = GameCatalog.FIRE_IDS.duplicate()
var rival_realm: String = "mirror"
var compendium_realm: String = "fire"

func _ready() -> void:
	theme = StoryStyle.theme()
	selected_commander_id = SaveStore.settings.commander
	selected_warband = SaveStore.settings.warband.duplicate()
	rival_realm = SaveStore.settings.rival
	world = World.new()
	add_child(world)
	battlefield = Battlefield.new()
	battlefield.position = Vector2(20, 64)
	add_child(battlefield)
	battlefield.visible = false
	surface = Control.new()
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(surface)
	if OS.has_feature("web"):
		qa_enabled = bool(JavaScriptBridge.eval("new URLSearchParams(location.search).has('qa')"))
	_panel(Rect2(184, 132, 272, 92))
	_label("Opening the storybook…", Rect2(190, 151, 260, 27), 17, true, true)
	_label("Preparing the Convergence Festival", Rect2(190, 188, 260, 20), 10, true)
	await get_tree().create_timer(0.25).timeout
	show_menu()

func _reset(next_screen: String) -> void:
	screen = next_screen
	modal = null
	modal_kind = ""
	modal_action = Callable()
	for child in surface.get_children():
		surface.remove_child(child)
		child.queue_free()
	world.battle_mode = next_screen == "battle"
	world.queue_redraw()
	battlefield.visible = next_screen == "battle"
	battlefield.reduced_effects = SaveStore.settings.reduced_effects
	battlefield.state = state
	battlefield.simulation = simulation
	offer_buttons.clear()
	_publish()

func _panel(rectangle: Rect2, parent: Control = null, color: Color = StoryStyle.PARCHMENT) -> Panel:
	var node := Panel.new()
	node.position = rectangle.position
	node.size = rectangle.size
	node.add_theme_stylebox_override("panel", StoryStyle.panel(color))
	(parent if parent else surface).add_child(node)
	return node

func _label(text_value: String, rectangle: Rect2, font_size: int = 11, centered: bool = false, serif: bool = false, parent: Control = null) -> Label:
	var node := Label.new()
	node.text = text_value
	node.position = rectangle.position
	node.size = rectangle.size
	node.add_theme_font_size_override("font_size", font_size)
	if serif:
		node.add_theme_font_override("font", HEADING)
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent else surface).add_child(node)
	return node

func _button(text_value: String, rectangle: Rect2, action: Callable, primary: bool = false, parent: Control = null) -> Button:
	var node := Button.new()
	node.text = text_value
	node.position = rectangle.position
	node.size = rectangle.size
	if primary:
		node.add_theme_stylebox_override("normal", StoryStyle.panel(StoryStyle.MOSS))
		node.add_theme_stylebox_override("hover", StoryStyle.panel(Color("5c8062")))
		node.add_theme_stylebox_override("pressed", StoryStyle.panel(Color("385b48")))
		for key in ["font_color", "font_hover_color", "font_pressed_color"]:
			node.add_theme_color_override(key, Color("fff1ce"))
	node.pressed.connect(func(): Sound.begin(); Sound.play("click"); action.call())
	(parent if parent else surface).add_child(node)
	return node

func _portrait(rectangle: Rect2, parent: Control = null, leader: CommanderData = null) -> void:
	var image := TextureRect.new()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture = (leader if leader else GameCatalog.commander(selected_commander_id)).portrait
	image.position = rectangle.position
	image.size = rectangle.size
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent else surface).add_child(image)

func _sprite(card: ArmyCardData, rectangle: Rect2, parent: Control) -> void:
	var texture := AtlasTexture.new()
	texture.atlas = card.sprite
	texture.region = Rect2(0, 0, 32, 32)
	var image := TextureRect.new()
	image.texture = texture
	image.position = rectangle.position
	image.size = rectangle.size
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)

func _title(title: String, subtitle: String) -> void:
	_label(title, Rect2(76, 48, 488, 40), 28, true, true)
	_label(subtitle, Rect2(80, 92, 480, 22), 11, true)

func show_menu() -> void:
	_reset("menu")
	_title("VTuber Era", "A little strategy. A little magic. A story worth sharing.")
	_panel(Rect2(214, 128, 212, 174))
	_label("Convergence Festival", Rect2(221, 141, 198, 23), 13, true, true)
	_button("Play", Rect2(235, 174, 170, 34), show_commander, true)
	_button("Army Compendium", Rect2(235, 218, 170, 29), show_compendium)
	_button("Settings", Rect2(235, 256, 170, 28), func(): settings_return="menu"; show_settings())
	_portrait(Rect2(83, 165, 96, 96))
	_label("Three realms await", Rect2(61, 268, 140, 20), 9, true)
	_label("FIRE  ·  WATER  ·  EARTH", Rect2(194, 327, 252, 20), 9, true)
	_publish()

func show_commander() -> void:
	_reset("commander")
	_title("Choose your Commander", "Lead any four armies. Your commander is yours to choose.")
	for index in range(3):
		var leader: CommanderData = GameCatalog.commander(GameCatalog.COMMANDER_IDS[index])
		var chosen: bool = selected_commander_id == leader.id
		var tile := _button("", Rect2(20+index*206, 124, 188, 179), _select_commander.bind(leader.id))
		tile.tooltip_text = leader.identity
		if chosen:
			tile.add_theme_stylebox_override("normal", StoryStyle.panel(Color("e5d7ad")))
		_portrait(Rect2(63, 6, 62, 62), tile, leader)
		_label(leader.display_name, Rect2(4, 71, 180, 20), 14, true, true, tile)
		_label(leader.passive_description, Rect2(8, 95, 174, 32), 9, false, false, tile)
		_label(leader.spell_name, Rect2(4, 131, 180, 17), 10, true, true, tile)
		_label(leader.spell_description, Rect2(4, 151, 180, 16), 9, true, false, tile)
		if chosen:
			_label("✓", Rect2(164, 6, 16, 16), 11, true, false, tile)
	_button("Back", Rect2(20, 315, 100, 28), show_menu)
	_button("Build your warband →", Rect2(323, 312, 297, 31), show_warband, true)
	_publish()

func _select_commander(id: String) -> void:
	var previous: String = GameCatalog.commander(selected_commander_id).set_id
	var previous_bond: SetBonusData = GameCatalog.warband_bond(selected_warband, GameCatalog.cards())
	selected_commander_id = id
	if previous_bond != null and previous_bond.set_id == previous:
		selected_warband = GameCatalog.realm_cards(GameCatalog.commander(id).set_id)
	show_commander()

func _preset(realm: String) -> void:
	selected_warband = GameCatalog.realm_cards(realm) if realm != "clear" else []
	show_warband()

func _toggle_card(id: String) -> void:
	if selected_warband.has(id):
		selected_warband.erase(id)
	elif selected_warband.size() < 4:
		selected_warband.append(id)
	show_warband()

func show_warband() -> void:
	_reset("warband")
	_panel(Rect2(10, 3, 620, 65))
	_label("Build your Warband", Rect2(20, 8, 600, 31), 24, true, true)
	_label("%s · %d / 4 unique armies" % [GameCatalog.commander(selected_commander_id).display_name, selected_warband.size()], Rect2(20, 43, 417, 22), 10)
	var rival := OptionButton.new()
	rival.position = Vector2(440, 40)
	rival.size = Vector2(180, 28)
	var rival_ids := ["mirror", "fire", "water", "earth"]
	for realm in rival_ids:
		rival.add_item("Rival: %s" % ("Mirror" if realm == "mirror" else realm.capitalize()))
	rival.select(rival_ids.find(rival_realm))
	rival.item_selected.connect(func(index: int): rival_realm=rival_ids[index]; _publish())
	surface.add_child(rival)
	var cards: Dictionary = GameCatalog.cards()
	for index in range(4):
		if index < selected_warband.size():
			var card: ArmyCardData = cards[selected_warband[index]]
			var slot := _button("", Rect2(17+index*152, 74, 143, 43), _toggle_card.bind(card.id))
			_sprite(card, Rect2(3, 6, 30, 30), slot)
			_label(card.short_name, Rect2(35, 3, 105, 19), 10, false, true, slot)
			_label("%s · remove" % card.set_id.capitalize(), Rect2(35, 23, 104, 15), 8, false, false, slot)
		else:
			var slot := _panel(Rect2(17+index*152, 74, 143, 43))
			_label("Choose an army", Rect2(5, 7, 133, 28), 10, true, false, slot)
	for index in range(3):
		var realm: String = GameCatalog.REALMS[index]
		var preset := _button("%s preset" % realm.capitalize(), Rect2(20+index*99, 124, 94, 23), _preset.bind(realm))
		preset.add_theme_font_size_override("font_size",9)
		preset.size = Vector2(94,23)
	_button("Clear", Rect2(322, 124, 72, 23), _preset.bind("clear"))
	_label("Pick cards below · each army may appear once", Rect2(402, 126, 216, 19), 8)
	for index in range(12):
		var card: ArmyCardData = cards[GameCatalog.ARMY_IDS[index]]
		var chosen: bool = selected_warband.has(card.id)
		var tile := _button("", Rect2(17+(index%4)*152, 155+int(index/4)*44, 143, 41), _toggle_card.bind(card.id))
		tile.disabled = not chosen and selected_warband.size() == 4
		if chosen:
			tile.add_theme_stylebox_override("normal", StoryStyle.panel(Color("e5d7ad")))
		_sprite(card, Rect2(3, 4, 30, 30), tile)
		_label(card.short_name, Rect2(35, 3, 105, 18), 10, false, true, tile)
		_label("%s · %d units%s" % [card.role.capitalize(), card.group_size, " ✓" if chosen else ""], Rect2(35, 22, 105, 14), 8, false, false, tile)
		tile.tooltip_text = "%s\n%s" % [card.display_name, card.description]
	var realm_bond: SetBonusData = GameCatalog.warband_bond(selected_warband, cards)
	_panel(Rect2(15, 286, 610, 40))
	_label("Realm Bond: %s" % realm_bond.display_name if realm_bond else "Mixed warbands have no Realm Bond" if selected_warband.size()==4 else "Choose exactly four unique armies", Rect2(20, 288, 600, 20), 12, true, true)
	_label(realm_bond.description if realm_bond else "Your commander's bonuses still apply to your chosen armies.", Rect2(20, 308, 600, 15), 9, true)
	_button("Back", Rect2(20, 328, 99, 26), show_commander)
	var enter := _button("Enter the festival →", Rect2(440, 328, 180, 26), new_match, true)
	enter.disabled = not GameCatalog.valid_warband(selected_warband, cards)
	_publish()

func new_match() -> void:
	if not GameCatalog.valid_warband(selected_warband, GameCatalog.cards()):
		return
	last_seed = int(Time.get_unix_time_from_system()) if last_seed == 0 else last_seed+1
	state = MatchState.new(last_seed, selected_commander_id, selected_warband,
		"" if rival_realm == "mirror" else rival_realm+"_commander")
	NormalAI.play(state)
	simulation = null
	accumulator = 0.0
	SaveStore.settings.commander = selected_commander_id
	SaveStore.settings.warband = selected_warband.duplicate()
	SaveStore.settings.rival = rival_realm
	SaveStore.save()
	show_battle()

func _roster_text(side: int, abbreviated: bool = false) -> String:
	var pieces: Array[String] = []
	var abbreviations := {"fire_archer":"Liza", "fire_melee":"Imp", "fire_tank":"Magma", "fire_assassin":"Ninja",
		"water_mage":"Wiz", "water_tank":"Ice", "water_melee":"Slime", "water_ranged":"Snow",
		"earth_tank":"Tree", "earth_melee":"Arma", "earth_ranged":"Bow", "earth_siege":"Siege"}
	for id in state.warband_for(side):
		var army: Dictionary = state.sides[side].roster[id]
		var army_name: String = abbreviations[id] if abbreviated else state.cards[id].short_name
		pieces.append("%s %d%s" % [army_name, army.count, " Ⅱ" if army.rank==2 else " Ⅲ" if army.rank==3 else ""])
	return "  ·  ".join(pieces)

func show_battle() -> void:
	_reset("battle")
	battlefield.rebuild_preview()
	_panel(Rect2(12, 4, 616, 54))
	_portrait(Rect2(18, 10, 30, 30), null, state.commander_for(0))
	_portrait(Rect2(590, 10, 30, 30), null, state.commander_for(1))
	_label("YOU · %d units" % state.total_units(0), Rect2(62, 8, 140, 15), 9)
	_label("%s AI · %d units" % [state.commander_for(1).set_id.to_upper(), state.total_units(1)], Rect2(428, 8, 148, 15), 9)
	var hearts_left := _label("♥ ".repeat(state.sides[0].hearts), Rect2(62, 23, 160, 18), 12)
	hearts_left.add_theme_color_override("font_color", StoryStyle.EMBER)
	var hearts_right := _label("♥ ".repeat(state.sides[1].hearts), Rect2(428, 23, 148, 18), 12)
	hearts_right.add_theme_color_override("font_color", StoryStyle.EMBER)
	_label("Round %d" % state.round_number, Rect2(234, 7, 172, 20), 14, true, true)
	phase_label = _label("Command Phase" if state.phase=="command" else "Automatic combat", Rect2(231, 27, 178, 14), 9, true)
	var bond_label := _label("Bond: %s" % state.bond.display_name if state.bond else "Mixed Warband", Rect2(237, 39, 166, 14), 8, true)
	bond_label.tooltip_text = "You: %s\nRival: %s" % [state.bond.description if state.bond else "No Realm Bond", state.bond_for(1).description if state.bond_for(1) else "No Realm Bond"]
	bond_label.mouse_filter = Control.MOUSE_FILTER_STOP
	var player_armies := _label(_roster_text(0, true), Rect2(18, 39, 217, 14), 7)
	player_armies.tooltip_text = _roster_tooltip(0)
	player_armies.mouse_filter = Control.MOUSE_FILTER_STOP
	var ai_armies := _label(_roster_text(1, true), Rect2(414, 39, 208, 14), 7)
	ai_armies.tooltip_text = _roster_tooltip(1)
	ai_armies.mouse_filter = Control.MOUSE_FILTER_STOP
	runes = Runes.new()
	runes.position = Vector2(19, 271)
	runes.size = Vector2(105, 23)
	runes.scale = Vector2(0.75, 0.75)
	runes.available = state.sides[0].points
	runes.capacity = state.config.command_points + (state.config.comeback_points if state.previous_loser==0 else 0)
	runes.tooltip_text = "One rune per Command Point. The teal rune is your comeback point."
	surface.add_child(runes)
	_label("%d Command Points" % state.sides[0].points if state.phase=="command" else "Watch your warband", Rect2(108, 272, 225, 16), 9)
	var options := _button("Options", Rect2(551, 273, 70, 18), func(): settings_return="battle"; show_settings())
	options.add_theme_font_size_override("font_size", 9)
	options.size = Vector2(70, 18)
	clock_label = _label("", Rect2(256, 249, 128, 15), 8, true)
	for index in range(3):
		var choice: Dictionary = state.sides[0].offers[index]
		var card: ArmyCardData = state.cards[choice.card_id]
		var army: Dictionary = state.sides[0].roster[choice.card_id]
		var tile := _button("", Rect2(18+index*145, 291, 138, 64), _pick.bind(index))
		tile.name = "Offer%d" % index
		tile.disabled = not state.can_choose(0, choice)
		offer_buttons.append(tile)
		var action_title: String = {"summon": "SUMMON ARMY", "reinforce": "REINFORCE", "promote": "PROMOTE"}[choice.kind]
		_label(action_title, Rect2(8, 3, 112, 13), 7, false, false, tile)
		_label(str(index+1), Rect2(120, 3, 12, 13), 8, true, false, tile)
		_sprite(card, Rect2(6, 19, 24, 24), tile)
		_label(card.short_name, Rect2(35, 17, 99, 17), 9, false, true, tile)
		var detail: String = "+%d %s" % [card.group_size, "units" if card.group_size>1 else "unit"]
		if choice.kind == "reinforce":
			detail = "%d → %d units" % [army.count, army.count*2]
		elif choice.kind == "promote":
			detail = "Rank %d → %d" % [army.rank, army.rank+1]
		_label(detail, Rect2(35, 33, 99, 14), 8, false, false, tile)
		_label("1 Command Point" if state.eligible(0, choice) else "Unit cap reached", Rect2(8, 49, 121, 13), 7, false, false, tile)
		var seal := Seal.new()
		seal.position = Vector2(124, 54)
		seal.scale = Vector2(0.7, 0.7)
		tile.add_child(seal)
		tile.tooltip_text = "%s\n%s\nHP %d · damage %d · %.2f attacks/s\nOwned: %d · Rank %d · normal summons: %d\nReinforcements used: %d / 2" % [card.display_name, card.description, card.stats.max_hp, card.stats.damage, card.stats.attacks_per_second, army.count, army.rank, army.summons, army.reinforcements]
	var spell_text := "%s\nPrepare · 1 Command Point" % state.commander.spell_name
	if state.sides[0].spell:
		spell_text = "%s\nQueued for next battle" % state.commander.spell_name
	if state.phase == "combat":
		spell_text = "%s\nPrepared before battle" % state.commander.spell_name
	spell_button = _button(spell_text, Rect2(459, 291, 162, 36), prepare_spell)
	spell_button.name = "CommandSpell"
	spell_button.disabled = not state.can_prepare_spell(0)
	spell_button.add_theme_font_size_override("font_size", 9)
	spell_button.size = Vector2(162, 36)
	spell_button.tooltip_text = state.commander.spell_description
	battle_button = _button("Begin battle  →" if state.phase=="command" else "Battle in progress", Rect2(459, 333, 162, 22), begin_battle, true)
	battle_button.add_theme_font_size_override("font_size", 9)
	battle_button.size = Vector2(162, 22)
	battle_button.name = "BeginBattle"
	battle_button.disabled = state.phase!="command" or state.total_units(0)==0
	battle_button.tooltip_text = "Enter automatic combat. Unused Command Points are discarded.\nSpace: begin battle · Escape: settings · F3: AI explanation"
	spell_label = _label(state.commander.spell_name+" queued" if state.sides[0].spell else "", Rect2(20, 62, 240, 15), 8)
	if state.sides[1].spell:
		_label("AI · %s %s" % [state.commander_for(1).spell_name, "queued" if state.phase=="command" else "prepared"], Rect2(362, 62, 251, 15), 8)
	if debug_ai:
		var debug_panel := _panel(Rect2(354, 90, 250, 89))
		_label("AI decisions · previous-round information", Rect2(8, 4, 236, 15), 8, false, false, debug_panel)
		_label("\n".join(state.ai_explanations), Rect2(8, 24, 233, 62), 8, false, false, debug_panel)
	_publish()

func _roster_tooltip(side: int) -> String:
	var lines: Array[String] = ["%d persistent units" % state.total_units(side)]
	for id in state.warband_for(side):
		var army: Dictionary = state.sides[side].roster[id]
		lines.append("%s: %d · Rank %d" % [state.cards[id].display_name, army.count, army.rank])
	return "\n".join(lines)

func _pick(index: int) -> void:
	if modal or state.phase != "command":
		return
	var choice: Dictionary = state.sides[0].offers[index]
	if not state.can_choose(0, choice):
		return
	if choice.kind == "reinforce":
		var army: Dictionary = state.sides[0].roster[choice.card_id]
		_dialog("Call Reinforcements?", "%s\n%d → %d units · Rank %d stays the same\nCosts 1 Command Point" % [state.cards[choice.card_id].display_name, army.count, army.count*2, army.rank], "Confirm Reinforcements", func(): _apply_choice(choice), "reinforce", true)
	else:
		_apply_choice(choice)

func _apply_choice(choice: Dictionary) -> void:
	if state.choose(0, choice):
		Sound.play("summon")
		show_battle()

func prepare_spell() -> void:
	if modal:
		return
	if state.prepare_spell(0):
		Sound.play("spell")
		show_battle()

func begin_battle() -> void:
	if modal or not state.start_combat():
		return
	Sound.play("battle")
	simulation = CombatSimulation.new(state)
	accumulator = 0.0
	show_battle()

func _process(delta: float) -> void:
	telemetry_time += delta
	if screen=="battle" and state and state.phase=="combat" and simulation:
		accumulator += delta * SaveStore.settings.combat_speed
		var step_time: float = 1.0 / float(state.config.ticks_per_second)
		var steps := 0
		while accumulator >= step_time and steps < 60 and not simulation.finished:
			simulation.step()
			battlefield.ingest(simulation.events)
			accumulator -= step_time
			steps += 1
		battlefield.interpolation = clampf(accumulator/step_time, 0.0, 1.0)
		var seconds: float = float(simulation.tick) / float(state.config.ticks_per_second)
		clock_label.text = "%.1fs · %dx" % [seconds, SaveStore.settings.combat_speed]
		phase_label.text = "Sudden death" if simulation.sudden_death else "Automatic combat"
		if state.sides[0].spell:
			spell_label.text = "%s · %.1fs" % [state.commander.spell_name, maxf(0.0, state.commander.spell_duration-seconds)] if seconds < state.commander.spell_duration else state.commander.spell_name+" complete"
		if simulation.finished:
			_round_over()
	if telemetry_time >= 0.25:
		telemetry_time = 0.0
		_publish()

func _round_over() -> void:
	if not state.complete_combat(simulation.result):
		return
	if spell_label:
		spell_label.text = ""
	if state.phase=="finished":
		show_results()
		return
	var winning_side: int = int(simulation.result.winner)
	Sound.play("victory" if winning_side==0 else "defeat")
	var title: String = "Round won!" if winning_side==0 else "A new spark awaits" if winning_side==1 else "A festival draw"
	var message: String = "Your rival loses a Heart." if winning_side==0 else "You lose a Heart. Next round: 4 Command Points." if winning_side==1 else "Both armies dispersed together. No Hearts lost."
	message += "\n%s · %.1fs\nYour units return at full HP next round." % [simulation.result.reason, simulation.result.seconds]
	_dialog(title, message, "Next round  →", next_round, "round_result")

func next_round() -> void:
	if not state.begin_round():
		return
	NormalAI.play(state)
	simulation = null
	battlefield.sparks.clear()
	show_battle()

func _dialog(title: String, body: String, button_text: String, action: Callable, kind: String, cancel: bool = false) -> void:
	modal_kind = kind
	modal_action = action
	modal = Control.new()
	modal.size = Vector2(640, 360)
	surface.add_child(modal)
	var dim := ColorRect.new()
	dim.color = Color(0.19, 0.16, 0.12, 0.46)
	dim.size = Vector2(640, 360)
	modal.add_child(dim)
	_panel(Rect2(158, 100, 324, 172), modal)
	_label(title, Rect2(166, 113, 308, 31), 18, true, true, modal)
	_label(body, Rect2(170, 150, 300, 61), 10, true, false, modal)
	_button(button_text, Rect2(190, 226, 260, 29), action, true, modal)
	if cancel:
		_button("Cancel", Rect2(255, 280, 130, 26), _close_dialog, false, modal)
	_publish()

func _close_dialog() -> void:
	if modal:
		modal.queue_free()
	modal = null
	modal_kind = ""
	modal_action = Callable()
	_publish()

func show_results() -> void:
	_reset("results")
	Sound.play("victory" if state.winner==0 else "defeat")
	_title("Victory!" if state.winner==0 else "Defeat", "Your Convergence story, written in sparks." if state.winner==0 else "A new festival. A new beginning.")
	_panel(Rect2(51, 128, 538, 170))
	_portrait(Rect2(71, 145, 79, 79))
	_label(state.commander.display_name, Rect2(55, 232, 126, 22), 10, true, true)
	_label("%d rounds · %d Hearts remaining" % [state.history.size(), state.sides[0].hearts], Rect2(190, 140, 372, 23), 14, false, true)
	var lines: Array[String] = []
	for record in state.history:
		var outcome: String = "Won" if record.winner==0 else "Lost" if record.winner==1 else "Draw"
		lines.append("Round %d    %s    %.1fs    %d / %d survivors" % [record.round, outcome, record.seconds, record.survivors[0], record.survivors[1]])
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(192,167)
	scroll.size = Vector2(378,100)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	surface.add_child(scroll)
	var summary := Label.new()
	summary.text = "\n".join(lines)
	summary.add_theme_font_size_override("font_size",10)
	scroll.add_child(summary)
	_label(_roster_text(0), Rect2(191, 271, 376, 18), 9)
	_button("Main menu", Rect2(51, 318, 160, 30), show_menu)
	_button("Rematch  →", Rect2(386, 315, 203, 34), new_match, true)
	_publish()

func show_compendium() -> void:
	_reset("compendium")
	_label("Army Compendium", Rect2(76, 27, 488, 40), 28, true, true)
	for index in range(3):
		var realm: String = GameCatalog.REALMS[index]
		_button(realm.capitalize(), Rect2(161+index*106, 79, 100, 28), _compendium_tab.bind(realm), compendium_realm == realm)
	var cards: Dictionary = GameCatalog.cards()
	for index in range(4):
		var card: ArmyCardData = cards[GameCatalog.realm_cards(compendium_realm)[index]]
		var tile := _panel(Rect2(30+(index%2)*296, 132+int(index/2)*84, 284, 77))
		_sprite(card, Rect2(6, 10, 48, 48), tile)
		_label(card.display_name, Rect2(56, 6, 222, 19), 11, false, true, tile)
		_label("%s · %d per summon · HP %d" % [card.role.capitalize(), card.group_size, card.stats.max_hp], Rect2(56, 29, 222, 18), 10, false, false, tile)
		_label("Damage %d · %.2f attacks/s · range %d" % [card.stats.damage, card.stats.attacks_per_second, card.stats.attack_range], Rect2(56, 49, 222, 16), 9, false, false, tile)
		tile.tooltip_text = card.description
	_label("Hover a card for its ability · %s" % GameCatalog.bond(compendium_realm).display_name, Rect2(30, 297, 580, 16), 9, true)
	_button("← Main menu", Rect2(223, 318, 194, 31), show_menu)
	_publish()

func _compendium_tab(realm: String) -> void:
	compendium_realm = realm
	show_compendium()

func show_settings() -> void:
	_reset("settings")
	_title("A comfortable festival", "Make yourself at home.")
	_panel(Rect2(142, 129, 356, 180))
	_label("Volume", Rect2(161, 147, 111, 24), 12, false, true)
	var slider := HSlider.new()
	slider.position = Vector2(273, 150)
	slider.size = Vector2(199, 23)
	slider.min_value = 0
	slider.max_value = 100
	slider.value = SaveStore.settings.volume*100.0
	slider.value_changed.connect(func(value: float): SaveStore.settings.volume=value/100.0; Sound.set_volume(value/100.0); SaveStore.save())
	surface.add_child(slider)
	_label("Combat speed", Rect2(161, 185, 118, 24), 12, false, true)
	var speed := OptionButton.new()
	speed.position = Vector2(295, 181)
	speed.size = Vector2(177, 28)
	for value in [1, 2, 3]:
		speed.add_item("%dx · %s" % [value, "Storybook" if value==1 else "Brisk" if value==2 else "Quick"])
	speed.select(int(SaveStore.settings.combat_speed)-1)
	speed.item_selected.connect(func(index: int): SaveStore.settings.combat_speed=float(index+1); SaveStore.save())
	surface.add_child(speed)
	var reduced := CheckButton.new()
	reduced.text = "Reduced effects"
	reduced.position = Vector2(155, 220)
	reduced.size = Vector2(320, 30)
	reduced.button_pressed = SaveStore.settings.reduced_effects
	reduced.toggled.connect(func(value: bool): SaveStore.settings.reduced_effects=value; SaveStore.save())
	surface.add_child(reduced)
	_label("No flashing hits, idle bounces or defeat particles.", Rect2(162, 258, 320, 17), 9)
	_label("Settings save automatically.", Rect2(162, 281, 320, 17), 9)
	_button("Back", Rect2(222, 322, 196, 29), func(): show_battle() if settings_return=="battle" else show_menu(), true)
	_publish()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if modal:
		if event.keycode==KEY_ENTER and modal_action.is_valid():
			get_viewport().set_input_as_handled()
			modal_action.call()
		elif event.keycode==KEY_ESCAPE and modal_kind=="reinforce":
			get_viewport().set_input_as_handled()
			_close_dialog()
		return
	if screen=="battle":
		if event.keycode in [KEY_1, KEY_2, KEY_3, KEY_B, KEY_SPACE, KEY_ESCAPE, KEY_F3]:
			get_viewport().set_input_as_handled()
		match event.keycode:
			KEY_1: _pick(0)
			KEY_2: _pick(1)
			KEY_3: _pick(2)
			KEY_B: prepare_spell()
			KEY_SPACE: begin_battle()
			KEY_ESCAPE: settings_return="battle"; show_settings()
			KEY_F3: debug_ai=not debug_ai; show_battle()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
		if screen=="settings" and settings_return=="battle":
			show_battle()
		else:
			show_menu()

func _publish() -> void:
	# Opt-in, read-only telemetry for browser QA. It never grants actions or
	# changes combat, RNG, statistics, points or the selected seed.
	if not qa_enabled:
		return
	var snapshot := {"screen": screen, "modal": modal_kind, "settings": SaveStore.settings,
		"release": "creature-armies-solid-collision",
		"selected_commander": selected_commander_id, "selected_warband": selected_warband,
		"rival": rival_realm, "compendium_realm": compendium_realm}
	if state:
		snapshot.merge({"phase": state.phase, "round": state.round_number,
			"points": state.sides[0].points, "spell": state.sides[0].spell,
			"hearts": [state.sides[0].hearts, state.sides[1].hearts],
			"seed": state.match_seed, "offers": state.sides[0].offers,
			"roster": state.sides[0].roster, "total": state.total_units(0),
			"commander": state.commander.id, "warbands": state.warbands,
			"commanders": [state.commander_for(0).id, state.commander_for(1).id],
			"bond": state.bond.id if state.bond else "", "groups": {}})
		for id in state.cards:
			snapshot.groups[id] = state.cards[id].group_size
		snapshot["arena"] = [CombatSimulation.ARENA_SIZE.x, CombatSimulation.ARENA_SIZE.y]
		snapshot["body_size"] = CombatSimulation.BODY_SIZE
		snapshot["preview"] = []
		for entry in battlefield.preview_units:
			snapshot.preview.append([entry.side, entry.card_id, entry.position.x, entry.position.y])
		if simulation:
			snapshot["tick"] = simulation.tick
			snapshot["combat_positions"] = []
			for unit in simulation.units:
				if unit.hp > 0.0:
					snapshot.combat_positions.append([unit.id, unit.side, unit.position.x, unit.position.y])
	JavaScriptBridge.eval("window.vtuberEraQA = %s;" % JSON.stringify(snapshot))
