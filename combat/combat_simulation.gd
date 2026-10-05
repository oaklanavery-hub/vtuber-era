class_name CombatSimulation
extends RefCounted

# Integer ticks, snapshot movement and buffered simultaneous damage. No render
# timing, global random source, physics engine or player input affects combat.
var config: BalanceConfig
var cards: Dictionary
var commander: CommanderData
var bond: SetBonusData
var commanders: Array = []
var bonds: Array = []
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
var target_clusters: Dictionary = {}
var reading_movement_snapshot: bool = false
const BACKLINE := ["ranged", "mage", "siege"]

func _init(state) -> void:
	config = state.config
	cards = state.cards
	commander = state.commander
	bond = state.bond
	commanders = state.commanders
	bonds = state.bonds
	wildfire = bond != null and bond.effect == "burn"
	for side in range(2):
		var leader: CommanderData = commanders[side]
		spell_prepared[side] = state.sides[side].spell
		for card_id in state.warband_for(side):
			var army: Dictionary = state.sides[side].roster[card_id]
			var card: ArmyCardData = cards[card_id]
			var hp_bonus: float = leader.max_hp_bonus + (leader.matching_max_hp_bonus if card.set_id == leader.set_id else 0.0)
			for index in range(int(army.count)):
				var hp: float = card.stats.max_hp * config.rank_hp[int(army.rank)-1] * (1.0 + hp_bonus)
				var location: Vector2 = formation(side, card.role, index)
				units.append({"id":units.size(), "side":side, "card_id":card_id,
					"role":card.role, "rank":army.rank, "hp":hp, "max_hp":hp,
					"damage":card.stats.damage * config.rank_damage[int(army.rank)-1] * (1.0 + leader.attack_damage_bonus),
					"position":location, "previous_position":location, "cooldown":0,
					"target":-1, "burn_until":0, "burn_next":0, "burn_dps":0.0, "first_attack":true,
					"slow_until":0, "slow_fraction":0.0, "shield":0.0, "shield_until":0,
					"recovery_used":false, "recovery_next":0, "recovery_remaining":0,
					"lifesteal_window":0, "lifesteal_healed":0.0,
					"hit_at":-100, "heal_at":-100, "attack_at":-100, "flanking":card.role=="assassin"})
				initial_hp[side] += hp
	# Every recipient uses its own commander affinity; nearby shields do not stack.
	for unit in units:
		var realm: SetBonusData = bonds[int(unit.side)]
		if realm != null and realm.effect == "shield" and cards[unit.card_id].set_id == realm.set_id:
			_grant_shield(unit, unit.max_hp * realm.shield_fraction, -1)
	for source in units:
		var stats: UnitStats = cards[source.card_id].stats
		if stats.ally_shield_fraction <= 0.0:
			continue
		for ally in units:
			if ally.side == source.side and ally.position.distance_to(source.position) <= stats.ally_shield_radius:
				_grant_shield(ally, ally.max_hp * stats.ally_shield_fraction, int(round(stats.ally_shield_duration * config.ticks_per_second)))

static func formation(side: int, role: String, index: int) -> Vector2:
	var x: float = {"tank":209.0, "melee":174.0, "ranged":104.0, "mage":92.0, "siege":60.0, "assassin":151.0}[role]
	var y: float = [70.0, 51.0, 89.0, 32.0, 108.0, 17.0, 125.0][index%7]
	x -= float(index/7)*22.0
	if role == "assassin":
		y = 16.0 if index%2 == 0 else 126.0
		x -= float(index/2)*13.0
	return Vector2(x if side == 0 else 560.0-x, y)

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
	return remaining/maxf(float(initial_hp[side]), 1.0)

func spell_active(side: int) -> bool:
	return spell_prepared[side] and tick < int(round(commanders[side].spell_duration * config.ticks_per_second))

func attack_speed(unit: Dictionary) -> float:
	var leader: CommanderData = commanders[int(unit.side)]
	var bonus: float = leader.matching_attack_speed_bonus if cards[unit.card_id].set_id == leader.set_id else 0.0
	if spell_active(int(unit.side)):
		bonus += leader.spell_attack_speed_bonus
	return 1.0+bonus

func damage_multiplier(unit: Dictionary) -> float:
	var leader: CommanderData = commanders[int(unit.side)]
	return (1.0-leader.damage_reduction) * (1.0-leader.spell_damage_reduction if spell_active(int(unit.side)) else 1.0)

