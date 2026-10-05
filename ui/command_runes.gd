extends Control

var available: int = 3
var capacity: int = 3

func _draw() -> void:
	for index in range(capacity):
		var origin := Vector2(12+index*25, 11)
		var active: bool = index < available
		var color := Color("dfaa4e") if index < 3 else Color("5f998c")
		if not active:
			color = Color("a69c81")
		var diamond := PackedVector2Array([origin+Vector2(0,-9), origin+Vector2(8,0), origin+Vector2(0,9), origin+Vector2(-8,0)])
		draw_colored_polygon(diamond, Color("51372f"))
		var inner := PackedVector2Array([origin+Vector2(0,-6), origin+Vector2(5,0), origin+Vector2(0,6), origin+Vector2(-5,0)])
		draw_colored_polygon(inner, color)
		if active:
			draw_line(origin+Vector2(0,-3), origin+Vector2(0,3), Color("fff2cf"), 1)
			draw_line(origin+Vector2(-2,0), origin+Vector2(2,0), Color("fff2cf"), 1)
