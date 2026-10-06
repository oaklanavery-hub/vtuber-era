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
var fields: Array = []
var pending_children: Array = []
var next_field_id: int = 0
var passive_counts: Dictionary = {}
const BACKLINE := ["ranged", "mage", "siege"]
const ARENA_SIZE := Vector2(600, 202)
# Collision stays on, but occupies only 30% of the old 24px footprint.
# Sprite/spawn spacing is independent so armies remain readable before combat.
const BODY_SIZE: float = 7.2
const SPAWN_SPACING: float = 24.0
const GRID_SIZE: float = 24.0
const DETOUR_COMMITMENT: float = 1.4
const BOUNCE_TICKS: int = 12
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
			_prepare_passive_state(units.back())
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

func _ticks(seconds: float) -> int:
	return maxi(1, int(round(seconds * config.ticks_per_second)))

func _prepare_passive_state(unit: Dictionary) -> void:
	var stats: UnitStats = cards[unit.card_id].stats
	unit.merge({"flame_until":0, "flame_next":0, "flame_dps":0.0,
		"ice_until":0, "ice_fraction":0.0, "attack_slow_until":0, "attack_slow_fraction":0.0,
		"revive_used":false, "death_processed":false, "is_child":false, "visual_scale":1.0,
		"next_flame":_ticks(stats.flame_interval), "next_ice":0, "ice_anchor":unit.position,
		"next_heal":_ticks(stats.heal_interval), "next_bounce":_ticks(stats.bounce_interval),
		"next_split_shot":_ticks(stats.split_shot_interval), "bounce_at":-100, "revive_at":-100}, true)

func _passive(ability: String, unit: Dictionary, radius: float = 0.0, location: Vector2 = Vector2.INF) -> void:
	passive_counts[ability] = int(passive_counts.get(ability, 0))+1
	events.append({"kind":"passive", "ability":ability, "unit":unit.id,
		"position":unit.position if location == Vector2.INF else location,
		"set_id":cards[unit.card_id].set_id, "radius":radius})

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
	var slow: float = float(unit.slow_fraction) if tick < int(unit.slow_until) else 0.0
	if tick < int(unit.ice_until):
		slow = maxf(slow, float(unit.ice_fraction))
	return cards[unit.card_id].stats.move_speed * (1.0-slow)

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

func _hit(source: Dictionary, target: Dictionary, amount: float, damage: Array, hits: Array, attack_effects: bool = true) -> void:
	damage[int(target.id)] += amount
	hits.append({"source":source.id, "target":target.id, "amount":amount})
	if not attack_effects:
		return
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
	if tick-int(unit.bounce_at) < BOUNCE_TICKS:
		return next_position
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

func _resolve_movements(movements: Array, forced: Dictionary = {}) -> void:
	# Permanent swept-box collision for BOTH teams. Reservations include the
	# entire path this tick, so interpolated collision bodies cannot cross.
	# Rotate priority each tick; no unit/team always wins a crowded lane.
	var grid: Dictionary = {}
	var reservations: Array = []
	var largest_motion: float = 0.0
	for unit in units:
		largest_motion = maxf(largest_motion, unit.position.distance_to(movements[int(unit.id)]))
	var search_radius: int = maxi(2, 1+ceili((largest_motion*2.0+BODY_SIZE)/GRID_SIZE))
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
		for x in range(cell.x-search_radius, cell.x+search_radius+1):
			for y in range(cell.y-search_radius, cell.y+search_radius+1):
				neighbors.append_array(grid.get(Vector2i(x,y), []))
		var best: Vector2 = _clip_motion(origin, desired, neighbors, reservations, id)
		var at_contact: bool = false
		if unit.target >= 0 and not unit.flanking:
			var projected: Dictionary = unit.duplicate()
			projected.position = origin+best
			at_contact = in_attack_range(projected, units[int(unit.target)])
		if not forced.has(id) and not at_contact and best.length_squared() < desired.length_squared()*0.95:
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

