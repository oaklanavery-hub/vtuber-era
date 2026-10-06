extends SceneTree

var checks: int = 0
var failures: int = 0
var overlap_logged: bool = false

func _init() -> void:
	_run.call_deferred()

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		if failures <= 15:
			printerr("COLLISION FAIL: ", message)

func populated(ids: Array, counts: Array, rival_ids: Array = []) -> MatchState:
	var state := MatchState.new(311, "fire_commander", ids, "water_commander", rival_ids if not rival_ids.is_empty() else ids)
	state.config = state.config.duplicate(true)
	state.config.battle_limit_seconds = 300.0
	for side in range(2):
		for index in range(4):
			state.sides[side].roster[state.warband_for(side)[index]].count = counts[index]
	return state

func clear_bodies(sim: CombatSimulation, alpha: float = 1.0) -> bool:
	for index in range(sim.units.size()):
		var a: Dictionary = sim.units[index]
		if a.hp <= 0.0:
			continue
		var first: Vector2 = a.previous_position.lerp(a.position, alpha)
		if first.x < CombatSimulation.MIN_POSITION.x-0.001 or first.x > CombatSimulation.MAX_POSITION.x+0.001 or first.y < CombatSimulation.MIN_POSITION.y-0.001 or first.y > CombatSimulation.MAX_POSITION.y+0.001:
			return false
		for second_index in range(index+1, sim.units.size()):
			var b: Dictionary = sim.units[second_index]
			if b.hp <= 0.0:
				continue
			var delta: Vector2 = (first-b.previous_position.lerp(b.position, alpha)).abs()
			if delta.x < CombatSimulation.BODY_SIZE-0.001 and delta.y < CombatSimulation.BODY_SIZE-0.001:
				if not overlap_logged:
					overlap_logged = true
					printerr("First overlap tick=", sim.tick, " alpha=", alpha, " ids=", [a.id,b.id], " old=", [a.previous_position,b.previous_position], " new=", [a.position,b.position], " delta=", delta)
				return false
	return true

func freeze_attacks(sim: CombatSimulation) -> void:
	for value in sim.units:
		value.cooldown = 100000
		value.flanking = false
		value.teleport_used = true

