extends SceneTree

const Store = preload("res://autoloads/save_store.gd")
var checks := 0
var failures: Array[String] = []

func _init() -> void:
	_run.call_deferred()

func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL: ", message)

func near(a: float, b: float) -> bool:
	return absf(a-b) < 0.0001

func offer(state: MatchState, side: int, id: String, kind: String = "summon") -> Dictionary:
	# Explicit fixtures isolate action validation from random offer sampling.
	var choice := {"kind": kind, "card_id": id}
	state.sides[side].offers = [choice]
	return choice

func take(state: MatchState, side: int, id: String, kind: String = "summon") -> bool:
	return state.choose(side, offer(state, side, id, kind))

func combat_fixture(seed_value: int = 4) -> MatchState:
	var state := MatchState.new(seed_value)
	# Isolate first-hit Wildfire and melee accounting from the separate ring.
	state.cards.fire_tank = state.cards.fire_tank.duplicate(true)
	state.cards.fire_tank.stats.fire_aura_radius = 0.0
	take(state, 0, "fire_tank")
	take(state, 1, "fire_tank")
	return state

func resolve(sim: CombatSimulation) -> void:
	while not sim.finished and sim.tick < 4500:
		sim.step()
	expect(sim.finished, "combat terminates within 150 simulation seconds")

