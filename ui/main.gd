extends Control

const World = preload("res://scenes/world.gd")
const Battlefield = preload("res://scenes/battlefield.gd")
const Runes = preload("res://ui/command_runes.gd")
const Hearts = preload("res://ui/hearts.gd")
const HEADING = StoryStyle.TEXT_FONT
const INFO_ICON = preload("res://assets/icons/info.svg")

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
var rival_spell_label: Label
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
var details_overlay: Control
var details_card_id: String = ""
var last_played: String = ""
var details_return_focus: Control

func _ready() -> void:
	theme = StoryStyle.theme()
	get_window().size_changed.connect(_update_pixel_scale)
	_update_pixel_scale()
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

func _update_pixel_scale() -> void:
	var window: Window = get_window()
	var available_scale: float = minf(float(window.size.x)/640.0,float(window.size.y)/360.0)
	# Integer pixels at a comfortable 2x or larger. Below that, fill the
	# smaller window so the 10px logical lettering does not become a tiny 1x UI.
	var policy: Window.ContentScaleStretch = Window.CONTENT_SCALE_STRETCH_INTEGER if available_scale >= 2.0 else Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	if window.content_scale_stretch != policy:
		window.content_scale_stretch = policy

func _reset(next_screen: String) -> void:
	screen = next_screen
	modal = null
	modal_kind = ""
	modal_action = Callable()
	details_overlay = null
	details_card_id = ""
	details_return_focus = null
	runes = null
	spell_button = null
	battle_button = null
	clock_label = null
	spell_label = null
	rival_spell_label = null
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
	# Assign typography before entering the tree: Godot caches the initial
	# line height when attaching a Label, before later font overrides settle.
	node.add_theme_font_override("font", HEADING if serif else StoryStyle.TEXT_FONT)
	node.add_theme_font_size_override("font_size", maxi(StoryStyle.MIN_FONT_SIZE,font_size))
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent else surface).add_child(node)
	StoryStyle.fit_label(node, rectangle, font_size)
	return node

func _button(text_value: String, rectangle: Rect2, action: Callable, primary: bool = false, parent: Control = null) -> Button:
	var node := Button.new()
	node.text = text_value
	node.clip_contents = true
	if primary:
		node.add_theme_stylebox_override("normal", StoryStyle.panel(StoryStyle.MOSS))
		node.add_theme_stylebox_override("hover", StoryStyle.panel(Color("5c8062")))
		node.add_theme_stylebox_override("pressed", StoryStyle.panel(Color("385b48")))
		for key in ["font_color", "font_hover_color", "font_hover_pressed_color", "font_pressed_color", "font_focus_color"]:
			node.add_theme_color_override(key, Color("fff1ce"))
	node.pressed.connect(func(): Sound.begin(); Sound.play("click"); action.call())
	(parent if parent else surface).add_child(node)
	StoryStyle.fit_button(node, rectangle)
	return node

func _hearts(rectangle: Rect2, count_value: int) -> void:
	var node := Hearts.new()
	node.position = rectangle.position
	node.size = rectangle.size
	node.count = count_value
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.add_child(node)

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

