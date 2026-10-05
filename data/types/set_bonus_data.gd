class_name SetBonusData
extends Resource

@export var id: String = "wildfire"
@export var display_name: String = "Wildfire"
@export var set_id: String = "fire"
@export var required_cards: int = 4
@export_enum("burn", "recovery", "shield") var effect: String = "burn"
@export var description: String = "Each Fire unit's first hit applies a 3-second Burn."
@export var burn_duration: float = 3.0
@export var burn_damage_per_second: float = 3.0
@export var recovery_threshold: float = 0.50
@export var recovery_fraction: float = 0.12
@export var recovery_seconds: int = 3
@export var shield_fraction: float = 0.10
