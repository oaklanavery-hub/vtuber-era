class_name StoryStyle
extends RefCounted

const INK := Color("51372f")
const PARCHMENT := Color("f9e9c5")
const HONEY := Color("e8ba61")
const MOSS := Color("456951")
const EMBER := Color("b75d3e")
const TEXT_FONT = preload("res://assets/fonts/pixel_ui.tres")
const ARROW = preload("res://assets/icons/arrow_down.svg")
const SWITCH_ON = preload("res://assets/icons/switch_on.svg")
const SWITCH_OFF = preload("res://assets/icons/switch_off.svg")
const SLIDER_GRAB = preload("res://assets/icons/slider_grab.svg")
const MIN_FONT_SIZE: int = 10

# Font metrics are checked against the assigned rectangle, including wrapped
# descriptions and explicit newlines. Clipping is a final safeguard for long
# live rosters; their complete text is available in the existing tooltip.
static func fit_label(node: Label, rectangle: Rect2, requested_size: int) -> void:
	var font: Font = node.get_theme_font("font")
	var font_size: int = maxi(MIN_FONT_SIZE, requested_size)
	node.clip_text = true
	node.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if rectangle.size.y >= font.get_height(font_size)*1.8 else TextServer.AUTOWRAP_OFF
	while font_size > MIN_FONT_SIZE and not _label_size_fits(node, font, font_size, rectangle.size):
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

static func fit_button(node: Button, rectangle: Rect2, requested_size: int = 11) -> void:
	node.clip_text = true
	node.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var font: Font = node.get_theme_font("font")
	var available: Vector2 = rectangle.size-node.get_theme_stylebox("normal").get_minimum_size()
	var font_size: int = maxi(MIN_FONT_SIZE, requested_size)
	while font_size > MIN_FONT_SIZE:
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
		# Label shaping is deferred until the next frame after a theme change.
		# Use the assigned font's metrics, not a stale default-font line cache.
		return node.clip_text and node.size.y+0.01 >= node.get_theme_font("font").get_height(node.get_theme_font_size("font_size"))
	if node is Button:
		return node.clip_text
	return true

static func panel(color: Color = PARCHMENT, border: Color = INK, width: int = 2) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(width)
	# Two-pixel cut corners remain crisp on the viewport grid.
	box.set_corner_radius_all(2)
	box.corner_detail = 1
	box.anti_aliasing = false
	box.shadow_size = 0
	box.content_margin_left = 8
	box.content_margin_right = 8
	return box

static func theme() -> Theme:
	var result := Theme.new()
	result.default_font = TEXT_FONT
	result.default_font_size = 11
	result.set_constant("line_spacing", "Label", 0)
	result.set_color("font_color", "Label", INK)
	result.set_color("font_color", "CheckButton", INK)
	for key in ["font_hover_color","font_hover_pressed_color","font_pressed_color","font_focus_color"]:
		result.set_color(key,"CheckButton",INK)
	result.set_icon("checked","CheckButton",SWITCH_ON)
	result.set_icon("unchecked","CheckButton",SWITCH_OFF)
	result.set_color("font_color", "Button", INK)
	result.set_color("font_hover_color", "Button", INK)
	result.set_color("font_pressed_color", "Button", INK)
	result.set_color("font_hover_pressed_color", "Button", INK)
	result.set_color("font_focus_color", "Button", INK)
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
	result.set_color("font_focus_color", "OptionButton", INK)
	result.set_color("font_hover_pressed_color", "OptionButton", INK)
	result.set_icon("arrow", "OptionButton", ARROW)
	for key in ["grabber","grabber_highlight","grabber_disabled"]:
		result.set_icon(key,"HSlider",SLIDER_GRAB)
	for key in ["slider","grabber_area","grabber_area_highlight"]:
		var track := StyleBoxFlat.new()
		track.bg_color = HONEY if key != "slider" else Color("ad9f7e")
		track.border_color = INK
		track.set_border_width_all(1)
		track.anti_aliasing = false
		track.content_margin_top = 2
		track.content_margin_bottom = 2
		result.set_stylebox(key,"HSlider",track)
	result.set_stylebox("panel", "PopupMenu", panel())
	result.set_stylebox("hover", "PopupMenu", panel(HONEY, EMBER, 1))
	result.set_color("font_color", "PopupMenu", INK)
	result.set_color("font_hover_color", "PopupMenu", INK)
	result.set_font_size("font_size", "PopupMenu", 11)
	return result
