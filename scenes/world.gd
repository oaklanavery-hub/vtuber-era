extends Node2D

var battle_mode: bool = false
const BROWN := Color("51372f")
const GRASS := Color("a3b977")

func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color("cddcb0"))
	draw_rect(Rect2(0, 0, 640, 138), Color("e9deb1"))
	draw_circle(Vector2(487, 58), 26, Color("f7e4a5"))
	draw_rect(Rect2(0, 118, 640, 38), Color("b7c995"))
	for index in range(15):
		var x: float = float(index * 47 - 18)
		draw_rect(Rect2(x, 96 + (index % 3) * 6, 39, 48), Color("92ac7c"))
		draw_rect(Rect2(x + 6, 84 + (index % 3) * 6, 26, 20), Color("a4bb88"))
	# Distant warm cottages.
	for x in [80, 507]:
		draw_rect(Rect2(x, 104, 38, 28), Color("f1d8a2"))
		draw_colored_polygon(PackedVector2Array([Vector2(x-5, 105), Vector2(x+19, 83), Vector2(x+43, 105)]), Color("b36b47"))
		draw_rect(Rect2(x+15, 115, 8, 17), Color("775348"))
		draw_rect(Rect2(x+4, 112, 7, 7), Color("f8eab8"))
	draw_rect(Rect2(0, 148, 640, 212), GRASS)
	draw_rect(Rect2(39, 185, 562, 117), Color("b9c588"))
	draw_rect(Rect2(65, 195, 510, 91), Color("cbd29a"))
	# Old mossy festival stones at the margins.
	for x in [39, 567]:
		draw_rect(Rect2(x, 154, 31, 35), Color("83916c"))
		draw_rect(Rect2(x+3, 153, 24, 27), Color("b0b197"))
		draw_rect(Rect2(x-3, 182, 39, 7), Color("7f9e63"))
	# Trees made from stepped blocks on the same pixel grid as the units.
	for tree in [[-22, 53, 1.4], [589, 39, 1.5], [-8, 235, .8], [594, 243, .8]]:
		_tree(Vector2(tree[0], tree[1]), float(tree[2]))
	# Woodland stream and a tiny wooden footbridge.
	draw_rect(Rect2(0, 317, 640, 43), Color("85b9aa"))
	draw_rect(Rect2(0, 318, 640, 5), Color("709883"))
	for index in range(21):
		draw_rect(Rect2(index*31+5, 335+(index%3)*6, 15, 2), Color("b7d9c1"))
	draw_rect(Rect2(293, 315, 54, 45), Color("815e44"))
	for y in range(316, 360, 7):
		draw_rect(Rect2(290, y, 60, 5), Color("ad8357"))
	# Flowers and lanterns stay clear of the main arena.
	for index in range(25):
		var x: float = float((index * 79 + 13) % 640)
		var y: float = 280.0 + float((index * 17) % 35)
		draw_rect(Rect2(x, y+3, 2, 5), Color("688455"))
		draw_rect(Rect2(x-2, y, 6, 3), Color("e9ad75") if index%2 == 0 else Color("f9e4b5"))
		draw_rect(Rect2(x, y-2, 2, 7), Color("e9ad75") if index%2 == 0 else Color("f9e4b5"))
	for x in [20, 617]:
		draw_rect(Rect2(x, 169, 3, 106), BROWN)
		draw_rect(Rect2(x-5, 173, 13, 17), BROWN)
		draw_rect(Rect2(x-3, 175, 9, 12), Color("f2ce79"))
		draw_rect(Rect2(x-1, 179, 5, 5), Color("fae7b5"))
	if battle_mode:
		draw_rect(Rect2(12, 60, 616, 210), BROWN)
		draw_rect(Rect2(15, 63, 610, 204), Color("b2be84"))
		draw_rect(Rect2(18, 64, 604, 202), Color("c6cc92"))
		for index in range(35):
			var x: float = float(27+(index*73)%586)
			var y: float = float(74+(index*37)%178)
			draw_rect(Rect2(x, y, 4, 2), Color("bac58b"))
		draw_line(Vector2(320, 64), Vector2(320, 266), Color("b7c18a"), 1)
	else:
		# Bunting behind the title, tied between the woodland trees.
		draw_line(Vector2(58, 23), Vector2(584, 23), BROWN, 2)
		for index in range(14):
			var x: float = 65.0+float(index)*37.0
			var color := Color("cd7954") if index%2==0 else Color("e8ba61")
			draw_colored_polygon(PackedVector2Array([Vector2(x, 24), Vector2(x+20, 24), Vector2(x+10, 41)]), color)

func _tree(origin: Vector2, scale_value: float) -> void:
	var shapes := [[31, 31, 15, 117, "795942"], [33, 28, 5, 114, "a07a50"],
		[7, 15, 62, 52, "537a55"], [18, 2, 39, 25, "537a55"],
		[0, 30, 75, 24, "537a55"], [11, 18, 55, 28, "71935f"],
		[23, 5, 30, 18, "8eac70"], [14, 21, 24, 10, "9eb97a"],
		[13, 57, 51, 9, "466f50"], [43, 27, 18, 9, "8eac70"]]
	for shape in shapes:
		draw_rect(Rect2(origin+Vector2(shape[0], shape[1])*scale_value, Vector2(shape[2], shape[3])*scale_value), Color(shape[4]))
