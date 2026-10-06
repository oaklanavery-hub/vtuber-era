class_name GameCatalog
extends RefCounted

const FIRE_IDS := ["fire_archer", "fire_melee", "fire_tank", "fire_assassin"]
const WATER_IDS := ["water_mage", "water_tank", "water_melee", "water_ranged"]
const EARTH_IDS := ["earth_tank", "earth_melee", "earth_ranged", "earth_siege"]
# Four-card presets stay compatible with saved warbands; each realm has five choices.
const FIRE_ARMIES := ["fire_archer", "fire_melee", "fire_tank", "fire_assassin", "fire_candle"]
const WATER_ARMIES := ["water_mage", "water_tank", "water_melee", "water_ranged", "water_penguin"]
const EARTH_ARMIES := ["earth_tank", "earth_melee", "earth_ranged", "earth_siege", "earth_pitcher"]
const ARMY_IDS := FIRE_ARMIES + WATER_ARMIES + EARTH_ARMIES
const REALMS := ["fire", "water", "earth"]
const COMMANDER_IDS := ["fire_commander", "water_commander", "earth_commander"]

static func cards() -> Dictionary:
	var result := {}
	for id in ARMY_IDS:
		result[id] = load("res://data/armies/%s.tres" % id)
	return result

static func balance() -> BalanceConfig:
	return load("res://data/balance.tres")

static func commander(id: String = "fire_commander") -> CommanderData:
	var realm: String = id.trim_suffix("_commander") if COMMANDER_IDS.has(id) else "fire"
	return load("res://data/commanders/%s.tres" % realm)

static func bond(realm: String = "fire") -> SetBonusData:
	var id: String = {"fire":"wildfire", "water":"tidal_recovery", "earth":"earthen_guard"}.get(realm, "wildfire")
	return load("res://data/bonds/%s.tres" % id)

static func realm_cards(realm: String) -> Array:
	return {"fire":FIRE_ARMIES, "water":WATER_ARMIES, "earth":EARTH_ARMIES}.get(realm, FIRE_ARMIES).duplicate()

static func realm_preset(realm: String) -> Array:
	return {"fire":FIRE_IDS, "water":WATER_IDS, "earth":EARTH_IDS}.get(realm, FIRE_IDS).duplicate()

static func army_cap(card: ArmyCardData, config: BalanceConfig = null) -> int:
	if config == null:
		config = balance()
	return mini(config.max_units_per_type, card.spawn_limit) if card.spawn_limit > 0 else config.unit_cap(card.role)

static func army_scale(id: String, split_child: bool = false) -> float:
	if split_child or id in ["earth_melee", "water_penguin", "fire_candle", "fire_melee", "fire_archer"]:
		return 0.6
	if id in ["fire_tank", "water_tank", "earth_tank", "earth_siege"]:
		return 1.5
	return 1.0

static func realm_color(realm: String) -> Color:
	return Color({"fire":"d57346", "water":"659fbb", "earth":"7d9661"}.get(realm, "7d9661"))

static func warband_bond(ids: Array, card_data: Dictionary) -> SetBonusData:
	if not valid_warband(ids, card_data):
		return null
	var candidate: SetBonusData = bond(card_data[ids[0]].set_id)
	return candidate if bond_active(ids, card_data, candidate) else null

static func valid_warband(ids: Array, card_data: Dictionary) -> bool:
	if ids.size() != 4:
		return false
	var seen := {}
	for id in ids:
		if not id is String or seen.has(id) or not card_data.has(id):
			return false
		seen[id] = true
	return true

static func bond_active(ids: Array, card_data: Dictionary, realm: SetBonusData) -> bool:
	if realm == null or not valid_warband(ids, card_data) or ids.size() != realm.required_cards:
		return false
	for id in ids:
		if card_data[id].set_id != realm.set_id:
			return false
	return true