func _projectile(source: Dictionary, target: Dictionary, amount: float, fan: int = 0, posthumous: bool = false) -> void:
	var stats: UnitStats = cards[source.card_id].stats
	projectiles.append({"id":next_projectile_id, "source":source.id, "card_id":source.card_id,
		"target":target.id, "side":source.side, "position":source.position+Vector2(0, fan*3),
		"impact":target.position, "speed":stats.projectile_speed, "damage":amount,
		"splash_radius":stats.death_blast_radius if posthumous else stats.splash_radius,
		"falloff":1.0 if posthumous else stats.splash_falloff, "posthumous":posthumous, "fan":fan})
	next_projectile_id += 1

func _attack(unit: Dictionary, target: Dictionary, damage: Array, hits: Array, fan_due: bool) -> void:
	var stats: UnitStats = cards[unit.card_id].stats
	unit.attack_at = tick
	events.append({"kind":"attack", "card_id":unit.card_id})
	unit.cooldown = float(maxi(1, int(ceil(float(config.ticks_per_second)/(stats.attacks_per_second*attack_speed(unit))))))
	if fan_due:
		var targets: Array = units.filter(func(enemy: Dictionary) -> bool:
			return enemy.side != unit.side and enemy.hp > 0.0 and in_attack_range(unit, enemy))
		targets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var first: float = unit.position.distance_squared_to(a.position)
			var second: float = unit.position.distance_squared_to(b.position)
			return first < second if first != second else a.id < b.id)
		for index in range(stats.split_shot_count):
			_projectile(unit, targets[index%targets.size()], unit.damage/float(stats.split_shot_count), index-1)
		unit.next_split_shot = tick+1+_ticks(stats.split_shot_interval)
		_passive("split_arrows", unit)
	elif unit.role in BACKLINE:
		_projectile(unit, target, unit.damage)
	else:
		_hit(unit, target, unit.damage, damage, hits)

func _tick_fields() -> void:
	fields = fields.filter(func(field: Dictionary) -> bool: return int(field.until) > tick)
	for unit in units:
		if unit.hp <= 0.0:
			continue
		var stats: UnitStats = cards[unit.card_id].stats
		if stats.flame_interval > 0.0 and tick+1 >= int(unit.next_flame):
			var enemy_id: int = _target(unit)
			if enemy_id >= 0:
				var direction: float = 1.0 if units[enemy_id].position.x >= unit.position.x else -1.0
				var size := Vector2(stats.flame_width, stats.flame_length)
				var center: Vector2 = unit.position+Vector2(direction*14.0, 0)
				center = center.clamp(size/2.0, ARENA_SIZE-size/2.0)
				fields.append({"id":next_field_id, "kind":"flame", "source":unit.id, "side":unit.side,
					"rect":Rect2(center-size/2.0, size), "until":tick+_ticks(stats.flame_lifetime),
					"dps":stats.flame_burn_dps, "duration":_ticks(stats.flame_burn_duration)})
				next_field_id += 1
				_passive("flame_wall", unit, stats.flame_length/2.0, center)
			unit.next_flame = tick+1+_ticks(stats.flame_interval)
		if stats.ice_interval > 0.0 and tick >= int(unit.next_ice):
			var start: Vector2 = unit.ice_anchor
			var end: Vector2 = unit.position
			var minimum := Vector2(minf(start.x,end.x), minf(start.y,end.y))
			var rectangle := Rect2(minimum-Vector2.ONE*stats.ice_width/2.0, (end-start).abs()+Vector2.ONE*stats.ice_width)
			var refreshed: bool = false
			# A stationary golem refreshes its path rather than piling up fields.
			if start.distance_squared_to(end) < 1.0:
				for field in fields:
					if field.kind == "ice" and field.source == unit.id and field.rect == rectangle:
						field.until = tick+_ticks(stats.ice_lifetime)
						refreshed = true
						break
			if not refreshed:
				fields.append({"id":next_field_id, "kind":"ice", "source":unit.id, "side":unit.side,
					"rect":rectangle, "until":tick+_ticks(stats.ice_lifetime),
					"fraction":stats.ice_slow_fraction, "duration":_ticks(stats.ice_slow_duration)})
				next_field_id += 1
				_passive("ice_path", unit, stats.ice_width/2.0, rectangle.get_center())
			unit.ice_anchor = end
			unit.next_ice = tick+_ticks(stats.ice_interval)

