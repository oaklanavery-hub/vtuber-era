extends Node

var music: AudioStreamPlayer
var effects: Array = []
var streams: Dictionary = {}

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
	for effect in ["click", "summon", "spell", "battle", "victory", "defeat"]:
		streams[effect] = load("res://assets/audio/%s.wav" % effect)
	set_volume(SaveStore.settings.volume)

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
