extends SceneTree

const Store = preload("res://autoloads/save_store.gd")
const MIXED := ["fire_archer", "water_melee", "water_mage", "earth_siege"]
var checks := 0
var failures := 0

func _init() -> void:
	_run.call_deferred()

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("ELEMENT FAIL: ", message)

func near(a: float, b: float) -> bool:
	return absf(a-b) < 0.0001

func take(state: MatchState, side: int, id: String, kind: String = "summon") -> bool:
	var choice := {"card_id":id, "kind":kind}
	state.sides[side].offers = [choice]
	return state.choose(side, choice)

func fixture(leader: String, ids: Array, own: Dictionary, rival: String = "fire_commander", enemy: Dictionary = {"fire_tank":1}) -> CombatSimulation:
	var state := MatchState.new(7, leader, ids, rival)
	state.config = state.config.duplicate(true)
	state.config.battle_limit_seconds = 300.0
	for id in state.cards:
		state.cards[id] = state.cards[id].duplicate(true)
		state.cards[id].stats.move_speed = 0.0
	for id in own:
		state.sides[0].roster[id].count = own[id]
	for id in enemy:
		state.sides[1].roster[id].count = enemy[id]
	var sim := CombatSimulation.new(state)
	for unit in sim.units:
		unit.cooldown = 100000
	return sim

func unit(sim: CombatSimulation, id: String, side: int = 0) -> Dictionary:
	for value in sim.units:
		if value.card_id == id and value.side == side:
			return value
	return {}