func _crosses_rect(start: Vector2, end: Vector2, rectangle: Rect2) -> bool:
	var delta: Vector2 = end-start
	var enter: float = 0.0
	var leave: float = 1.0
	for axis in range(2):
		if absf(delta[axis]) < 0.000001:
			if start[axis] < rectangle.position[axis] or start[axis] > rectangle.end[axis]:
				return false
		else:
			var first: float = (rectangle.position[axis]-start[axis])/delta[axis]
			var last: float = (rectangle.end[axis]-start[axis])/delta[axis]
			enter = maxf(enter, minf(first,last))
			leave = minf(leave, maxf(first,last))
	return enter <= leave

func _field_contacts(movements: Array = []) -> void:
	for field in fields:
		for unit in units:
			if unit.side == field.side or unit.hp <= 0.0:
				continue
			var end: Vector2 = unit.position if movements.is_empty() else movements[int(unit.id)]
			if not _crosses_rect(unit.position, end, field.rect):
				continue
			if field.kind == "flame":
				if int(unit.flame_until) < tick or int(unit.flame_next) == 0:
					unit.flame_next = tick+config.ticks_per_second
					_passive("flame_burn", units[int(field.source)], 0.0, end)
				unit.flame_until = tick+int(field.duration)
				unit.flame_dps = maxf(float(unit.flame_dps), float(field.dps))
			else:
				# Separate timers let the stronger Wizard Slow expire correctly.
				unit.ice_until = maxi(int(unit.ice_until), tick+int(field.duration))
				unit.ice_fraction = maxf(float(unit.ice_fraction), float(field.fraction))

func _bounce_passives() -> void:
	for unit in units:
		if unit.hp <= 0.0:
			continue
		var stats: UnitStats = cards[unit.card_id].stats
		if stats.bounce_interval <= 0.0 or tick+1 < int(unit.next_bounce):
			continue
		unit.bounce_at = tick
		unit.next_bounce = tick+1+_ticks(stats.bounce_interval)
		for enemy in units:
			if enemy.side != unit.side and enemy.hp > 0.0 and unit.position.distance_to(enemy.position) <= stats.bounce_radius:
				enemy.attack_slow_fraction = maxf(float(enemy.attack_slow_fraction), stats.attack_slow_fraction)
				enemy.attack_slow_until = maxi(int(enemy.attack_slow_until), tick+_ticks(stats.attack_slow_duration))
		_passive("armadillo_bounce", unit, stats.bounce_radius)

func _tree_healing() -> void:
	for unit in units:
		if unit.hp <= 0.0:
			continue
		var stats: UnitStats = cards[unit.card_id].stats
		if stats.heal_interval <= 0.0 or tick+1 < int(unit.next_heal):
			continue
		for ally in units:
			if ally.side == unit.side and ally.hp > 0.0 and ally.position.distance_to(unit.position) <= stats.heal_radius:
				_heal(ally, ally.max_hp*stats.heal_fraction)
		unit.next_heal = tick+1+_ticks(stats.heal_interval)
		_passive("tree_heal", unit, stats.heal_radius)

