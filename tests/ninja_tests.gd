extends SceneTree

var checks: int = 0
var failures: int = 0

func _init() -> void:
	_run.call_deferred()

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		if failures <= 20: printerr("NINJA FAIL: ", message)

func fixture(own: Dictionary, enemy: Dictionary) -> CombatSimulation:
	var first: Array = own.keys()
	var second: Array = enemy.keys()
	for id in GameCatalog.ARMY_IDS:
		if first.size() < 4 and not first.has(id): first.append(id)
		if second.size() < 4 and not second.has(id): second.append(id)
	var state := MatchState.new(123, "fire_commander", first, "fire_commander", second)
	state.config = state.config.duplicate(true)
	state.config.battle_limit_seconds = 300.0
	for id in state.cards:
		state.cards[id] = state.cards[id].duplicate(true)
		state.cards[id].stats.fire_aura_radius = 0.0
		if id != "fire_assassin": state.cards[id].stats.move_speed = 0.0
	for id in own: state.sides[0].roster[id].count = own[id]
	for id in enemy: state.sides[1].roster[id].count = enemy[id]
	var sim := CombatSimulation.new(state)
	for unit in sim.units:
		if unit.card_id != "fire_assassin":
			unit.cooldown = 100000.0
			unit.hp = 10000.0
			unit.max_hp = 10000.0
	return sim

func place(unit: Dictionary, position: Vector2) -> void:
	unit.position = position
	unit.previous_position = position

func ninjas(sim: CombatSimulation) -> Array:
	return sim.units.filter(func(unit: Dictionary) -> bool: return unit.role == "assassin")