# The same clean card face is used in the round picker and the compendium.
# Passive rules and statistics live behind the dedicated, keyboard-focusable icon.
func _card_face(card: ArmyCardData, rectangle: Rect2, parent: Control, action: Callable = Callable(), choice: Dictionary = {}) -> Control:
	var tile: Control = _button("", rectangle, action, false, parent) if action.is_valid() else _panel(rectangle, parent)
	tile.set_meta("card_face", card.id)
	var width: float = rectangle.size.x
	var height: float = rectangle.size.y
	var accent := ColorRect.new()
	accent.position = Vector2(4, 4)
	accent.size = Vector2(width-8, 3)
	accent.color = GameCatalog.realm_color(card.set_id)
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(accent)
	var info := _button("", Rect2(7, 10, 23, 23), _show_card_details.bind(card.id, choice), false, tile)
	info.name = "CardInfo"
	info.icon = INFO_ICON
	info.add_theme_constant_override("icon_max_width", 16)
	for key in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box: StyleBoxFlat = StoryStyle.panel(StoryStyle.HONEY if key == "hover" else StoryStyle.PARCHMENT, StoryStyle.INK, 1)
		box.content_margin_left = 2
		box.content_margin_right = 2
		info.add_theme_stylebox_override(key, box)
	info.tooltip_text = "View %s effects" % card.display_name
	info.set_meta("card_info_id", card.id)
	var title: String = card.set_id.capitalize() if choice.is_empty() else {"summon":"Summon", "reinforce":"Reinforce", "promote":"Promote"}[choice.kind]
	_label(title, Rect2(34, 11, width-42, 20), 11, true, false, tile)
	_sprite(card, Rect2((width-64)/2.0, 38, 64, 64), tile)
	_label(card.display_name, Rect2(7, height-65, width-14, 23), 14, true, true, tile)
	var short_effect: String = card.role.capitalize()
	var footer: String = "%d %s · Max %d" % [card.group_size, "unit" if card.group_size == 1 else "units", GameCatalog.army_cap(card)]
	if not choice.is_empty():
		var army: Dictionary = state.sides[0].roster[card.id]
		var gain: int = state.action_gain(0, choice)
		short_effect = "+%d %s" % [gain, "units" if gain != 1 else "unit"]
		if choice.kind == "reinforce": short_effect = "%d → %d units" % [army.count, state.target_count(0, choice)]
		elif choice.kind == "promote": short_effect = "Rank %d → %d" % [army.rank, army.rank+1]
		footer = "1 Command Point" if state.eligible(0, choice) else "Unit cap reached"
	_label(short_effect, Rect2(7, height-39, width-14, 18), 11, true, false, tile)
	_label(footer, Rect2(7, height-20, width-14, 16), 10, true, false, tile)
	return tile

func _show_card_details(card_id: String, choice: Dictionary = {}) -> void:
	if details_overlay or (modal and modal_kind != "command"):
		return
	var card: ArmyCardData = GameCatalog.cards()[card_id]
	details_return_focus = get_viewport().gui_get_focus_owner()
	details_card_id = card_id
	details_overlay = Control.new()
	details_overlay.name = "CardDetails"
	details_overlay.size = Vector2(640, 360)
	surface.add_child(details_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.19, 0.16, 0.12, 0.64)
	dim.size = Vector2(640, 360)
	details_overlay.add_child(dim)
	_panel(Rect2(108, 41, 424, 282), details_overlay)
	_sprite(card, Rect2(125, 61, 64, 64), details_overlay)
	_label(card.display_name, Rect2(200, 54, 305, 28), 22, false, true, details_overlay)
	_label("%s · %s · Max %d" % [card.set_id.capitalize(), card.role.capitalize(), GameCatalog.army_cap(card)], Rect2(200, 87, 305, 23), 12, false, false, details_overlay)
	_label("Base stats", Rect2(127, 126, 385, 21), 14, false, true, details_overlay)
	_label("HP %d   Damage %d   %.2f attacks/s\nRange %d   Move speed %d" % [card.stats.max_hp, card.stats.damage, card.stats.attacks_per_second, card.stats.attack_range, card.stats.move_speed], Rect2(127, 149, 385, 37), 11, false, false, details_overlay)
	_label("Army effects", Rect2(127, 191, 385, 22), 14, false, true, details_overlay)
	_label(card.description, Rect2(127, 216, 385, 42), 12, false, false, details_overlay)
	var note: String = ""
	if not choice.is_empty() and state:
		var army: Dictionary = state.sides[0].roster[card_id]
		match choice.kind:
			"summon": note = "Summon adds %d %s. Costs 1 Command Point." % [state.action_gain(0, choice), "unit" if state.action_gain(0, choice) == 1 else "units"]
			"reinforce": note = "Reinforce adds units: %d → %d units; rank stays %d." % [army.count, state.target_count(0, choice), army.rank]
			"promote": note = "Promote raises rank %d → %d; unit count stays %d." % [army.rank, army.rank+1,army.count]
	_label(note, Rect2(127, 262, 385, 20), 10, true, false, details_overlay)
	var close := _button("Close", Rect2(248, 289, 144, 25), _close_card_details, true, details_overlay)
	close.grab_focus()
	_publish()

func _close_card_details() -> void:
	if details_overlay:
		surface.remove_child(details_overlay)
		details_overlay.queue_free()
	details_overlay = null
	details_card_id = ""
	if is_instance_valid(details_return_focus):
		details_return_focus.grab_focus()
	details_return_focus = null
	_publish()

