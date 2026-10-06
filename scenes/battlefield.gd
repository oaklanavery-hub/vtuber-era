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
	if reduced_effects:
		return
	for event in events:
		if event.kind == "defeat":
			sparks.append({"position": event.position, "age": 0.0, "color": GameCatalog.realm_color(event.get("set_id", "fire"))})
		elif event.kind == "splash" or event.kind == "passive":
			sparks.append({"position": event.position, "age": 0.0, "color": GameCatalog.realm_color(event.set_id),
				"radius":event.get("radius",0.0), "ability":event.get("ability","")})

func _draw_unit(texture: Texture2D, location: Vector2, frame: int, side: int, rank_value: int, hurt: bool = false, visual_scale: float = 1.0) -> void:
	var tint := Color.WHITE
	if hurt and not reduced_effects:
		tint = Color(1.0, 0.68, 0.55)
	# Mirror around the unit's actual center, so its portrait, HP and position
	# remain aligned. Negative destination widths alone offset Godot regions.
	draw_set_transform(location, 0.0, Vector2(-1 if side==1 else 1, 1)*visual_scale)
	draw_texture_rect_region(texture, Rect2(-16, -24, 32, 32), Rect2(frame*32, 0, 32, 32), tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for star in range(rank_value-1):
		draw_rect(Rect2(location.x-4+star*6, location.y-32, 4, 2), Color("e8ba61"))

func _draw() -> void:
	if simulation:
		# Fields carry gameplay information even with reduced cosmetic effects.
		for field in simulation.fields:
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
		var visible_units: Array = simulation.units.filter(func(unit: Dictionary) -> bool: return unit.hp > 0.0)
		visible_units.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var first: float = a.previous_position.lerp(a.position, interpolation).y
			var second: float = b.previous_position.lerp(b.position, interpolation).y
			return first < second if first != second else a.id < b.id)
		for unit in visible_units:
			if unit.hp <= 0.0:
				continue
			var location: Vector2 = unit.previous_position.lerp(unit.position, interpolation)
			var moving: bool = unit.position.distance_squared_to(unit.previous_position) > 0.01
			var frame: int = int(simulation.tick/4) % 6 if moving else int(clock*3) % 6
			if reduced_effects:
				frame = 0
			if simulation.tick-int(unit.attack_at) < 4 and not reduced_effects:
				frame = 6
			if simulation.tick-int(unit.revive_at) < 15 and not reduced_effects:
				frame = 7
			draw_rect(Rect2(location.x-8, location.y+5, 16, 2), Color("91a471"))
			var sprite_location: Vector2 = location
			if simulation.tick-int(unit.bounce_at) < CombatSimulation.BOUNCE_TICKS and not reduced_effects:
				sprite_location.y -= sin(float(simulation.tick-int(unit.bounce_at))/float(CombatSimulation.BOUNCE_TICKS)*PI)*7.0
			_draw_unit(state.cards[unit.card_id].sprite, sprite_location, frame, unit.side, unit.rank, simulation.tick-int(unit.hit_at)<3, unit.visual_scale)
			var color := Color("659789") if unit.side == 0 else Color("c57857")
			draw_rect(Rect2(location.x-10, location.y-26, 20, 3), Color("51372f"))
			draw_rect(Rect2(location.x-9, location.y-25, roundf(18*unit.hp/unit.max_hp), 1), color)
			if (int(unit.burn_until) >= simulation.tick and unit.burn_until > 0) or (int(unit.flame_until) >= simulation.tick and unit.flame_until > 0):
				draw_rect(Rect2(location.x+9, location.y-16, 2, 4), Color("d57346"))
				draw_rect(Rect2(location.x+10, location.y-15, 1, 2), Color("f9e4b5"))
			if unit.shield > 0.0:
				draw_rect(Rect2(location.x-10, location.y-29, 20, 2), Color("8fc6cb"))
			if unit.slow_until > simulation.tick or unit.ice_until > simulation.tick:
				draw_rect(Rect2(location.x+9, location.y-9, 2, 2), Color("659fbb"))
			if unit.attack_slow_until > simulation.tick:
				draw_rect(Rect2(location.x+9, location.y-5, 2, 2), Color("e8ba61"))
			if simulation.tick-int(unit.revive_at) < 30:
				_pixel_ring(location-Vector2(0,9), 18, Color("e8ba61"))
				# A spent resurrection remains visible after its one-second cue.
			if unit.revive_used:
				draw_rect(Rect2(location.x+12,location.y-26,3,3), Color("e8ba61"))
			if simulation.tick-int(unit.heal_at) < 5 and not reduced_effects:
				draw_rect(Rect2(location.x-12, location.y-12, 5, 1), Color("7dba9d"))
				draw_rect(Rect2(location.x-10, location.y-14, 1, 5), Color("7dba9d"))
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
			_draw_unit(state.cards[entry.card_id].sprite, entry.position, 0 if reduced_effects else int(clock*3+entry.index)%6, entry.side, entry.rank)
	for spark in sparks:
		if float(spark.get("radius",0.0)) > 0.0:
			var ring_color: Color = spark.color
			ring_color.a = (1.0-spark.age/0.7)*0.7
			_pixel_ring(spark.position, int(round(spark.radius*(0.5+spark.age/1.4))), ring_color)
		for index in range(5):
			var offset := Vector2(sin(float(index)*2.4)*spark.age*21, -spark.age*25+cos(float(index))*7)
			var color: Color = spark.color if index%2==0 else Color("f9e4b5")
			color.a = 1.0-spark.age/0.7
			draw_rect(Rect2(spark.position+offset, Vector2(3, 3)), color)

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
