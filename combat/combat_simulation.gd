class_name CombatSimulation
extends RefCounted

# Everything here advances in integer ticks. No Node, rendering time, physics
# engine, global random source or player input participates in combat.
var config: BalanceConfig
var cards: Dictionary
var commander: CommanderData
var bond: SetBonusData
var units: Array = []
var projectiles: Array = []
var spell_prepared: Array = [false, false]
var wildfire: bool = false
var tick: int = 0
var finished: bool = false
var sudden_death: bool = false
var result: Dictionary = {}
var events: Array = []
var initial_hp: Array = [0.0, 0.0]
var next_projectile_id: int = 0

func _init(state) -> void:
	config = state.config
	cards = state.cards
	commander = state.commander
	bond = state.bond
	wildfire = GameCatalog.bond_active(state.warband, cards, bond)
	for side in range(2):
		spell_prepared[side] = state.sides[side].spell
		for card_id in state.warband:
			var army: Dictionary = state.sides[side].roster[card_id]
			var card: ArmyCardData = cards[card_id]
			for index in range(int(army.count)):
				var hp: float = card.stats.max_hp * config.rank_hp[int(army.rank) - 1]
				var location: Vector2 = formation(side, card.role, index)
				units.append({"id": units.size(), "side": side, "card_id": card_id,
					"role": card.role, "rank": army.rank, "hp": hp, "max_hp": hp,
					"damage": card.stats.damage * config.rank_damage[int(army.rank) - 1] * (1.0 + commander.attack_damage_bonus),
					"position": location, "previous_position": location, "cooldown": 0,
					"target": -1, "burn_until": 0, "burn_next": 0, "first_attack": true,
					"hit_at": -100, "attack_at": -100, "flanking": card.role == "assassin"})
				initial_hp[side] += hp

static func formation(side: int, role: String, index: int) -> Vector2:
	var x: float = {"tank": 209.0, "melee": 174.0, "ranged": 104.0, "assassin": 151.0}[role]
	var y: float = [70.0, 51.0, 89.0, 32.0, 108.0, 17.0, 125.0][index % 7]
	x -= float(index / 7) * 22.0
	if role == "assassin":
		y = 16.0 if index % 2 == 0 else 126.0
		x -= float(index / 2) * 13.0
	return Vector2(x if side == 0 else 560.0 - x, y)

func alive_count(side: int) -> int:
	var count := 0
	for unit in units:
		if unit.side == side and unit.hp > 0.0:
			count += 1
	return count

func hp_fraction(side: int) -> float:
	var remaining: float = 0.0
	for unit in units:
		if unit.side == side:
			remaining += maxf(float(unit.hp), 0.0)
	return remaining / maxf(float(initial_hp[side]), 1.0)

func attack_speed(unit: Dictionary) -> float:
	var bonus: float = commander.matching_attack_speed_bonus if cards[unit.card_id].set_id == commander.set_id else 0.0
	if spell_prepared[int(unit.side)] and tick < int(round(commander.spell_duration * config.ticks_per_second)):
		bonus += commander.spell_attack_speed_bonus
	return 1.0 + bonus

func _target(unit: Dictionary) -> int:
	var best_id := -1
	var best_priority := 99
	var best_distance: float = INF
	for enemy in units:
		if enemy.side == unit.side or enemy.hp <= 0.0:
			continue
		var priority := 0
		if unit.role == "assassin":
			# Ranged first; other rear units next, tanks last.
			priority = 0 if enemy.role == "ranged" else (2 if enemy.role == "tank" else 1)
		var distance: float = unit.position.distance_squared_to(enemy.position)
		if priority < best_priority or (priority == best_priority and (distance < best_distance - 0.0001 or (absf(distance - best_distance) <= 0.0001 and int(enemy.id) < best_id))):
			best_priority = priority
			best_distance = distance
			best_id = enemy.id
	return best_id

func _apply_first_burn(source: Dictionary, target: Dictionary) -> void:
	if not source.first_attack:
		return
	source.first_attack = false
	if wildfire and cards[source.card_id].set_id == bond.set_id and int(target.burn_until) <= tick:
		target.burn_until = tick + int(round(bond.burn_duration * config.ticks_per_second))
		target.burn_next = tick + config.ticks_per_second
		events.append({"kind": "burn", "unit": target.id})

