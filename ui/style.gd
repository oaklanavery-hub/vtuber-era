class_name StoryStyle
extends RefCounted

const INK := Color("51372f")
const PARCHMENT := Color("f9e9c5")
const HONEY := Color("e8ba61")
const MOSS := Color("456951")
const EMBER := Color("b75d3e")

static func panel(color: Color = PARCHMENT, border: Color = INK, width: int = 2) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(5)
	box.shadow_color = Color(0.22, 0.13, 0.1, 0.23)
	box.shadow_size = 3
	box.shadow_offset = Vector2(0, 3)
	box.content_margin_left = 8
	box.content_margin_right = 8
	return box

static func theme() -> Theme:
	var result := Theme.new()
	result.default_font = load("res://assets/fonts/body.ttf")
	result.default_font_size = 11
	result.set_color("font_color", "Label", INK)
	result.set_color("font_color", "Button", INK)
	result.set_color("font_hover_color", "Button", INK)
	result.set_color("font_pressed_color", "Button", INK)
	result.set_color("font_disabled_color", "Button", Color("a2987d"))
	result.set_stylebox("normal", "Button", panel())
	result.set_stylebox("hover", "Button", panel(Color("fff2d4"), EMBER))
	result.set_stylebox("pressed", "Button", panel(Color("ebcc99"), EMBER))
	result.set_stylebox("disabled", "Button", panel(Color("daceaf"), Color("ad9f7e"), 1))
	result.set_stylebox("focus", "Button", panel(Color(0,0,0,0), MOSS, 2))
	result.set_stylebox("panel", "Panel", panel())
	result.set_stylebox("panel", "PanelContainer", panel())
	result.set_stylebox("panel", "TooltipPanel", panel())
	result.set_color("font_color", "TooltipLabel", INK)
	result.set_font_size("font_size", "TooltipLabel", 11)
	result.set_stylebox("normal", "OptionButton", panel())
	result.set_stylebox("hover", "OptionButton", panel(Color("fff2d4"), EMBER))
	result.set_stylebox("pressed", "OptionButton", panel(Color("ebcc99"), EMBER))
	result.set_color("font_color", "OptionButton", INK)
	result.set_color("font_hover_color", "OptionButton", INK)
	result.set_color("font_pressed_color", "OptionButton", INK)
	result.set_stylebox("panel", "PopupMenu", panel())
	result.set_stylebox("hover", "PopupMenu", panel(HONEY, EMBER, 1))
	result.set_color("font_color", "PopupMenu", INK)
	result.set_color("font_hover_color", "PopupMenu", INK)
	result.set_font_size("font_size", "PopupMenu", 11)
	return result
