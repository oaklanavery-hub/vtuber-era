class_name MatchState
extends RefCounted

var config: BalanceConfig
var cards: Dictionary
var commander: CommanderData
var bond: SetBonusData
var warband: Array = GameCatalog.FIRE_IDS.duplicate()
var rng := RandomNumberGenerator.new()
var match_seed: int
var sides: Array = []
var round_number: int = 0
var phase: String = "command"
var previous_loser: int = -1
var winner: int = -2
var history: Array = []
var action_log: Array = []
var ai_explanations: Array = []
var opponent_snapshot: Dictionary = {}

func _init(seed_value: int = 1) -> void:
	config = GameCatalog.balance()
	cards = GameCatalog.cards()
	commander = GameCatalog.commander()
	bond = GameCatalog.bond()
	match_seed = seed_value
	rng.seed = seed_value
	for _side in range(2):
		var roster := {}
		for id in warband:
			roster[id] = {"count": 0, "rank": 1, "summons": 0, "reinforcements": 0}
		sides.append({"hearts": config.starting_hearts, "points": 0,
			"spell": false, "roster": roster, "offers": []})
	begin_round()

func total_units(side: int) -> int:
	var total := 0
	for id in warband:
		total += int(sides[side].roster[id].count)
	return total

func eligible(side: int, choice: Dictionary) -> bool:
	if side < 0 or side >= sides.size() or not choice.has("card_id") or not choice.has("kind"):
		return false
	if not warband.has(choice.card_id):
		return false
	var army: Dictionary = sides[side].roster[choice.card_id]
	var data: ArmyCardData = cards[choice.card_id]
	match choice.kind:
		"summon":
			return army.count + data.group_size <= config.max_units_per_type and total_units(side) + data.group_size <= config.max_units_per_side
		"reinforce":
			return army.summons >= config.normal_summons_for_special and army.count > 0 and army.reinforcements < config.max_reinforcements and army.count * 2 <= config.max_units_per_type and total_units(side) + army.count <= config.max_units_per_side
		"promote":
			return army.summons >= config.normal_summons_for_special and army.rank < config.max_rank
	return false

func can_choose(side: int, choice: Dictionary) -> bool:
	if side < 0 or side >= sides.size():
		return false
	return phase == "command" and sides[side].points > 0 and sides[side].offers.has(choice) and eligible(side, choice)

func choose(side: int, choice: Dictionary) -> bool:
	if not can_choose(side, choice):
		return false
	var army: Dictionary = sides[side].roster[choice.card_id]
	match choice.kind:
		"summon":
			army.count += cards[choice.card_id].group_size
			army.summons += 1
		"reinforce":
			army.count *= 2
			army.reinforcements += 1
		"promote":
			army.rank += 1
	sides[side].points -= 1
	action_log.append({"round": round_number, "side": side, "choice": choice.duplicate()})
	sides[side].offers = OfferGenerator.generate(self, side)
	return true

func can_prepare_spell(side: int) -> bool:
	if side < 0 or side >= sides.size():
		return false
	return phase == "command" and sides[side].points > 0 and not sides[side].spell

func prepare_spell(side: int) -> bool:
	if not can_prepare_spell(side):
		return false
	sides[side].points -= 1
	sides[side].spell = true
	action_log.append({"round": round_number, "side": side, "choice": {"kind": "spell"}})
	return true

func begin_round() -> bool:
	if phase == "finished" or (round_number > 0 and phase != "round_result"):
		return false
	round_number += 1
	phase = "command"
	ai_explanations.clear()
	opponent_snapshot = sides[0].roster.duplicate(true)
	for side in range(2):
		sides[side].points = config.command_points + (config.comeback_points if previous_loser == side else 0)
		sides[side].spell = false
		sides[side].offers = OfferGenerator.generate(self, side)
	return true

func start_combat() -> bool:
	if phase != "command" or total_units(0) == 0 or total_units(1) == 0:
		return false
	phase = "combat"
	for side in sides:
		side.points = 0
	return true

func complete_combat(result: Dictionary) -> bool:
	if phase != "combat" or not result.has("winner") or int(result.winner) < -1 or int(result.winner) > 1:
		return false
	var winning_side: int = int(result.winner)
	previous_loser = 1 - winning_side if winning_side >= 0 else -1
	if previous_loser >= 0:
		sides[previous_loser].hearts -= 1
	var record := result.duplicate(true)
	record["round"] = round_number
	history.append(record)
	for side in sides:
		side.spell = false
	if sides[0].hearts <= 0 or sides[1].hearts <= 0:
		winner = 0 if sides[1].hearts <= 0 else 1
		phase = "finished"
	else:
		phase = "round_result"
	return true
