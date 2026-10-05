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

func _ready() -> void:
	theme = StoryStyle.theme()
	world = World.new()
	add_child(world)
	battlefield = Battlefield.new()
	battlefield.position = Vector2(40, 79)
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

func _portrait(rectangle: Rect2, parent: Control = null) -> void:
	var image := TextureRect.new()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture = GameCatalog.commander().portrait
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
	_label("The Fire Realm awaits", Rect2(61, 268, 140, 20), 9, true)
	_label("PHASE 1  ·  FIRE REALM", Rect2(194, 327, 252, 20), 9, true)
	_publish()

func show_commander() -> void:
	_reset("commander")
	_title("Choose your Commander", "Every good story starts with a spark.")
	_panel(Rect2(100, 131, 440, 167))
	_portrait(Rect2(122, 159, 96, 96))
	_label("Fire Commander", Rect2(239, 147, 272, 26), 18, false, true)
	_label("A cheerful flame warden & festival champion", Rect2(240, 177, 275, 19), 10)
	_label("All allies: +5% attack damage\nFire allies: +5% attack speed", Rect2(240, 202, 270, 36), 11)
	_label("Blazing Orders · +25% attack speed for 6s\nPrepare before battle for 1 Command Point.", Rect2(240, 243, 274, 35), 10)
	_button("Back", Rect2(100, 313, 100, 28), show_menu)
	_button("Choose Fire Commander →", Rect2(323, 312, 217, 31), show_warband, true)
	_publish()

func show_warband() -> void:
	_reset("warband")
	_title("Your Fire Warband", "Four different armies. One warm-hearted realm.")
	var cards: Dictionary = GameCatalog.cards()
	for index in range(4):
		var card: ArmyCardData = cards[GameCatalog.FIRE_IDS[index]]
		var tile := _panel(Rect2(25+index*150, 135, 140, 119))
		_sprite(card, Rect2(48, 11, 44, 44), tile)
		_label(card.short_name, Rect2(5, 61, 130, 20), 12, true, true, tile)
		_label("%s · %d units" % [card.role.capitalize(), card.group_size], Rect2(5, 89, 130, 17), 10, true, false, tile)
	_label("✦ Wildfire Realm Bond active", Rect2(85, 270, 470, 20), 13, true, true)
	_label("Each Fire unit's first hit applies a 3-second Burn.", Rect2(85, 291, 470, 18), 10, true)
	_button("Back", Rect2(25, 321, 99, 28), show_commander)
	_button("Enter the festival →", Rect2(408, 319, 207, 32), new_match, true)
	_publish()

func new_match() -> void:
	last_seed = int(Time.get_unix_time_from_system()) if last_seed == 0 else last_seed+1
	state = MatchState.new(last_seed)
	NormalAI.play(state)
	simulation = null
	accumulator = 0.0
	SaveStore.save()
	show_battle()

func _roster_text(side: int, abbreviated: bool = false) -> String:
	var pieces: Array[String] = []
	for id in state.warband:
		var army: Dictionary = state.sides[side].roster[id]
		var army_name: String = {"ranged":"Bow", "melee":"Blade", "tank":"Guard", "assassin":"Veil"}[state.cards[id].role] if abbreviated else state.cards[id].short_name
		pieces.append("%s %d%s" % [army_name, army.count, " Ⅱ" if army.rank==2 else " Ⅲ" if army.rank==3 else ""])
	return "  ·  ".join(pieces)

