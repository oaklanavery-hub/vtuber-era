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
const ARENA_SIZE := Vector2(600, 202)
# Collision stays on, but occupies only 30% of the old 24px footprint.
# Sprite/spawn spacing is independent so armies remain readable before combat.
const BODY_SIZE: float = 7.2
const SPAWN_SPACING: float = 24.0
const GRID_SIZE: float = 24.0
const DETOUR_COMMITMENT: float = 1.4
const MIN_POSITION := Vector2(16, 28)
const MAX_POSITION := Vector2(584, 180)
const SPAWN_ROWS := [100.0, 76.0, 124.0, 52.0, 148.0, 28.0, 172.0]

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
		for entry in spawn_layout(state, side):
			var card_id: String = entry.card_id
			var army: Dictionary = state.sides[side].roster[card_id]
			var card: ArmyCardData = cards[card_id]
			var hp_bonus: float = leader.max_hp_bonus + (leader.matching_max_hp_bonus if card.set_id == leader.set_id else 0.0)
			var hp: float = card.stats.max_hp * config.rank_hp[int(army.rank)-1] * (1.0 + hp_bonus)
			var location: Vector2 = entry.position
			units.append({"id":units.size(), "side":side, "card_id":card_id,
				"role":card.role, "rank":army.rank, "hp":hp, "max_hp":hp,
				"damage":card.stats.damage * config.rank_damage[int(army.rank)-1] * (1.0 + leader.attack_damage_bonus),
				"position":location, "previous_position":location, "cooldown":0,
				"target":-1, "burn_until":0, "burn_next":0, "burn_dps":0.0, "first_attack":true,
				"slow_until":0, "slow_fraction":0.0, "shield":0.0, "shield_until":0,
				"recovery_used":false, "recovery_next":0, "recovery_remaining":0,
				"lifesteal_window":0, "lifesteal_healed":0.0,
				"navigation_bias":(-1.0 if location.y <= 100.0 else 1.0) * (1.0 if side == 0 else -1.0),
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
	var x: float = {"tank":244.0, "melee":220.0, "ranged":100.0, "mage":76.0, "siege":52.0, "assassin":196.0}[role]
	var y: float = SPAWN_ROWS[index%7]
	x -= float(index/7)*SPAWN_SPACING
	if role == "assassin":
		y = 28.0 if index%2 == 0 else 172.0
		x -= float(index/2)*SPAWN_SPACING
	return Vector2(x if side == 0 else ARENA_SIZE.x-x, y)

static func spawn_layout(state, side: int) -> Array:
	# One shared allocator for preview and combat. Mixed armies never reuse a
	# role's positions. The 77 slots accommodate the 72-unit per-side cap.
	var entries: Array = []
	var role_counts: Dictionary = {}
	var priority := {"tank":0, "melee":1, "assassin":2, "ranged":3, "mage":4, "siege":5}
	for card_id in state.warband_for(side):
		var army: Dictionary = state.sides[side].roster[card_id]
		var role: String = state.cards[card_id].role
		for index in range(int(army.count)):
			var role_index: int = int(role_counts.get(role, 0))
			role_counts[role] = role_index+1
			entries.append({"card_id":card_id, "index":index, "rank":army.rank,
				"order":entries.size(), "priority":priority[role],
				"preferred":formation(0, role, role_index), "position":Vector2.ZERO, "side":side})
	var placement: Array = entries.duplicate()
	placement.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.priority < b.priority if a.priority != b.priority else a.order < b.order)
	var slots: Array[Vector2] = []
	for column in range(11):
		for row in SPAWN_ROWS:
			slots.append(Vector2(28.0+column*SPAWN_SPACING, row))
	for entry in placement:
		var best: int = 0
		var best_distance: float = INF
		for index in range(slots.size()):
			var distance: float = slots[index].distance_squared_to(entry.preferred)
			if distance < best_distance:
				best = index
				best_distance = distance
		var position: Vector2 = slots[best]
		slots.remove_at(best)
		entry.position = Vector2(position.x if side == 0 else ARENA_SIZE.x-position.x, position.y)
	return entries

func in_attack_range(unit: Dictionary, target: Dictionary) -> bool:
	var reach: float = cards[unit.card_id].stats.attack_range
	var delta: Vector2 = (unit.position-target.position).abs()
	if unit.role in BACKLINE:
		return delta.length_squared() <= reach*reach
	# Melee attacks meet at the body edges. A short-range attacker can make
	# contact with a solid enemy without having to enter the enemy's footprint.
	var gap := Vector2(maxf(0.0, delta.x-BODY_SIZE), maxf(0.0, delta.y-BODY_SIZE))
	return gap.length() <= maxf(0.0, reach-BODY_SIZE)+0.06

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
	var destination: Vector2 = target.position
	if unit.flanking:
		var flank_y: float = 28.0 if int(unit.id)%2 == 0 else 172.0
		var waypoint := Vector2(354.0 if unit.side == 0 else 246.0, flank_y)
		if unit.position.distance_to(waypoint) < 12.0 or (unit.side == 0 and unit.position.x >= 346.0) or (unit.side == 1 and unit.position.x <= 254.0):
			unit.flanking = false
		else:
			destination = waypoint
	if not in_attack_range(unit, target) or unit.flanking:
		next_position = unit.position.move_toward(destination, move_speed(unit)*dt)
	return next_position

func _clip_motion(origin: Vector2, motion: Vector2, neighbors: Array, reservations: Array, own_id: int) -> Vector2:
	var limit: float = 1.0
	for axis in range(2):
		if motion[axis] > 0.000001:
			limit = minf(limit, (MAX_POSITION[axis]-origin[axis])/motion[axis])
		elif motion[axis] < -0.000001:
			limit = minf(limit, (MIN_POSITION[axis]-origin[axis])/motion[axis])
	for id in neighbors:
		if id == own_id:
			continue
		var obstacle: Rect2 = reservations[id]
		# A diagonal path's conservative reservation can surround a neighbor's
		# old corner without the actual bodies touching. That neighbor waits
		# this tick; treating a negative ray entry as clear would let it clip.
		if origin.x > obstacle.position.x+0.000001 and origin.x < obstacle.end.x-0.000001 and origin.y > obstacle.position.y+0.000001 and origin.y < obstacle.end.y-0.000001:
			return Vector2.ZERO
		var entry: float = -INF
		var leave: float = INF
		var possible: bool = true
		for axis in range(2):
			if absf(motion[axis]) < 0.000001:
				# Exact edge contact is legal: slide along, never into, a body.
				if origin[axis] <= obstacle.position[axis]+0.000001 or origin[axis] >= obstacle.end[axis]-0.000001:
					possible = false
					break
			else:
				var first: float = (obstacle.position[axis]-origin[axis])/motion[axis]
				var last: float = (obstacle.end[axis]-origin[axis])/motion[axis]
				entry = maxf(entry, minf(first, last))
				leave = minf(leave, maxf(first, last))
		if possible and entry <= leave and leave > 0.000001 and entry >= -0.000001:
			limit = minf(limit, maxf(0.0, entry-0.00001))
	return motion*clampf(limit, 0.0, 1.0)

func _resolve_movements(movements: Array) -> void:
	# Permanent swept-box collision for BOTH teams. Reservations include the
	# entire path this tick, so interpolated collision bodies cannot cross.
	# Rotate priority each tick; no unit/team always wins a crowded lane.
	var grid: Dictionary = {}
	var reservations: Array = []
	for unit in units:
		var location: Vector2 = unit.position
		reservations.append(Rect2(location-Vector2.ONE*BODY_SIZE, Vector2.ONE*BODY_SIZE*2.0))
		if unit.hp <= 0.0:
			continue
		var cell := Vector2i(floori(location.x/GRID_SIZE), floori(location.y/GRID_SIZE))
		if not grid.has(cell):
			grid[cell] = []
		grid[cell].append(unit.id)
	for order in range(units.size()):
		var id: int = (order+tick)%units.size()
		var unit: Dictionary = units[id]
		var origin: Vector2 = unit.position
		var desired: Vector2 = movements[id]-origin
		if unit.hp <= 0.0 or desired.length_squared() < 0.000001:
			continue
		var neighbors: Array = []
		var cell := Vector2i(floori(origin.x/GRID_SIZE), floori(origin.y/GRID_SIZE))
		for x in range(cell.x-2, cell.x+3):
			for y in range(cell.y-2, cell.y+3):
				neighbors.append_array(grid.get(Vector2i(x,y), []))
		var best: Vector2 = _clip_motion(origin, desired, neighbors, reservations, id)
		var at_contact: bool = false
		if unit.target >= 0 and not unit.flanking:
			var projected: Dictionary = unit.duplicate()
			projected.position = origin+best
			at_contact = in_attack_range(projected, units[int(unit.target)])
		if not at_contact and best.length_squared() < desired.length_squared()*0.95:
			# A blocked, out-of-range unit seeks a free lane. Test both sides and
			# allow sideways/backward steps when a direct approach is congested.
			var direction: Vector2 = desired.normalized()
			var best_score: float = best.length()+best.dot(direction)*0.65
			var escape_bias: float = float(unit.navigation_bias)
			for angle in [PI/4.0, PI/2.0, PI*3.0/4.0]:
				for sign_value in [float(unit.navigation_bias), -float(unit.navigation_bias)]:
					var candidate: Vector2 = _clip_motion(origin, desired.rotated(angle*sign_value), neighbors, reservations, id)
					var score: float = candidate.length()+candidate.dot(direction)*0.65
					if sign_value == float(unit.navigation_bias):
						score += candidate.length()*DETOUR_COMMITMENT
					if score > best_score+0.00001:
						best = candidate
						best_score = score
						escape_bias = sign_value
			# Axis-aligned lanes matter for square bodies: a rotated tangent
			# may still point into a long wall. Keep a stable escape-side bias
			# so the unit does not oscillate between two blocked approaches.
			var vertical_bias: float = float(unit.navigation_bias)*(1.0 if unit.side == 0 else -1.0)
			for sign_value in [vertical_bias, -vertical_bias]:
				var candidate: Vector2 = _clip_motion(origin, Vector2(0,sign_value)*desired.length(), neighbors, reservations, id)
				var score: float = candidate.length()+candidate.dot(direction)*0.65
				if sign_value == vertical_bias:
					score += candidate.length()*DETOUR_COMMITMENT
				if score > best_score+0.00001:
					best = candidate
					best_score = score
					escape_bias = sign_value*(1.0 if unit.side == 0 else -1.0)
			if best.length_squared() >= desired.length_squared()*0.5:
				# If the preferred lane is closed (especially at an arena edge),
				# commit to the other escape side rather than bouncing back.
				unit.navigation_bias = escape_bias
		movements[id] = origin+best
		var minimum := Vector2(minf(origin.x, movements[id].x), minf(origin.y, movements[id].y))
		var maximum := Vector2(maxf(origin.x, movements[id].x), maxf(origin.y, movements[id].y))
		reservations[id] = Rect2(minimum-Vector2.ONE*BODY_SIZE, maximum-minimum+Vector2.ONE*BODY_SIZE*2.0)

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
	_resolve_movements(movements)
	for unit in units:
		if unit.hp <= 0.0:
			continue
		unit.cooldown = maxi(int(unit.cooldown)-1, 0)
		if unit.target >= 0 and unit.cooldown == 0 and not unit.flanking:
			var target: Dictionary = units[int(unit.target)]
			var stats: UnitStats = cards[unit.card_id].stats
			if in_attack_range(unit, target):
				unit.attack_at = tick
				events.append({"kind":"attack", "card_id":unit.card_id})
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
			unit.shield, unit.slow_until, unit.recovery_used, unit.recovery_remaining, unit.lifesteal_healed,
			unit.navigation_bias, unit.flanking])
	return JSON.stringify([tick, snapshot, projectiles, result]).sha256_text()
