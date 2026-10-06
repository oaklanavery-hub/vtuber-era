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
@export var spell_name: String = "Meteor Rain"
@export_enum("meteors", "frozen_field", "earth_walls") var spell_kind: String = "meteors"
@export var spell_description: String = "6 meteors · before battle"
@export_multiline var spell_details: String = "Six meteors strike across the enemy field before armies move. Each deals 30 area damage in a 34-pixel radius. Shields and defence apply."
@export var meteor_count: int = 6
@export var meteor_damage: float = 30.0
@export var meteor_radius: float = 34.0
@export var meteor_first_impact: float = 0.5
@export var meteor_interval: float = 0.22
@export var meteor_opening_seconds: float = 2.0
@export var spell_slow_fraction: float = 0.15
@export var spell_defence_reduction: float = 0.08
@export var spell_wall_size: Vector2 = Vector2(12, 72)
@export var portrait: Texture2D
