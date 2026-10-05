extends Node2D

func _draw() -> void:
	var points := PackedVector2Array([Vector2(-5,-8),Vector2(5,-8),Vector2(8,-5),Vector2(8,5),Vector2(5,8),Vector2(-5,8),Vector2(-8,5),Vector2(-8,-5)])
	draw_colored_polygon(points, Color("51372f"))
	var middle := PackedVector2Array([Vector2(-4,-6),Vector2(4,-6),Vector2(6,-4),Vector2(6,4),Vector2(4,6),Vector2(-4,6),Vector2(-6,4),Vector2(-6,-4)])
	draw_colored_polygon(middle, Color("b75d3e"))
	draw_rect(Rect2(-3,-2,6,5), Color("e8ba61"))
	draw_rect(Rect2(-1,-5,2,7), Color("e8ba61"))
	draw_rect(Rect2(-1,0,2,3), Color("f9e4b5"))