func _run() -> void:
	_test_content()
	_test_economy_and_spell()
	_test_summons_and_specials()
	_test_caps_and_offers()
	_test_persistence_and_hearts()
	_test_combat_effects()
	_test_timeout()
	_test_ai_and_replay()
	_test_saves()
	print("\n%d checks; %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _test_content() -> void:
	var state := MatchState.new(12)
	expect(GameCatalog.valid_warband(state.warband, state.cards), "exactly four unique equipped cards")
	expect(not GameCatalog.valid_warband(["fire_tank","fire_tank","fire_melee","fire_archer"], state.cards), "duplicate cards rejected")
	expect(not GameCatalog.valid_warband(["fire_tank"], state.cards), "wrong warband size rejected")
	expect(GameCatalog.bond_active(state.warband, state.cards, state.bond), "full Fire warband activates Wildfire")
	var other := state.cards.duplicate()
	other.fire_archer = state.cards.fire_archer.duplicate()
	other.fire_archer.set_id = "different"
	expect(not GameCatalog.bond_active(state.warband, other, state.bond), "mixed set has no four-piece bond")
	for id in state.warband:
		expect(state.cards[id].stats is UnitStats, "%s uses a stats Resource" % id)

func _test_economy_and_spell() -> void:
	var state := combat_fixture()
	expect(state.round_number == 1, "starts at round one")
	expect(state.sides[0].points == 2 and state.sides[1].points == 2, "round one grants three points before one summon")
	var offers_before: String = JSON.stringify(state.sides[0].offers)
	expect(state.prepare_spell(0), "spell can be prepared")
	expect(state.sides[0].points == 1, "spell costs exactly one point")
	expect(state.sides[0].spell, "queued spell indicator persists")
	expect(JSON.stringify(state.sides[0].offers) == offers_before, "spell leaves offers unchanged")
	expect(not state.prepare_spell(0), "spell cannot be prepared twice")
	expect(state.sides[0].points == 1, "failed spell spends no point")
	expect(state.start_combat(), "rosters enter combat")
	expect(not state.prepare_spell(1), "no spell input during combat")
	var sim := CombatSimulation.new(state)
	expect(near(sim.attack_speed(sim.units[0]), 1.05), "Fire active preserves its matching attack-speed passive")
	sim.step()
	expect(sim.opening_active() and sim.tick == 0 and sim.meteors.size() == 6, "prepared Fire skill starts a six-meteor opening")
	while sim.opening_active():
		sim.step()
	expect(sim.skill_counts.meteors[0] == 6 and not sim.spell_active(0), "all six meteors land before combat begins")
	state.complete_combat({"winner": 1})
	expect(not state.sides[0].spell and not state.sides[1].spell, "both queued spells clear after combat")
	state.begin_round()
	expect(state.sides[0].points == 4, "previous loser receives four points")
	expect(state.sides[1].points == 3, "previous winner receives three points")
	var next := CombatSimulation.new(state)
	expect(near(next.attack_speed(next.units[0]), 1.05), "previous spell does not affect next battle")
	var empty := MatchState.new()
	empty.sides[0].points = 0
	expect(not empty.prepare_spell(0), "spell cannot be free")
	expect(not empty.start_combat(), "cannot start an empty battle")

func _test_summons_and_specials() -> void:
	for id in GameCatalog.FIRE_IDS:
		var state := MatchState.new()
		expect(take(state, 0, id), "%s normal summon legal" % id)
		expect(state.sides[0].roster[id].count == state.cards[id].group_size, "%s adds correct group size" % id)
		expect(not state.eligible(0, {"kind":"reinforce", "card_id":id}), "reinforce requires two normal summons for %s" % id)
		expect(not state.eligible(0, {"kind":"promote", "card_id":id}), "promote requires two normal summons for %s" % id)
		take(state, 0, id)
		expect(state.eligible(0, {"kind":"reinforce", "card_id":id}), "reinforce eligible after second normal summon")
		expect(state.eligible(0, {"kind":"promote", "card_id":id}), "promote eligible after second normal summon")
		var previous_count: int = state.sides[0].roster[id].count
		expect(take(state, 0, id, "reinforce"), "targeted reinforcement legal")
		expect(state.sides[0].roster[id].count == mini(previous_count*2,state.army_cap(id)), "reinforcement adds up to the role cap")
		expect(state.sides[0].roster[id].rank == 1, "reinforcement preserves Rank")
		state.sides[0].points = 8
		expect(take(state, 0, id, "reinforce") == (state.sides[0].roster[id].count < state.army_cap(id)), "second reinforcement is legal only below the cap")
		expect(not state.eligible(0, {"kind":"reinforce", "card_id":id}), "maximum two reinforcements per type")
		previous_count = state.sides[0].roster[id].count
		expect(take(state, 0, id, "promote"), "promotion to Rank 2 legal")
		expect(state.sides[0].roster[id].rank == 2 and state.sides[0].roster[id].count == previous_count, "promotion increases Rank without count")
		expect(take(state, 0, id, "promote"), "promotion to Rank 3 legal")
		expect(not take(state, 0, id, "promote"), "Rank 3 cap cannot be bypassed")
		if state.sides[0].roster[id].count < state.army_cap(id):
			take(state, 0, id)
		var sim := CombatSimulation.new(state)
		expect(near(sim.units[0].max_hp, state.cards[id].stats.max_hp*1.55), "Rank 3 upgrades existing and future unit HP")
		expect(near(sim.units[0].damage, state.cards[id].stats.damage*1.55*1.05), "Rank 3 upgrades damage with Commander passive")

func _test_caps_and_offers() -> void:
	var expected := {"ranged":8,"melee":10,"tank":3,"mage":5,"assassin":3,"siege":4}
	for id in GameCatalog.ARMY_IDS:
		var ids: Array = [id]
		for other in GameCatalog.ARMY_IDS:
			if ids.size() < 4 and not ids.has(other): ids.append(other)
		var capped := MatchState.new(778,"fire_commander",ids)
		capped.sides[0].points = 100
		var limit: int = {"fire_candle":4,"water_penguin":4,"earth_pitcher":6}.get(id,expected[capped.cards[id].role])
		expect(capped.army_cap(id) == limit,"requested role cap for "+id)
		while capped.sides[0].roster[id].count < limit:
			var before: int = capped.sides[0].roster[id].count
			var advertised: int = capped.action_gain(0,{"kind":"summon","card_id":id})
			expect(take(capped,0,id),"summon can fill the remaining slots for "+id)
			expect(capped.sides[0].roster[id].count-before == advertised,"card advertises its actual gain")
		expect(capped.sides[0].roster[id].count == limit,"exact role cap is reachable for "+id)
		var points: int = capped.sides[0].points
		var history: int = capped.action_log.size()
		expect(not take(capped,0,id) and not take(capped,0,id,"reinforce"),"summons and reinforcements stop at the cap")
		expect(points == capped.sides[0].points and history == capped.action_log.size(),"capped cards cannot spend points or log an action")
		expect(take(capped,0,id,"promote"),"capped armies can still be promoted")
	var state := MatchState.new(778)
	state.sides[0].points = 100
	for id in state.warband:
		while take(state,0,id): pass
	expect(state.total_units(0) == 24,"Fire maxima: eight ranged, ten melee, three tanks, three assassins")
	var mixed := MatchState.new(779,"fire_commander",["fire_archer","water_ranged","earth_ranged","water_mage"])
	mixed.sides[0].points = 100
	for id in mixed.warband:
		while take(mixed,0,id): pass
	expect(mixed.total_units(0) == 29,"same-role armies have separate caps in a mixed warband")
	var partial := MatchState.new()
	partial.sides[0].points = 100
	take(partial,0,"fire_melee")
	take(partial,0,"fire_melee")
	expect(partial.action_gain(0,{"kind":"reinforce","card_id":"fire_melee"}) == 4,"reinforcement shows six to ten, adding four")
	expect(take(partial,0,"fire_melee","reinforce") and partial.sides[0].roster.fire_melee.count == 10,"partial reinforcement fills the cap for one point")
	var total := MatchState.new()
	total.config = total.config.duplicate(true)
	total.config.max_units_per_side = 10
	total.sides[0].points = 100
	for index in range(3): take(total,0,"fire_melee")
	expect(take(total,0,"fire_archer") and total.sides[0].roster.fire_archer.count == 1,"a partial summon also respects the total safety cap")
	expect(not take(total,0,"fire_tank") and not take(total,0,"fire_melee","reinforce"),"no action can exceed the total cap")
	for subject in [state, partial, MatchState.new(82)]:
		var summon_available: bool = subject.warband.any(func(id: String) -> bool: return subject.eligible(0, {"kind":"summon", "card_id":id}))
		for _sample in range(75):
			var choices: Array = OfferGenerator.generate(subject, 0)
			expect(choices.size() == 3, "three offers including saturated roster")
			var seen := {}
			var legal_choices := true
			for choice in choices:
				seen[OfferGenerator.key(choice)] = true
				legal_choices = legal_choices and subject.eligible(0, choice)
			expect(seen.size()==3 and legal_choices and choices[0].kind == ("summon" if summon_available else "power"), "three unique legal offers, with a summon or a late-game power first")
	var first := MatchState.new(829)
	var second := MatchState.new(829)
	expect(JSON.stringify(first.sides[0].offers) == JSON.stringify(second.sides[0].offers), "seed reproduces offers")
	var illegal := {"kind":"promote", "card_id":"not_in_warband"}
	expect(not first.choose(0, illegal), "unoffered or unknown choices rejected")
	expect(not first.choose(9, illegal), "unknown side rejected")

func _test_persistence_and_hearts() -> void:
	var state := combat_fixture()
	take(state, 0, "fire_tank")
	state.start_combat()
	var before: Dictionary = state.sides[0].roster.duplicate(true)
	var sim := CombatSimulation.new(state)
	sim.units[0].hp = 1.0
	sim.units[0].burn_until = 60
	state.complete_combat({"winner": 0})
	expect(state.sides[1].hearts==3 and state.sides[0].hearts==4, "exactly defeated side loses one Heart")
	expect(not state.complete_combat({"winner": 0}), "result cannot consume Hearts twice")
	state.begin_round()
	var reset := CombatSimulation.new(state)
	expect(state.sides[0].roster == before, "counts, ranks, summon history persist across rounds")
	for unit in reset.units:
		expect(near(unit.hp, unit.max_hp) and unit.burn_until==0 and unit.cooldown==0 and unit.first_attack, "full HP and fresh temporary effects each round")
	for _index in range(3):
		state.start_combat()
		state.complete_combat({"winner": 0})
		if state.phase != "finished":
			state.begin_round()
	expect(state.sides[1].hearts==0 and state.phase=="finished" and state.winner==0, "zero Hearts concludes match")
	expect(not state.begin_round(), "finished match cannot continue")

func _test_combat_effects() -> void:
	var state := combat_fixture()
	var sim := CombatSimulation.new(state)
	sim.units[0].position = Vector2(272, 70)
	sim.units[1].position = Vector2(295, 70)
	sim.step()
	expect(sim.units[0].hp < sim.units[0].max_hp, "melee damage lands")
	expect(sim.units[0].burn_until>0 and sim.units[1].burn_until>0, "first successful attacks apply Wildfire burn")
	expect(not sim.units[0].first_attack, "Wildfire used once per unit per battle")
	var original_expiry: int = sim.units[1].burn_until
	sim.units[0].first_attack = true
	sim.units[0].cooldown = 0
	sim.step()
	expect(sim.units[1].burn_until == original_expiry, "active Burn neither stacks nor refreshes")
	var health_before: float = sim.units[0].hp
	sim.units[0].cooldown = 1000
	sim.units[1].cooldown = 1000
	for _index in range(90):
		sim.step()
	expect(near(health_before-sim.units[0].hp, 9.0), "Burn deals exactly three editable one-second ticks")
	var ranged_state := MatchState.new()
	take(ranged_state, 0, "fire_archer")
	take(ranged_state, 1, "fire_tank")
	var ranged := CombatSimulation.new(ranged_state)
	for unit in ranged.units:
		unit.position = Vector2(230 if unit.side==0 else 320, 40+unit.id*24)
	ranged.step()
	expect(not ranged.projectiles.is_empty(), "ranged attacks create simulated projectiles")
	for _index in range(20):
		ranged.step()
	expect(ranged.units[-1].hp < ranged.units[-1].max_hp, "projectiles travel and deal damage")
	var assassin_state := MatchState.new()
	take(assassin_state, 0, "fire_assassin")
	take(assassin_state, 1, "fire_tank")
	take(assassin_state, 1, "fire_archer")
	var assassin := CombatSimulation.new(assassin_state)
	assassin.units[0].teleport_used = true
	assassin.step()
	var selected: Dictionary = assassin.units[int(assassin.units[0].target)]
	expect(selected.role == "ranged", "assassin prefers ranged over nearer frontline tank")
	resolve(sim)
	expect(sim.projectiles.is_empty() and not sim.spell_prepared[0], "projectiles and temporary spell flags cleaned on resolution")
	for unit in sim.units:
		expect(unit.burn_until==0 and unit.cooldown==0, "Burn and attack timers cleaned after combat")
	var draw := CombatSimulation.new(combat_fixture())
	for unit in draw.units:
		unit.hp = 1.0
		unit.position = Vector2(279+unit.side*23, 70)
	draw.step()
	expect(draw.finished and draw.result.winner==-1, "simultaneous dispersal is a visible draw, never an arbitrary winner")

func _test_timeout() -> void:
	var state := combat_fixture()
	state.config = state.config.duplicate()
	state.config.battle_limit_seconds = 0.1
	var sim := CombatSimulation.new(state)
	sim.units[0].hp *= .5
	resolve(sim)
	expect(sim.result.winner==1 and sim.result.reason.contains("remaining HP"), "timeout first compares remaining total HP percentage")
	take(state, 0, "fire_tank")
	var count_sim := CombatSimulation.new(state)
	resolve(count_sim)
	expect(count_sim.result.winner==0 and count_sim.result.reason.contains("surviving units"), "timeout HP tie compares surviving count")
	var tied := CombatSimulation.new(combat_fixture())
	tied.config = tied.config.duplicate()
	tied.config.battle_limit_seconds = 0.0
	tied.step()
	expect(tied.sudden_death and not tied.finished, "equal timeout enters sudden death")
	resolve(tied)
	expect(tied.result.reason=="Sudden death", "escalating damage resolves sudden death")

func full_match(seed_value: int) -> Dictionary:
	var state := MatchState.new(seed_value)
	var signatures: Array[String] = []
	while state.phase != "finished" and state.round_number < 18:
		for side in [1,0]:
			var before: int = state.sides[side].points
			var actions_before: int = state.action_log.size()
			NormalAI.play(state, side)
			expect(before-state.sides[side].points == state.action_log.size()-actions_before, "AI every action costs exactly one legal point")
			expect(state.sides[side].points >= 0 and state.total_units(side)<=72, "AI obeys point and total unit limits")
			for id in state.warband:
				var army: Dictionary = state.sides[side].roster[id]
				expect(army.count<=state.army_cap(id) and army.rank<=3 and army.reinforcements<=2, "AI obeys per-army limits")
		expect(state.start_combat(), "full match reaches automatic combat")
		var sim := CombatSimulation.new(state)
		resolve(sim)
		signatures.append(sim.signature())
		state.complete_combat(sim.result)
		if state.phase != "finished":
			state.begin_round()
	expect(state.phase=="finished", "seed %d completes a full four-Heart match" % seed_value)
	return {"history": state.history, "winner":state.winner, "actions":state.action_log, "signatures":signatures}

func _test_ai_and_replay() -> void:
	var state := MatchState.new(932)
	var clone := MatchState.new(932)
	# Alter the player's current roster after the snapshot. AI must not react.
	clone.sides[0].roster.fire_archer.count = 8
	NormalAI.play(state)
	NormalAI.play(clone)
	expect(state.sides[1].roster == clone.sides[1].roster and state.ai_explanations == clone.ai_explanations, "AI ignores player's current/future draft actions")
	var first: Dictionary = full_match(814)
	var second: Dictionary = full_match(814)
	expect(first == second, "same seed and actions reproduce offers, AI, movement, damage and complete match result")
	for seed_value in [19, 42, 723]:
		full_match(seed_value)
	var batched := CombatSimulation.new(combat_fixture(881))
	var continuous := CombatSimulation.new(combat_fixture(881))
	for _frame in range(45):
		for _tick in range(4):
			batched.step()
	for _tick in range(180):
		continuous.step()
	expect(batched.signature()==continuous.signature(), "different rendering batches produce identical fixed-tick state")

func _test_saves() -> void:
	expect(Store.sanitize(null)==Store.defaults(), "missing save safely defaults")
	expect(Store.sanitize("broken")==Store.defaults(), "invalid save safely defaults")
	expect(Store.sanitize({"version": 99, "volume":0.0})==Store.defaults(), "unsupported future version safely defaults")
	var migrated: Dictionary = Store.sanitize({"version":0,"volume":0.8,"combat_speed":3.0,"reduced_effects":true})
	expect(migrated.version==2 and migrated.volume==0.8 and migrated.combat_speed==3.0 and migrated.reduced_effects, "known old settings migrate safely")
	var invalid: Dictionary = Store.sanitize({"volume":5,"combat_speed":999,"reduced_effects":"false"})
	expect(invalid.volume==1.0 and invalid.combat_speed==1.0 and invalid.reduced_effects==false, "invalid setting fields recover independently")