func _advance_projectiles(movements: Array, damage: Array, hits: Array) -> Dictionary:
	var remaining: Array = []
	var forces: Dictionary = {}
	var dt: float = 1.0/float(config.ticks_per_second)
	for projectile in projectiles:
		var source: Dictionary = units[int(projectile.source)]
		var stats: UnitStats = cards[source.card_id].stats
		var target: Dictionary = units[int(projectile.target)]
		var radius: float = projectile.splash_radius
		if target.hp <= 0.0 and radius <= 0.0:
			continue
		if target.hp > 0.0 and source.role != "siege":
			projectile.impact = movements[int(target.id)]
		projectile.position = projectile.position.move_toward(projectile.impact, projectile.speed*dt)
		if projectile.position.distance_to(projectile.impact) > 7.0:
			remaining.append(projectile)
			continue
		for victim in units:
			if victim.side == source.side or victim.hp <= 0.0:
				continue
			if (radius <= 0.0 and victim.id != target.id) or (radius > 0.0 and movements[int(victim.id)].distance_to(projectile.impact) > radius):
				continue
			_hit(source, victim, projectile.damage*(1.0 if victim.id == target.id else projectile.falloff), damage, hits, not projectile.posthumous)
			if stats.knockback_distance > 0.0 and not projectile.posthumous:
				var direction: Vector2 = (movements[int(victim.id)]-source.position).normalized()
				forces[victim.id] = forces.get(victim.id,Vector2.ZERO)+direction*stats.knockback_distance
				_passive("pushback", source, 0.0, movements[int(victim.id)])
		if radius > 0.0:
			events.append({"kind":"splash", "position":projectile.impact, "set_id":cards[source.card_id].set_id, "radius":radius})
			if projectile.posthumous:
				_passive("snow_head_impact", source, radius, projectile.impact)
			elif source.role == "siege":
				_passive("siege_blast", source, radius, projectile.impact)
			elif stats.knockback_distance <= 0.0:
				_passive("lizard_splash", source, radius, projectile.impact)
	projectiles = remaining
	return forces

func _damage_wave(damage: Array, hits: Array) -> Array:
	var deaths: Array = []
	var hp_lost: Array = []
	hp_lost.resize(units.size())
	hp_lost.fill(0.0)
	for unit in units:
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
			deaths.append(unit.id)
			events.append({"kind":"defeat", "unit":unit.id, "position":unit.position, "side":unit.side, "set_id":cards[unit.card_id].set_id})
		else:
			var realm: SetBonusData = bonds[int(unit.side)]
			if realm != null and realm.effect == "recovery" and cards[unit.card_id].set_id == realm.set_id and not unit.recovery_used and unit.hp < unit.max_hp*realm.recovery_threshold:
				unit.recovery_used = true
				unit.recovery_remaining = realm.recovery_seconds
				unit.recovery_next = tick+config.ticks_per_second
	# Credit only actual HP damage; shields, overkill and Burn grant no lifesteal.
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
	return deaths

func _death_effects(deaths: Array, revivals: Array, damage: Array, hits: Array) -> void:
	for id in deaths:
		var source: Dictionary = units[int(id)]
		if source.death_processed:
			continue
		source.death_processed = true
		var stats: UnitStats = cards[source.card_id].stats
		if stats.death_blast_radius > 0.0:
			if stats.death_projectile:
				var target_id: int = _target(source)
				if target_id >= 0:
					_projectile(source, units[target_id], source.damage*stats.death_blast_fraction, 0, true)
				_passive("snow_head", source, stats.death_blast_radius)
			else:
				for enemy in units:
					if enemy.side != source.side and enemy.hp > 0.0 and source.position.distance_to(enemy.position) <= stats.death_blast_radius:
						_hit(source, enemy, source.damage*stats.death_blast_fraction, damage, hits, false)
				_passive("imp_explosion", source, stats.death_blast_radius)
		if stats.revive_fraction > 0.0 and not source.revive_used:
			revivals.append(source.id)
		if stats.split_count > 0 and not source.is_child:
			for index in range(stats.split_count):
				pending_children.append({"parent":source.id, "index":index})
			_passive("slime_split", source)

func _clear_statuses(unit: Dictionary) -> void:
	for key in ["burn_until", "burn_next", "slow_until", "ice_until", "attack_slow_until", "flame_until", "flame_next", "recovery_next", "recovery_remaining", "shield_until", "cooldown"]:
		unit[key] = 0
	for key in ["shield", "slow_fraction", "ice_fraction", "attack_slow_fraction", "burn_dps", "flame_dps"]:
		unit[key] = 0.0

