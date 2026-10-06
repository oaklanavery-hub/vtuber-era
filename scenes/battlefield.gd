extends Node2D

var simulation: CombatSimulation
var state: MatchState
var interpolation: float = 0.0
var reduced_effects: bool = false
var clock: float = 0.0
var sparks: Array = []
var preview_units: Array = []

func rebuild_preview() -> void:
	preview_units.clear()
	if state:
		for side in range(2):
			preview_units.append_array(CombatSimulation.spawn_layout(state, side))

func _process(delta: float) -> void:
	clock += delta
	var remaining: Array = []
	for spark in sparks:
		spark.age += delta
		if spark.age < 0.7:
			remaining.append(spark)
	sparks = remaining
	queue_redraw()

func ingest(events: Array) -> void:
	for event in events:
		if reduced_effects and event.kind != "meteor_impact":
			continue
		if event.kind == "defeat":
			sparks.append({"position": event.position, "age": 0.0, "color": GameCatalog.realm_color(event.get("set_id", "fire"))})
		elif event.kind in ["splash", "passive", "meteor_impact", "wall_hit"]:
			sparks.append({"position": event.position, "age": 0.0, "color": GameCatalog.realm_color(event.set_id),
				"radius":event.get("radius",0.0), "ability":event.get("ability","")})

