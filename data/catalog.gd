class_name GameCatalog
extends RefCounted

const FIRE_IDS := ["fire_archer", "fire_melee", "fire_tank", "fire_assassin"]

static func cards() -> Dictionary:
	var result := {}
	for id in FIRE_IDS:
		result[id] = load("res://data/armies/%s.tres" % id)
	return result

static func balance() -> BalanceConfig:
	return load("res://data/balance.tres")

static func commander() -> CommanderData:
	return load("res://data/commanders/fire.tres")

static func bond() -> SetBonusData:
	return load("res://data/bonds/wildfire.tres")

static func valid_warband(ids: Array, card_data: Dictionary) -> bool:
	if ids.size() != 4:
		return false
	var seen := {}
	for id in ids:
		if seen.has(id) or not card_data.has(id):
			return false
		seen[id] = true
	return true

static func bond_active(ids: Array, card_data: Dictionary, realm: SetBonusData) -> bool:
	if not valid_warband(ids, card_data) or ids.size() != realm.required_cards:
		return false
	for id in ids:
		if card_data[id].set_id != realm.set_id:
			return false
	return true