func _show_skill_details(leader: CommanderData) -> void:
	if details_overlay or (modal and modal_kind != "command"):
		return
	details_return_focus = get_viewport().gui_get_focus_owner()
	details_card_id = leader.id
	details_overlay = Control.new()
	details_overlay.name = "CommanderSkillDetails"
	details_overlay.size = Vector2(640, 360)
	surface.add_child(details_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.19, 0.16, 0.12, 0.64)
	dim.size = Vector2(640, 360)
	details_overlay.add_child(dim)
	_panel(Rect2(108, 58, 424, 264), details_overlay)
	_portrait(Rect2(126, 77, 58, 58), details_overlay, leader)
	_label(leader.spell_name, Rect2(198, 76, 309, 28), 22, false, true, details_overlay)
	_label(leader.display_name+" · Active skill", Rect2(198, 111, 309, 20), 11, false, false, details_overlay)
	_label("1 Command Point · Once per round", Rect2(127, 145, 385, 21), 13, false, true, details_overlay)
	_label(leader.spell_details, Rect2(127, 176, 385, 84), 12, false, false, details_overlay)
	_label("Prepare during card selection. Cast when battle starts.", Rect2(127, 267, 385, 18), 10, true, false, details_overlay)
	var close := _button("Close", Rect2(248, 291, 144, 25), _close_card_details, true, details_overlay)
	close.grab_focus()
	_publish()

func _skill_info(rectangle: Rect2, parent: Control, leader: CommanderData) -> Button:
	var info := _button("", rectangle, _show_skill_details.bind(leader), false, parent)
	info.name = "CommanderInfo"
	info.icon = INFO_ICON
	info.add_theme_constant_override("icon_max_width", 16)
	for key in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box: StyleBoxFlat = StoryStyle.panel(StoryStyle.HONEY if key == "hover" else StoryStyle.PARCHMENT, StoryStyle.INK, 1)
		box.content_margin_left = 2
		box.content_margin_right = 2
		info.add_theme_stylebox_override(key, box)
	info.tooltip_text = "View %s effects" % leader.spell_name
	info.set_meta("skill_info_id", leader.id)
	return info

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
		_skill_info(Rect2(7, 10, 23, 23), tile, leader)
		_label(leader.display_name, Rect2(4, 71, 180, 20), 14, true, true, tile)
		_label(leader.passive_description, Rect2(8, 95, 174, 32), 9, false, false, tile)
		_label(leader.spell_name, Rect2(4, 131, 180, 17), 10, true, true, tile)
		_label(leader.spell_description, Rect2(4, 151, 180, 16), 9, true, false, tile)
		if chosen:
			_label("OK", Rect2(164, 6, 16, 16), 8, true, false, tile)
	_button("Back", Rect2(20, 315, 100, 28), show_menu)
	_button("Build your warband →", Rect2(323, 312, 297, 31), show_warband, true)
	_publish()

func _select_commander(id: String) -> void:
	var previous: String = GameCatalog.commander(selected_commander_id).set_id
	var previous_bond: SetBonusData = GameCatalog.warband_bond(selected_warband, GameCatalog.cards())
	selected_commander_id = id
	if previous_bond != null and previous_bond.set_id == previous:
		selected_warband = GameCatalog.realm_preset(GameCatalog.commander(id).set_id)
	show_commander()

