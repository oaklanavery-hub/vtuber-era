extends "res://tests/passive_tests.gd"

const Store = preload("res://autoloads/save_store.gd")
const NEW_WARBAND := ["fire_candle", "water_penguin", "earth_pitcher", "fire_tank"]

func _run() -> void:
	_army_sizes()
	_limits_and_loadouts()
	_ring()
	_candle_ground()
	_puddles()
	_pulls()
	_combat_replay()
	print("\nGarden armies, fire ring and stacking puddles: %d checks; %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _army_sizes() -> void:
	var sizes := {
		1.0:["fire_assassin","water_mage","water_ranged","earth_ranged","earth_pitcher","water_melee"],
		1.5:["fire_tank","water_tank","earth_tank","earth_siege"],
		0.6:["earth_melee","water_penguin","fire_candle","fire_melee","fire_archer"]}
	for scale_value in sizes:
		for id in sizes[scale_value]:
			var sim := fixture({id:1},{"water_tank":1})
			var actor: Dictionary = army(sim,id)[0]
			expect(near(actor.visual_scale,scale_value),"spawned army uses its requested character scale: "+id)
			expect(near(sim.BODY_SIZE,7.2),"visual size keeps the existing compact collision footprint")

func _limits_and_loadouts() -> void:
	var caps := {"fire_candle":4,"water_penguin":4,"earth_pitcher":6}
	for id in caps:
		var state := MatchState.new(72,"water_commander",NEW_WARBAND)
		state.sides[0].points = 30
		expect(state.cards[id].group_size == 2 and state.army_cap(id) == caps[id],"new army group size and individual cap: "+id)
		for index in range(2):
			var choice := {"kind":"summon","card_id":id}
			state.sides[0].offers = [choice]
			expect(state.choose(0,choice),"new army can be summoned twice")
		var reinforce := {"kind":"reinforce","card_id":id}
		state.sides[0].offers = [reinforce]
		if id == "earth_pitcher":
			expect(state.action_gain(0,reinforce) == 2 and state.choose(0,reinforce),"Pitcher reinforcement fills four to six, never eight")
		else:
			expect(not state.choose(0,reinforce),"four-unit specialist refuses excess reinforcement")
		var before: int = state.sides[0].points
		for kind in ["summon","reinforce"]:
			var choice := {"kind":kind,"card_id":id}
			state.sides[0].offers = [choice]
			expect(not state.choose(0,choice),"capped specialist refuses extra units")
		expect(state.sides[0].points == before and state.sides[0].roster[id].count == caps[id],"cap rejection preserves points and roster")
		var promote := {"kind":"promote","card_id":id}
		state.sides[0].offers = [promote]
		expect(state.choose(0,promote),"specialists still promote at their cap")
	for realm in GameCatalog.REALMS:
		var choices: Array = GameCatalog.realm_cards(realm)
		expect(choices.size() == 5 and GameCatalog.realm_preset(realm).size() == 4,"five choices and a compatible four-card preset")
		var ids: Array = choices.slice(0,3)+[choices[4]]
		expect(GameCatalog.valid_warband(ids,GameCatalog.cards()) and GameCatalog.warband_bond(ids,GameCatalog.cards()).set_id == realm,"new army participates in its four-card Realm Bond")
		expect(Store.sanitize({"version":2,"commander":realm+"_commander","warband":ids}).warband == ids,"new army selection survives saving")
	var ai := MatchState.new(914,"fire_commander",NEW_WARBAND)
	ai.sides[1].points = 30
	NormalAI.play(ai)
	for id in NEW_WARBAND:
		expect(ai.sides[1].roster[id].count <= ai.army_cap(id),"AI respects specialist caps")

func _ring() -> void:
	var sim := fixture({"fire_tank":2,"fire_archer":1},{"water_tank":1})
	sim.cards.fire_tank.stats.fire_aura_radius = 48.0
	var golems: Array = army(sim,"fire_tank")
	var enemy: Dictionary = army(sim,"water_tank",1)[0]
	var ally: Dictionary = army(sim,"fire_archer")[0]
	place(golems[0],Vector2(200,100)); place(golems[1],Vector2(200,124))
	place(enemy,Vector2(240,112)); place(ally,Vector2(214,112))
	var hp: float = enemy.hp
	steps(sim,30)
	expect(near(enemy.hp,hp-3.0),"overlapping fire rings deal exactly three HP per second")
	expect(near(ally.hp,ally.max_hp) and sim.fields.is_empty(),"ring is enemy-only and does not leave an old wall")
	expect(near(sim.cards.fire_tank.stats.fire_aura_radius,sim.cards.water_tank.stats.ice_aura_radius),"golem aura radii match")
	place(golems[0],Vector2(280,100)); place(golems[1],Vector2(280,124))
	steps(sim,30)
	expect(near(enemy.hp,hp-6.0),"ring follows its moving source")
	place(enemy,Vector2(340,112)); steps(sim,30)
	expect(near(enemy.hp,hp-6.0) and enemy.fire_aura_dps == 0.0,"leaving the circle stops ring damage")
	golems[0].hp = 0.0; golems[1].hp = 0.0
	place(enemy,Vector2(290,112)); steps(sim,30)
	expect(near(enemy.hp,hp-6.0),"dead golems leave no damaging ring")

func _candle_ground() -> void:
	var sim := fixture({"fire_candle":1,"fire_melee":1},{"water_tank":1,"water_mage":1})
	var candle: Dictionary = army(sim,"fire_candle")[0]
	var enemy: Dictionary = army(sim,"water_tank",1)[0]
	var mage: Dictionary = army(sim,"water_mage",1)[0]
	var ally: Dictionary = army(sim,"fire_melee")[0]
	place(candle,Vector2(100,100)); place(enemy,Vector2(200,100))
	place(mage,Vector2(200,112)); place(ally,Vector2(210,124))
	sim._projectile(candle,enemy,candle.damage)
	land(sim)
	expect(sim.fields.size() == 1 and sim.fields[0].kind == "ground_fire","Candle projectile creates a fire pool on impact")
	var field: Dictionary = sim.fields[0]
	expect(int(field.until)-sim.tick+1 == 90 and field.radius == 24.0,"ground burns for exactly three seconds in a circle")
	expect(near(enemy.hp,enemy.max_hp-7.1) and near(mage.hp,mage.max_hp-7.1),"fire spit hits every enemy in its AOE")
	steps(sim,89)
	expect(near(enemy.hp,enemy.max_hp-16.0) and near(ally.hp,ally.max_hp),"three-second ground Burn deals nine HP and never hurts allies")
	sim.step()
	expect(sim.fields.is_empty() and enemy.ground_fire_dps == 0.0,"Candle pool and ground damage expire on schedule")
	sim = fixture({"fire_candle":1,"fire_tank":1},{"water_tank":1})
	candle = army(sim,"fire_candle")[0]; enemy = army(sim,"water_tank",1)[0]
	place(candle,Vector2(100,100)); place(enemy,Vector2(220,120))
	sim._impact_field(candle,Vector2(200,100)); sim._impact_field(candle,Vector2(200,100))
	sim.step()
	expect(near(enemy.hp,enemy.max_hp),"outside circle corners do not burn")
	place(enemy,Vector2(200,100)); candle.hp = 0.0
	steps(sim,30)
	expect(near(enemy.hp,enemy.max_hp-3.0),"fire persists after Candle death and overlaps do not double Burn")
	sim = fixture({"fire_candle":1},{"water_tank":1})
	candle = army(sim,"fire_candle")[0]; enemy = army(sim,"water_tank",1)[0]
	place(candle,Vector2(100,100)); place(enemy,Vector2(200,100))
	sim.walls = [{"id":0,"side":1,"rect":Rect2(150,60,12,80)}]
	sim._projectile(candle,enemy,candle.damage); land(sim)
	expect(sim.fields.is_empty() and near(enemy.hp,enemy.max_hp),"blocked fire spit cannot create a pool through a wall")

func _puddles() -> void:
	var sim := fixture({"water_penguin":2,"fire_tank":1},{"water_tank":1})
	var penguins: Array = army(sim,"water_penguin")
	var ally: Dictionary = army(sim,"fire_tank")[0]
	var enemy: Dictionary = army(sim,"water_tank",1)[0]
	place(ally,Vector2(200,100)); place(enemy,Vector2(200,124))
	ally.hp = ally.max_hp/2.0; enemy.hp = enemy.max_hp/2.0
	var hp: float = ally.hp
	sim._impact_field(penguins[0],Vector2(200,100)); sim._impact_field(penguins[1],Vector2(200,100))
	penguins[0].hp = 0.0
	steps(sim,30)
	expect(near(ally.hp,hp),"puddles wait one full second before healing")
	sim.step()
	expect(near(ally.hp,hp+ally.max_hp*.10),"two puddles stack to ten percent max HP per second")
	expect(near(enemy.hp,enemy.max_hp/2.0),"puddle never heals an enemy")
	steps(sim,60)
	expect(near(ally.hp,hp+ally.max_hp*.30),"each puddle delivers three independent heals, even after its source dies")
	sim.step(); steps(sim,30)
	expect(sim.fields.is_empty() and near(ally.hp,hp+ally.max_hp*.30),"expired puddles stop healing")
	sim._impact_field(penguins[1],ally.position)
	ally.hp = ally.max_hp-1.0
	steps(sim,31)
	expect(near(ally.hp,ally.max_hp),"stacking healing never exceeds max HP")
	ally.hp = 0.0; steps(sim,30)
	expect(ally.hp <= 0.0,"puddle cannot resurrect a fallen unit")
	# The damaging splash and friendly ground effect belong to the same real shot.
	sim = fixture({"water_penguin":1,"fire_melee":1},{"water_tank":1})
	var penguin: Dictionary = army(sim,"water_penguin")[0]
	enemy = army(sim,"water_tank",1)[0]; ally = army(sim,"fire_melee")[0]
	place(penguin,Vector2(100,100)); place(enemy,Vector2(200,100)); place(ally,Vector2(210,124))
	ally.hp = ally.max_hp/2.0
	sim._projectile(penguin,enemy,penguin.damage); land(sim)
	expect(sim.fields.size() == 1 and sim.fields[0].kind == "puddle" and near(enemy.hp,enemy.max_hp-4.0),"Penguin water splash damages enemies and creates the healing puddle")
	steps(sim,30)
	expect(near(ally.hp,ally.max_hp*.55),"allies entering the splash area get its five percent heal")

func _pulls() -> void:
	var sim := fixture({"earth_pitcher":2},{"water_mage":2,"water_tank":1})
	var plants: Array = army(sim,"earth_pitcher")
	var mages: Array = army(sim,"water_mage",1)
	var tank: Dictionary = army(sim,"water_tank",1)[0]
	for index in range(2):
		place(plants[index],Vector2(200,100+index*40)); plants[index].next_pull = 0
		place(mages[index],Vector2(330,100+index*40))
	place(tank,Vector2(245,120))
	sim.step()
	expect(plants[0].pull_target == mages[0].id and plants[1].pull_target == mages[1].id,"roots prefer backline enemies over the nearer tank and claim distinct prey")
	steps(sim,14)
	expect(near(mages[0].position.x,330.0),"root windup does not instantly teleport its target")
	for index in range(70):
		sim.step()
		expect(solid(sim),"tendril pull obeys body collision, including interpolation")
		if sim.passive_counts.get("pitcher_bite",0) == 2: break
	expect(sim.passive_counts.get("pitcher_bite",0) == 2,"both plants reel in and bite their prey")
	for mage in mages:
		expect(near(mage.hp,mage.max_hp-13.0) and mage.position.x <= 220.01,"each pull ends with one melee bite")
	expect(near(tank.position.x,245.0),"the frontline tank is not the preferred meal")
	sim = fixture({"earth_pitcher":1},{"water_mage":1})
	var plant: Dictionary = army(sim,"earth_pitcher")[0]
	var target: Dictionary = army(sim,"water_mage",1)[0]
	place(plant,Vector2(200,100)); place(target,Vector2(330,100)); plant.next_pull = 0
	sim.walls = [{"id":0,"side":1,"rect":Rect2(260,60,12,80)}]
	steps(sim,40)
	expect(plant.pull_target == -1 and near(target.position.x,330.0),"roots require clear line of sight and cannot pull through Earth walls")
	sim = fixture({"earth_pitcher":1,"fire_tank":1},{"water_mage":1})
	plant = army(sim,"earth_pitcher")[0]; target = army(sim,"water_mage",1)[0]
	var blocker: Dictionary = army(sim,"fire_tank")[0]
	place(plant,Vector2(200,100)); place(target,Vector2(330,100)); place(blocker,Vector2(280,100)); plant.next_pull = 0
	for index in range(80):
		sim.step()
		expect(solid(sim),"blocked tendrils do not drag a body through another army")
	expect(target.position.x >= 280.0+CombatSimulation.BODY_SIZE-0.001 and sim.passive_counts.get("pitcher_bite",0) == 0,"blocked prey stops at the obstacle and takes no remote melee damage")
	expect(plant.pull_target == -1,"an obstructed pull releases rather than stalling forever")
	sim = fixture({"earth_pitcher":1},{"water_mage":1})
	plant = army(sim,"earth_pitcher")[0]; target = army(sim,"water_mage",1)[0]
	place(plant,Vector2(200,100)); place(target,Vector2(500,100)); plant.next_pull = 0
	sim.cards.earth_pitcher.stats.move_speed = 26.0
	steps(sim,30)
	expect(plant.position.x > 200.0 and near(target.hp,target.max_hp),"out-of-range Pitcher walks closer before pulling or biting")

func _combat_replay() -> void:
	var state := MatchState.new(198,"earth_commander",NEW_WARBAND,"water_commander",NEW_WARBAND)
	for side in range(2):
		state.sides[side].spell = true
		for id in NEW_WARBAND:
			state.sides[side].roster[id].count = state.army_cap(id)
	var first := CombatSimulation.new(state)
	var second := CombatSimulation.new(state)
	for index in range(4500):
		first.step(); second.step()
		if index%10 == 0:
			expect(first.signature() == second.signature(),"new armies replay identically with both commander skills")
			expect(solid(first),"mixed specialist combat keeps collision enabled")
			for unit in first.units:
				if unit.hp <= 0.0: continue
				for wall in first.walls:
					for alpha in [0.0,0.5,1.0]:
						expect(not wall.rect.grow(CombatSimulation.BODY_SIZE/2.0-0.001).has_point(unit.previous_position.lerp(unit.position,alpha)),"new army movement and pull interpolation cannot cross walls")
		if first.finished: break
	expect(first.finished and second.finished and first.result == second.result,"specialist battle terminates with a reproducible result")
	for ability in ["candle_fire","penguin_puddle","pitcher_pull","fire_ring"]:
		expect(first.passive_counts.get(ability,0) > 0,"new passive triggers in actual mixed combat: "+ability)
	expect(first.fields.is_empty() and first.pending_pushback.is_empty(),"round end clears temporary pools and forced movement")