func show_battle() -> void:
	_reset("battle")
	_panel(Rect2(15, 7, 610, 60))
	_portrait(Rect2(23, 14, 38, 38))
	_portrait(Rect2(579, 14, 38, 38))
	_label("YOU · %d units" % state.total_units(0), Rect2(71, 10, 140, 18), 10)
	_label("EMBER AI · %d units" % state.total_units(1), Rect2(433, 10, 134, 18), 10)
	var hearts_left := _label("♥ ".repeat(state.sides[0].hearts), Rect2(71, 27, 160, 21), 16)
	hearts_left.add_theme_color_override("font_color", StoryStyle.EMBER)
	var hearts_right := _label("♥ ".repeat(state.sides[1].hearts), Rect2(433, 27, 143, 21), 16)
	hearts_right.add_theme_color_override("font_color", StoryStyle.EMBER)
	_label("Round %d" % state.round_number, Rect2(234, 9, 172, 22), 15, true, true)
	phase_label = _label("Command Phase" if state.phase=="command" else "Automatic combat", Rect2(231, 31, 178, 18), 10, true)
	_label("✦ Wildfire", Rect2(242, 49, 156, 17), 9, true)
	var player_armies := _label(_roster_text(0, true), Rect2(20, 50, 217, 14), 8)
	player_armies.tooltip_text = _roster_tooltip(0)
	player_armies.mouse_filter = Control.MOUSE_FILTER_STOP
	var ai_armies := _label(_roster_text(1, true), Rect2(411, 50, 211, 14), 8)
	ai_armies.tooltip_text = _roster_tooltip(1)
	ai_armies.mouse_filter = Control.MOUSE_FILTER_STOP
	runes = Runes.new()
	runes.position = Vector2(19, 225)
	runes.size = Vector2(105, 23)
	runes.available = state.sides[0].points
	runes.capacity = state.config.command_points + (state.config.comeback_points if state.previous_loser==0 else 0)
	runes.tooltip_text = "One rune per Command Point. The teal rune is your comeback point."
	surface.add_child(runes)
	_label("%d Command Points" % state.sides[0].points if state.phase=="command" else "Watch your warband", Rect2(128, 226, 225, 20), 10)
	_button("Options", Rect2(546, 226, 75, 21), func(): settings_return="battle"; show_settings())
	clock_label = _label("", Rect2(256, 198, 128, 18), 9, true)
	for index in range(3):
		var choice: Dictionary = state.sides[0].offers[index]
		var card: ArmyCardData = state.cards[choice.card_id]
		var army: Dictionary = state.sides[0].roster[choice.card_id]
		var tile := _button("", Rect2(18+index*145, 254, 138, 96), _pick.bind(index))
		tile.name = "Offer%d" % index
		tile.disabled = not state.can_choose(0, choice)
		offer_buttons.append(tile)
		var action_title: String = {"summon": "SUMMON ARMY", "reinforce": "REINFORCE", "promote": "PROMOTE"}[choice.kind]
		_label(action_title, Rect2(8, 4, 112, 17), 8, false, false, tile)
		_label(str(index+1), Rect2(120, 4, 12, 16), 9, true, false, tile)
		_sprite(card, Rect2(6, 27, 32, 32), tile)
		_label(card.short_name, Rect2(39, 25, 96, 21), 11, false, true, tile)
		var detail: String = "+%d %s" % [card.group_size, "units" if card.group_size>1 else "unit"]
		if choice.kind == "reinforce":
			detail = "%d → %d units" % [army.count, army.count*2]
		elif choice.kind == "promote":
			detail = "Rank %d → %d" % [army.rank, army.rank+1]
		_label(detail, Rect2(39, 47, 96, 18), 10, false, false, tile)
		_label("1 Command Point" if state.eligible(0, choice) else "Unit cap reached", Rect2(8, 71, 121, 17), 9, false, false, tile)
		var seal := Seal.new()
		seal.position = Vector2(124, 80)
		tile.add_child(seal)
		tile.tooltip_text = "%s\n%s\nHP %d · damage %d · %.2f attacks/s\nOwned: %d · Rank %d · normal summons: %d\nReinforcements used: %d / 2" % [card.display_name, card.description, card.stats.max_hp, card.stats.damage, card.stats.attacks_per_second, army.count, army.rank, army.summons, army.reinforcements]
	var spell_text := "Blazing Orders\n+25% attack speed · 6s\n1 Command Point"
	if state.sides[0].spell:
		spell_text = "Blazing Orders queued\nYour next battle starts\nwith +25% attack speed"
	if state.phase == "combat":
		spell_text = "Blazing Orders\nPrepared before battle"
	spell_button = _button(spell_text, Rect2(459, 254, 162, 61), prepare_spell)
	spell_button.name = "CommandSpell"
	spell_button.disabled = not state.can_prepare_spell(0)
	spell_button.add_theme_font_size_override("font_size", 10)
	spell_button.size = Vector2(162, 61)
	battle_button = _button("Begin battle  →" if state.phase=="command" else "Battle in progress", Rect2(459, 322, 162, 28), begin_battle, true)
	battle_button.name = "BeginBattle"
	battle_button.disabled = state.phase!="command" or state.total_units(0)==0
	battle_button.tooltip_text = "Enter automatic combat. Unused Command Points are discarded.\nSpace: begin battle · Escape: settings · F3: AI explanation"
	spell_label = _label("Blazing Orders queued" if state.sides[0].spell else "", Rect2(32, 76, 202, 18), 9)
	if state.sides[1].spell:
		_label("AI · Blazing Orders queued" if state.phase=="command" else "AI · Blazing Orders prepared", Rect2(435, 76, 178, 18), 9)
	if debug_ai:
		var debug_panel := _panel(Rect2(354, 90, 250, 89))
		_label("AI decisions · previous-round information", Rect2(8, 4, 236, 15), 8, false, false, debug_panel)
		_label("\n".join(state.ai_explanations), Rect2(8, 24, 233, 62), 8, false, false, debug_panel)
	_publish()

