extends SceneTree

# Optional balance sample, separate from pass/fail correctness checks.
# Both sides use the same AI policy and budgets. Outcomes measure this policy,
# these seeds and this tuning, rather than competitive player win rates.
const SEEDS := [42,914,71,103,251,808,1207,2026]
var trace: bool = OS.get_environment("VTUBER_BALANCE_TRACE") == "1"

func _init() -> void:
	_run.call_deferred()

func play_match(seed_value: int, own: String, rival: String) -> Dictionary:
	var state := MatchState.new(seed_value, own+"_commander", [], rival+"_commander")
	var duration := 0.0
	while state.phase != "finished" and state.round_number <= 18:
		NormalAI.play(state,0)
		NormalAI.play(state,1)
		state.start_combat()
		var sim := CombatSimulation.new(state)
		while not sim.finished and sim.tick < 4500:
			sim.step()
		if not sim.finished:
			return {"winner":-2,"rounds":state.history.size(),"seconds":duration}
		duration += sim.result.seconds
		state.complete_combat(sim.result)
		if trace:
			print("ROUND ",JSON.stringify({"round":state.round_number,"result":sim.result,"rosters":[state.sides[0].roster,state.sides[1].roster]}))
		if state.phase != "finished":
			state.begin_round()
	return {"winner":state.winner,"rounds":state.history.size(),"seconds":duration}

func _run() -> void:
	var sample: Array = []
	var seeds: Array = [42] if trace else SEEDS
	var pair: String = OS.get_environment("VTUBER_BALANCE_PAIR")
	for own in GameCatalog.REALMS:
		for rival in GameCatalog.REALMS:
			if not pair.is_empty() and pair != own+":"+rival:
				continue
			var record := {"player":own,"rival":rival,"matches":seeds.size(),"wins":0,"mean_rounds":0.0,"mean_seconds":0.0}
			for seed_value in seeds:
				var result: Dictionary = play_match(seed_value,own,rival)
				if result.winner < 0:
					printerr("Unfinished balance match: ",own," / ",rival," seed ",seed_value)
					quit(1)
					return
				record.wins += 1 if result.winner == 0 else 0
				record.mean_rounds += result.rounds / float(seeds.size())
				record.mean_seconds += result.seconds / float(seeds.size())
			sample.append(record)
			print(JSON.stringify(record))
	print("BALANCE_REPORT ",JSON.stringify({"seeds":seeds,"samples":sample,"policy":"NormalAI for both sides; full four-Heart matches"}))
	quit(0)
