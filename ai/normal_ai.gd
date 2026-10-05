class_name NormalAI
extends RefCounted

static func score(state, side: int, choice: Dictionary, opponent: Dictionary) -> float:
	var own: Dictionary = state.sides[side].roster
	var count: int = int(own[choice.card_id].count)
	var army: ArmyCardData = state.cards[choice.card_id]
	var frontline := 0
	var enemy_ranged := 0
	for id in own:
		if state.cards[id].role in ["tank", "melee"]:
			frontline += int(own[id].count)
	for id in opponent:
		if state.cards[id].role == "ranged":
			enemy_ranged += int(opponent[id].count)
	match choice.kind:
		"reinforce":
			return 20.0 + float(count) * (2.8 if army.role != "tank" else 4.8)
		"promote":
			return 17.0 + float(count) * (2.3 if army.role != "tank" else 4.0)
		"summon":
			var value: float = 25.0 + float(army.group_size) * 2.0 - float(count) * 0.8
			if army.role == "tank":
				value += 24.0 if frontline == 0 else 8.0
			if army.role == "melee" and frontline < 4:
				value += 14.0
			if army.role == "ranged" and frontline > 0:
				value += 9.0
			if army.role == "assassin":
				value += minf(float(enemy_ranged) * 2.0, 22.0)
			if state.previous_loser == side and army.role == "tank":
				value += 3.0
			return value
	return -INF

static func play(state, side: int = 1) -> void:
	# Frozen at the START of the command phase; never reads the player's
	# in-progress or future actions. No RNG, extra units or offer rerolls.
	var opponent: Dictionary = state.opponent_snapshot
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
		if state.can_prepare_spell(side) and state.total_units(side) >= 10:
			spell_score = 21.0 + float(state.total_units(side)) * 0.7
			if state.previous_loser == side:
				spell_score += 7.0
		if spell_score > best_score:
			state.prepare_spell(side)
			state.ai_explanations.append("Blazing Orders · %.1f · strengthen %d units" % [spell_score, state.total_units(side)])
		elif not best.is_empty():
			state.choose(side, best)
			state.ai_explanations.append("%s %s · %.1f" % [best.kind, state.cards[best.card_id].short_name, best_score])
		else:
			# No legal offered action. Unused points are discarded at battle start.
			break