func _draw_unit(texture: Texture2D, location: Vector2, frame: int, side: int, rank_value: int, hurt: bool = false, visual_scale: float = 1.0) -> void:
	var tint := Color.WHITE
	if hurt and not reduced_effects:
		tint = Color(1.0, 0.68, 0.55)
	# Mirror around the unit's actual center, so its portrait, HP and position
	# remain aligned. Negative destination widths alone offset Godot regions.
	# All sizes share the same feet anchor; enlarging a tank grows it upward.
	draw_set_transform(location+Vector2(0, 8), 0.0, Vector2(-1 if side==1 else 1, 1)*visual_scale)
	draw_texture_rect_region(texture, Rect2(-16, -32, 32, 32), Rect2(frame*32, 0, 32, 32), tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for star in range(rank_value-1):
		draw_rect(Rect2(location.x-4+star*6, location.y-32*visual_scale, 4, 2), Color("e8ba61"))

func _draw() -> void:
	if simulation:
		if (simulation.spell_active(0) and simulation.commanders[0].spell_kind == "frozen_field") or (simulation.spell_active(1) and simulation.commanders[1].spell_kind == "frozen_field"):
			_draw_frozen_field()
		for source in simulation.units:
			var radius: float = state.cards[source.card_id].stats.ice_aura_radius
			if source.hp > 0.0 and radius > 0.0:
				_draw_ice_aura(source.previous_position.lerp(source.position, interpolation), int(radius))
			var fire_radius: float = state.cards[source.card_id].stats.fire_aura_radius
			if source.hp > 0.0 and fire_radius > 0.0:
				_draw_fire_ring(source.previous_position.lerp(source.position, interpolation), int(fire_radius))
		# Fields carry gameplay information even with reduced cosmetic effects.
		for field in simulation.fields:
			if field.kind in ["ground_fire", "puddle"]:
				_draw_ground_pool(field)
				continue
			var rectangle: Rect2 = field.rect
			var color := Color(0.46,0.75,0.87,0.36) if field.kind == "ice" else Color(0.86,0.35,0.14,0.45)
			draw_rect(rectangle, color)
			draw_rect(rectangle, Color("b8e5e4") if field.kind == "ice" else Color("e8ba61"), false, 1.0)
			if field.kind == "flame":
				for index in range(int(rectangle.size.y/6.0)):
					var height: float = 4.0 if reduced_effects else 3.0+float((simulation.tick/4+index)%3)
					draw_rect(Rect2(rectangle.position+Vector2(2,index*6), Vector2(rectangle.size.x-4,height)), Color("e8ba61"))
			else:
				for index in range(int(rectangle.size.x/7.0)):
					draw_line(rectangle.position+Vector2(index*7,rectangle.size.y), rectangle.position+Vector2(index*7+5,0), Color(0.80,0.94,0.94,0.45), 1.0)
		# Sprites can overlap above their smaller feet. Paint rear units first;
		# never reorder the simulation array, whose indices are stable unit IDs.
		var actors: Array = []
		for unit in simulation.units:
			if unit.hp > 0.0:
				actors.append({"kind":"unit", "unit":unit, "depth":unit.previous_position.lerp(unit.position, interpolation).y, "id":unit.id})
		for wall in simulation.walls:
			actors.append({"kind":"wall", "wall":wall, "depth":wall.rect.end.y, "id":-1-int(wall.id)})
		actors.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return a.depth < b.depth if a.depth != b.depth else a.id < b.id)
		for actor in actors:
			if actor.kind == "wall":
				_draw_earth_wall(actor.wall.rect)
				continue
			var unit: Dictionary = actor.unit
			var location: Vector2 = unit.previous_position.lerp(unit.position, interpolation)
			var moving: bool = unit.position.distance_squared_to(unit.previous_position) > 0.01
			var frame: int = int(simulation.tick/4) % 6 if moving else int(clock*3) % 6
			if reduced_effects:
				frame = 0
			if simulation.tick-int(unit.attack_at) < 4 and not reduced_effects:
				frame = 6
			if unit.pull_target >= 0 and not reduced_effects:
				frame = 6
			if (simulation.tick-int(unit.revive_at) < 15 or simulation.tick-int(unit.teleport_at) < 12 or simulation.teleport_charging(unit)) and not reduced_effects:
				frame = 7
			var shadow_width: float = roundf(16*unit.visual_scale)
			draw_rect(Rect2(location.x-shadow_width/2.0, location.y+5, shadow_width, 2), Color("91a471"))
			var sprite_location: Vector2 = location
			if simulation.tick-int(unit.bounce_at) < CombatSimulation.BOUNCE_TICKS and not reduced_effects:
				sprite_location.y -= sin(float(simulation.tick-int(unit.bounce_at))/float(CombatSimulation.BOUNCE_TICKS)*PI)*7.0
			# Teleport can put an attacker behind the other army: turn toward its target.
			var facing: int = int(unit.side)
			var face_target: int = int(unit.pull_target) if unit.pull_target >= 0 else int(unit.target)
			if face_target >= 0:
				var target_x: float = simulation.units[face_target].position.x
				if absf(target_x-location.x) > 0.01: facing = 0 if target_x > location.x else 1
			_draw_unit(state.cards[unit.card_id].sprite, sprite_location, frame, facing, unit.rank, simulation.tick-int(unit.hit_at)<3, unit.visual_scale)
			if simulation.teleport_charging(unit) and not simulation.opening_active():
				_draw_ninja_charge(unit, location)
			var color := Color("659789") if unit.side == 0 else Color("c57857")
			var bar_width: float = roundf(20*unit.visual_scale)
			var bar_y: float = roundf(location.y+6-32*unit.visual_scale)
			draw_rect(Rect2(location.x-bar_width/2.0, bar_y, bar_width, 3), Color("51372f"))
			draw_rect(Rect2(location.x-bar_width/2.0+1, bar_y+1, roundf((bar_width-2)*unit.hp/unit.max_hp), 1), color)
			if (int(unit.burn_until) >= simulation.tick and unit.burn_until > 0) or (int(unit.flame_until) >= simulation.tick and unit.flame_until > 0) or (int(unit.blast_burn_until) >= simulation.tick and unit.blast_burn_until > 0) or unit.fire_aura_dps > 0.0 or unit.ground_fire_dps > 0.0:
				draw_rect(Rect2(location.x+9, location.y-16, 2, 4), Color("d57346"))
				draw_rect(Rect2(location.x+10, location.y-15, 1, 2), Color("f9e4b5"))
			if unit.shield > 0.0:
				draw_rect(Rect2(location.x-bar_width/2.0, bar_y-3, bar_width, 2), Color("8fc6cb"))
			if unit.slow_until > simulation.tick or unit.ice_until > simulation.tick or unit.ice_aura_fraction > 0.0 or simulation.defence_multiplier(unit) < 1.0:
				draw_rect(Rect2(location.x+9, location.y-9, 2, 2), Color("659fbb"))
			if simulation.defence_multiplier(unit) < 1.0:
				draw_rect(Rect2(location.x+12, location.y-9, 3, 1), Color("b8e5e4"))
				draw_rect(Rect2(location.x+13, location.y-8, 1, 3), Color("659fbb"))
			if simulation.attack_rate(unit) < 1.0:
				draw_rect(Rect2(location.x+9, location.y-5, 2, 2), Color("e8ba61"))
			if simulation.tick-int(unit.revive_at) < 30:
				_pixel_ring(location-Vector2(0,9), 18, Color("e8ba61"))
				# A spent resurrection remains visible after its one-second cue.
			if unit.revive_used:
				draw_rect(Rect2(location.x+bar_width/2.0+2,bar_y,3,3), Color("e8ba61"))
			if simulation.tick-int(unit.heal_at) < 5 and not reduced_effects:
				draw_rect(Rect2(location.x-12, location.y-12, 5, 1), Color("7dba9d"))
				draw_rect(Rect2(location.x-10, location.y-14, 1, 5), Color("7dba9d"))
		_draw_tendrils()
		_draw_meteors()
		for projectile in simulation.projectiles:
			var card: ArmyCardData = state.cards[projectile.card_id]
			if projectile.posthumous:
				# Snowman's head is distinct from its ordinary small snowballs.
				draw_rect(Rect2(projectile.position+Vector2(-4,-3),Vector2(8,6)),Color("edf1de"))
				draw_rect(Rect2(projectile.position+Vector2(-3,-4),Vector2(6,8)),Color("edf1de"))
				draw_rect(Rect2(projectile.position+Vector2(-3,-5), Vector2(6,2)), Color("51372f"))
				draw_rect(Rect2(projectile.position+Vector2(2,0), Vector2(3,2)), Color("e8ba61"))
				continue
			var size := Vector2(6, 6) if card.role == "siege" else Vector2(4, 4) if card.role == "mage" else Vector2(6, 2)
			draw_rect(Rect2(projectile.position-size/2, size), GameCatalog.realm_color(card.set_id))
			draw_rect(Rect2(projectile.position, Vector2(2, 2)), Color("f9e4b5"))
	elif state:
		for entry in preview_units:
			_draw_unit(state.cards[entry.card_id].sprite, entry.position, 0 if reduced_effects else int(clock*3+entry.index)%6, entry.side, entry.rank, false, GameCatalog.army_scale(entry.card_id))
	for spark in sparks:
		if float(spark.get("radius",0.0)) > 0.0:
			var ring_color: Color = spark.color
			ring_color.a = (1.0-spark.age/0.7)*0.7
			_pixel_ring(spark.position, int(round(spark.radius*(0.5+spark.age/1.4))), ring_color)
		if reduced_effects:
			continue
		for index in range(5):
			var offset := Vector2(sin(float(index)*2.4)*spark.age*21, -spark.age*25+cos(float(index))*7)
			var color: Color = spark.color if index%2==0 else Color("f9e4b5")
			color.a = 1.0-spark.age/0.7
			draw_rect(Rect2(spark.position+offset, Vector2(3, 3)), color)