func step() -> void:
	if finished:
		return
	events.clear()
	var dt: float = 1.0 / float(config.ticks_per_second)
	var damage: Array = []
	var movements: Array = []
	damage.resize(units.size())
	damage.fill(0.0)
	# Targeting and movement read the same start-of-tick state on both sides.
	for unit in units:
		unit.previous_position = unit.position
		var next_position: Vector2 = unit.position
		if unit.hp > 0.0:
			unit.target = _target(unit)
			if unit.target >= 0:
				var target: Dictionary = units[int(unit.target)]
				var stats: UnitStats = cards[unit.card_id].stats
				var destination: Vector2 = target.position
				if unit.flanking:
					var flank_y: float = 16.0 if int(unit.id) % 2 == 0 else 126.0
					var waypoint := Vector2(334.0 if unit.side == 0 else 226.0, flank_y)
					if unit.position.distance_to(waypoint) < 12.0 or (unit.side == 0 and unit.position.x >= 326.0) or (unit.side == 1 and unit.position.x <= 234.0):
						unit.flanking = false
					else:
						destination = waypoint
				if unit.position.distance_to(target.position) > stats.attack_range or unit.flanking:
					next_position = unit.position.move_toward(destination, stats.move_speed * dt)
				# Gentle same-side separation keeps silhouettes legible. A snapshot
				# ensures this cannot depend on update order or render frame rate.
				var separation := Vector2.ZERO
				for ally in units:
					if ally.id == unit.id or ally.side != unit.side or ally.hp <= 0.0:
						continue
					var offset: Vector2 = unit.position - ally.position
					var distance: float = offset.length()
					if distance < 12.0:
						var direction: Vector2 = offset / distance if distance > 0.001 else Vector2(0, -1 if unit.id < ally.id else 1)
						separation += direction * (12.0 - distance) * dt * 3.0
				next_position += separation
				next_position.x = clampf(next_position.x, 12.0, 548.0)
				next_position.y = clampf(next_position.y, 16.0, 126.0)
		movements.append(next_position)
	# Resolve attacks into a damage buffer; simultaneous attacks are fair.
	for unit in units:
		if unit.hp <= 0.0:
			continue
		unit.cooldown = maxi(int(unit.cooldown) - 1, 0)
		if unit.target >= 0 and unit.cooldown == 0 and not unit.flanking:
			var target: Dictionary = units[int(unit.target)]
			var stats: UnitStats = cards[unit.card_id].stats
			if unit.position.distance_to(target.position) <= stats.attack_range:
				unit.attack_at = tick
				unit.cooldown = maxi(1, int(ceil(float(config.ticks_per_second) / (stats.attacks_per_second * attack_speed(unit)))))
				if unit.role == "ranged":
					projectiles.append({"id": next_projectile_id, "source": unit.id,
						"target": target.id, "side": unit.side, "position": unit.position,
						"speed": stats.projectile_speed, "damage": unit.damage})
					next_projectile_id += 1
				else:
					damage[int(target.id)] += unit.damage
					_apply_first_burn(unit, target)
		if int(unit.burn_until) >= tick and int(unit.burn_next) > 0 and int(unit.burn_next) <= tick:
			damage[int(unit.id)] += bond.burn_damage_per_second
			unit.burn_next += config.ticks_per_second
		if tick > int(unit.burn_until):
			unit.burn_until = 0
			unit.burn_next = 0
		if sudden_death:
			var overtime: float = float(tick) * dt - config.battle_limit_seconds
			damage[int(unit.id)] += (config.sudden_death_dps + maxf(overtime, 0.0) * config.sudden_death_escalation) * dt
	var remaining_projectiles: Array = []
	for projectile in projectiles:
		var target: Dictionary = units[int(projectile.target)]
		if target.hp <= 0.0:
			continue
		projectile.position = projectile.position.move_toward(movements[int(target.id)], projectile.speed * dt)
		if projectile.position.distance_to(movements[int(target.id)]) <= 7.0:
			damage[int(target.id)] += projectile.damage
			_apply_first_burn(units[int(projectile.source)], target)
		else:
			remaining_projectiles.append(projectile)
	projectiles = remaining_projectiles
	for unit in units:
		unit.position = movements[int(unit.id)]
		if unit.hp <= 0.0:
			continue
		if damage[int(unit.id)] > 0.0:
			unit.hp = maxf(0.0, unit.hp - damage[int(unit.id)])
			unit.hit_at = tick
			events.append({"kind": "hit", "unit": unit.id, "amount": damage[int(unit.id)]})
		if unit.hp == 0.0:
			events.append({"kind": "defeat", "unit": unit.id, "position": unit.position, "side": unit.side})
	tick += 1
	var left: int = alive_count(0)
	var right: int = alive_count(1)
	if left == 0 or right == 0:
		_finish(-1 if left == 0 and right == 0 else (0 if right == 0 else 1), "Sudden death" if sudden_death else "Army dispersed")
	elif not sudden_death and tick >= int(round(config.battle_limit_seconds * config.ticks_per_second)):
		var difference: float = hp_fraction(0) - hp_fraction(1)
		if absf(difference) > 0.000001:
			_finish(0 if difference > 0 else 1, "Time limit · remaining HP")
		elif left != right:
			_finish(0 if left > right else 1, "Time limit · surviving units")
		else:
			sudden_death = true
			events.append({"kind": "sudden_death"})

func _finish(winning_side: int, reason: String) -> void:
	finished = true
	result = {"winner": winning_side, "reason": reason,
		"seconds": float(tick) / float(config.ticks_per_second),
		"survivors": [alive_count(0), alive_count(1)],
		"hp_percent": [hp_fraction(0), hp_fraction(1)]}
	# No temporary effect or queued projectile leaks into another battle.
	projectiles.clear()
	spell_prepared = [false, false]
	for unit in units:
		unit.burn_until = 0
		unit.burn_next = 0
		unit.cooldown = 0

func signature() -> String:
	var snapshot: Array = []
	for unit in units:
		snapshot.append([unit.id, unit.hp, unit.position.x, unit.position.y, unit.cooldown, unit.burn_until])
	return JSON.stringify([tick, snapshot, result]).sha256_text()
