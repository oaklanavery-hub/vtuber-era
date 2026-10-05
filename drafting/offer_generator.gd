class_name OfferGenerator
extends RefCounted

static func key(choice: Dictionary) -> String:
	return "%s:%s" % [choice.kind, choice.card_id]

static func generate(state, side: int) -> Array:
	# One normal card is mandatory. The remaining two slots use category weights.
	# Capped normal cards remain visible (disabled), so even a full roster has
	# three distinct offers and can proceed to battle without a free reroll.
	var pools := {"summon": [], "reinforce": [], "promote": []}
	for id in state.warband_for(side):
		pools.summon.append({"kind": "summon", "card_id": id})
		for kind in ["reinforce", "promote"]:
			var special := {"kind": kind, "card_id": id}
			if state.eligible(side, special):
				pools[kind].append(special)
	var offers: Array = []
	var first: int = state.rng.randi_range(0, pools.summon.size() - 1)
	offers.append(pools.summon.pop_at(first))
	while offers.size() < 3:
		var weights := {"summon": state.config.army_weight,
			"reinforce": state.config.reinforcement_weight,
			"promote": state.config.promotion_weight}
		var total: float = 0.0
		for kind in weights:
			if pools[kind].is_empty():
				weights[kind] = 0.0
			total += weights[kind]
		var roll: float = state.rng.randf() * total
		var category: String = "summon"
		for kind in weights:
			roll -= weights[kind]
			if roll < 0.0:
				category = kind
				break
		var index: int = state.rng.randi_range(0, pools[category].size() - 1)
		offers.append(pools[category].pop_at(index))
	return offers