func _run() -> void:
	_charge_and_landing()
	_wall_landings()
	_pursuit_and_revival()
	_charge_revival_and_reset()
	_meteor_opening()
	_simultaneous_mirrors()
	print("\nNinja teleport, pursuit and resurrection: %d checks; %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _charge_and_landing() -> void:
	for ninja_side in range(2):
		var own := {"fire_assassin":3}
		var rival := {"earth_ranged":2,"fire_tank":3}
		var sim := fixture(own if ninja_side == 0 else rival,rival if ninja_side == 0 else own)
		var origins: Array = ninjas(sim).map(func(unit: Dictionary) -> Vector2: return unit.position)
		for frame in range(60):
			sim.step()
			for index in range(3):
				var unit: Dictionary = ninjas(sim)[index]
				expect(unit.position == origins[index] and not unit.teleport_used and unit.first_attack,"Ninja charges for two full seconds without moving or attacking")
			expect(solid(sim),"charging units keep solid bodies")
		sim.step()
		var rear: float = -INF
		var direction: float = 1.0 if ninja_side == 0 else -1.0
		for unit in sim.units:
			if unit.side != ninja_side: rear = maxf(rear,unit.position.x*direction)
		for unit in ninjas(sim):
			expect(unit.teleport_used and unit.teleport_at == 60,"teleport happens exactly after the sixty-tick animation")
			expect(unit.position.x*direction > rear,"teleport lands behind the complete enemy line on either side")
			expect(unit.previous_position.distance_to(unit.position) < 3.0,"teleport never interpolates a travel path across other armies")
		expect(sim.passive_counts.get("ninja_charge",0) == 3 and sim.passive_counts.get("ninja_teleport",0) == 3,"all three Ninjas emit one visible charge and arrival")
		expect(solid(sim),"simultaneous teleport destinations never overlap")
	# Being in reach at the opening cannot bypass the requested animation.
	var sim := fixture({"fire_assassin":1},{"earth_ranged":1})
	place(sim.units[0],Vector2(240,100))
	place(sim.units[1],Vector2(255,100))
	var hp: float = sim.units[1].hp
	sim.step()
	expect(sim.units[1].hp == hp and sim.units[0].first_attack,"opening contact still waits for the teleport charge")
	# Against a melee-only enemy, blink behind that line and then fight normally.
	sim = fixture({"fire_assassin":1},{"fire_tank":1})
	for frame in range(61): sim.step()
	expect(sim.units[0].teleport_used and sim.units[0].position.x > sim.units[1].position.x,"teleport also works when there is no ranged backline")

func _wall_landings() -> void:
	for side in range(2):
		var own := {"fire_assassin":3}
		var rival := {"earth_ranged":1,"fire_tank":1}
		var sim := fixture(own if side == 0 else rival,rival if side == 0 else own)
		for unit in sim.units:
			if unit.side != side:
				place(unit,Vector2(500 if side == 0 else 100,100 if unit.role == "ranged" else 140))
		# Terrain blocks the preferred rear landing, rather than the blink's travel.
		sim.walls = [{"id":0,"side":side,"rect":Rect2(509 if side == 0 else 79,70,12,60)}]
		sim._build_navigation()
		for frame in range(90):
			sim.step()
			expect(solid(sim),"teleports and following pursuit respect wall and unit footprints")
		expect(ninjas(sim).all(func(unit: Dictionary) -> bool: return unit.teleport_used),"all Ninjas find a free rear landing when the preferred tile is blocked")
	# When the enemy's rear touches the arena edge, use an adjacent free lane.
	var edge := fixture({"fire_assassin":3},{"earth_ranged":1})
	place(edge.units.back(),Vector2(584,28))
	for frame in range(61): edge.step()
	expect(solid(edge) and ninjas(edge).all(func(unit: Dictionary) -> bool: return unit.teleport_used),"edge-clamped teleport finds separate legal flanking positions")

func _pursuit_and_revival() -> void:
	for ninja_side in range(2):
		var own := {"fire_assassin":3}
		var rival := {"earth_ranged":2,"fire_tank":3}
		var first := fixture(own if ninja_side == 0 else rival,rival if ninja_side == 0 else own)
		var replay := fixture(own if ninja_side == 0 else rival,rival if ninja_side == 0 else own)
		for frame in range(240):
			first.step()
			replay.step()
			expect(first.signature() == replay.signature(),"charge, landing and actual attacks replay deterministically")
			expect(solid(first),"post-teleport pursuit keeps permanent collision")
		expect(ninjas(first).all(func(unit: Dictionary) -> bool: return not unit.first_attack),"all three Ninjas reach contact and attack after teleporting")
		var unit: Dictionary = ninjas(first)[0]
		var landing_tick: int = unit.teleport_at
		var damage: Array = []
		damage.resize(first.units.size())
		damage.fill(0.0)
		damage[int(unit.id)] = unit.hp+1.0
		first._settle_damage(damage,[])
		expect(unit.revive_used and is_equal_approx(unit.hp,unit.max_hp*0.3),"Ninja still resurrects once with exactly thirty percent HP")
		expect(unit.teleport_used and unit.teleport_at == landing_tick and unit.cooldown == first._attack_cooldown(unit),"resurrection preserves the spent teleport and resumes its normal attack cycle")
		for frame in range(65): first.step()
		expect(first.passive_counts.ninja_teleport == 3,"resurrection never grants a second teleport")
		expect(solid(first),"revived pursuit remains collision-safe")
	# A solid defender in reach must be attacked before a distant backline.
	var sim := fixture({"fire_assassin":1},{"fire_tank":1,"earth_ranged":1})
	place(sim.units[0],Vector2(280,100))
	place(sim.units[1],Vector2(295,100))
	place(sim.units[2],Vector2(520,100))
	sim.units[0].teleport_used = true
	var hp: float = sim.units[1].hp
	sim.step()
	expect(sim.units[0].target == 1 and sim.units[1].hp < hp,"a post-teleport Ninja fights a reachable blocker instead of walking through it")

func _charge_revival_and_reset() -> void:
	var sim := fixture({"fire_assassin":1},{"fire_tank":1})
	place(sim.units[0],Vector2(200,100))
	place(sim.units[1],Vector2(219,100))
	sim.units[0].hp = 1.0
	sim.units[1].damage = 1000.0
	sim.units[1].cooldown = 0.0
	sim.step()
	expect(sim.units[0].revive_used and not sim.units[0].teleport_used,"death during the animation does not cancel an unused teleport")
	sim.units[1].cooldown = 100000.0
	for frame in range(60): sim.step()
	expect(sim.units[0].teleport_at == 60,"revival during the charge keeps the original two-second deadline")
	sim._finish(0,"Cleanup fixture")
	expect(not sim.teleport_charging(sim.units[0]),"round cleanup removes the charge indicator")
	var next := fixture({"fire_assassin":1},{"fire_tank":1})
	expect(not next.units[0].teleport_used and not next.units[0].revive_used,"a fresh battle restores both one-use passives")

func _meteor_opening() -> void:
	var sim := fixture({"fire_assassin":1},{"earth_ranged":1})
	sim.spell_prepared[0] = true
	var start: Vector2 = sim.units[0].position
	for frame in range(60):
		sim.step()
		expect(sim.tick == 0 and sim.units[0].position == start and not sim.units[0].teleport_started,"meteor opening cannot consume the Ninja's two-second charge")
	expect(sim.skill_counts.meteors[0] == 6,"all meteors finish before the Ninja charge begins")
	for frame in range(60): sim.step()
	expect(not sim.units[0].teleport_used,"Ninja still receives two full combat seconds after meteors")
	sim.step()
	expect(sim.units[0].teleport_at == 60 and solid(sim),"post-meteor teleport uses the same deadline and collision rules")

func _simultaneous_mirrors() -> void:
	var sim := fixture({"fire_assassin":3},{"fire_assassin":3})
	var rear: Array = [-INF,-INF]
	for unit in sim.units:
		unit.cooldown = 100000.0
		var direction: float = 1.0 if unit.side == 1 else -1.0
		rear[int(unit.side)] = maxf(rear[int(unit.side)], unit.position.x*direction)
	for frame in range(61): sim.step()
	for unit in sim.units:
		var direction: float = 1.0 if unit.side == 0 else -1.0
		expect(unit.teleport_used and unit.previous_position.x*direction > float(rear[1-int(unit.side)]),"both Ninja-only teams blink behind the original opposing line")
	for index in range(3):
		var a: Vector2 = sim.units[index].previous_position
		var b: Vector2 = sim.units[index+3].previous_position
		expect(is_equal_approx(a.x,600.0-b.x) and is_equal_approx(a.y,b.y),"simultaneous mirror teleports have no team-order advantage")
	expect(sim.passive_counts.ninja_teleport == 6 and solid(sim),"all six simultaneous mirror landings remain collision-safe")

func solid(sim: CombatSimulation) -> bool:
	for alpha in [0.0,0.25,0.5,0.75,1.0]:
		for index in range(sim.units.size()):
			var a: Dictionary = sim.units[index]
			if a.hp <= 0.0: continue
			var position: Vector2 = a.previous_position.lerp(a.position,alpha)
			if position.x < CombatSimulation.MIN_POSITION.x-0.001 or position.x > CombatSimulation.MAX_POSITION.x+0.001 or position.y < CombatSimulation.MIN_POSITION.y-0.001 or position.y > CombatSimulation.MAX_POSITION.y+0.001: return false
			for wall in sim.walls:
				if wall.rect.grow(CombatSimulation.BODY_SIZE/2.0-0.001).has_point(position): return false
			for next in range(index+1,sim.units.size()):
				var b: Dictionary = sim.units[next]
				if b.hp <= 0.0: continue
				var delta: Vector2 = (position-b.previous_position.lerp(b.position,alpha)).abs()
				if delta.x < CombatSimulation.BODY_SIZE-0.001 and delta.y < CombatSimulation.BODY_SIZE-0.001: return false
	return true
