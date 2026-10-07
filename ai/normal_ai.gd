class_name NormalAI
extends RefCounted

static func score(state, side: int, choice: Dictionary, opponent: Dictionary) -> float:
	if choice.kind == "power":
		# Army-wide gains become worthwhile as the roster grows. No live
		# opponent choices or extra draft randomness are read here.
		var value: float = 18.0 + float(state.total_units(side))*0.9
		var stacks: Dictionary = state.sides[side].powers
		value /= PowerCards.multiplier(stacks, choice.card_id)
		if state.previous_loser == side and choice.card_id in ["power_hp", "power_defence"]:
			value += 3.0
		return value
	var own: Dictionary = state.sides[side].roster
	var count: int = int(own[choice.card_id].count)
	var army: ArmyCardData = state.cards[choice.card_id]
	var frontline := 0
	var enemy_ranged := 0
	for id in own:
		if state.cards[id].role in ["tank", "melee"]:
			frontline += int(own[id].count)
	for id in opponent:
		if state.cards[id].role in CombatSimulation.BACKLINE:
			enemy_ranged += int(opponent[id].count)
	match choice.kind:
		"reinforce":
			return 20.0 + float(state.action_gain(side, choice)) * (2.8 if army.role != "tank" else 4.8)
		"promote":
			return 17.0 + float(count) * (2.3 if army.role != "tank" else 4.0)
		"summon":
			var value: float = 25.0 + float(state.action_gain(side, choice)) * 2.0 - float(count) * 0.8
			if army.role == "tank":
				value += 24.0 if frontline == 0 else 8.0
			if army.role == "melee" and frontline < 4:
				value += 14.0
			if army.role in CombatSimulation.BACKLINE and frontline > 0:
				value += 9.0
			if army.role == "siege":
				value += minf(float(enemy_ranged)*1.5, 10.0)
			if army.role == "mage":
				value += minf(float(enemy_ranged), 6.0)
			var leader: CommanderData = state.commander_for(side)
			if army.set_id == leader.set_id:
				value += 2.0
			if state.bond_for(side) != null:
				value += 2.0
			if army.role == "assassin":
				# A few flankers punish a backline. Repeatedly buying only
				# flankers leaves the main army exposed to splash and shields.
				value += minf(float(enemy_ranged) * 2.0, 14.0) - float(count)*2.0
			if state.previous_loser == side and army.role == "tank":
				value += 3.0
			return value
	return -INF

static func play(state, side: int = 1) -> void:
	# Frozen at the START of the command phase; never reads the player's
	# in-progress or future actions. No RNG, extra units or offer rerolls.
	var opponent: Dictionary = state.snapshot_for(side)
	while state.sides[side].points > 0:
		var best: Dictionary = {}
		var best_score: float = -INF
		for choice in state.sides[side].offers:
			if state.can_choose(side, choice):
				var value: float = score(state, side, choice, opponent)
				if value > best_score:
					best_score = value
					best = choice
		var spell_score: float = -INF
		var army_hp: float = 0.0
		for id in state.warband_for(side):
			army_hp += state.cards[id].stats.max_hp * state.sides[side].roster[id].count * state.config.rank_hp[state.sides[side].roster[id].rank-1]
		if state.can_prepare_spell(side) and (state.total_units(side) >= 10 or army_hp >= 650.0):
			var leader: CommanderData = state.commander_for(side)
			var enemy_units: int = 0
			for id in opponent:
				enemy_units += int(opponent[id].count)
			spell_score = 21.0+army_hp/65.0
			if leader.spell_kind == "meteors":
				spell_score = 21.0+float(enemy_units)*0.85
			elif leader.spell_kind == "earth_walls":
				spell_score += minf(float(enemy_ranged_count(state, opponent))*0.7, 8.0)
			if state.previous_loser == side:
				spell_score += 7.0
		if spell_score > best_score:
			state.prepare_spell(side)
			state.ai_explanations.append("%s · %.1f · %d units" % [state.commander_for(side).spell_name, spell_score, state.total_units(side)])
		elif not best.is_empty():
			state.choose(side, best)
			var name: String = PowerCards.DEFINITIONS[best.card_id].label if best.kind == "power" else state.cards[best.card_id].short_name
			state.ai_explanations.append("%s %s · %.1f" % [best.kind, name, best_score])
		else:
			# No legal offered action. Unused points are discarded at battle start.
			break

static func enemy_ranged_count(state, opponent: Dictionary) -> int:
	var count: int = 0
	for id in opponent:
		if state.cards[id].role in CombatSimulation.BACKLINE:
			count += int(opponent[id].count)
	return count