func _settle_damage(damage: Array, hits: Array) -> void:
	var revivals: Array = []
	var deaths: Array = _damage_wave(damage, hits)
	# Death explosions form simultaneous waves. Each body triggers only once,
	# regardless of array order. Resurrections wait until those waves settle.
	while not deaths.is_empty():
		damage.fill(0.0)
		hits.clear()
		_death_effects(deaths, revivals, damage, hits)
		deaths = _damage_wave(damage, hits)
	for id in revivals:
		var unit: Dictionary = units[int(id)]
		_clear_statuses(unit)
		unit.revive_used = true
		unit.death_processed = false
		unit.hp = unit.max_hp*cards[unit.card_id].stats.revive_fraction
		unit.revive_at = tick
		unit.flanking = false
		unit.cooldown = _ticks(1.0/cards[unit.card_id].stats.attacks_per_second)
		_passive("ninja_revive", unit)

func _birth_position(origin: Vector2, index: int) -> Vector2:
	# Check swept positions as well as endpoints: a newly visible child must
	# not overlap another body during render interpolation either.
	for ring in range(1,15):
		for direction in range(16):
			var angle: float = TAU*float((direction+index*8)%16)/16.0
			var candidate: Vector2 = origin+Vector2(cos(angle), sin(angle))*float(ring)*8.0
			if candidate.x < MIN_POSITION.x or candidate.x > MAX_POSITION.x or candidate.y < MIN_POSITION.y or candidate.y > MAX_POSITION.y:
				continue
			var free: bool = true
			for unit in units:
				if unit.hp <= 0.0:
					continue
				var minimum := Vector2(minf(unit.previous_position.x,unit.position.x), minf(unit.previous_position.y,unit.position.y))
				var maximum := Vector2(maxf(unit.previous_position.x,unit.position.x), maxf(unit.previous_position.y,unit.position.y))
				if Rect2(minimum-Vector2.ONE*(BODY_SIZE+0.01), maximum-minimum+Vector2.ONE*(BODY_SIZE+0.01)*2.0).has_point(candidate):
					free = false
					break
			if free:
				return candidate
	return Vector2.INF

func _birth_children() -> void:
	var waiting: Array = []
	for entry in pending_children:
		var parent: Dictionary = units[int(entry.parent)]
		var location: Vector2 = _birth_position(parent.position, entry.index)
		if location == Vector2.INF:
			waiting.append(entry)
			continue
		var stats: UnitStats = cards[parent.card_id].stats
		var child: Dictionary = parent.duplicate(true)
		child.id = units.size()
		child.position = location
		child.previous_position = location
		child.max_hp = parent.max_hp*stats.split_hp_fraction
		child.hp = child.max_hp
		child.damage = parent.damage*stats.split_damage_fraction
		_prepare_passive_state(child)
		_clear_statuses(child)
		child.is_child = true
		child.visual_scale = 0.65
		child.recovery_used = false
		child.lifesteal_healed = 0.0
		child.hit_at = -100
		child.heal_at = -100
		child.attack_at = -100
		child.target = -1
		units.append(child)
		_passive("slime_child", child)
	pending_children = waiting

