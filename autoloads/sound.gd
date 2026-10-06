extends Node

var music: AudioStreamPlayer
var effects: Array = []
var streams: Dictionary = {}
var combat_players: Array = []
var combat_cooldowns: Dictionary = {}
var combat_sounds_played: int = 0
const COMBAT_CUES := ["disperse", "siege_launch", "siege_impact", "fire_breath", "water_cast",
	"snowball", "arrow", "slash", "swing", "shield_hit", "impact", "heal"]
const ATTACK_CUES := {"fire_archer":"fire_breath", "fire_melee":"swing", "fire_tank":"swing",
	"fire_assassin":"slash", "water_mage":"water_cast", "water_tank":"swing",
	"water_melee":"swing", "water_ranged":"snowball", "earth_tank":"swing",
	"earth_melee":"swing", "earth_ranged":"arrow", "earth_siege":"siege_launch"}

func _ready() -> void:
	music = AudioStreamPlayer.new()
	music.stream = load("res://assets/audio/festival.wav")
	music.volume_db = -10.0
	add_child(music)
	music.finished.connect(func(): music.play())
	for index in range(5):
		var player := AudioStreamPlayer.new()
		player.volume_db = -9.0
		add_child(player)
		effects.append(player)
	# Combat gets its own quiet voice pool; it cannot swallow menu/result cues.
	for index in range(6):
		var player := AudioStreamPlayer.new()
		player.volume_db = -12.0
		add_child(player)
		combat_players.append(player)
	for effect in ["click", "summon", "spell", "battle", "victory", "defeat"]+COMBAT_CUES:
		streams[effect] = load("res://assets/audio/%s.wav" % effect)
	set_volume(SaveStore.settings.volume)

func _process(delta: float) -> void:
	for effect in combat_cooldowns:
		combat_cooldowns[effect] = maxf(0.0, float(combat_cooldowns[effect])-delta)

func combat_requests(events: Array) -> Dictionary:
	# Coalesce a rendered frame's fixed-tick events, including 2x/3x playback.
	# No audio decision feeds back into combat or its deterministic RNG.
	var requests: Dictionary = {}
	for event in events:
		match event.kind:
			"attack": requests[ATTACK_CUES.get(event.card_id, "swing")] = true
			"splash": requests["siege_impact" if event.set_id == "earth" else "fire_breath" if event.set_id == "fire" else "water_cast"] = true
			"hit": requests["shield_hit" if event.absorbed > 0.0 else "impact"] = true
			"heal": requests["heal"] = true
			"defeat": requests["disperse"] = true
			"passive":
				var cue: String = {"imp_explosion":"fire_breath", "flame_wall":"fire_breath",
					"ninja_revive":"slash", "ice_path":"water_cast", "slime_split":"water_cast",
					"snow_head":"snowball", "tree_heal":"heal", "armadillo_bounce":"impact",
					"split_arrows":"arrow", "siege_blast":"siege_impact"}.get(event.ability, "")
				if not cue.is_empty():
					requests[cue] = true
	return requests

func combat(events: Array) -> void:
	if DisplayServer.get_name() == "headless" or AudioServer.is_bus_mute(0):
		return
	var requests: Dictionary = combat_requests(events)
	var played: int = 0
	for effect in COMBAT_CUES:
		if played >= 3:
			break
		if not requests.has(effect) or float(combat_cooldowns.get(effect, 0.0)) > 0.0:
			continue
		for player in combat_players:
			if not player.playing:
				player.stream = streams[effect]
				player.play()
				combat_cooldowns[effect] = 0.18 if effect in ["impact", "swing", "shield_hit"] else 0.28
				combat_sounds_played += 1
				played += 1
				break

func begin() -> void:
	if DisplayServer.get_name()=="headless":
		return
	if not music.playing:
		music.play()

func play(effect: String) -> void:
	if DisplayServer.get_name()=="headless":
		return
	if not streams.has(effect):
		return
	for player in effects:
		if not player.playing:
			player.stream = streams[effect]
			player.play()
			return

func set_volume(value: float) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(value, 0.0001)))
	AudioServer.set_bus_mute(0, value <= 0.0)