func _roster_tooltip(side: int) -> String:
	var lines: Array[String] = ["%d persistent units" % state.total_units(side)]
	for id in state.warband:
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
			spell_label.text = "Blazing Orders · %.1fs" % maxf(0.0, state.commander.spell_duration-seconds) if seconds < state.commander.spell_duration else "Blazing Orders complete"
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
	var message: String = "Ember AI loses a Heart." if winning_side==0 else "You lose a Heart. Next round: 4 Command Points." if winning_side==1 else "Both armies dispersed together. No Hearts lost."
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
	_label("Fire Commander", Rect2(63, 232, 110, 22), 10, true, true)
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
	_title("Fire Army Compendium", "Meet the festival's warmest company.")
	var cards: Dictionary = GameCatalog.cards()
	for index in range(4):
		var card: ArmyCardData = cards[GameCatalog.FIRE_IDS[index]]
		var tile := _panel(Rect2(30+(index%2)*296, 132+int(index/2)*84, 284, 77))
		_sprite(card, Rect2(6, 10, 48, 48), tile)
		_label(card.display_name, Rect2(56, 6, 222, 19), 11, false, true, tile)
		_label("%s · %d per summon · HP %d" % [card.role.capitalize(), card.group_size, card.stats.max_hp], Rect2(56, 29, 222, 18), 10, false, false, tile)
		_label("Damage %d · %.2f attacks/s · range %d" % [card.stats.damage, card.stats.attacks_per_second, card.stats.attack_range], Rect2(56, 49, 222, 16), 9, false, false, tile)
		tile.tooltip_text = card.description
	_button("← Main menu", Rect2(223, 318, 194, 31), show_menu)
	_publish()

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
	var snapshot := {"screen": screen, "modal": modal_kind, "settings": SaveStore.settings}
	if state:
		snapshot.merge({"phase": state.phase, "round": state.round_number,
			"points": state.sides[0].points, "spell": state.sides[0].spell,
			"hearts": [state.sides[0].hearts, state.sides[1].hearts],
			"seed": state.match_seed, "offers": state.sides[0].offers,
			"roster": state.sides[0].roster, "total": state.total_units(0)})
		if simulation:
			snapshot["tick"] = simulation.tick
	JavaScriptBridge.eval("window.vtuberEraQA = %s;" % JSON.stringify(snapshot))
