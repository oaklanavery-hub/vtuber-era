extends SceneTree

var checks: int = 0
var failures: int = 0

func _init() -> void:
	_run.call_deferred()

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		if failures <= 20:
			printerr("ACTIVE SKILL FAIL: ", message)

func near(a: float, b: float) -> bool:
	return absf(a-b) < 0.001

func warband(counts: Dictionary) -> Array:
	var ids: Array = counts.keys()
	for id in GameCatalog.ARMY_IDS:
		if ids.size() == 4:
			break
		if not ids.has(id):
			ids.append(id)
	return ids

func fixture(leader: String, own: Dictionary, rival: String, enemy: Dictionary, prepared: Array = [false, false]) -> CombatSimulation:
	var state := MatchState.new(414, leader, warband(own), rival, warband(enemy))
	state.config = state.config.duplicate(true)
	state.config.battle_limit_seconds = 300.0
	for id in state.cards:
		state.cards[id] = state.cards[id].duplicate(true)
		state.cards[id].stats.fire_aura_radius = 0.0
	for side in range(2):
		state.sides[side].spell = prepared[side]
		var counts: Dictionary = own if side == 0 else enemy
		for id in counts:
			state.sides[side].roster[id].count = counts[id]
	var sim := CombatSimulation.new(state)
	for value in sim.units:
		value.cooldown = 100000
		value.flanking = false
		value.teleport_used = true
		value.next_flame = 100000
		value.next_ice = 100000
		value.next_heal = 100000
		value.next_bounce = 100000
		value.next_split_shot = 100000
	return sim

func unit(sim: CombatSimulation, id: String, side: int = 0) -> Dictionary:
	for value in sim.units:
		if value.card_id == id and value.side == side:
			return value
	return {}

func positions(sim: CombatSimulation) -> Array:
	return sim.units.map(func(value: Dictionary) -> Vector2: return value.position)

func buffers(sim: CombatSimulation) -> Array:
	var damage: Array = []
	damage.resize(sim.units.size())
	damage.fill(0.0)
	return damage

func add_wall(sim: CombatSimulation, rectangle: Rect2, side: int = 0) -> void:
	sim.walls.append({"id":sim.walls.size(), "side":side, "rect":rectangle})
	sim._build_navigation()

func bodies_clear(sim: CombatSimulation, alpha: float = 1.0) -> bool:
	for index in range(sim.units.size()):
		var first: Dictionary = sim.units[index]
		if first.hp <= 0.0:
			continue
		var position: Vector2 = first.previous_position.lerp(first.position, alpha)
		for wall in sim.walls:
			if wall.rect.grow(CombatSimulation.BODY_SIZE/2.0-0.001).has_point(position):
				return false
		for other in range(index+1, sim.units.size()):
			var second: Dictionary = sim.units[other]
			if second.hp <= 0.0:
				continue
			var delta: Vector2 = (position-second.previous_position.lerp(second.position, alpha)).abs()
			if delta.x < CombatSimulation.BODY_SIZE-0.001 and delta.y < CombatSimulation.BODY_SIZE-0.001:
				return false
	return true

