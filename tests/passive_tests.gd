extends SceneTree

var checks: int = 0
var failures: int = 0

func _init() -> void:
	_run.call_deferred()

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		if failures <= 30:
			printerr("PASSIVE FAIL: ", message)

func near(a: float, b: float) -> bool:
	return absf(a-b) < 0.0001

func warband(counts: Dictionary) -> Array:
	var ids: Array = counts.keys()
	for id in GameCatalog.ARMY_IDS:
		if ids.size() < 4 and not ids.has(id):
			ids.append(id)
	return ids

func fixture(own: Dictionary, enemy: Dictionary = {"fire_tank":1}) -> CombatSimulation:
	var state := MatchState.new(123, "fire_commander", warband(own), "fire_commander", warband(enemy))
	state.config = state.config.duplicate(true)
	state.config.battle_limit_seconds = 300.0
	state.bond = null
	state.bonds = [null,null]
	for side in range(2):
		state.commanders[side] = state.commanders[side].duplicate(true)
		var leader: CommanderData = state.commanders[side]
		leader.attack_damage_bonus = 0.0
		leader.matching_attack_speed_bonus = 0.0
		leader.max_hp_bonus = 0.0
		leader.matching_max_hp_bonus = 0.0
		leader.damage_reduction = 0.0
		leader.matching_healing_shield_bonus = 0.0
	state.commander = state.commanders[0]
	for id in state.cards:
		state.cards[id] = state.cards[id].duplicate(true)
		state.cards[id].stats.move_speed = 0.0
		state.cards[id].stats.fire_aura_radius = 0.0
	for id in own:
		state.sides[0].roster[id].count = own[id]
	for id in enemy:
		state.sides[1].roster[id].count = enemy[id]
	var sim := CombatSimulation.new(state)
	for value in sim.units:
		value.cooldown = 100000.0
		value.shield = 0.0
		value.flanking = false
		value.teleport_used = true
	return sim

func army(sim: CombatSimulation, id: String, side: int = 0) -> Array:
	return sim.units.filter(func(value: Dictionary) -> bool: return value.card_id == id and value.side == side)

func place(value: Dictionary, location: Vector2) -> void:
	value.position = location
	value.previous_position = location
	value.ice_anchor = location

func steps(sim: CombatSimulation, count: int) -> void:
	for index in range(count):
		sim.step()

func land(sim: CombatSimulation) -> void:
	var count: int = 0
	while not sim.projectiles.is_empty() and count < 120:
		sim.step()
		count += 1
	expect(sim.projectiles.is_empty(), "projectiles reach their impacts in finite time")

func solid(sim: CombatSimulation) -> bool:
	for alpha in [0.0,0.25,0.5,0.75,1.0]:
		for index in range(sim.units.size()):
			var a: Dictionary = sim.units[index]
			if a.hp <= 0.0:
				continue
			var first: Vector2 = a.previous_position.lerp(a.position,alpha)
			if first.x < CombatSimulation.MIN_POSITION.x-0.001 or first.x > CombatSimulation.MAX_POSITION.x+0.001 or first.y < CombatSimulation.MIN_POSITION.y-0.001 or first.y > CombatSimulation.MAX_POSITION.y+0.001:
				return false
			for second in range(index+1,sim.units.size()):
				var b: Dictionary = sim.units[second]
				if b.hp > 0.0:
					var delta: Vector2 = (first-b.previous_position.lerp(b.position,alpha)).abs()
					if delta.x < CombatSimulation.BODY_SIZE-0.001 and delta.y < CombatSimulation.BODY_SIZE-0.001:
						return false
	return true