func _preset(realm: String) -> void:
	selected_warband = GameCatalog.realm_preset(realm) if realm != "clear" else []
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
			_sprite(card, Rect2(2, 5, 32, 32), slot)
			_label(card.short_name, Rect2(35, 3, 105, 19), 10, false, true, slot)
			_label("%s · remove" % card.set_id.capitalize(), Rect2(35, 23, 104, 15), 8, false, false, slot)
		else:
			var slot := _panel(Rect2(17+index*152, 74, 143, 43))
			_label("Choose an army", Rect2(5, 7, 133, 28), 10, true, false, slot)
	for index in range(3):
		var realm: String = GameCatalog.REALMS[index]
		var preset := _button("%s set" % realm.capitalize(), Rect2(20+index*99, 124, 94, 23), _preset.bind(realm))
		preset.add_theme_font_size_override("font_size",10)
		preset.size = Vector2(94,23)
	_button("Clear", Rect2(322, 124, 72, 23), _preset.bind("clear"))
	_label("Choose any four armies", Rect2(402, 126, 216, 19), 10)
	for index in range(GameCatalog.ARMY_IDS.size()):
		var card: ArmyCardData = cards[GameCatalog.ARMY_IDS[index]]
		var chosen: bool = selected_warband.has(card.id)
		var tile := _button("", Rect2(17+(index%5)*122, 155+int(index/5)*44, 118, 41), _toggle_card.bind(card.id))
		tile.disabled = not chosen and selected_warband.size() == 4
		if chosen:
			tile.add_theme_stylebox_override("normal", StoryStyle.panel(Color("e5d7ad")))
		_sprite(card, Rect2(2, 3, 32, 32), tile)
		_label(card.short_name, Rect2(35, 3, 80, 18), 10, false, true, tile)
		_label("%s · %d%s" % [card.role.capitalize(), card.group_size, " +" if chosen else ""], Rect2(35, 22, 80, 14), 10, false, false, tile)
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
	last_played = ""
	SaveStore.settings.commander = selected_commander_id
	SaveStore.settings.warband = selected_warband.duplicate()
	SaveStore.settings.rival = rival_realm
	SaveStore.save()
	show_battle()

func _roster_text(side: int, abbreviated: bool = false) -> String:
	var pieces: Array[String] = []
	var abbreviations := {"fire_archer":"Liza", "fire_melee":"Imp", "fire_tank":"Magma", "fire_assassin":"Ninja",
		"water_mage":"Wiz", "water_tank":"Ice", "water_melee":"Slime", "water_ranged":"Snow",
		"earth_tank":"Tree", "earth_melee":"Arma", "earth_ranged":"Bow", "earth_siege":"Siege",
		"fire_candle":"Candle", "water_penguin":"Peng", "earth_pitcher":"Pitch"}
	for id in state.warband_for(side):
		var army: Dictionary = state.sides[side].roster[id]
		var army_name: String = abbreviations[id] if abbreviated else state.cards[id].short_name
		pieces.append("%s %d%s" % [army_name, army.count, " R2" if army.rank==2 else " R3" if army.rank==3 else ""])
	return "  ·  ".join(pieces)

func show_battle() -> void:
	_reset("battle")
	battlefield.rebuild_preview()
	_panel(Rect2(12, 4, 616, 54))
	_portrait(Rect2(18, 10, 30, 30), null, state.commander_for(0))
	_portrait(Rect2(590, 10, 30, 30), null, state.commander_for(1))
	var player := _label("YOU · %d units" % state.total_units(0), Rect2(62, 8, 140, 17), 11)
	player.tooltip_text = _roster_tooltip(0)
	player.mouse_filter = Control.MOUSE_FILTER_STOP
	var rival := _label("%s AI · %d units" % [state.commander_for(1).set_id.to_upper(), state.total_units(1)], Rect2(428, 8, 148, 17), 11)
	rival.tooltip_text = _roster_tooltip(1)
	rival.mouse_filter = Control.MOUSE_FILTER_STOP
	_hearts(Rect2(62, 28, 160, 18), state.sides[0].hearts)
	_hearts(Rect2(428, 28, 148, 18), state.sides[1].hearts)
	_label("Round %d" % state.round_number, Rect2(228, 6, 150, 20), 16, true, true)
	phase_label = _label("Choose your cards" if state.phase=="command" else "Automatic combat", Rect2(228, 27, 178, 15), 10, true)
	clock_label = _label("", Rect2(232, 42, 172, 15), 10, true)
	var options := _button("...", Rect2(380, 7, 31, 22), func(): settings_return="battle"; show_settings())
	options.name = "BattleOptions"
	options.tooltip_text = "Options · Escape"
	if state.phase == "command":
		_show_command_picker()
	elif state.sides[0].spell:
		spell_label = _label(state.commander.spell_name, Rect2(26, 70, 246, 17), 10)
		spell_label.tooltip_text = state.commander.spell_details
		spell_label.mouse_filter = Control.MOUSE_FILTER_STOP
	if state.phase == "combat" and state.sides[1].spell:
		rival_spell_label = _label("Rival: "+state.commander_for(1).spell_name, Rect2(390, 70, 220, 17), 10, true)
		rival_spell_label.tooltip_text = state.commander_for(1).spell_details
		rival_spell_label.mouse_filter = Control.MOUSE_FILTER_STOP
	if debug_ai:
		var debug_panel := _panel(Rect2(354, 90, 250, 89))
		_label("AI decisions", Rect2(8, 4, 236, 18), 12, false, false, debug_panel)
		_label("\n".join(state.ai_explanations), Rect2(8, 25, 233, 60), 10, false, false, debug_panel)
	_publish()

