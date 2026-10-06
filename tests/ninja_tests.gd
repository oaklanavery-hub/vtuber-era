extends SceneTree

var checks: int = 0
var failures: int = 0

func _init() -> void:
	_run.call_deferred()

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("NINJA FAIL: ", message)

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
		if id != "fire_assassin": state.cards[id].stats.move_speed = 0.0
	for id in own: state.sides[0].roster[id].count = own[id]
	for id in enemy: state.sides[1].roster[id].count = enemy[id]
	var sim := CombatSimulation.new(state)
	for unit in sim.units:
		if unit.card_id != "fire_assassin": unit.cooldown = 100000.0
	return sim

func place(unit: Dictionary, position: Vector2) -> void:
	unit.position = position
	unit.previous_position = position

func _run() -> void:
	# An assassin already in reach must attack, including the opening tick.
	var sim := fixture({"fire_assassin":1}, {"earth_ranged":1})
	place(sim.units[0], Vector2(240,28))
	place(sim.units[1], Vector2(255,28))
	var before: float = sim.units[1].hp
	sim.step()
	expect(sim.units[1].hp < before and not sim.units[0].flanking, "opening flank ends at an enemy in reach")

	# Do not repeatedly walk into a solid defender while chasing a distant archer.
	sim = fixture({"fire_assassin":1}, {"fire_tank":1,"earth_ranged":1})
	place(sim.units[0], Vector2(280,100))
	place(sim.units[1], Vector2(295,100))
	place(sim.units[2], Vector2(520,100))
	sim.units[0].flanking = false
	before = sim.units[1].hp
	sim.step()
	expect(sim.units[0].target == 1 and sim.units[1].hp < before, "Ninja fights a blocker within reach before pursuing the backline")

	# A one-unit change in another army must not swap the Ninja's flank lane.
	for imp_count in [0,1]:
		sim = fixture({"fire_melee":imp_count,"fire_assassin":2}, {"earth_ranged":1})
		for unit in sim.units:
			if unit.side == 0 and unit.role == "assassin":
				var y: float = unit.position.y
				var next: Vector2 = sim._move(unit, 1.0/sim.config.ticks_per_second)
				expect(absf(next.y-y) < 0.001, "flank lane follows spawn position, independent of roster ID parity")

	# No backline means a direct approach; the Ninja need not visit a distant corner.
	sim = fixture({"fire_assassin":1}, {"fire_tank":1})
	place(sim.units[0], Vector2(240,100))
	place(sim.units[1], Vector2(400,100))
	sim.step()
	expect(not sim.units[0].flanking and absf(sim.units[0].position.y-100.0) < 0.001, "Ninja closes directly when no backline remains")

	# A blocked opening route cannot keep the attack gate disabled forever.
	sim = fixture({"fire_assassin":1}, {"earth_ranged":1})
	sim.tick = 6*sim.config.ticks_per_second
	sim._move(sim.units[0],1.0/sim.config.ticks_per_second)
	expect(not sim.units[0].flanking,"opening flank has a six-second deadline")

	# Real formations, movement speed and flanking stay enabled on BOTH sides.
	# Enemy attacks wait so this isolates navigation and actual contact attacks.
	for ninja_side in range(2):
		var own := {"fire_assassin":2}
		var rival := {"earth_ranged":2,"fire_tank":4}
		var first := fixture(own if ninja_side == 0 else rival,rival if ninja_side == 0 else own)
		var replay := fixture(own if ninja_side == 0 else rival,rival if ninja_side == 0 else own)
		for frame in range(240):
			first.step()
			replay.step()
			expect(first.signature() == replay.signature(),"live Ninja pursuit replays deterministically")
			expect(solid(first),"live Ninja flanks and attacks keep collision active")
		var ninjas: Array = first.units.filter(func(unit: Dictionary) -> bool: return unit.role == "assassin")
		expect(ninjas.all(func(unit: Dictionary) -> bool: return not unit.first_attack),"both opening lanes reach an enemy and attack with actual movement")
		var ninja: Dictionary = ninjas[0]
		var damage: Array = []
		damage.resize(first.units.size())
		damage.fill(0.0)
		damage[int(ninja.id)] = ninja.hp+1.0
		first._settle_damage(damage,[])
		expect(ninja.revive_used and is_equal_approx(ninja.hp,ninja.max_hp*0.3),"moving Ninja revives with exactly 30 percent HP")
		expect(not ninja.flanking and ninja.cooldown == first._attack_cooldown(ninja),"resurrection resumes pursuit with its commander-adjusted attack cycle")
		expect(solid(first),"resurrection keeps the Ninja's reserved body position")

	print("\nNinja pursuit and resurrection: %d checks; %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func solid(sim: CombatSimulation) -> bool:
	for alpha in [0.0,0.5,1.0]:
		for index in range(sim.units.size()):
			var a: Dictionary = sim.units[index]
			if a.hp <= 0.0: continue
			for next in range(index+1,sim.units.size()):
				var b: Dictionary = sim.units[next]
				if b.hp <= 0.0: continue
				var delta: Vector2 = (a.previous_position.lerp(a.position,alpha)-b.previous_position.lerp(b.position,alpha)).abs()
				if delta.x < CombatSimulation.BODY_SIZE-0.001 and delta.y < CombatSimulation.BODY_SIZE-0.001: return false
	return true
