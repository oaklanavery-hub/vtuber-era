extends Node

const VERSION := 2
const SAVE_PATH := "user://vtuber_era_v1.json"
var settings: Dictionary = defaults()

static func defaults() -> Dictionary:
	return {"version": VERSION, "volume": 0.55, "combat_speed": 1.0,
		"reduced_effects": false, "commander": "fire_commander",
		"rival": "mirror",
		"warband": ["fire_archer", "fire_melee", "fire_tank", "fire_assassin"]}

static func sanitize(raw: Variant) -> Dictionary:
	var result := defaults()
	if not raw is Dictionary:
		return result
	var version: Variant = raw.get("version", 0)
	if not (version is float or version is int) or int(version) < 0 or int(version) > VERSION:
		return result
	var volume: Variant = raw.get("volume", result.volume)
	if (volume is float or volume is int) and is_finite(float(volume)):
		result.volume = clampf(float(volume), 0.0, 1.0)
	var speed: Variant = raw.get("combat_speed", result.combat_speed)
	if (speed is float or speed is int) and float(speed) in [1.0, 2.0, 3.0]:
		result.combat_speed = float(speed)
	if raw.get("reduced_effects") is bool:
		result.reduced_effects = raw.reduced_effects
	var leader: Variant = raw.get("commander", "fire_commander")
	if leader is String and GameCatalog.COMMANDER_IDS.has(leader):
		result.commander = leader
	var ids: Variant = raw.get("warband", [])
	if ids is Array and GameCatalog.valid_warband(ids, GameCatalog.cards()):
		result.warband = ids.duplicate()
	else:
		result.warband = GameCatalog.realm_preset(GameCatalog.commander(result.commander).set_id)
	var rival: Variant = raw.get("rival", "mirror")
	if rival is String and rival in ["mirror", "fire", "water", "earth"]:
		result.rival = rival
	return result

func _ready() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file and file.get_length() < 1048576:
			settings = sanitize(JSON.parse_string(file.get_as_text()))

func save() -> bool:
	settings = sanitize(settings)
	var temporary := SAVE_PATH + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if not file:
		return false
	file.store_string(JSON.stringify(settings, "\t"))
	file.close()
	return DirAccess.rename_absolute(temporary, SAVE_PATH) == OK
