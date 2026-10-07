class_name PowerCards
extends RefCounted

# Match-wide upgrades live outside the four-card army loadout and unit caps.
const IDS := ["power_hp", "power_damage", "power_defence", "power_speed"]
const DEFINITIONS := {
	"power_hp": {"label":"+15% HP", "stat":"HP", "bonus":0.15,
		"description":"All your armies gain 15% max HP, including future summons, split Slimes and revived Ninjas."},
	"power_damage": {"label":"+10% Damage", "stat":"Damage", "bonus":0.10,
		"description":"All your armies deal 10% more damage with attacks, explosions, fire rings and burns."},
	"power_defence": {"label":"+12% DEF", "stat":"DEF", "bonus":0.12,
		"description":"All your armies gain 12% defence. Incoming damage is divided by their defence multiplier."},
	"power_speed": {"label":"+10% Attack Speed", "stat":"Attack Speed", "bonus":0.10,
		"description":"All your armies attack 10% faster. Movement speed and timed passive intervals stay the same."}
}

static func empty_stacks() -> Dictionary:
	return {"power_hp":0, "power_damage":0, "power_defence":0, "power_speed":0}

static func multiplier(stacks: Dictionary, id: String) -> float:
	return 1.0 + float(DEFINITIONS[id].bonus)*maxi(0, int(stacks.get(id, 0)))

static func summary(stacks: Dictionary) -> String:
	var parts: Array[String] = []
	for id in IDS:
		var count: int = int(stacks.get(id, 0))
		if count > 0:
			parts.append("%s +%d%%" % [DEFINITIONS[id].stat, roundi(float(DEFINITIONS[id].bonus)*count*100.0)])
	return " · ".join(parts)
