extends "res://tests/passive_tests.gd"

func take(state: MatchState, side: int, id: String, kind: String = "power") -> bool:
	var choice := {"kind":kind, "card_id":id}
	state.sides[side].offers = [choice]
	return state.choose(side, choice)

func cap_roster(state: MatchState, side: int, rank_value: int = 3) -> void:
	for id in state.warband_for(side):
		state.sides[side].roster[id] = {"count":state.army_cap(id), "rank":rank_value, "summons":3, "reinforcements":2}
	state.sides[side].offers = OfferGenerator.generate(state, side)

func buffers(sim: CombatSimulation) -> Array:
	var damage: Array = []
	damage.resize(sim.units.size())
	damage.fill(0.0)
	return damage

func _run() -> void:
	_economy_and_persistence()
	_late_game_offers()
	_combat_bonuses()
	_damage_passives_and_descendants()
	_replay()
	print("\nPower cards: %d checks; %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _economy_and_persistence() -> void:
	var state := MatchState.new(901)
	for id in PowerCards.IDS:
		expect(not state.eligible(0, {"kind":"power", "card_id":id}), "an empty army must summon before spending points on powers")
	for side in range(2):
		expect(take(state, side, "fire_melee", "summon"), "both sides can summon an army first")
	state.sides[0].points = 20
	var roster_before: Dictionary = state.sides[0].roster.duplicate(true)
	var actions_before: int = state.action_log.size()
	for id in PowerCards.IDS:
		for stack in range(2):
			var points: int = state.sides[0].points
			expect(take(state, 0, id), "each of the four powers can be played repeatedly")
			expect(state.sides[0].powers[id] == stack+1 and state.sides[0].points == points-1, "each power stacks for exactly one Command Point")
	expect(state.sides[0].roster == roster_before and state.action_log.size() == actions_before+8, "powers preserve all counts, ranks and summon history and log each purchase")
	expect(state.sides[1].powers == PowerCards.empty_stacks(), "one side's powers never leak to its rival")
	expect(near(PowerCards.multiplier(state.sides[0].powers, "power_hp"),1.30), "two HP cards add 30%, rather than compounding")
	expect(near(PowerCards.multiplier(state.sides[0].powers, "power_defence"),1.24), "two defence cards add 24% defence")
	var choice := {"kind":"power", "card_id":"power_hp"}
	state.sides[0].offers = [{"kind":"power", "card_id":"power_damage"}]
	var rng_before: int = state.rng.state
	var points_before: int = state.sides[0].points
	expect(not state.choose(0, choice) and not state.choose(9, choice), "unoffered powers and unknown sides are rejected")
	expect(not take(state,0,"unknown_power") and not take(state,0,"fire_melee"), "unknown powers and army IDs disguised as powers are rejected")
	expect(state.sides[0].points == points_before and state.rng.state == rng_before, "rejected powers cannot spend points or reroll")
	state.sides[0].points = 0
	expect(not take(state,0,"power_hp"), "powers require a point")
	state.sides[0].points = 1
	expect(state.start_combat(), "powered armies enter combat")
	expect(not take(state,0,"power_hp"), "powers cannot be played during combat")
	var powers_before: Dictionary = state.sides[0].powers.duplicate()
	state.complete_combat({"winner":1})
	state.begin_round()
	expect(state.sides[0].powers == powers_before and state.sides[0].points == 4, "powers survive a lost round and coexist with comeback points")
	var fresh := MatchState.new(901)
	expect(fresh.sides[0].powers == PowerCards.empty_stacks() and fresh.sides[1].powers == PowerCards.empty_stacks(), "a fresh match clears both sides' power stacks")

func _late_game_offers() -> void:
	for realm in GameCatalog.REALMS:
		var state := MatchState.new(912,realm+"_commander")
		for side in range(2):
			cap_roster(state,side)
			for sample in range(80):
				var offers: Array = OfferGenerator.generate(state,side)
				var unique := {}
				for choice in offers:
					unique[OfferGenerator.key(choice)] = true
					expect(choice.kind == "power" and state.eligible(side,choice), "fully capped armies always draw usable power cards")
				expect(offers.size() == 3 and unique.size() == 3, "three distinct powers remain available at every late-game draft")
			state.sides[side].points = 4
			state.sides[side].spell = true
			var roster_before: Dictionary = state.sides[side].roster.duplicate(true)
			var actions_before: int = state.action_log.size()
			NormalAI.play(state,side)
			expect(state.sides[side].points == 0 and state.action_log.size() == actions_before+4 and state.sides[side].roster == roster_before, "AI spends every late-game point on legal powers without exceeding army caps")
	var state := MatchState.new(913)
	cap_roster(state,0,1)
	for sample in range(30):
		var offers: Array = OfferGenerator.generate(state,0)
		expect(offers[0].kind == "power", "a full army count guarantees a power even while promotions remain")
		for choice in offers: expect(state.eligible(0,choice), "late-game promotions and powers are all legal")
	cap_roster(state,0)
	state.config = state.config.duplicate(true)
	state.config.power_weight = 0.0
	var fallback: Array = OfferGenerator.generate(state,0)
	expect(fallback.size() == 3 and fallback.all(func(choice: Dictionary) -> bool: return choice.kind == "power"), "fully capped drafts still work when the editable power weight is zero")
	var mixed := MatchState.new(914,"water_commander",["fire_candle","water_penguin","earth_pitcher","fire_tank"])
	mixed.sides[0].roster.fire_tank.count = 3
	var seen_powers := {}
	for sample in range(160):
		var offers: Array = OfferGenerator.generate(mixed,0)
		expect(offers[0].kind == "summon" and offers[0].card_id != "fire_tank", "a partial roster keeps a legal summon first and removes capped summons")
		for choice in offers:
			expect(mixed.eligible(0,choice), "mixed drafts never show dead choices")
			if choice.kind == "power": seen_powers[choice.card_id] = true
	expect(seen_powers.size() == 4, "all four powers enter the ordinary mixed-army pool")
	var limited := MatchState.new(915)
	limited.config = limited.config.duplicate(true)
	limited.config.max_units_per_side = 3
	limited.sides[0].roster.fire_tank.count = 3
	var limit_offers: Array = OfferGenerator.generate(limited,0)
	expect(limit_offers.all(func(choice: Dictionary) -> bool: return choice.kind == "power"), "the total unit safety cap also falls back to powers")

func _combat_bonuses() -> void:
	for realm in GameCatalog.REALMS:
		var state := MatchState.new(922,realm+"_commander",["fire_assassin","water_melee","earth_tank","fire_candle"],"water_commander")
		for side in range(2):
			for id in state.warband_for(side):
				state.sides[side].roster[id].count = 1
				state.sides[side].roster[id].rank = 3
		var baseline := CombatSimulation.new(state)
		for side in range(2):
			for id in PowerCards.IDS: state.sides[side].powers[id] = 2 if side == 0 else 1
		var boosted := CombatSimulation.new(state)
		for index in range(boosted.units.size()):
			var actor: Dictionary = boosted.units[index]
			var original: Dictionary = baseline.units[index]
			var stack: int = 2 if actor.side == 0 else 1
			expect(near(actor.max_hp,original.max_hp*(1.0+0.15*stack)) and near(actor.hp,actor.max_hp), "HP powers multiply rank and commander HP for every allied element")
			expect(near(actor.damage,original.damage*(1.0+0.10*stack)), "damage powers multiply rank and commander damage on both sides")
			expect(near(boosted.attack_speed(actor),baseline.attack_speed(original)*(1.0+0.10*stack)), "attack speed stacks with elemental commander affinity")
			expect(near(boosted.defence_multiplier(actor),1.0+0.12*stack), "defence buffs affect every allied army")
			expect(boosted._attack_cooldown(actor) <= baseline._attack_cooldown(original), "attack-speed powers shorten actual attack cycles")
			actor.shield = 0.0
			var damage: Array = buffers(boosted)
			damage[int(actor.id)] = 20.0
			var hp_before: float = actor.hp
			boosted._damage_wave(damage,[])
			expect(near(hp_before-actor.hp,20.0*(1.0-boosted.commanders[int(actor.side)].damage_reduction)/(1.0+0.12*stack)), "actual incoming damage is mitigated by the purchased defence")
		boosted.spell_prepared[1] = true
		boosted.skills_activated[1] = true
		expect(near(boosted.defence_multiplier(boosted.units[0]),1.24*0.92), "Frozen Field still reduces boosted defence by 8%")
		state.sides[0].powers.power_hp += 1
		expect(boosted.powers[0].power_hp == 2, "combat snapshots isolate powers from later state changes")
		var next := CombatSimulation.new(state)
		expect(near(next.units[0].max_hp,baseline.units[0].max_hp*1.45), "future battles receive the current stack total")
		state.sides[0].roster.fire_candle.count = 2
		var future := CombatSimulation.new(state)
		var candles: Array = army(future,"fire_candle")
		expect(candles.size() == 2 and near(candles[0].max_hp,candles[1].max_hp) and near(candles[0].damage,candles[1].damage), "future summons inherit all previously purchased powers")
	var defence := fixture({"earth_tank":1})
	defence.powers[0].power_defence = 100
	expect(defence.damage_multiplier(defence.units[0]) > 0.0 and near(defence.damage_multiplier(defence.units[0]),1.0/13.0), "repeated defence cannot grant complete damage immunity")

func _damage_passives_and_descendants() -> void:
	var ring := fixture({"fire_tank":1},{"water_tank":1})
	ring.powers[0].power_damage = 2
	ring.cards.fire_tank.stats.fire_aura_radius = 48.0
	place(ring.units[0],Vector2(200,100)); place(ring.units[1],Vector2(240,100))
	var hp_before: float = ring.units[1].hp
	steps(ring,30)
	expect(near(hp_before-ring.units[1].hp,3.6), "damage powers increase continuous fire-ring DPS")
	var candle := fixture({"fire_candle":1},{"water_tank":1})
	candle.powers[0].power_damage = 2
	place(candle.units[0],Vector2(100,100)); place(candle.units[1],Vector2(200,100))
	candle._impact_field(candle.units[0],candle.units[1].position)
	expect(near(candle.fields[0].dps,candle.cards.fire_candle.stats.ground_fire_dps*1.2), "damage powers scale Candle ground fire at impact")
	var ground_damage: Array = buffers(candle)
	candle._area_damage(ground_damage)
	expect(near(float(ground_damage[1]),candle.cards.fire_candle.stats.ground_fire_dps*1.2/30.0), "boosted ground-fire damage reaches its victim")
	var imp := fixture({"fire_melee":1},{"water_tank":1})
	imp.powers[0].power_damage = 2
	imp.units[0].damage *= 1.2
	place(imp.units[0],Vector2(200,100)); place(imp.units[1],Vector2(224,100))
	imp.units[0].hp = 0.0
	var death_damage: Array = buffers(imp)
	imp._death_effects([0],[],death_damage,[])
	expect(near(float(death_damage[1]),imp.units[0].damage*imp.cards.fire_melee.stats.death_blast_fraction), "damage powers carry through an Imp death explosion")
	expect(near(imp.units[1].blast_burn_dps,imp.cards.fire_melee.stats.death_burn_dps*1.2), "damage powers scale the Imp's separate death burn")
	var wildfire := fixture({"fire_archer":1},{"water_tank":1})
	wildfire.bonds[0] = GameCatalog.warband_bond(GameCatalog.FIRE_IDS,wildfire.cards)
	wildfire.powers[0].power_damage = 2
	wildfire._apply_first_burn(wildfire.units[0],wildfire.units[1])
	expect(near(wildfire.units[1].burn_dps,wildfire.bonds[0].burn_damage_per_second*1.2), "damage powers scale Wildfire without changing its nonstacking rule")
	var slime := fixture({"water_melee":1},{"fire_tank":1})
	var parent: Dictionary = slime.units[0]
	parent.max_hp *= 1.30
	parent.hp = parent.max_hp
	parent.damage *= 1.20
	var lethal: Array = buffers(slime)
	lethal[0] = parent.max_hp+1.0
	slime._settle_damage(lethal,[])
	slime._birth_children()
	var children: Array = slime.units.filter(func(unit: Dictionary) -> bool: return unit.is_child)
	expect(children.size() == 2, "powered Slimes still split into two children")
	for child in children:
		expect(near(child.damage,parent.damage*0.5) and near(child.max_hp,parent.max_hp*0.5), "split children inherit boosted HP and exactly half their parent's boosted damage")
	var ninja := fixture({"fire_assassin":1},{"water_tank":1})
	ninja.units[0].max_hp *= 1.30
	ninja.units[0].hp = ninja.units[0].max_hp
	lethal = buffers(ninja)
	lethal[0] = ninja.units[0].max_hp+1.0
	ninja._settle_damage(lethal,[])
	expect(ninja.units[0].revive_used and near(ninja.units[0].hp,ninja.units[0].max_hp*0.30), "Ninja resurrection uses 30% of its boosted max HP")

func _replay() -> void:
	var first := MatchState.new(944)
	var second := MatchState.new(944)
	for state in [first,second]:
		for side in range(2):
			cap_roster(state,side)
			NormalAI.play(state,side)
	expect(first.action_log == second.action_log and first.sides == second.sides and first.ai_explanations == second.ai_explanations, "the same seed reproduces capped drafts, AI power choices and bonuses")
	var sim := CombatSimulation.new(first)
	var replay := CombatSimulation.new(second)
	for tick_value in range(90):
		sim.step(); replay.step()
		expect(sim.signature() == replay.signature(), "power-enhanced movement and damage replay deterministically")
