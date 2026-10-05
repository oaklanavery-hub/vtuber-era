class_name ArmyCardData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var short_name: String = ""
@export var set_id: String = "fire"
@export_enum("tank", "melee", "ranged", "assassin", "mage", "siege") var role: String = "melee"
@export var group_size: int = 3
@export var description: String = ""
@export var stats: UnitStats
@export var sprite: Texture2D