func _run() -> void:
	_content_and_drafts()
	_commanders()
	_shields()
	_healing()
	_slow_and_splash()
	_lifesteal()
	_saves()
	_matchups()
	print("\nElemental expansion: %d checks; %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _content_and_drafts() -> void:
	var cards: Dictionary = GameCatalog.cards()
	expect(cards.size() == 12, "twelve distinct Resource-backed armies")
	expect(GameCatalog.valid_warband(MIXED, cards), "mixed four-card warband is legal")
	expect(GameCatalog.warband_bond(MIXED, cards) == null, "mixed warband has no bond")
	for realm in GameCatalog.REALMS:
		var ids: Array = GameCatalog.realm_cards(realm)
		var state := MatchState.new(11, "fire_commander", ids, "earth_commander")
		expect(state.bond.set_id == realm, "bond depends on cards, independently of commander")
		for id in ids:
			expect(cards[id].set_id == realm and cards[id].sprite != null, "card has realm, stats and original sprite")
			var draft := MatchState.new(12, realm+"_commander")
			expect(take(draft, 0, id) and take(draft, 0, id), "two normal summons are legal")
			expect(draft.sides[0].roster[id].count == 2*cards[id].group_size, "normal summons use configured group size")
			expect(take(draft, 0, id, "reinforce"), "special reinforcement unlocks after two summons")
			expect(draft.sides[0].roster[id].count == 4*cards[id].group_size and draft.sides[0].points == 0, "reinforcement doubles count for one point")
			draft.phase = "round_result"
			draft.begin_round()
			expect(take(draft, 0, id, "promote") and draft.sides[0].roster[id].rank == 2, "promotion preserves new army types")
			for choice in draft.sides[1].offers:
				expect(draft.warband_for(1).has(choice.card_id), "rival draws exclusively from its own warband")
	var state := MatchState.new(19, "water_commander", MIXED, "earth_commander")
	var frozen: String = JSON.stringify(state.snapshot_for(1))
	take(state, 0, "earth_siege")
	expect(JSON.stringify(state.snapshot_for(1)) == frozen, "AI opponent snapshot excludes in-progress player actions")
	expect(state.snapshot_for(0).has("earth_tank"), "each side sees the correct opposing roster")

func _commanders() -> void:
	var fire := fixture("fire_commander", MIXED, {"fire_archer":1,"water_melee":1})
	expect(near(unit(fire,"water_melee").damage, 6.0*1.05), "Fire damage bonus reaches non-Fire allies")
	expect(near(fire.attack_speed(unit(fire,"water_melee")),1.0), "Fire affinity speed excludes Water")
	expect(near(fire.attack_speed(unit(fire,"fire_archer")),1.05), "Fire affinity speed reaches Fire")
	var water := fixture("water_commander", MIXED, {"fire_archer":1,"water_melee":1})
	expect(near(unit(water,"fire_archer").max_hp,34.0*1.05), "Water max HP bonus reaches every realm")
	expect(near(water.healing_multiplier(unit(water,"water_melee")),1.1), "Water healing affinity reaches Water")
	expect(near(water.healing_multiplier(unit(water,"fire_archer")),1.0), "Water healing affinity excludes Fire")
	var earth := fixture("earth_commander", ["earth_tank","fire_archer","water_melee","earth_siege"], {"earth_tank":1,"water_melee":1})
	expect(near(unit(earth,"earth_tank").max_hp,250.0*1.05), "Earth affinity max HP reaches Earth")
	expect(near(unit(earth,"water_melee").max_hp,52.0), "Earth affinity max HP excludes Water")
	expect(near(earth.damage_multiplier(unit(earth,"water_melee")),.95), "Earth passive protects every realm")
	earth.spell_prepared[0] = true
	expect(near(earth.damage_multiplier(unit(earth,"water_melee")),.76), "Earth spell and passive compose multiplicatively")
	earth.tick = 7*earth.config.ticks_per_second
	expect(near(earth.damage_multiplier(unit(earth,"water_melee")),.95), "Stonewall expires at exactly seven seconds")
	for realm in GameCatalog.REALMS:
		var state := MatchState.new(1, realm+"_commander")
		var before: String = JSON.stringify(state.sides[0].offers)
		expect(state.prepare_spell(0) and state.sides[0].points == 2, "all command spells cost one point")
		expect(before == JSON.stringify(state.sides[0].offers) and not state.prepare_spell(0), "all spells preserve offers and queue only once")

func _shields() -> void:
	var earth := fixture("earth_commander", GameCatalog.EARTH_IDS, {"earth_tank":1,"earth_siege":1})
	for value in earth.units:
		if value.side == 0:
			expect(near(value.shield, value.max_hp*.10), "Earthen Guard shields every deployed Earth unit")
	var mixed := fixture("earth_commander", MIXED, {"earth_siege":1})
	expect(unit(mixed,"earth_siege").shield == 0.0, "mixed Earth units receive no Realm Bond shield")
	var coral := fixture("water_commander", GameCatalog.WATER_IDS, {"water_tank":2,"water_melee":1,"water_ranged":1})
	var blade: Dictionary = unit(coral,"water_melee")
	expect(near(blade.shield,blade.max_hp*.08*1.1), "nearby Coral shield gains recipient's Water affinity")
	expect(unit(coral,"water_ranged").shield == 0.0, "Coral shield respects radius")
	expect(near(unit(coral,"water_tank").shield,unit(coral,"water_tank").max_hp*.088), "multiple Wardens do not stack shields")
	coral.tick = 8*coral.config.ticks_per_second
	coral.step()
	expect(blade.shield == 0.0, "Coral shields expire at eight seconds")
	var hit := fixture("earth_commander", GameCatalog.EARTH_IDS, {"earth_tank":1}, "fire_commander", {"fire_melee":1})
	var guard: Dictionary = unit(hit,"earth_tank")
	var attacker: Dictionary = unit(hit,"fire_melee",1)
	guard.position = Vector2(200,70)
	attacker.position = Vector2(224,70)
	attacker.cooldown = 0
	attacker.damage = 10.0
	var before: float = guard.shield
	hit.step()
	expect(near(guard.hp,guard.max_hp) and near(guard.shield,before-9.5), "reduced damage consumes shield before HP")
	attacker.cooldown = 0
	attacker.damage = 100.0
	before = guard.shield
	hit.step()
	expect(near(guard.hp,guard.max_hp-(95.0-before)) and guard.shield == 0.0, "shield overflow damages HP exactly once")

func _healing() -> void:
	var healing := fixture("water_commander", MIXED, {"water_melee":1,"fire_archer":1,"water_mage":1})
	var blade: Dictionary = unit(healing,"water_melee")
	var archer: Dictionary = unit(healing,"fire_archer")
	blade.hp = blade.max_hp*.2
	archer.hp = archer.max_hp*.2
	unit(healing,"water_mage").hp = 0.0
	healing.spell_prepared[0] = true
	for index in range(5*healing.config.ticks_per_second):
		healing.step()
	expect(near(blade.hp,blade.max_hp*(.2+.165)), "Healing Current supplies five boosted Water healing ticks")
	expect(near(archer.hp,archer.max_hp*(.2+.15)), "Healing Current also heals non-Water allies")
	expect(unit(healing,"water_mage").hp == 0.0, "healing cannot resurrect dispersed units")
	var after: float = blade.hp
	for index in range(60):
		healing.step()
	expect(near(blade.hp,after), "Healing Current stops after exactly five seconds")
	var tidal := fixture("water_commander", GameCatalog.WATER_IDS, {"water_melee":1})
	blade = unit(tidal,"water_melee")
	blade.hp = blade.max_hp*.4
	for index in range(3*tidal.config.ticks_per_second+1):
		tidal.step()
	expect(blade.recovery_used and blade.recovery_remaining == 0, "Tidal Recovery triggers once below half HP")
	expect(near(blade.hp,blade.max_hp*(.4+.132)), "Tidal Recovery heals twelve percent over three boosted ticks")
	blade.hp = blade.max_hp*.2
	for index in range(120):
		tidal.step()
	expect(near(blade.hp,blade.max_hp*.2), "Tidal Recovery never retriggers in the same battle")
	tidal._heal(blade,blade.max_hp*5.0)
	expect(near(blade.hp,blade.max_hp), "all healing clamps to max HP")

func _slow_and_splash() -> void:
	var slow := fixture("earth_commander", MIXED, {"water_mage":1})
	var mage: Dictionary = unit(slow,"water_mage")
	var target: Dictionary = unit(slow,"fire_tank",1)
	mage.position = Vector2(200,70)
	target.position = Vector2(224,70)
	slow.cards.fire_tank.stats.move_speed = 27.0
	mage.cooldown = 0
	for index in range(4):
		slow.step()
	expect(near(target.slow_fraction,.25) and near(slow.move_speed(target),27.0*.75), "Tidecaller projectile really slows movement")
	mage.cooldown = 0
	for index in range(4):
		slow.step()
	expect(near(target.slow_fraction,.25), "repeated Slow never stacks its strength")
	mage.cooldown = 100000
	var expiry: int = target.slow_until
	while slow.tick <= expiry:
		slow.step()
	expect(near(slow.move_speed(target),27.0) and target.slow_fraction == 0.0, "Slow expires and restores movement")
	var siege := fixture("earth_commander", MIXED, {"earth_siege":1}, "water_commander", {"water_tank":1,"water_melee":2,"water_ranged":1})
	var launcher: Dictionary = unit(siege,"earth_siege")
	launcher.position = Vector2(150,70)
	var clustered: Array = []
	for value in siege.units:
		if value.side == 1:
			value.shield = 0.0
			value.position = [Vector2(300,70),Vector2(300,94),Vector2(300,46),Vector2(350,142)][clustered.size()]
			clustered.append(value)
	expect(siege._target(launcher) == clustered[0].id, "siege targets a reachable dense cluster")
	launcher.cooldown = 0
	siege.step()
	expect(siege.projectiles.size() == 1 and near(clustered[0].hp,clustered[0].max_hp), "siege damage waits for projectile travel")
	while not siege.projectiles.is_empty():
		siege.step()
	expect(near(clustered[0].hp,clustered[0].max_hp-20.0), "siege primary hit deals configured damage")
	expect(near(clustered[1].hp,clustered[1].max_hp-14.0) and near(clustered[2].hp,clustered[2].max_hp-14.0), "siege splash damages the nearby cluster")
	expect(near(clustered[3].hp,clustered[3].max_hp), "siege splash excludes targets outside radius")
	var assassin := fixture("fire_commander", GameCatalog.FIRE_IDS, {"fire_assassin":1}, "earth_commander", {"earth_tank":1,"earth_siege":1})
	expect(assassin.units[assassin._target(unit(assassin,"fire_assassin"))].role == "siege", "assassins prioritize siege over the frontline")
	assassin = fixture("fire_commander", GameCatalog.FIRE_IDS, {"fire_assassin":1}, "water_commander", {"water_tank":1,"water_mage":1})
	expect(assassin.units[assassin._target(unit(assassin,"fire_assassin"))].role == "mage", "assassins prioritize mages over the frontline")

func _lifesteal() -> void:
	var life := fixture("water_commander", MIXED, {"water_melee":1}, "fire_commander", {"fire_tank":1,"fire_archer":1})
	var blade: Dictionary = unit(life,"water_melee")
	var target: Dictionary = unit(life,"fire_tank",1)
	blade.position = Vector2(200,70)
	target.position = Vector2(224,70)
	blade.hp = blade.max_hp*.5
	blade.damage = 1000.0
	blade.cooldown = 0
	target.max_hp = 100000.0
	target.hp = target.max_hp
	target.shield = 10000.0
	life.step()
	expect(near(blade.hp,blade.max_hp*.5), "lifesteal excludes damage absorbed by shields")
	target.shield = 0.0
	for index in range(10):
		blade.cooldown = 0
		life.step()
	expect(near(blade.hp,blade.max_hp*.52), "lifesteal is capped at two percent actual max HP per second")
	while life.tick < life.config.ticks_per_second:
		life.step()
	blade.cooldown = 0
	life.step()
	expect(near(blade.hp,blade.max_hp*.54), "lifesteal allowance renews in the next second")
	var tidal := fixture("water_commander", GameCatalog.WATER_IDS, {"water_melee":1})
	blade = unit(tidal,"water_melee")
	target = unit(tidal,"fire_tank",1)
	blade.position = Vector2(200,70)
	target.position = Vector2(224,70)
	blade.hp = blade.max_hp*.49
	blade.damage = 100.0
	blade.cooldown = 0
	tidal.step()
	expect(blade.hp > blade.max_hp*.50 and blade.recovery_used, "same-tick lifesteal cannot hide crossing the recovery threshold")

func _saves() -> void:
	var raw := {"version":1,"commander":"water_commander","warband":MIXED,"rival":"earth","volume":.8}
	var saved: Dictionary = Store.sanitize(raw)
	expect(saved.version == 2 and saved.warband == MIXED and saved.commander == "water_commander" and saved.rival == "earth", "v1 saves migrate and preserve a legal mixed loadout")
	expect(Store.sanitize({"commander":"earth_commander","warband":["earth_tank","earth_tank"]}).warband == GameCatalog.EARTH_IDS, "invalid saved warband falls back to chosen commander's realm")
	expect(Store.sanitize({"commander":"unknown","rival":"unknown"}).commander == "fire_commander", "unknown commander safely defaults")

func play_match(seed_value: int, own_realm: String, rival_realm: String, mixed: bool = false) -> Dictionary:
	var state := MatchState.new(seed_value, own_realm+"_commander", MIXED if mixed else [], rival_realm+"_commander")
	var signatures: Array = []
	while state.phase != "finished" and state.round_number <= 18:
		for side in range(2):
			NormalAI.play(state,side)
			expect(state.total_units(side) > 0 and state.total_units(side) <= state.config.max_units_per_side, "AI fields a legal army in every realm matchup")
			expect(state.sides[side].points >= 0, "AI uses the shared Command Point budget")
		expect(state.start_combat(), "faction matchup enters combat")
		var sim := CombatSimulation.new(state)
		while not sim.finished and sim.tick < 4500:
			sim.step()
		expect(sim.finished, "all faction matchups terminate")
		for value in sim.units:
			expect(is_finite(value.hp) and value.hp >= 0.0 and value.hp <= value.max_hp, "health stays finite and bounded")
			expect(value.shield == 0.0 and value.slow_until == 0 and value.recovery_remaining == 0, "temporary statuses clear after every battle")
		signatures.append(sim.signature())
		state.complete_combat(sim.result)
		if state.phase != "finished":
			state.begin_round()
	expect(state.phase == "finished" and (state.sides[0].hearts == 0 or state.sides[1].hearts == 0), "full four-Heart faction match concludes")
	return {"winner":state.winner,"rounds":state.history.size(),"digest":JSON.stringify([state.action_log,state.history,signatures]).sha256_text()}

func _matchups() -> void:
	for own in GameCatalog.REALMS:
		for rival in GameCatalog.REALMS:
			for seed_value in [42,914]:
				var report: Dictionary = play_match(seed_value,own,rival)
				if seed_value == 42:
					expect(report == play_match(seed_value,own,rival), "cross-realm draft and combat replay deterministically")
				print("MATCH %s / %s seed %d: side %d wins in %d rounds" % [own,rival,seed_value,report.winner,report.rounds])
	for leader in GameCatalog.REALMS:
		var report: Dictionary = play_match(82,leader,"earth",true)
		expect(report == play_match(82,leader,"earth",true), "every commander supports deterministic mixed warbands")
		print("MIXED %s / earth: side %d wins in %d rounds" % [leader,report.winner,report.rounds])