func healing_multiplier(unit: Dictionary) -> float:
	var leader: CommanderData = commanders[int(unit.side)]
	return 1.0 + (leader.matching_healing_shield_bonus if cards[unit.card_id].set_id == leader.set_id else 0.0)

func move_speed(unit: Dictionary) -> float:
	return cards[unit.card_id].stats.move_speed * (1.0-float(unit.slow_fraction) if tick < int(unit.slow_until) else 1.0)

func _grant_shield(unit: Dictionary, amount: float, until: int) -> void:
	var value: float = amount * healing_multiplier(unit)
	if value > float(unit.shield):
		unit.shield = value
		unit.shield_until = until

func _heal(unit: Dictionary, amount: float) -> float:
	if unit.hp <= 0.0:
		return 0.0
	var received: float = minf(amount * healing_multiplier(unit), unit.max_hp-unit.hp)
	if received > 0.0:
		unit.hp += received
		unit.heal_at = tick
		events.append({"kind":"heal", "unit":unit.id, "amount":received})
	return received

func _target(unit: Dictionary) -> int:
	var best_id := -1
	var best_priority := 999
	var best_distance: float = INF
	var stats: UnitStats = cards[unit.card_id].stats
	for enemy in units:
		if enemy.side == unit.side or enemy.hp <= 0.0:
			continue
		var distance: float = unit.position.distance_squared_to(enemy.position)
		var priority := 0
		if unit.role == "assassin":
			priority = 0 if enemy.role in BACKLINE else (2 if enemy.role == "tank" else 1)
		elif unit.role == "siege":
			var cluster: int = _cluster_size(enemy,stats.splash_radius)
			# Prefer reachable clusters, then their density. Distance/id break ties.
			priority = (0 if distance <= stats.attack_range*stats.attack_range else 100) - cluster
		if priority < best_priority or (priority == best_priority and (distance < best_distance-0.0001 or (absf(distance-best_distance) <= 0.0001 and int(enemy.id) < best_id))):
			best_priority = priority
			best_distance = distance
			best_id = enemy.id
	return best_id

func _cluster_size(enemy: Dictionary, radius: float) -> int:
	var key := Vector2(float(enemy.id),radius)
	if reading_movement_snapshot and target_clusters.has(key):
		return int(target_clusters[key])
	var count := 0
	for neighbor in units:
		if neighbor.side == enemy.side and neighbor.hp > 0.0 and neighbor.position.distance_squared_to(enemy.position) <= radius*radius:
			count += 1
	if reading_movement_snapshot:
		target_clusters[key] = count
	return count

func _apply_first_burn(source: Dictionary, target: Dictionary) -> void:
	if not source.first_attack:
		return
	source.first_attack = false
	var realm: SetBonusData = bonds[int(source.side)]
	if realm != null and realm.effect == "burn" and cards[source.card_id].set_id == realm.set_id and int(target.burn_until) <= tick:
		target.burn_until = tick + int(round(realm.burn_duration*config.ticks_per_second))
		target.burn_next = tick + config.ticks_per_second
		target.burn_dps = realm.burn_damage_per_second
		events.append({"kind":"burn", "unit":target.id})

func _hit(source: Dictionary, target: Dictionary, amount: float, damage: Array, hits: Array) -> void:
	damage[int(target.id)] += amount
	hits.append({"source":source.id, "target":target.id, "amount":amount})
	_apply_first_burn(source, target)
	var stats: UnitStats = cards[source.card_id].stats
	if stats.slow_fraction > 0.0:
		target.slow_fraction = maxf(float(target.slow_fraction), stats.slow_fraction)
		target.slow_until = maxi(int(target.slow_until), tick+1+int(round(stats.slow_duration*config.ticks_per_second)))
		events.append({"kind":"slow", "unit":target.id})

func _move(unit: Dictionary, dt: float) -> Vector2:
	var next_position: Vector2 = unit.position
	if unit.hp <= 0.0:
		return next_position
	unit.target = _target(unit)
	if unit.target < 0:
		return next_position
	var target: Dictionary = units[int(unit.target)]
	var stats: UnitStats = cards[unit.card_id].stats
	var destination: Vector2 = target.position
	if unit.flanking:
		var flank_y: float = 16.0 if int(unit.id)%2 == 0 else 126.0
		var waypoint := Vector2(334.0 if unit.side == 0 else 226.0, flank_y)
		if unit.position.distance_to(waypoint) < 12.0 or (unit.side == 0 and unit.position.x >= 326.0) or (unit.side == 1 and unit.position.x <= 234.0):
			unit.flanking = false
		else:
			destination = waypoint
	if unit.position.distance_to(target.position) > stats.attack_range or unit.flanking:
		next_position = unit.position.move_toward(destination, move_speed(unit)*dt)
	var separation := Vector2.ZERO
	for ally in units:
		if ally.id == unit.id or ally.side != unit.side or ally.hp <= 0.0:
			continue
		var offset: Vector2 = unit.position-ally.position
		var distance: float = offset.length()
		if distance < 12.0:
			var direction: Vector2 = offset/distance if distance > 0.001 else Vector2(0, -1 if unit.id < ally.id else 1)
			separation += direction*(12.0-distance)*dt*3.0
	next_position += separation
	return Vector2(clampf(next_position.x, 12.0, 548.0), clampf(next_position.y, 16.0, 126.0))