func _run() -> void:
	_economy()
	_meteors()
	_meteor_deaths()
	_frozen_field()
	_wall_routes()
	_wall_shots()
	_births_and_pushback()
	_dense_and_replays()
	print("\nCommander active skills: %d checks; %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _economy() -> void:
	for realm in GameCatalog.REALMS:
		var state := MatchState.new(71, realm+"_commander")
		for side in range(2):
			var before: String = JSON.stringify(state.sides[side].offers)
			var rng_state: int = state.rng.state
			expect(state.prepare_spell(side) and state.sides[side].points == 2, "active skill costs exactly one point on either team")
			expect(not state.prepare_spell(side) and state.sides[side].points == 2, "cannot prepare twice in one round")
			expect(before == JSON.stringify(state.sides[side].offers) and rng_state == state.rng.state, "preparing preserves offers and RNG")
		state.phase = "round_result"
		state.begin_round()
		expect(not state.sides[0].spell and not state.sides[1].spell, "next round requires a new paid skill")
		state.phase = "combat"
		expect(not state.prepare_spell(0), "cannot cast from combat input")

func _meteors() -> void:
	var sim := fixture("fire_commander", {"fire_tank":1}, "fire_commander", {"fire_melee":2}, [true,false])
	var enemies: Array = sim.units.filter(func(value: Dictionary) -> bool: return value.side == 1)
	enemies[0].position = Vector2(356,140)
	enemies[1].position = Vector2(380,140)
	for value in sim.units:
		value.hp = 1000.0
		value.max_hp = 1000.0
		value.shield = 0.0
	var before: Array = positions(sim)
	sim.step()
	expect(sim.meteors.size() == 6 and sim.opening_active(), "Fire schedules exactly six opening meteors")
	var impacts: int = 0
	while sim.opening_active():
		sim.step()
		for event in sim.events:
			if event.kind == "meteor_impact":
				impacts += 1
		expect(sim.tick == 0 and positions(sim) == before and sim.projectiles.is_empty(), "troops and battle clock wait for all meteor strikes")
		expect(sim.units[0].cooldown == 100000, "opening does not consume attack cooldowns")
	expect(impacts == 6 and sim.skill_counts.meteors == [6,0], "all six meteors visibly resolve once")
	expect(near(enemies[0].hp,970.0) and near(enemies[1].hp,970.0), "one meteor deals configured damage to multiple nearby enemies")
	expect(near(sim.units[0].hp,1000.0), "meteor damage never hits its caster's troops")
	sim.step()
	expect(sim.tick == 1 and not sim.spell_active(0), "battle begins after the opening, without recasting")
	var mirrored := fixture("fire_commander", {"fire_melee":3,"fire_tank":2}, "fire_commander", {"fire_melee":3,"fire_tank":2}, [true,true])
	var left: Array = mirrored._meteor_layout(0,6)
	var right: Array = mirrored._meteor_layout(1,6)
	for index in range(6):
		expect(near(left[index].x+right[index].x,600.0) and near(left[index].y,right[index].y), "meteor targeting mirrors for both teams")
	var draw := fixture("fire_commander", {"fire_tank":1}, "fire_commander", {"fire_tank":1}, [true,true])
	for value in draw.units:
		value.hp = 1.0
		value.shield = 0.0
	for step in range(90):
		if not draw.finished:
			draw.step()
	expect(draw.finished and draw.result.winner == -1 and draw.skill_counts.meteors == [6,6], "simultaneous opening defeat is fair and still resolves all six strikes per side")
	expect(draw.walls.is_empty() and draw.meteors.is_empty() and not draw.spell_prepared[0], "opening defeat cleans temporary skill state")

func _meteor_deaths() -> void:
	var sim := fixture("fire_commander", {"fire_tank":1}, "fire_commander", {"fire_assassin":1,"water_melee":1}, [true,false])
	var ninja: Dictionary = unit(sim,"fire_assassin",1)
	var slime: Dictionary = unit(sim,"water_melee",1)
	ninja.position = Vector2(404,140)
	slime.position = Vector2(380,140)
	ninja.hp = 1.0
	slime.hp = 1.0
	for value in sim.units:
		value.shield = 0.0
	for step in range(61):
		sim.step()
	expect(ninja.revive_used and near(ninja.hp,ninja.max_hp*.3), "meteor kills trigger Ninja's one-time 30% revival")
	var children: Array = sim.units.filter(func(value: Dictionary) -> bool: return value.is_child)
	expect(children.size() == 2, "meteor kills trigger Slime's two children")
	for child in children:
		expect(near(child.damage,slime.damage*.5), "meteor-born Slime children retain half base damage")
	expect(bodies_clear(sim), "opening revivals and births keep collision bodies separate")

func _frozen_field() -> void:
	var sim := fixture("water_commander", {"water_mage":1,"fire_tank":1}, "earth_commander", {"earth_tank":1,"fire_melee":1}, [true,false])
	sim._activate_skills()
	for value in sim.units:
		var speed: float = sim.cards[value.card_id].stats.move_speed
		expect(near(sim.move_speed(value),speed*(.85 if value.side == 1 else 1.0)), "Frozen Field slows every enemy realm by 15% and leaves allies unchanged")
		expect(near(sim.defence_multiplier(value),.92 if value.side == 1 else 1.0), "Frozen Field reduces only enemy defence by exactly 8%")
	var tank: Dictionary = unit(sim,"earth_tank",1)
	expect(near(sim.damage_multiplier(tank),.95/.92), "Water defence reduction composes with Earth commander's passive")
	tank.slow_fraction = .25
	tank.slow_until = 10
	expect(near(sim.move_speed(tank),sim.cards.earth_tank.stats.move_speed*.75), "stronger movement slows take priority instead of stacking")
	sim.tick = 10
	expect(near(sim.move_speed(tank),sim.cards.earth_tank.stats.move_speed*.85), "field slow remains after a stronger slow expires")
	tank.shield = 120.0
	var damage: Array = buffers(sim)
	damage[tank.id] = 100.0
	sim._settle_damage(damage,[])
	expect(near(tank.shield,120.0-100.0*.95/.92) and near(tank.hp,tank.max_hp), "defence applies before shield absorption, exactly once")
	sim._clear_statuses(tank)
	sim.tick = 9000
	expect(near(sim.defence_multiplier(tank),.92) and sim.spell_active(0), "global ice survives status clearing and lasts the whole round")
	sim._finish(0,"test")
	expect(near(sim.defence_multiplier(tank),1.0) and near(sim.move_speed(tank),sim.cards.earth_tank.stats.move_speed), "ice debuffs fully clear at round end")
	var children_sim := fixture("water_commander", {"fire_tank":1}, "fire_commander", {"water_melee":1,"fire_assassin":1}, [true,false])
	children_sim._activate_skills()
	damage = buffers(children_sim)
	for value in children_sim.units:
		if value.side == 1:
			damage[value.id] = 10000.0
	children_sim._settle_damage(damage,[])
	children_sim._birth_children()
	for value in children_sim.units:
		if value.side == 1 and value.hp > 0.0:
			expect(near(children_sim.defence_multiplier(value),.92) and near(children_sim.move_speed(value),children_sim.cards[value.card_id].stats.move_speed*.85), "children and revived Ninjas inherit field debuffs")

func _wall_routes() -> void:
	var sim := fixture("fire_commander", {"fire_melee":1}, "earth_commander", {"earth_tank":1})
	var walker: Dictionary = unit(sim,"fire_melee")
	var enemy: Dictionary = unit(sim,"earth_tank",1)
	walker.position = Vector2(240,140)
	enemy.position = Vector2(350,140)
	sim.cards.earth_tank.stats.move_speed = 0.0
	add_wall(sim,Rect2(290,76,12,128))
	var went_around: bool = false
	for step in range(360):
		sim.step()
		went_around = went_around or walker.position.y < 73.0 or walker.position.y > 207.0
		expect(bodies_clear(sim) and bodies_clear(sim,.5), "melee routes around a tall wall without clipping at endpoints or interpolation")
	expect(went_around and sim.can_attack(walker,enemy), "blocked melee reaches enemy contact around the wall")
	var ranged := fixture("fire_commander", {"fire_archer":1}, "earth_commander", {"earth_tank":1})
	var archer: Dictionary = unit(ranged,"fire_archer")
	enemy = unit(ranged,"earth_tank",1)
	archer.position = Vector2(240,140)
	archer.cooldown = 0
	enemy.position = Vector2(350,140)
	ranged.cards.earth_tank.stats.move_speed = 0.0
	add_wall(ranged,Rect2(290,76,12,128))
	expect(ranged.in_attack_range(archer,enemy) and not ranged.can_attack(archer,enemy), "range alone cannot authorize a shot through a wall")
	var fired: bool = false
	for step in range(300):
		ranged.step()
		for event in ranged.events:
			if event.kind == "attack":
				fired = true
				expect(ranged.line_of_sight(archer.position,enemy.position), "repositioned ranged unit only shoots with clear line of sight")
		expect(bodies_clear(ranged), "ranged repositioning respects walls")
	expect(fired and archer.position != Vector2(240,140), "in-range but obscured archer moves to a clear shooting position")
	var alternate := fixture("earth_commander", {"earth_ranged":1}, "fire_commander", {"fire_tank":2})
	archer = alternate.units[0]
	archer.position = Vector2(240,140)
	alternate.units[1].position = Vector2(350,140)
	alternate.units[2].position = Vector2(240,70)
	add_wall(alternate,Rect2(290,76,12,128))
	expect(alternate._target(archer) == 2, "ranged attacker prefers an available visible target")
	alternate._attack(archer,alternate.units[2],buffers(alternate),[],true)
	expect(alternate.projectiles.size() == 3, "Wood Archer still fires its three-arrow passive")
	for shot in alternate.projectiles:
		expect(shot.target == 2, "split arrows never select an obscured secondary target")

func _wall_shots() -> void:
	for id in ["fire_archer","water_mage","water_ranged","earth_ranged","earth_siege"]:
		for posthumous in [false,true] if id == "water_ranged" else [false]:
			var sim := fixture("fire_commander", {id:1}, "earth_commander", {"earth_tank":1})
			var shooter: Dictionary = sim.units[0]
			var enemy: Dictionary = sim.units[1]
			shooter.position = Vector2(240,140)
			enemy.position = Vector2(350,140)
			add_wall(sim,Rect2(290,76,12,128))
			sim._projectile(shooter,enemy,1000.0,0,posthumous)
			sim.projectiles[0].speed = 30000.0
			var damage: Array = buffers(sim)
			sim._advance_projectiles(positions(sim),damage,[])
			expect(sim.projectiles.is_empty() and damage[enemy.id] == 0.0 and sim.skill_counts.blocked_projectiles == 1, "wall absorbs fast projectile and splash before damage: "+id)
			expect(sim.events.any(func(event: Dictionary) -> bool: return event.kind == "wall_hit"), "projectile collision produces a visible wall impact")
	var final_gap := fixture("fire_commander", {"fire_archer":1}, "earth_commander", {"earth_tank":1})
	final_gap.units[0].position = Vector2(240,140)
	final_gap.units[1].position = Vector2(320,140)
	add_wall(final_gap,Rect2(308,90,4,100))
	final_gap._projectile(final_gap.units[0],final_gap.units[1],100.0)
	final_gap.projectiles[0].position = Vector2(300,140)
	final_gap.projectiles[0].speed = 420.0
	var damage: Array = buffers(final_gap)
	final_gap._advance_projectiles(positions(final_gap),damage,[])
	expect(damage[1] == 0.0 and final_gap.projectiles.is_empty(), "last seven pixels of projectile travel cannot tunnel through a wall")
	expect(not final_gap.line_of_sight(Vector2(300,140),Vector2(320,140)) and final_gap.line_of_sight(Vector2(300,70),Vector2(320,70)), "vision is blocked through walls and clear around their ends")

func _births_and_pushback() -> void:
	var sim := fixture("water_commander", {"water_mage":1}, "earth_commander", {"water_melee":1})
	sim.units[0].position = Vector2(240,140)
	sim.units[1].position = Vector2(340,140)
	add_wall(sim,Rect2(350,90,12,100))
	sim._projectile(sim.units[0],sim.units[1],1.0)
	sim.projectiles[0].speed = 30000.0
	var movements: Array = positions(sim)
	var forces: Dictionary = sim._advance_projectiles(movements,buffers(sim),[])
	expect(forces.has(1), "Wizard projectile still generates knockback")
	movements[1] += forces[1]
	sim._resolve_movements(movements,forces)
	expect(movements[1].x <= 346.4 and movements[1].x >= 340.0, "knockback stops at the wall instead of tunnelling or detouring")
	var damage: Array = buffers(sim)
	damage[1] = 10000.0
	sim._settle_damage(damage,[])
	sim._birth_children()
	expect(sim.units.size() == 4 and bodies_clear(sim), "Slime children are born outside solid walls and other bodies")
	for child in sim.units:
		if child.is_child:
			expect(sim._wall_path_clear(sim.units[1].position,child.position,CombatSimulation.BODY_SIZE/2.0), "children cannot spawn across a blocking wall")
	var clipped: Vector2 = sim._clip_motion(Vector2(280,140),Vector2(250,0),[],[],0)
	expect(absf(280.0+clipped.x-346.4) < 0.01 and clipped.x < 70.0, "swept static collision clips an arbitrarily large movement step")

func _dense_and_replays() -> void:
	for pair in [["earth","earth"],["fire","earth"],["water","earth"],["earth","water"]]:
		var own: Dictionary = {}
		var enemy: Dictionary = {}
		for id in GameCatalog.realm_preset(pair[0]):
			own[id] = 18
		for id in GameCatalog.realm_preset(pair[1]):
			enemy[id] = 18
		var first := fixture(pair[0]+"_commander",own,pair[1]+"_commander",enemy,[true,true])
		var second := fixture(pair[0]+"_commander",own,pair[1]+"_commander",enemy,[true,true])
		first._activate_skills()
		second._activate_skills()
		expect(first.units.size() == 144 and bodies_clear(first), "walls grow safely through a fully populated formation")
		var expected_walls: int = 3*int(pair[0] == "earth")+3*int(pair[1] == "earth")
		expect(first.walls.size() == expected_walls, "every Earth cast produces three walls, including both sides together")
		for step in range(120):
			first.step()
			second.step()
			expect(first.signature() == second.signature(), "opening, terrain, navigation and skills replay deterministically: "+str(pair))
			expect(bodies_clear(first) and bodies_clear(first,.5), "full crowds remain solid around walls: "+str(pair))
		first._finish(0,"test")
		expect(first.walls.is_empty() and first.navigation_nodes.is_empty() and first.navigation_distances.is_empty(), "round end removes walls and their navigation graph")
