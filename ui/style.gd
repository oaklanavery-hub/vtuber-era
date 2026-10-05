class_name StoryStyle
extends RefCounted

const INK := Color("51372f")
const PARCHMENT := Color("f9e9c5")
const HONEY := Color("e8ba61")
const MOSS := Color("456951")
const EMBER := Color("b75d3e")
const PIXEL_FONT = preload("res://assets/fonts/Tiny5-Regular.ttf")

# Font metrics are checked against the assigned rectangle, including wrapped
# descriptions and explicit newlines. Clipping is a final safeguard for long
# live rosters; their complete text is available in the existing tooltip.
static func fit_label(node: Label, rectangle: Rect2, requested_size: int) -> void:
	var font: Font = node.get_theme_font("font")
	var font_size: int = maxi(8, requested_size)
	node.clip_text = true
	node.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if rectangle.size.y >= font.get_height(font_size)*1.8 else TextServer.AUTOWRAP_OFF
	while font_size > 8 and not _label_size_fits(node, font, font_size, rectangle.size):
		font_size -= 1
	node.add_theme_font_size_override("font_size", font_size)
	node.position = rectangle.position
	node.size = rectangle.size
	node.set_meta("text_box", rectangle)
	node.set_meta("text_size", requested_size)
	node.set_meta("fitted_text", node.text)

static func _label_size_fits(node: Label, font: Font, font_size: int, available: Vector2) -> bool:
	var width: float = available.x if node.autowrap_mode != TextServer.AUTOWRAP_OFF else -1.0
	var measured: Vector2 = font.get_multiline_string_size(node.text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size)
	return measured.x <= available.x+0.01 and measured.y <= available.y+0.01

static func refit_label(node: Label) -> void:
	if node.text != node.get_meta("fitted_text", ""):
		fit_label(node, node.get_meta("text_box"), node.get_meta("text_size"))

static func fit_button(node: Button, rectangle: Rect2, requested_size: int = 10) -> void:
	node.clip_text = true
	node.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var font: Font = node.get_theme_font("font")
	var available: Vector2 = rectangle.size-node.get_theme_stylebox("normal").get_minimum_size()
	var font_size: int = requested_size
	while font_size > 8:
		var measured: Vector2 = font.get_multiline_string_size(node.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		if measured.x <= available.x and measured.y <= available.y:
			break
		font_size -= 1
	node.add_theme_font_size_override("font_size", font_size)
	node.position = rectangle.position
	node.size = rectangle.size
	node.set_meta("text_box", rectangle)

static func text_within_box(node: Control) -> bool:
	if not node.has_meta("text_box"):
		return true
	var box: Rect2 = node.get_meta("text_box")
	if node.size.x > box.size.x+0.01 or node.size.y > box.size.y+0.01:
		return false
	if node is Label:
		return node.clip_text and node.size.y+0.01 >= node.get_line_height()
	if node is Button:
		return node.clip_text
	return true

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
	result.default_font = PIXEL_FONT
	result.default_font_size = 10
	result.set_constant("line_spacing", "Label", 0)
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