func _run() -> void:
	_content()
	if OS.get_environment("VTUBER_COLLISION_ROUTES_ONLY") != "1":
		_spawn_and_crowds()
	_blocked_routes()
	_contact_and_determinism()
	print("\nCreature formations and permanent collision: %d checks; %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _content() -> void:
	expect(is_equal_approx(CombatSimulation.BODY_SIZE, 24.0*0.3), "collision width and height are 70 percent smaller")
	expect(CombatSimulation.SPAWN_SPACING == 24.0, "spawn spacing remains independent of smaller collision bodies")
	var names := {"fire_archer":"Fire Lizard", "fire_melee":"Fire Imp", "fire_tank":"Magma Golem", "fire_assassin":"Red Ninja",
		"water_mage":"Water Wizard", "water_tank":"Ice Golem", "water_melee":"Water Slime", "water_ranged":"Snowman",
		"earth_tank":"Tree", "earth_melee":"Armadillo", "earth_ranged":"Wood Archer", "earth_siege":"Wooden Siege"}
	var values := {"fire_archer":[3,34,9,1.0,34,138], "fire_melee":[3,64,8,1.05,39,20],
		"fire_tank":[1,220,7,.65,27,23], "fire_assassin":[1,60,13,1.55,62,19],
		"water_mage":[2,34,6,.60,30,146], "water_tank":[1,180,6,.55,24,23],
		"water_melee":[3,52,6,.90,35,21], "water_ranged":[3,34,7,1.0,32,154],
		"earth_tank":[1,250,6,.55,22,25], "earth_melee":[2,80,10,.75,32,23],
		"earth_ranged":[2,44,13,.65,28,150], "earth_siege":[1,75,20,.20,17,220]}
	var cards: Dictionary = GameCatalog.cards()
	for id in names:
		var card: ArmyCardData = cards[id]
		expect(card.short_name == names[id], "requested creature name: "+id)
		expect(card.sprite.get_size() == Vector2(256,32), "eight animation frames: "+id)
		var actual: Array = [card.group_size, card.stats.max_hp, card.stats.damage, card.stats.attacks_per_second,
			card.stats.move_speed, card.stats.attack_range]
		var unchanged: bool = true
		for index in range(actual.size()):
			unchanged = unchanged and absf(float(actual[index])-float(values[id][index])) < 0.0001
		expect(unchanged, "army stats unchanged: "+id)

func _spawn_and_crowds() -> void:
	var warbands: Array = [GameCatalog.FIRE_IDS, GameCatalog.WATER_IDS, GameCatalog.EARTH_IDS,
		["fire_tank","water_tank","earth_tank","earth_melee"],
		["fire_archer","water_ranged","earth_ranged","water_mage"]]
	for ids in warbands:
		var state := populated(ids, [18,18,18,18])
		var sim := CombatSimulation.new(state)
		expect(sim.units.size() == 144, "both sides support their full 72-unit cap")
		expect(clear_bodies(sim), "dense and duplicate-role spawn footprints never overlap")
		var left: Array = CombatSimulation.spawn_layout(state, 0)
		var right: Array = CombatSimulation.spawn_layout(state, 1)
		for index in range(left.size()):
			expect(left[index].position == sim.units[index].position, "preview and combat share exactly the same formation")
			expect(absf(left[index].position.x+right[index].position.x-600.0) < 0.001 and left[index].position.y == right[index].position.y, "equal armies get mirrored placements")
		freeze_attacks(sim)
		for tick in range(100):
			sim.step()
			expect(clear_bodies(sim), "collision remains on for a maximum-size moving crowd")
			if tick%10 == 0:
				for alpha in [.25,.5,.75]:
					expect(clear_bodies(sim, alpha), "render interpolation cannot clip moving bodies")
			for value in sim.units:
				expect(value.position.distance_to(value.previous_position) <= sim.cards[value.card_id].stats.move_speed/sim.config.ticks_per_second+0.001, "collision never teleports or accelerates a unit")
		# A single 24-unit army must also use unique slots.
	for id in GameCatalog.cards():
		var ids: Array = GameCatalog.realm_preset(id.get_slice("_",0))
		if not ids.has(id): ids[3] = id
		var state := populated(ids, [0,0,0,0])
		for side in range(2):
			state.sides[side].roster[id].count = 24
		expect(clear_bodies(CombatSimulation.new(state)), "24 units of one army do not reuse slots: "+id)

func _blocked_routes() -> void:
	var state := populated(GameCatalog.FIRE_IDS, [0,1,2,0])
	# Only a stationary distant enemy remains on the right.
	state.sides[1].roster.fire_melee.count = 0
	state.sides[1].roster.fire_tank.count = 1
	state.cards = state.cards.duplicate(true)
	state.cards.fire_tank = state.cards.fire_tank.duplicate(true)
	state.cards.fire_tank.stats.move_speed = 0.0
	var sim := CombatSimulation.new(state)
	freeze_attacks(sim)
	var walker: Dictionary = sim.units[0]
	walker.position = Vector2(180,100)
	sim.units[1].position = Vector2(228,100-CombatSimulation.BODY_SIZE/2.0)
	sim.units[2].position = Vector2(228,100+CombatSimulation.BODY_SIZE/2.0)
	var target: Dictionary = sim.units[3]
	target.position = Vector2(360,100)
	for value in sim.units:
		value.previous_position = value.position
	var went_around: bool = false
	for tick in range(320):
		sim.step()
		went_around = went_around or absf(walker.position.y-100.0) >= CombatSimulation.BODY_SIZE*1.5-0.01
		expect(clear_bodies(sim), "fighter routes around allied wall without clipping")
	expect(went_around, "blocked fighter uses a side lane rather than stacking")
	expect(sim.in_attack_range(walker,target), "blocked fighter continues until it reaches enemy contact")
	# The preferred upper detour must not trap a fighter against the boundary.
	walker.position = Vector2(180,28)
	walker.navigation_bias = -1.0
	sim.units[1].position = Vector2(228,28)
	sim.units[2].position = Vector2(228,28+CombatSimulation.BODY_SIZE)
	target.position = Vector2(360,28)
	for value in sim.units:
		value.previous_position = value.position
	for tick in range(320):
		sim.step()
		expect(clear_bodies(sim), "boundary detour keeps all bodies inside and separate")
	expect(sim.in_attack_range(walker,target), "fighter changes escape side when a wall reaches the arena edge")
	# An assassin fights a hostile defender in reach, then pursues the backline.
	# Keep its real attack cycle enabled; freezing attacks would pin it at the
	# defender forever, which is correct contact behavior rather than a detour.
	state = populated(GameCatalog.FIRE_IDS, [0,0,0,1])
	state.sides[1].roster.fire_assassin.count = 0
	state.sides[1].roster.fire_tank.count = 1
	state.sides[1].roster.fire_archer.count = 1
	for id in ["fire_tank","fire_archer"]:
		state.cards[id] = state.cards[id].duplicate(true)
		state.cards[id].stats.move_speed = 0.0
	sim = CombatSimulation.new(state)
	freeze_attacks(sim)
	walker = sim.units[0]
	walker.cooldown = 0.0
	walker.position = Vector2(180,100)
	target = sim.units[1]
	target.position = Vector2(380,100)
	sim.units[2].position = Vector2(250,100)
	for value in sim.units:
		value.previous_position = value.position
	var reached_backline: bool = false
	for tick in range(480):
		sim.step()
		expect(clear_bodies(sim), "hostile bodies also block the assassin's path")
		reached_backline = reached_backline or sim.in_attack_range(walker,target)
	expect(reached_backline, "assassin fights through a blocking tank and reaches its preferred backline")

func _contact_and_determinism() -> void:
	var state := populated(GameCatalog.FIRE_IDS, [0,1,0,0])
	var sim := CombatSimulation.new(state)
	sim.units[0].position = Vector2(200,100)
	sim.units[1].position = Vector2(210,100)
	freeze_attacks(sim)
	sim.step()
	expect(clear_bodies(sim) and sim.units[0].position.distance_to(sim.units[1].position) < 24.0, "sprites can crowd together while their smaller collision bodies stay separate")
	sim = CombatSimulation.new(state)
	sim.units[0].position = Vector2(200,100)
	sim.units[1].position = Vector2(380,100)
	for value in sim.units:
		value.previous_position = value.position
	expect(not sim.in_attack_range(sim.units[0],sim.units[1]), "distant melee target starts out of range")
	var hp: float = sim.units[1].hp
	sim.step()
	expect(sim.units[0].position.x > 200.0 and sim.units[1].hp == hp, "out-of-range attacker moves closer and cannot hit remotely")
	var contact: bool = false
	for tick in range(180):
		sim.step()
		expect(clear_bodies(sim), "opposing melee bodies never enter each other")
		contact = contact or sim.units[1].hp < hp
	expect(contact, "short-range melee actually lands attacks at solid body contact")
	state = populated(["fire_melee","water_melee","earth_tank","water_mage"], [6,6,3,4])
	var first := CombatSimulation.new(state)
	var second := CombatSimulation.new(state)
	for tick in range(180):
		first.step()
		second.step()
		expect(first.signature() == second.signature(), "navigation and collision stay fixed-tick deterministic")
		expect(clear_bodies(first), "mixed teams remain solid during live attacks")
