class_name CommanderData
extends Resource

@export var id: String = "fire_commander"
@export var display_name: String = "Fire Commander"
@export var set_id: String = "fire"
@export var identity: String = "A cheerful flame warden and festival champion."
@export_multiline var passive_description: String = "All allies: +5% attack damage\nFire allies: +5% attack speed"
@export var attack_damage_bonus: float = 0.05
@export var matching_attack_speed_bonus: float = 0.05
@export var max_hp_bonus: float = 0.0
@export var matching_max_hp_bonus: float = 0.0
@export var damage_reduction: float = 0.0
@export var matching_healing_shield_bonus: float = 0.0
@export var spell_name: String = "Blazing Orders"
@export_enum("attack_speed", "healing", "damage_reduction") var spell_kind: String = "attack_speed"
@export var spell_description: String = "+25% attack speed · 6s"
@export var spell_attack_speed_bonus: float = 0.25
@export var spell_healing_per_second: float = 0.0
@export var spell_damage_reduction: float = 0.0
@export var spell_duration: float = 6.0
@export var portrait: Texture2D
