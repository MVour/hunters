class_name LobbyStyle extends RefCounted
## The lobby's look in one place: dark panels with a thin gold edge (like the
## match screen's dialogs), headings, and buttons sized so longer Greek texts
## still fit.

const BG := Color(0.07, 0.08, 0.11)
const PANEL := Color(0.04, 0.05, 0.08, 0.92)
const GOLD := Color("c8a85a")
const SIDE_COLOURS := {"vampires_count": "e06a6a", "werewolves_count": "e0a84c", "humans_count": "8fb8e0"}


static func panel(border := Color(GOLD, 0.55)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(18)
	return style


static func heading() -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color("ffd27a"))
	return label


static func small_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(48, 44)
	button.add_theme_font_size_override("font_size", 22)
	return button


## A wide button; `gold` for the main action (Start).
static func big_button(height: float, gold := false) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, height)
	button.add_theme_font_size_override("font_size", 30 if gold else 22)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = (Color(0.16, 0.13, 0.06) if gold else Color(0.1, 0.11, 0.15)).lightened(0.1 if state == "hover" else 0.0)
		style.border_color = GOLD if gold else Color(1, 1, 1, 0.25)
		style.border_color = style.border_color.lightened(0.25) if state == "hover" else style.border_color
		style.set_border_width_all(2)
		style.set_corner_radius_all(10)
		style.set_content_margin_all(8)
		button.add_theme_stylebox_override(state, style)
	if gold:
		button.add_theme_color_override("font_color", Color("ffe2a8"))
	return button