func _run() -> void:
	_lizard()
	_imps()
	_imp_blast()
	_flames()
	_ninjas()
	_pushback()
	_ice()
	_slimes()
	_snowmen()
	_trees()
	_armadillos()
	_arrows()
	_siege()
	_crowds_and_replay()
	_persistence_and_reset()
	print("\nArmy passives: %d checks; %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func _lizard() -> void:
	var sim := fixture({"fire_archer":1,"fire_tank":1}, {"fire_tank":3})
	var lizard: Dictionary = army(sim,"fire_archer")[0]
	var enemies: Array = army(sim,"fire_tank",1)
	place(lizard,Vector2(100,100))
	place(enemies[0],Vector2(200,100))
	place(enemies[1],Vector2(200,112))
	place(enemies[2],Vector2(200,124))
	var ally: Dictionary = army(sim,"fire_tank")[0]
	place(ally,Vector2(200,88))
	lizard.cooldown = 0.0
	sim.step()
	expect(enemies[0].hp == enemies[0].max_hp, "Lizard damage waits for projectile travel")
	land(sim)
	expect(near(enemies[0].hp,enemies[0].max_hp-9.0), "Lizard primary receives full attack damage")
	expect(near(enemies[1].hp,enemies[1].max_hp-4.5), "every Lizard projectile splashes nearby enemies")
	expect(enemies[2].hp == enemies[2].max_hp and ally.hp == ally.max_hp, "small splash excludes distant enemies and allies")
	expect(sim.passive_counts.get("lizard_splash",0) == 1, "Lizard splash emits a visible ability event")

func _imps() -> void:
	var sim := fixture({"fire_melee":1,"fire_tank":1}, {"fire_melee":1,"fire_tank":1})
	var imp: Dictionary = army(sim,"fire_melee")[0]
	var ally: Dictionary = army(sim,"fire_tank")[0]
	var enemy_imp: Dictionary = army(sim,"fire_melee",1)[0]
	var killer: Dictionary = army(sim,"fire_tank",1)[0]
	place(imp,Vector2(200,100))
	place(ally,Vector2(200,116))
	place(enemy_imp,Vector2(218,112))
	place(killer,Vector2(218,100))
	imp.hp = 1.0
	enemy_imp.hp = 1.0
	killer.damage = 2.0
	killer.cooldown = 0.0
	var own_hp: float = ally.hp
	var enemy_hp: float = killer.hp
	sim.step()
	expect(imp.hp == 0.0 and enemy_imp.hp == 0.0, "Imp death explosion can trigger an opposing death explosion")
	expect(near(killer.hp,enemy_hp-8.0) and near(ally.hp,own_hp-8.0), "simultaneous death waves hit enemies only, once per Imp")
	expect(sim.passive_counts.get("imp_explosion",0) == 2, "both explosions resolve without array-order recursion")
	steps(sim,5)
	expect(sim.passive_counts.imp_explosion == 2, "dead Imps cannot explode repeatedly")

func _imp_blast() -> void:
	var sim := fixture({"fire_melee":1,"fire_archer":1},{"fire_tank":3})
	var imp: Dictionary = army(sim,"fire_melee")[0]
	var ally: Dictionary = army(sim,"fire_archer")[0]
	var enemies: Array = army(sim,"fire_tank",1)
	place(imp,Vector2(200,100))
	place(ally,Vector2(188,100))
	place(enemies[0],Vector2(218,100))
	place(enemies[1],Vector2(200,118))
	place(enemies[2],Vector2(250,100))
	imp.hp = 1.0
	enemies[0].damage = 2.0
	enemies[0].cooldown = 0.0
	var hp: float = enemies[0].hp
	sim.step()
	expect(near(enemies[0].hp,hp-8.0) and enemies[0].blast_burn_until == 60,"Imp blast hits then starts its own two-second Burn")
	expect(enemies[1].blast_burn_until == 60 and enemies[2].blast_burn_until == 0 and ally.blast_burn_until == 0,"blast Burn affects only enemies inside the AOE")
	sim.step()
	expect(near(enemies[0].position.x,230.0) and near(enemies[1].position.y,130.0),"Imp pushes every nearby enemy radially by 12 pixels")
	expect(solid(sim),"radial pushes preserve body collision and interpolation")
	steps(sim,59)
	expect(near(enemies[0].hp,hp-14.0),"Imp Burn deals two ticks of three damage after leaving the blast")
	sim.step()
	expect(enemies[0].blast_burn_until == 0 and sim.passive_counts.imp_explosion == 1,"Burn expires and the corpse never explodes twice")
	# Existing Wildfire and flame-wall damage must remain independent of the blast.
	sim = fixture({"fire_melee":1,"fire_archer":1},{"fire_tank":1})
	imp = army(sim,"fire_melee")[0]
	var burned: Dictionary = army(sim,"fire_tank",1)[0]
	place(imp,Vector2(200,100))
	place(burned,Vector2(218,100))
	imp.hp = 1.0
	burned.damage = 2.0
	burned.cooldown = 0.0
	burned.burn_until = 90
	burned.burn_next = 30
	burned.burn_dps = 3.0
	burned.flame_until = 60
	burned.flame_next = 30
	burned.flame_dps = 3.0
	hp = burned.hp
	steps(sim,91)
	expect(near(burned.hp,hp-29.0),"blast Burn, flame-wall Burn and Wildfire retain all seven independent damage ticks")
	for wall_test in [false,true]:
		sim = fixture({"fire_melee":1,"fire_archer":1},{"fire_tank":2})
		imp = army(sim,"fire_melee")[0]
		enemies = army(sim,"fire_tank",1)
		place(imp,Vector2(200,100))
		place(enemies[0],Vector2(218,100))
		place(enemies[1],Vector2(227,100) if not wall_test else Vector2(280,100))
		if wall_test: sim.walls = [{"id":0,"side":0,"rect":Rect2(225,80,12,40)}]
		imp.hp = 1.0
		enemies[0].damage = 2.0
		enemies[0].cooldown = 0.0
		sim.step()
		sim.step()
		expect(enemies[0].position.x <= (225.0-CombatSimulation.BODY_SIZE/2.0+0.001 if wall_test else 227.0-CombatSimulation.BODY_SIZE+0.001),"Imp pushback stops at terrain or another army")
		expect(solid(sim),"blocked Imp pushback cannot clip through a body")

func _flames() -> void:
	var sim := fixture({"fire_tank":1,"fire_archer":1},{"water_tank":1})
	sim.cards.fire_tank.stats.fire_aura_radius = 48.0
	var golem: Dictionary = army(sim,"fire_tank")[0]
	var ally: Dictionary = army(sim,"fire_archer")[0]
	var enemy: Dictionary = army(sim,"water_tank",1)[0]
	place(golem,Vector2(200,100))
	place(ally,Vector2(214,112))
	place(enemy,Vector2(248,100))
	var before: float = enemy.hp
	steps(sim,30)
	expect(near(enemy.hp,before-3.0) and near(ally.hp,ally.max_hp),"48px moving ring deals three enemy-only HP per second")
	expect(sim.fields.is_empty() and sim.passive_counts.get("fire_ring",0) == 1,"fire ring replaces the old flame wall")
	place(enemy,Vector2(249,100))
	steps(sim,30)
	expect(near(enemy.hp,before-3.0) and enemy.fire_aura_dps == 0.0,"leaving the ring immediately ends its damage")

func _ninjas() -> void:
	var sim := fixture({"fire_assassin":1})
	var ninja: Dictionary = army(sim,"fire_assassin")[0]
	var enemy: Dictionary = army(sim,"fire_tank",1)[0]
	place(ninja,Vector2(200,100))
	place(enemy,Vector2(219,100))
	ninja.hp = 1.0
	ninja.first_attack = false
	ninja.slow_until = 100
	ninja.slow_fraction = 0.25
	enemy.damage = 1000.0
	enemy.cooldown = 0.0
	sim.step()
	expect(not sim.finished and near(ninja.hp,ninja.max_hp*0.30), "last Ninja resurrects with exactly 30 percent max HP")
	expect(ninja.revive_used and not ninja.first_attack and ninja.slow_until == 0, "revival clears debuffs without restoring one-use attacks")
	enemy.cooldown = 0.0
	sim.step()
	expect(sim.finished and ninja.hp == 0.0 and sim.passive_counts.ninja_revive == 1, "a Ninja gets only one resurrection per battle")
	sim = fixture({"fire_assassin":1}, {"fire_assassin":1})
	place(sim.units[0],Vector2(200,100))
	place(sim.units[1],Vector2(219,100))
	for value in sim.units:
		value.hp = 1.0
		value.damage = 1000.0
		value.cooldown = 0.0
	sim.step()
	expect(not sim.finished and sim.alive_count(0) == 1 and sim.alive_count(1) == 1, "simultaneous last Ninjas both revive fairly")
	for value in sim.units:
		value.cooldown = 0.0
	sim.step()
	expect(sim.finished and sim.result.winner == -1, "simultaneous second Ninja deaths resolve to a draw")

func _pushback() -> void:
	var sim := fixture({"water_mage":1})
	var wizard: Dictionary = army(sim,"water_mage")[0]
	var enemy: Dictionary = army(sim,"fire_tank",1)[0]
	place(wizard,Vector2(100,100))
	place(enemy,Vector2(140,100))
	wizard.cooldown = 0.0
	sim.step()
	land(sim)
	expect(near(enemy.position.x,152.0) and near(enemy.hp,enemy.max_hp-6.0), "Wizard projectile pushes its target back 12px and deals damage")
	expect(enemy.slow_fraction == 0.25, "pushback retains the Wizard's original movement Slow")
	sim = fixture({"water_mage":1,"fire_tank":1})
	wizard = army(sim,"water_mage")[0]
	enemy = army(sim,"fire_tank",1)[0]
	var blocker: Dictionary = army(sim,"fire_tank")[0]
	place(wizard,Vector2(100,100))
	place(enemy,Vector2(128,100))
	place(blocker,Vector2(136.5,100))
	wizard.cooldown = 0.0
	sim.step()
	while not sim.projectiles.is_empty():
		sim.step()
		expect(solid(sim), "knockback cannot cross a solid blocker, including interpolation")
	expect(enemy.position.x <= 129.301 and blocker.position.x == 136.5, "crowded pushback stops at the blocking body")
	sim = fixture({"water_mage":1})
	wizard = army(sim,"water_mage")[0]
	enemy = army(sim,"fire_tank",1)[0]
	place(wizard,Vector2(560,100))
	place(enemy,Vector2(582,100))
	wizard.cooldown = 0.0
	sim.step()
	land(sim)
	expect(solid(sim) and near(enemy.position.x,584.0), "pushback stops at the arena edge")

func _ice() -> void:
	var sim := fixture({"water_tank":2,"fire_melee":1})
	var golems: Array = army(sim,"water_tank")
	var enemy: Dictionary = army(sim,"fire_tank",1)[0]
	var ally: Dictionary = army(sim,"fire_melee")[0]
	place(golems[0],Vector2(200,100))
	place(golems[1],Vector2(200,124))
	place(enemy,Vector2(232,108))
	place(ally,Vector2(214,108))
	sim.cards.fire_tank.stats.move_speed = 30.0
	enemy.cooldown = 100.0
	sim.step()
	expect(near(enemy.ice_aura_fraction,0.15) and near(sim.move_speed(enemy),25.5),"overlapping auras slow movement by exactly 15 percent")
	expect(near(sim.attack_rate(enemy),0.85) and near(enemy.cooldown,99.15),"ice aura slows the actual attack timer by 15 percent")
	expect(ally.ice_aura_fraction == 0.0 and near(sim.attack_rate(ally),1.0),"the aura never slows allies")
	enemy.slow_fraction = 0.25
	enemy.slow_until = 31
	expect(near(sim.move_speed(enemy),22.5),"stronger Wizard Slow overrides the aura without stacking")
	enemy.attack_slow_fraction = 0.20
	enemy.attack_slow_until = 31
	expect(near(sim.attack_rate(enemy),0.80),"stronger Armadillo attack Slow overrides the aura")
	while sim.tick < 31: sim.step()
	expect(near(sim.move_speed(enemy),25.5) and near(sim.attack_rate(enemy),0.85),"stronger debuffs expire independently, restoring the aura")
	place(enemy,Vector2(300,108))
	sim._refresh_ice_auras()
	expect(near(sim.move_speed(enemy),30.0) and near(sim.attack_rate(enemy),1.0),"both aura slows end immediately outside the radius")
	place(golems[0],Vector2(270,108))
	sim._refresh_ice_auras()
	expect(near(sim.move_speed(enemy),25.5),"the ice radius follows a moving Golem")
	golems[0].hp = 0.0
	sim._refresh_ice_auras()
	expect(near(sim.move_speed(enemy),30.0),"a dead Golem cannot leave a lingering aura")
	expect(sim.fields.is_empty(),"the new aura replaces the old trail fields")

func _slimes() -> void:
	var sim := fixture({"water_melee":1})
	var parent: Dictionary = army(sim,"water_melee")[0]
	var enemy: Dictionary = army(sim,"fire_tank",1)[0]
	place(parent,Vector2(200,100))
	place(enemy,Vector2(219,100))
	parent.max_hp = 104.0
	parent.damage = 12.0
	parent.hp = 1.0
	sim.initial_hp[0] = 104.0
	enemy.damage = 1000.0
	enemy.cooldown = 0.0
	sim.step()
	var children: Array = sim.units.filter(func(value: Dictionary) -> bool: return value.is_child)
	expect(not sim.finished and children.size() == 2 and parent.hp == 0.0, "a last Slime's two children keep its side in the battle")
	for child in children:
		expect(near(child.damage,6.0) and near(child.max_hp,52.0), "each child inherits half its parent's promoted damage and HP")
		child.hp = 1.0
		child.burn_until = sim.tick
		child.burn_next = sim.tick
		child.burn_dps = 1000.0
	expect(solid(sim) and sim.hp_fraction(0) <= 1.0, "children find free, bounded collision positions")
	sim.step()
	expect(sim.finished and sim.units.size() == 4 and sim.passive_counts.slime_split == 1, "mini Slimes do not split recursively")

func _snowmen() -> void:
	var sim := fixture({"water_ranged":1}, {"fire_tank":2})
	var snowman: Dictionary = army(sim,"water_ranged")[0]
	var enemies: Array = army(sim,"fire_tank",1)
	place(snowman,Vector2(200,100))
	place(enemies[0],Vector2(220,100))
	place(enemies[1],Vector2(220,116))
	snowman.hp = 1.0
	enemies[0].damage = 1000.0
	enemies[0].cooldown = 0.0
	enemies[0].hp = 6.0
	var before: float = enemies[1].hp
	sim.step()
	expect(not sim.finished and sim.projectiles.size() == 1 and sim.projectiles[0].posthumous, "last Snowman throws its head before the round can finish")
	land(sim)
	expect(enemies[0].hp == 0.0 and near(enemies[1].hp,before-7.0), "Snowman's thrown head deals a small enemy-only area blast")
	expect(sim.finished and sim.result.winner == 1 and sim.passive_counts.snow_head_impact == 1, "round resolution waits for the actual head impact")
	sim = fixture({"water_ranged":1})
	place(sim.units[0],Vector2(200,100))
	place(sim.units[1],Vector2(220,100))
	sim.units[0].hp = 1.0
	sim.units[1].hp = 6.0
	sim.units[1].damage = 1000.0
	sim.units[1].cooldown = 0.0
	sim.step()
	land(sim)
	expect(sim.finished and sim.result.winner == -1, "a posthumous head can turn the last enemy's win into a draw")

func _trees() -> void:
	var sim := fixture({"earth_tank":1,"fire_archer":2,"fire_melee":1})
	var tree: Dictionary = army(sim,"earth_tank")[0]
	var allies: Array = army(sim,"fire_archer")
	var dead: Dictionary = army(sim,"fire_melee")[0]
	place(tree,Vector2(200,100))
	place(allies[0],Vector2(220,100))
	place(allies[1],Vector2(300,100))
	place(dead,Vector2(220,124))
	tree.hp = tree.max_hp*0.5
	for value in allies:
		value.hp = value.max_hp*0.5
	dead.hp = 0.0
	steps(sim,59)
	expect(near(allies[0].hp,17.0), "Tree healing waits for its two-second interval")
	sim.step()
	expect(near(tree.hp,tree.max_hp*0.55) and near(allies[0].hp,allies[0].max_hp*0.55), "Tree heals five percent of each nearby ally's own max HP")
	expect(near(allies[1].hp,17.0) and dead.hp == 0.0, "Tree aura excludes distant allies and cannot resurrect")
	steps(sim,60)
	expect(near(allies[0].hp,allies[0].max_hp*0.60) and sim.passive_counts.tree_heal == 2, "Tree healing repeats every two seconds")

func _armadillos() -> void:
	var sim := fixture({"earth_melee":2})
	var armadillos: Array = army(sim,"earth_melee")
	var enemy: Dictionary = army(sim,"fire_tank",1)[0]
	place(armadillos[0],Vector2(200,100))
	place(armadillos[1],Vector2(200,116))
	place(enemy,Vector2(220,100))
	steps(sim,89)
	expect(enemy.attack_slow_until == 0, "Armadillo pulse waits three seconds")
	enemy.cooldown = 10.0
	sim.step()
	expect(near(enemy.attack_slow_fraction,0.20) and near(enemy.cooldown,9.2), "bounce slows the ongoing attack cycle by exactly 20 percent")
	expect(sim.passive_counts.armadillo_bounce == 2 and solid(sim), "multiple bounces do not stack attack Slow or move collision bodies")
	var expiry: int = enemy.attack_slow_until
	enemy.cooldown = 100000.0
	while sim.tick < expiry:
		sim.step()
	enemy.cooldown = 10.0
	sim.step()
	expect(near(enemy.cooldown,9.0) and enemy.attack_slow_fraction == 0.0, "attack Slow expires and normal attack progress resumes")
	sim = fixture({"earth_melee":1})
	var walker: Dictionary = army(sim,"earth_melee")[0]
	enemy = army(sim,"fire_tank",1)[0]
	place(walker,Vector2(200,100))
	place(enemy,Vector2(400,100))
	sim.cards.earth_melee.stats.move_speed = 32.0
	walker.next_bounce = 1
	steps(sim,CombatSimulation.BOUNCE_TICKS)
	expect(walker.position == Vector2(200,100), "Armadillo stays in place for its whole visible bounce")
	sim.step()
	expect(walker.position.x > 200.0, "out-of-range Armadillo resumes pursuit after bouncing")

func _arrows() -> void:
	var sim := fixture({"earth_ranged":1}, {"fire_tank":3})
	var archer: Dictionary = army(sim,"earth_ranged")[0]
	var enemies: Array = army(sim,"fire_tank",1)
	place(archer,Vector2(100,100))
	for index in range(enemies.size()):
		place(enemies[index],Vector2(200,84+index*16))
	steps(sim,149)
	expect(sim.projectiles.is_empty(), "split-arrow shot waits for its five-second timer")
	sim.step()
	var total: float = 0.0
	var targets: Dictionary = {}
	for projectile in sim.projectiles:
		total += projectile.damage
		targets[projectile.target] = true
	expect(sim.projectiles.size() == 3 and targets.size() == 3 and near(total,archer.damage), "three split arrows share one attack's damage across three enemies")
	land(sim)
	for enemy in enemies:
		expect(near(enemy.hp,enemy.max_hp-13.0/3.0), "each split arrow deals exactly one third base damage")
	archer.cooldown = 100000.0
	while sim.tick < 300:
		sim.step()
	expect(sim.passive_counts.split_arrows == 2, "split shots repeat at five-second intervals")
	sim = fixture({"earth_ranged":1})
	archer = army(sim,"earth_ranged")[0]
	var enemy: Dictionary = army(sim,"fire_tank",1)[0]
	place(archer,Vector2(100,100))
	place(enemy,Vector2(400,100))
	steps(sim,160)
	expect(sim.projectiles.is_empty(), "split arrows cannot attack a target outside normal range")
	place(enemy,Vector2(200,100))
	sim.step()
	expect(sim.projectiles.size() == 3, "ready split shot still fires all three arrows with only one target")
	land(sim)
	expect(near(enemy.hp,enemy.max_hp-13.0), "one enemy receives the same total base damage, never triple damage")

func _siege() -> void:
	var sim := fixture({"earth_siege":1,"fire_melee":1}, {"fire_tank":4})
	var siege: Dictionary = army(sim,"earth_siege")[0]
	var enemies: Array = army(sim,"fire_tank",1)
	place(siege,Vector2(150,100))
	for index in range(enemies.size()):
		place(enemies[index],[Vector2(300,100),Vector2(300,154),Vector2(358,100),Vector2(368,100)][index])
	var ally: Dictionary = army(sim,"fire_melee")[0]
	place(ally,Vector2(330,130))
	siege.cooldown = 0.0
	sim.step()
	land(sim)
	expect(near(enemies[0].hp,enemies[0].max_hp-20.0), "huge siege blast preserves primary base damage")
	expect(near(enemies[1].hp,enemies[1].max_hp-14.0) and near(enemies[2].hp,enemies[2].max_hp-14.0), "huge siege area reaches enemies beyond the original small splash")
	expect(enemies[3].hp == enemies[3].max_hp and ally.hp == ally.max_hp, "siege area respects its 64px boundary and excludes allies")
	expect(sim.passive_counts.get("siege_blast",0) == 1, "huge blast emits its own ability event")

func _crowds_and_replay() -> void:
	var counts := {"water_melee":24,"fire_tank":18,"earth_tank":18,"earth_melee":12}
	var first := fixture(counts,counts)
	var second := fixture(counts,counts)
	for sim in [first,second]:
		for value in sim.units:
			if value.card_id == "water_melee":
				value.hp = 1.0
				value.burn_until = 1
				value.burn_next = 1
				value.burn_dps = 100000.0
	steps(first,2)
	steps(second,2)
	expect(first.units.size() == 240 and first.alive_count(0) == 96 and first.alive_count(1) == 96, "oversized collision stress fixtures can split every Slime into bounded children")
	expect(solid(first) and first.pending_children.is_empty(), "all crowd children find clear collision and interpolation positions")
	for index in range(100):
		first.step()
		second.step()
		expect(first.signature() == second.signature(), "split children, auras and combat replay deterministically")
		expect(solid(first), "crowd children keep permanent collision while moving and attacking")
		for value in first.units:
			expect(is_finite(value.hp) and value.hp >= 0.0 and value.hp <= value.max_hp, "crowd passive health stays finite and bounded")
	first._finish(0,"Cleanup fixture")
	expect(first.fields.is_empty() and first.projectiles.is_empty() and first.pending_children.is_empty(), "round end clears fields and deferred death effects")
	for value in first.units:
		expect(value.ice_until == 0 and value.flame_until == 0 and value.attack_slow_until == 0, "round end clears every new temporary status")

func _persistence_and_reset() -> void:
	var state := MatchState.new(71,"water_commander",[],"fire_commander")
	state.sides[0].roster.water_melee.count = 3
	state.sides[1].roster.fire_tank.count = 1
	var roster_before: String = JSON.stringify(state.sides)
	var sim := CombatSimulation.new(state)
	for value in sim.units:
		value.cooldown = 100000.0
		if value.card_id == "water_melee":
			value.hp = 1.0
			value.shield = 0.0
			value.burn_until = 1
			value.burn_next = 1
			value.burn_dps = 10000.0
	steps(sim,2)
	expect(sim.alive_count(0) == 6 and sim.units.size() == 10, "real Water roster births two children per original Slime")
	expect(JSON.stringify(state.sides) == roster_before, "combat children never change persistent counts, caps or draft history")
	var next_battle := CombatSimulation.new(state)
	expect(next_battle.units.size() == 4 and next_battle.alive_count(0) == 3, "next battle restores the original roster without carrying children over")
	for value in next_battle.units:
		expect(value.hp == value.max_hp and not value.is_child and not value.revive_used, "next battle restores full health and one-use passive eligibility")