func _show_command_picker() -> void:
	modal_kind = "command"
	modal = Control.new()
	modal.name = "CommandPicker"
	modal.size = Vector2(640, 360)
	surface.add_child(modal)
	var dim := ColorRect.new()
	dim.color = Color(0.19, 0.16, 0.12, 0.44)
	dim.size = Vector2(640, 360)
	modal.add_child(dim)
	_panel(Rect2(40, 68, 560, 276), modal)
	_label("Round %d · Choose cards" % state.round_number, Rect2(56, 77, 335, 24), 19, false, true, modal)
	_label("%d Command Points" % state.sides[0].points, Rect2(438, 79, 145, 22), 11, true, false, modal)
	runes = Runes.new()
	runes.position = Vector2(389, 82)
	runes.size = Vector2(105, 23)
	runes.scale = Vector2(0.5, 0.5)
	runes.available = state.sides[0].points
	runes.capacity = state.config.command_points + (state.config.comeback_points if state.previous_loser==0 else 0)
	runes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal.add_child(runes)
	_label("Play cards with your points, then start the battle." if state.sides[0].points>0 else "Your warband is ready. Start the battle!", Rect2(56, 102, 526, 16), 11, false, false, modal)
	for index in range(3):
		var choice: Dictionary = state.sides[0].offers[index]
		var card: ArmyCardData = state.cards[choice.card_id]
		var tile: Button = _card_face(card, Rect2(54+index*178, 119, 166, 172), modal, _pick.bind(index), choice)
		tile.name = "Offer%d" % index
		tile.disabled = not state.can_choose(0, choice)
		tile.tooltip_text = "Play this card · %d" % (index+1)
		offer_buttons.append(tile)
	_label(last_played, Rect2(56, 291, 526, 16), 10, true, false, modal)
	var spell_text: String = "%s · Prepare\n1 Command Point" % state.commander.spell_name
	if state.sides[0].spell:
		spell_text = "%s · Prepared\nReady for this battle" % state.commander.spell_name
	spell_button = _button(spell_text, Rect2(54, 308, 266, 29), prepare_spell, false, modal)
	spell_button.name = "CommandSpell"
	spell_button.disabled = not state.can_prepare_spell(0)
	spell_button.tooltip_text = state.commander.spell_description
	_skill_info(Rect2(326, 311, 23, 23), modal, state.commander)
	battle_button = _button("Battle →", Rect2(410, 308, 166, 29), begin_battle, true, modal)
	battle_button.name = "BeginBattle"
	battle_button.disabled = state.total_units(0)==0
	battle_button.tooltip_text = "Start automatic combat · Space. Unused Command Points are discarded."

func _roster_tooltip(side: int) -> String:
	var lines: Array[String] = ["%d persistent units" % state.total_units(side)]
	for id in state.warband_for(side):
		var army: Dictionary = state.sides[side].roster[id]
		lines.append("%s: %d · Rank %d" % [state.cards[id].display_name, army.count, army.rank])
	return "\n".join(lines)

func _pick(index: int) -> void:
	if details_overlay or (modal and modal_kind != "command") or state.phase != "command":
		return
	var choice: Dictionary = state.sides[0].offers[index]
	if not state.can_choose(0, choice):
		return
	if choice.kind == "reinforce":
		var army: Dictionary = state.sides[0].roster[choice.card_id]
		_dialog("Call Reinforcements?", "%s\n%d → %d units · Rank %d stays the same\nCosts 1 Command Point" % [state.cards[choice.card_id].display_name, army.count, state.target_count(0, choice), army.rank], "Confirm Reinforcements", func(): _apply_choice(choice), "reinforce", true)
	else:
		_apply_choice(choice)

func _apply_choice(choice: Dictionary) -> void:
	if state.choose(0, choice):
		Sound.play("summon")
		last_played = "%s · %s played" % [state.cards[choice.card_id].display_name, choice.kind.capitalize()]
		show_battle()