func _draw_ice_aura(center: Vector2, radius: int) -> void:
	# Stepped, translucent ice on the sprite grid; the border marks its true radius.
	center = center.round()
	for y in range(-radius+3, radius, 6):
		var span: float = floorf(sqrt(maxf(0.0, float(radius*radius-y*y)))/3.0)*3.0
		draw_rect(Rect2(center+Vector2(-span,y-3), Vector2(span*2,6)), Color(0.56,0.82,0.94,0.22))
	_pixel_ring(center, radius, Color(0.59,0.84,0.93,0.68))
	for index in range(9):
		var point: Vector2 = center+Vector2((index*29)%73-36, (index*47)%67-33)
		draw_rect(Rect2(point, Vector2(5,1)), Color(0.82,0.95,0.96,0.65))
		draw_rect(Rect2(point+Vector2(2,-2), Vector2(1,5)), Color(0.82,0.95,0.96,0.65))

func _pixel_disc(center: Vector2, radius: int, color: Color) -> void:
	for y in range(-radius, radius+1, 4):
		var span: int = int(floor(sqrt(maxf(0.0,float(radius*radius-y*y)))/2.0))*2
		draw_rect(Rect2(center.round()+Vector2(-span,y),Vector2(span*2,4)),color)

func _draw_fire_ring(center: Vector2, radius: int) -> void:
	center = center.round()
	_pixel_disc(center,radius,Color(0.86,0.33,0.16,0.12))
	_pixel_ring(center,radius,Color(0.89,0.45,0.23,0.75))
	_pixel_ring(center,radius-2,Color(0.97,0.72,0.35,0.65))
	for index in range(16):
		var angle: float = TAU*float(index)/16.0
		var point: Vector2 = (center+Vector2(cos(angle),sin(angle))*float(radius-1)).round()
		var height: int = 3 if reduced_effects else 3+(int(simulation.tick/5)+index)%3
		draw_rect(Rect2(point-Vector2(1,height),Vector2(3,height)),Color("d57346"))
		draw_rect(Rect2(point-Vector2(0,height-1),Vector2(1,height-1)),Color("ffc477"))

