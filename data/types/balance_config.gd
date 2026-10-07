class_name BalanceConfig
extends Resource

@export var starting_hearts: int = 4
@export var command_points: int = 3
@export var comeback_points: int = 1
@export var max_units_per_type: int = 24
@export var role_unit_caps: Dictionary = {"ranged":8, "melee":10, "tank":3, "mage":5, "assassin":3, "siege":4}
@export var max_units_per_side: int = 72
@export var max_reinforcements: int = 2
@export var normal_summons_for_special: int = 2
@export var max_rank: int = 3
@export var rank_hp: PackedFloat32Array = PackedFloat32Array([1.0, 1.25, 1.55])
@export var rank_damage: PackedFloat32Array = PackedFloat32Array([1.0, 1.25, 1.55])
@export var army_weight: float = 0.50
@export var reinforcement_weight: float = 0.15
@export var promotion_weight: float = 0.15
@export var power_weight: float = 0.20
@export var ticks_per_second: int = 30
@export var battle_limit_seconds: float = 45.0
@export var sudden_death_dps: float = 8.0
@export var sudden_death_escalation: float = 4.0

func unit_cap(role: String) -> int:
	return maxi(0, mini(max_units_per_type, int(role_unit_caps.get(role, max_units_per_type))))