func prepare_spell() -> void:
	if details_overlay or (modal and modal_kind != "command"):
		return
	if state.prepare_spell(0):
		Sound.play("spell")
		last_played = "%s prepared" % state.commander.spell_name
		show_battle()

func begin_battle() -> void:
	if details_overlay or (modal and modal_kind != "command") or not state.start_combat():
		return
	Sound.play("battle")
	simulation = CombatSimulation.new(state)
	accumulator = 0.0
	show_battle()

func _process(delta: float) -> void:
	# Viewport stretch keeps the logical viewport at 640x360, so its
	# size_changed signal may not fire for a Web canvas resize.
	_update_pixel_scale()
	telemetry_time += delta
	if screen=="battle" and state and state.phase=="combat" and simulation:
		accumulator += delta * SaveStore.settings.combat_speed
		var step_time: float = 1.0 / float(state.config.ticks_per_second)
		var steps := 0
		var audio_events: Array = []
		while accumulator >= step_time and steps < 60 and not simulation.finished:
			simulation.step()
			battlefield.ingest(simulation.events)
			audio_events.append_array(simulation.events)
			accumulator -= step_time
			steps += 1
		Sound.combat(audio_events)
		battlefield.interpolation = clampf(accumulator/step_time, 0.0, 1.0)
		var seconds: float = float(simulation.tick) / float(state.config.ticks_per_second)
		clock_label.text = "%.1fs · %dx" % [seconds, SaveStore.settings.combat_speed]
		phase_label.text = "Sudden death" if simulation.sudden_death else "Automatic combat"
		if simulation.opening_active():
			phase_label.text = "Commander skills"
			clock_label.text = "Starts in %.1fs · %dx" % [float(simulation.opening_duration-simulation.opening_tick)/float(state.config.ticks_per_second), SaveStore.settings.combat_speed]
		StoryStyle.refit_label(clock_label)
		StoryStyle.refit_label(phase_label)
		if state.sides[0].spell and spell_label:
			spell_label.text = _skill_status(0)
			StoryStyle.refit_label(spell_label)
		if rival_spell_label:
			rival_spell_label.text = "Rival: "+_skill_status(1)
			StoryStyle.refit_label(rival_spell_label)
		if simulation.finished:
			_round_over()
	if telemetry_time >= 0.25:
		telemetry_time = 0.0
		_publish()

func _skill_status(side: int) -> String:
	var leader: CommanderData = state.commander_for(side)
	if leader.spell_kind == "meteors":
		return "%s · %d / %d" % [leader.spell_name, simulation.skill_counts.meteors[side], leader.meteor_count] if simulation.opening_active() else leader.spell_name+" complete"
	return leader.spell_name+" active"

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
	last_played = ""
	battlefield.sparks.clear()
	show_battle()

func _dialog(title: String, body: String, button_text: String, action: Callable, kind: String, cancel: bool = false) -> void:
	if modal:
		surface.remove_child(modal)
		modal.queue_free()
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
	var reopen_picker: bool = modal_kind == "reinforce"
	if modal:
		surface.remove_child(modal)
		modal.queue_free()
	modal = null
	modal_kind = ""
	modal_action = Callable()
	if reopen_picker:
		show_battle()
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
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.custom_minimum_size.x = 362
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.add_theme_font_size_override("font_size",10)
	scroll.add_child(summary)
	_label(_roster_text(0), Rect2(191, 271, 376, 18), 9)
	_button("Main menu", Rect2(51, 318, 160, 30), show_menu)
	_button("Rematch  →", Rect2(386, 315, 203, 34), new_match, true)
	_publish()