func _draw_ground_pool(field: Dictionary) -> void:
	var center: Vector2 = field.position.round()
	var radius: int = int(field.radius)
	var water: bool = field.kind == "puddle"
	_pixel_disc(center,radius,Color(0.35,0.66,0.79,0.32) if water else Color(0.83,0.29,0.14,0.30))
	_pixel_ring(center,radius,Color(0.61,0.85,0.84,0.82) if water else Color("ee8e58"))
	for index in range(8):
		var point: Vector2 = center+Vector2((index*13)%37-18,(index*19)%31-15)
		if water:
			draw_rect(Rect2(point,Vector2(5,1)),Color("a7d6dd"))
			if index%3 == 0: draw_rect(Rect2(point+Vector2(2,-2),Vector2(1,5)),Color("a2bc79"))
		else:
			var height: int = 3 if reduced_effects else 3+(int(simulation.tick/4)+index)%3
			draw_rect(Rect2(point,Vector2(3,height)),Color("d65c49"))
			draw_rect(Rect2(point+Vector2(1,-1),Vector2(1,height-1)),Color("ffc477"))

func _draw_tendrils() -> void:
	for source in simulation.units:
		if source.hp <= 0.0 or source.pull_target < 0:
			continue
		var target: Dictionary = simulation.units[int(source.pull_target)]
		if target.hp <= 0.0:
			continue
		var start: Vector2 = source.previous_position.lerp(source.position,interpolation)-Vector2(0,12)
		var end: Vector2 = target.previous_position.lerp(target.position,interpolation)-Vector2(0,9)
		var progress: float = clampf(float(simulation.tick-int(source.pull_started_at))/float(maxi(1,int(source.pull_ready_at)-int(source.pull_started_at))),0.0,1.0)
		end = start.lerp(end,progress)
		var count: int = maxi(1,ceili(start.distance_to(end)/2.0))
		for index in range(count+1):
			var point: Vector2 = start.lerp(end,float(index)/float(count)).round()
			draw_rect(Rect2(point,Vector2(2,2)),Color("4d6850"))
			if index%2 == 0: draw_rect(Rect2(point,Vector2.ONE),Color("a2bc79"))
		_pixel_ring(end,3,Color("d3a368"))

func _draw_ninja_charge(unit: Dictionary, location: Vector2) -> void:
	var progress: float = clampf(float(simulation.tick)/float(unit.teleport_due), 0.0, 1.0)
	_pixel_ring(location, 13, Color("b75d3e"))
	draw_rect(Rect2(location+Vector2(-11,9), Vector2(22,3)), Color("51372f"))
	draw_rect(Rect2(location+Vector2(-10,10), Vector2(roundf(20*progress),1)), Color("e8ba61"))
	if reduced_effects:
		return
	for index in range(6):
		var angle: float = float(index)*TAU/6.0+float(simulation.tick)*0.14
		var smoke: Vector2 = location+Vector2(cos(angle)*12, -12+sin(angle)*11)
		draw_rect(Rect2(smoke.round(), Vector2(3,3)), Color("625261"))
		draw_rect(Rect2(smoke.round()+Vector2.ONE, Vector2(1,1)), Color("e8ba61"))

