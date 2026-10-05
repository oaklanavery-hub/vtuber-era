extends Control

var count: int = 4
const ROWS := ["0110110", "1111111", "1111111", "0111110", "0011100", "0001000"]

func _draw() -> void:
	for heart in range(count):
		for y in range(ROWS.size()):
			for x in range(7):
				if ROWS[y][x] == "1":
					draw_rect(Rect2(heart*18+x*2, y*2+2, 2, 2), Color("b75d3e"))