func show_compendium() -> void:
	_reset("compendium")
	_label("Army Compendium", Rect2(76, 22, 488, 40), 28, true, true)
	_label("Tap a card's info icon to see its full effects.", Rect2(76, 61, 488, 18), 11, true)
	for index in range(3):
		var realm: String = GameCatalog.REALMS[index]
		_button(realm.capitalize(), Rect2(161+index*106, 86, 100, 27), _compendium_tab.bind(realm), compendium_realm == realm)
	var cards: Dictionary = GameCatalog.cards()
	var realm_ids: Array = GameCatalog.realm_cards(compendium_realm)
	for index in range(realm_ids.size()):
		var card: ArmyCardData = cards[realm_ids[index]]
		_card_face(card, Rect2(16+index*123, 123, 116, 184), surface)
	_button("← Main menu", Rect2(223, 322, 194, 29), show_menu)
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
	if details_overlay:
		# Keep gameplay shortcuts and GUI Space activation inside this overlay.
		# Its focused Close button responds to Enter/Escape or a pointer click.
		get_viewport().set_input_as_handled()
		if event.keycode in [KEY_ENTER, KEY_ESCAPE]:
			_close_card_details()
		return
	if modal and modal_kind != "command":
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
		"release": "elemental-garden-armies", "text_font": StoryStyle.TEXT_FONT.get_font_name(),
		"card_details": details_card_id, "command_popup": modal_kind == "command",
		"battle_controls_visible": is_instance_valid(battle_button) and battle_button.is_visible_in_tree(),
		"pixel_scale_mode":"integer" if get_window().content_scale_stretch == Window.CONTENT_SCALE_STRETCH_INTEGER else "fit",
		"combat_sounds": Sound.combat_sounds_played, "text_overflows": _text_overflows(surface),
		"selected_commander": selected_commander_id, "selected_warband": selected_warband,
		"rival": rival_realm, "compendium_realm": compendium_realm,
		"compendium_cards":GameCatalog.realm_cards(compendium_realm), "army_ids":GameCatalog.ARMY_IDS}
	if state:
		snapshot.merge({"phase": state.phase, "round": state.round_number,
			"points": state.sides[0].points, "spell": state.sides[0].spell,
			"hearts": [state.sides[0].hearts, state.sides[1].hearts],
			"seed": state.match_seed, "offers": state.sides[0].offers,
			"roster": state.sides[0].roster, "total": state.total_units(0),
			"commander": state.commander.id, "warbands": state.warbands,
			"commanders": [state.commander_for(0).id, state.commander_for(1).id],
			"bond": state.bond.id if state.bond else "", "groups": {}, "caps": {}})
		for id in state.cards:
			snapshot.groups[id] = state.cards[id].group_size
			snapshot.caps[id] = state.army_cap(id)
		snapshot["arena"] = [CombatSimulation.ARENA_SIZE.x, CombatSimulation.ARENA_SIZE.y]
		snapshot["body_size"] = CombatSimulation.BODY_SIZE
		snapshot["spawn_spacing"] = CombatSimulation.SPAWN_SPACING
		snapshot["preview"] = []
		for entry in battlefield.preview_units:
			snapshot.preview.append([entry.side, entry.card_id, entry.position.x, entry.position.y])
		if simulation:
			snapshot["tick"] = simulation.tick
			snapshot["passives"] = simulation.passive_counts
			snapshot["active_fields"] = simulation.fields.size()
			snapshot["ground_fields"] = []
			for field in simulation.fields:
				if field.kind in ["ground_fire", "puddle"]:
					snapshot.ground_fields.append([field.kind, field.side, field.position.x, field.position.y, field.radius, field.until])
			snapshot["skills"] = {"prepared":simulation.spell_prepared, "activated":simulation.skills_activated,
				"counts":simulation.skill_counts, "opening":simulation.opening_active(), "opening_tick":simulation.opening_tick,
				"opening_duration":simulation.opening_duration}
			snapshot["walls"] = []
			for wall in simulation.walls:
				snapshot.walls.append([wall.side, wall.rect.position.x, wall.rect.position.y, wall.rect.size.x, wall.rect.size.y])
			snapshot["combat_statuses"] = []
			snapshot["combat_positions"] = []
			for unit in simulation.units:
				if unit.hp > 0.0:
					snapshot.combat_positions.append([unit.id, unit.side, unit.position.x, unit.position.y])
					snapshot.combat_statuses.append([unit.id, simulation.move_speed(unit), simulation.defence_multiplier(unit), simulation.attack_rate(unit), unit.ice_aura_fraction, unit.teleport_used, simulation.teleport_charging(unit), unit.blast_burn_until, unit.fire_aura_dps, unit.ground_fire_dps, unit.pull_target])
	JavaScriptBridge.eval("window.vtuberEraQA = %s;" % JSON.stringify(snapshot))

func _text_overflows(parent: Node) -> int:
	var count: int = 0
	for child in parent.get_children():
		if child is Control and not StoryStyle.text_within_box(child):
			count += 1
		count += _text_overflows(child)
	return count
