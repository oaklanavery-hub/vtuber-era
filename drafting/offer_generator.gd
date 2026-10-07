class_name OfferGenerator
extends RefCounted

static func key(choice: Dictionary) -> String:
	return "%s:%s" % [choice.kind, choice.card_id]

static func generate(state, side: int) -> Array:
	# Keep a summon when one is legal. Full rosters receive a power instead;
	# every offer remains useful even when all counts and ranks are capped.
	var pools := {"summon": [], "reinforce": [], "promote": [], "power": []}
	for id in state.warband_for(side):
		for kind in ["summon", "reinforce", "promote"]:
			var choice := {"kind": kind, "card_id": id}
			if state.eligible(side, choice):
				pools[kind].append(choice)
	for id in PowerCards.IDS:
		var choice := {"kind":"power", "card_id":id}
		if state.eligible(side, choice): pools.power.append(choice)
	var offers: Array = []
	var first_kind: String = "summon" if not pools.summon.is_empty() else "power"
	var first: int = state.rng.randi_range(0, pools[first_kind].size() - 1)
	offers.append(pools[first_kind].pop_at(first))
	while offers.size() < 3:
		var weights := {"summon": state.config.army_weight,
			"reinforce": state.config.reinforcement_weight,
			"promote": state.config.promotion_weight, "power": state.config.power_weight}
		var total: float = 0.0
		for kind in weights:
			if pools[kind].is_empty():
				weights[kind] = 0.0
			total += weights[kind]
		var roll: float = state.rng.randf() * total
		var category: String = "summon"
		if total <= 0.0:
			# A required fallback still works if an editable weight is zero.
			for kind in pools:
				if not pools[kind].is_empty():
					category = kind
					break
		for kind in weights:
			roll -= weights[kind]
			if roll < 0.0:
				category = kind
				break
		var index: int = state.rng.randi_range(0, pools[category].size() - 1)
		offers.append(pools[category].pop_at(index))
	return offers