func _draw_frozen_field() -> void:
	draw_rect(Rect2(Vector2.ZERO, CombatSimulation.ARENA_SIZE), Color(0.63,0.84,0.94,0.70))
	draw_rect(Rect2(1,1,598,278), Color(0.78,0.94,0.96,0.6), false, 1.0)
	for index in range(42):
		var position := Vector2(8+(index*97)%580, 10+(index*61)%260)
		draw_rect(Rect2(position, Vector2(10,1)), Color(0.80,0.95,0.96,0.45))
		draw_rect(Rect2(position+Vector2(7,-3), Vector2(1,7)), Color(0.80,0.95,0.96,0.45))
		draw_rect(Rect2(position+Vector2(10,1), Vector2(4,1)), Color(0.59,0.81,0.88,0.65))

func _draw_earth_wall(rectangle: Rect2) -> void:
	# Physical footprint, earthy side face, stepped grass cap and roots.
	draw_rect(rectangle.grow(2), Color(0.24,0.30,0.20,0.30))
	draw_rect(rectangle, Color("51372f"))
	var top := Rect2(rectangle.position-Vector2(0,7), rectangle.size-Vector2(0,2))
	draw_rect(top, Color("b0b197"))
	for row in range(int(top.size.y/6.0)):
		var offset: float = 2.0 if row%2 == 0 else 5.0
		draw_rect(Rect2(top.position+Vector2(1,row*6), Vector2(top.size.x-2,1)), Color("c8c5a5"))
		draw_rect(Rect2(top.position+Vector2(offset,row*6), Vector2(1,5)), Color("83916c"))
		if row%3 == 1:
			draw_rect(Rect2(top.position+Vector2(0,row*6+1), Vector2(4,3)), Color("456951"))
			draw_rect(Rect2(top.position+Vector2(1,row*6), Vector2(2,2)), Color("a3b977"))
	draw_rect(Rect2(top.position, Vector2(top.size.x,3)), Color("456951"))
	draw_rect(Rect2(top.position+Vector2(1,0), Vector2(top.size.x-3,1)), Color("a3b977"))
	for index in range(3):
		draw_rect(Rect2(rectangle.position+Vector2(index*4-1,rectangle.size.y-2), Vector2(3,4+index%2*2)), Color("795942"))

func _draw_meteors() -> void:
	for meteor in simulation.meteors:
		if meteor.landed:
			continue
		var position: Vector2 = meteor.position
		_pixel_ring(position.round(), int(meteor.radius), Color(0.84,0.35,0.17,0.45))
		draw_rect(Rect2(position-Vector2(4,0), Vector2(9,1)), Color("e8ba61"))
		draw_rect(Rect2(position-Vector2(0,4), Vector2(1,9)), Color("e8ba61"))
		var remaining: int = int(meteor.impact_tick)-simulation.opening_tick
		var fall_ticks: int = int(round(0.4*simulation.config.ticks_per_second))
		if remaining > fall_ticks:
			continue
		var progress: float = clampf(1.0-float(remaining)/float(fall_ticks), 0.0, 1.0)
		var start := Vector2(position.x-34, maxf(10.0, position.y-65))
		var falling: Vector2 = start.lerp(position, progress).round()
		if not reduced_effects:
			for tail in range(4):
				draw_rect(Rect2(falling-Vector2(3+tail*3,5+tail*4), Vector2(4,5)), Color("e8ba61") if tail%2 else Color("d57346"))
		draw_rect(Rect2(falling-Vector2(5,3), Vector2(10,6)), Color("51372f"))
		draw_rect(Rect2(falling-Vector2(3,5), Vector2(6,10)), Color("51372f"))
		draw_rect(Rect2(falling-Vector2(3,3), Vector2(6,6)), Color("b75d3e"))
		draw_rect(Rect2(falling-Vector2(2,2), Vector2(3,3)), Color("f9e4b5"))

func _pixel_ring(center: Vector2, radius: int, color: Color) -> void:
	# Midpoint circle: one-pixel steps, the same grid as sprites and particles.
	var x: int = radius
	var y: int = 0
	var error: int = 1-radius
	while x >= y:
		for offset in [Vector2(x,y),Vector2(y,x),Vector2(-y,x),Vector2(-x,y),Vector2(-x,-y),Vector2(-y,-x),Vector2(y,-x),Vector2(x,-y)]:
			draw_rect(Rect2(center.round()+offset,Vector2.ONE),color)
		y += 1
		if error < 0:
			error += 2*y+1
		else:
			x -= 1
			error += 2*(y-x)+1