func step() -> void:
	if finished:
		return
	events.clear()
	var dt: float = 1.0/float(config.ticks_per_second)
	var damage: Array = []
	damage.resize(units.size())
	damage.fill(0.0)
	var movements: Array = []
	var hits: Array = []
	target_clusters.clear()
	reading_movement_snapshot = true
	for unit in units:
		unit.previous_position = unit.position
		if int(unit.shield_until) > 0 and tick >= int(unit.shield_until):
			unit.shield = 0.0
		if tick >= int(unit.slow_until):
			unit.slow_fraction = 0.0
		movements.append(_move(unit, dt))
	reading_movement_snapshot = false
	for unit in units:
		if unit.hp <= 0.0:
			continue
		unit.cooldown = maxi(int(unit.cooldown)-1, 0)
		if unit.target >= 0 and unit.cooldown == 0 and not unit.flanking:
			var target: Dictionary = units[int(unit.target)]
			var stats: UnitStats = cards[unit.card_id].stats
			if unit.position.distance_to(target.position) <= stats.attack_range:
				unit.attack_at = tick
				unit.cooldown = maxi(1, int(ceil(float(config.ticks_per_second)/(stats.attacks_per_second*attack_speed(unit)))))
				if unit.role in BACKLINE:
					projectiles.append({"id":next_projectile_id, "source":unit.id, "card_id":unit.card_id,
						"target":target.id, "side":unit.side, "position":unit.position,
						"impact":target.position, "speed":stats.projectile_speed, "damage":unit.damage})
					next_projectile_id += 1
				else:
					_hit(unit, target, unit.damage, damage, hits)
		if int(unit.burn_until) >= tick and int(unit.burn_next) > 0 and int(unit.burn_next) <= tick:
			damage[int(unit.id)] += unit.burn_dps
			unit.burn_next += config.ticks_per_second
		if tick > int(unit.burn_until):
			unit.burn_until = 0
			unit.burn_next = 0
		if sudden_death:
			var overtime: float = float(tick)*dt-config.battle_limit_seconds
			damage[int(unit.id)] += (config.sudden_death_dps+maxf(overtime, 0.0)*config.sudden_death_escalation)*dt
	var remaining: Array = []
	for projectile in projectiles:
		var source: Dictionary = units[int(projectile.source)]
		var stats: UnitStats = cards[source.card_id].stats
		var target: Dictionary = units[int(projectile.target)]
		if target.hp <= 0.0 and stats.splash_radius <= 0.0:
			continue
		if target.hp > 0.0 and source.role != "siege":
			projectile.impact = movements[int(target.id)]
		projectile.position = projectile.position.move_toward(projectile.impact, projectile.speed*dt)
		if projectile.position.distance_to(projectile.impact) > 7.0:
			remaining.append(projectile)
			continue
		if stats.splash_radius <= 0.0:
			_hit(source, target, projectile.damage, damage, hits)
		else:
			for victim in units:
				if victim.side == source.side or victim.hp <= 0.0 or movements[int(victim.id)].distance_to(projectile.impact) > stats.splash_radius:
					continue
				_hit(source, victim, projectile.damage*(1.0 if victim.id == target.id else stats.splash_falloff), damage, hits)
			events.append({"kind":"splash", "position":projectile.impact, "set_id":cards[source.card_id].set_id, "radius":stats.splash_radius})
	projectiles = remaining
	var hp_lost: Array = []
	hp_lost.resize(units.size())
	hp_lost.fill(0.0)
	for unit in units:
		unit.position = movements[int(unit.id)]
		if unit.hp <= 0.0:
			continue
		var incoming: float = float(damage[int(unit.id)])*damage_multiplier(unit)
		var absorbed: float = minf(float(unit.shield), incoming)
		unit.shield -= absorbed
		incoming -= absorbed
		hp_lost[int(unit.id)] = minf(float(unit.hp), incoming)
		unit.hp = maxf(0.0, unit.hp-incoming)
		if float(damage[int(unit.id)]) > 0.0:
			unit.hit_at = tick
			events.append({"kind":"hit", "unit":unit.id, "amount":incoming, "absorbed":absorbed})
		if unit.hp == 0.0:
			events.append({"kind":"defeat", "unit":unit.id, "position":unit.position, "side":unit.side, "set_id":cards[unit.card_id].set_id})
		else:
			var realm: SetBonusData = bonds[int(unit.side)]
			# Record crossing the threshold before lifesteal or spell healing can
			# raise HP again during this same simultaneous damage step.
			if realm != null and realm.effect == "recovery" and cards[unit.card_id].set_id == realm.set_id and not unit.recovery_used and unit.hp < unit.max_hp*realm.recovery_threshold:
				unit.recovery_used = true
				unit.recovery_remaining = realm.recovery_seconds
				unit.recovery_next = tick+config.ticks_per_second
	# Lifesteal is credited only for actual HP damage, never shield absorption,
	# overkill or Burn. Prorating buffered hits makes simultaneous attackers fair.
	for hit in hits:
		var source: Dictionary = units[int(hit.source)]
		var stats: UnitStats = cards[source.card_id].stats
		if source.hp <= 0.0 or stats.lifesteal_fraction <= 0.0:
			continue
		var window: int = int(tick/config.ticks_per_second)
		if source.lifesteal_window != window:
			source.lifesteal_window = window
			source.lifesteal_healed = 0.0
		var credit: float = hp_lost[int(hit.target)]*float(hit.amount)/maxf(float(damage[int(hit.target)]), 0.0001)
		var allowance: float = maxf(0.0, source.max_hp*stats.lifesteal_cap_per_second-float(source.lifesteal_healed))
		var raw_heal: float = minf(credit*stats.lifesteal_fraction, allowance/healing_multiplier(source))
		source.lifesteal_healed += _heal(source, raw_heal)
	for unit in units:
		if unit.hp <= 0.0:
			continue
		var realm: SetBonusData = bonds[int(unit.side)]
		if realm != null and realm.effect == "recovery" and cards[unit.card_id].set_id == realm.set_id:
			if unit.recovery_remaining > 0 and tick >= int(unit.recovery_next):
				_heal(unit, unit.max_hp*realm.recovery_fraction/float(realm.recovery_seconds))
				unit.recovery_remaining -= 1
				unit.recovery_next += config.ticks_per_second
		var leader: CommanderData = commanders[int(unit.side)]
		if spell_active(int(unit.side)) and leader.spell_healing_per_second > 0.0 and (tick+1)%config.ticks_per_second == 0:
			_heal(unit, unit.max_hp*leader.spell_healing_per_second)
	tick += 1
	var left: int = alive_count(0)
	var right: int = alive_count(1)
	if left == 0 or right == 0:
		_finish(-1 if left == 0 and right == 0 else (0 if right == 0 else 1), "Sudden death" if sudden_death else "Army dispersed")
	elif not sudden_death and tick >= int(round(config.battle_limit_seconds*config.ticks_per_second)):
		var difference: float = hp_fraction(0)-hp_fraction(1)
		if absf(difference) > 0.000001:
			_finish(0 if difference > 0 else 1, "Time limit · remaining HP")
		elif left != right:
			_finish(0 if left > right else 1, "Time limit · surviving units")
		else:
			sudden_death = true
			events.append({"kind":"sudden_death"})

func _finish(winning_side: int, reason: String) -> void:
	finished = true
	result = {"winner":winning_side, "reason":reason,
		"seconds":float(tick)/float(config.ticks_per_second),
		"survivors":[alive_count(0), alive_count(1)], "hp_percent":[hp_fraction(0), hp_fraction(1)]}
	projectiles.clear()
	spell_prepared = [false, false]
	for unit in units:
		for key in ["burn_until", "burn_next", "slow_until", "recovery_next", "recovery_remaining", "cooldown"]:
			unit[key] = 0
		unit.shield = 0.0
		unit.shield_until = 0
		unit.slow_fraction = 0.0

func signature() -> String:
	var snapshot: Array = []
	for unit in units:
		snapshot.append([unit.id, unit.hp, unit.position.x, unit.position.y, unit.cooldown, unit.burn_until,
			unit.shield, unit.slow_until, unit.recovery_used, unit.recovery_remaining, unit.lifesteal_healed])
	return JSON.stringify([tick, snapshot, projectiles, result]).sha256_text()