func _last_wishes_pending() -> bool:
	if not pending_children.is_empty():
		return true
	for projectile in projectiles:
		if projectile.posthumous:
			return true
	return false

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
	_tick_fields()
	_field_contacts()
	_bounce_passives()
	target_clusters.clear()
	reading_movement_snapshot = true
	for unit in units:
		unit.previous_position = unit.position
		if int(unit.shield_until) > 0 and tick >= int(unit.shield_until):
			unit.shield = 0.0
		if tick >= int(unit.slow_until):
			unit.slow_fraction = 0.0
		if tick >= int(unit.ice_until):
			unit.ice_fraction = 0.0
		if tick >= int(unit.attack_slow_until):
			unit.attack_slow_fraction = 0.0
		movements.append(_move(unit, dt))
	reading_movement_snapshot = false
	_resolve_movements(movements)
	for unit in units:
		if unit.hp <= 0.0:
			continue
		var rate: float = 1.0-float(unit.attack_slow_fraction) if tick < int(unit.attack_slow_until) else 1.0
		unit.cooldown = maxf(float(unit.cooldown)-rate, 0.0)
		var stats: UnitStats = cards[unit.card_id].stats
		var fan_due: bool = stats.split_shot_interval > 0.0 and tick+1 >= int(unit.next_split_shot)
		if unit.target >= 0 and (unit.cooldown <= 0.000001 or fan_due) and not unit.flanking:
			var target: Dictionary = units[int(unit.target)]
			if in_attack_range(unit, target):
				_attack(unit, target, damage, hits, fan_due)
		if int(unit.burn_until) >= tick and int(unit.burn_next) > 0 and int(unit.burn_next) <= tick:
			damage[int(unit.id)] += unit.burn_dps
			unit.burn_next += config.ticks_per_second
		if tick > int(unit.burn_until):
			unit.burn_until = 0
			unit.burn_next = 0
		if int(unit.flame_until) >= tick and int(unit.flame_next) > 0 and int(unit.flame_next) <= tick:
			damage[int(unit.id)] += unit.flame_dps
			unit.flame_next += config.ticks_per_second
		if tick > int(unit.flame_until):
			unit.flame_until = 0
			unit.flame_next = 0
			unit.flame_dps = 0.0
		if sudden_death:
			var overtime: float = float(tick)*dt-config.battle_limit_seconds
			damage[int(unit.id)] += (config.sudden_death_dps+maxf(overtime, 0.0)*config.sudden_death_escalation)*dt
	var forces: Dictionary = _advance_projectiles(movements, damage, hits)
	if not forces.is_empty():
		for id in forces:
			# Simultaneous hits contribute to pushback without tunnelling through
			# bodies or turning a forced displacement into a navigation detour.
			movements[int(id)] += forces[id].limit_length(24.0)
		_resolve_movements(movements, forces)
	_field_contacts(movements)
	for unit in units:
		unit.position = movements[int(unit.id)]
	_settle_damage(damage, hits)
	_birth_children()
	_tree_healing()
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
	if (left == 0 or right == 0) and not _last_wishes_pending():
		_finish(-1 if left == 0 and right == 0 else (0 if right == 0 else 1), "Sudden death" if sudden_death else "Army dispersed")
	elif left > 0 and right > 0 and not sudden_death and tick >= int(round(config.battle_limit_seconds*config.ticks_per_second)):
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
	fields.clear()
	pending_children.clear()
	spell_prepared = [false, false]
	for unit in units:
		_clear_statuses(unit)
		unit.bounce_at = -100

func signature() -> String:
	var snapshot: Array = []
	for unit in units:
		snapshot.append([unit.id, unit.hp, unit.position.x, unit.position.y, unit.cooldown,
			unit.burn_until, unit.burn_next, unit.burn_dps, unit.first_attack, unit.shield, unit.shield_until,
			unit.slow_until, unit.slow_fraction, unit.ice_until, unit.ice_fraction, unit.attack_slow_until,
			unit.attack_slow_fraction, unit.flame_until, unit.flame_next, unit.flame_dps,
			unit.recovery_used, unit.recovery_remaining, unit.recovery_next, unit.lifesteal_healed, unit.lifesteal_window,
			unit.navigation_bias, unit.flanking, unit.revive_used, unit.death_processed, unit.is_child,
			unit.next_flame, unit.next_ice, unit.ice_anchor, unit.next_heal, unit.next_bounce, unit.next_split_shot, unit.bounce_at])
	return JSON.stringify([tick, snapshot, projectiles, fields, pending_children, spell_prepared,
		next_projectile_id, next_field_id, sudden_death, passive_counts, result]).sha256_text()
