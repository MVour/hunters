class_name LocationSprite extends Sprite2D
## One location on the board: its art, a badge showing which dice totals
## lead here and what you can do, and a tooltip explaining it on hover.

## Where pawns stand, relative to the location's centre: a curve on the
## ground in front of it, filled from the middle outward. Up to 8 players.
const PAWN_SPOTS := [
	Vector2(-25, 83), Vector2(25, 83), Vector2(-65, 77), Vector2(65, 77),
	Vector2(-97, 67), Vector2(97, 67), Vector2(-118, 54), Vector2(118, 54),
]

## Clicked while selectable (e.g. choosing where to go after rolling a 7).
signal chosen(location_id: String)

var _size := Vector2(128, 128)  # art size, set from the texture
var _selectable := false
var _pulse: Tween
var _hover_area: Control

@export var location := {}
@onready var index_label: Label = $IndexLabel
@onready var location_label: Label = $LocationLabel


func set_location(loc: Dictionary, terrain: Texture2D) -> void:
	location = loc
	texture = terrain
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_size = terrain.get_size()
	# The name lives in the badge, keeping the ground in front free for pawns.
	location_label.hide()
	index_label.hide()

	var action: Dictionary = Global.LOCATION_ACTIONS[loc.action]
	_add_badge(loc, action)
	_add_hover_area(loc, action)


## Global position where the n-th pawn at this location stands (feet).
func pawn_spot(n: int) -> Vector2:
	return global_position + PAWN_SPOTS[n % PAWN_SPOTS.size()]


static func rolls_text(rolls: Array, separator := " / ") -> String:
	var parts := []
	for r in rolls:
		parts.append(str(r))
	return separator.join(parts)


## "[ Widow's River  4 / 5 | icon ]" floating above the art, in the action's colour.
func _add_badge(loc: Dictionary, action: Dictionary) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.07, 0.88)
	style.border_color = Color(action.color)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 8
	style.content_margin_right = 6
	style.content_margin_top = 2
	style.content_margin_bottom = 2

	var badge := PanelContainer.new()
	badge.name = "RollBadge"
	badge.add_theme_stylebox_override("panel", style)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(row)

	var name_label := Label.new()
	name_label.text = loc.label
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name_label)

	var label := Label.new()
	label.text = rolls_text(loc.rolls)
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(action.color).lightened(0.35))
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)

	var icon := TextureRect.new()
	icon.texture = load(action.icon)
	icon.custom_minimum_size = Vector2(28, 28)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

	add_child(badge)
	# Centre it above the tile once its size is known.
	badge.resized.connect(_place_badge.bind(badge))
	_place_badge.call_deferred(badge)


func _place_badge(badge: Control) -> void:
	badge.reset_size()
	badge.position = Vector2(-badge.size.x / 2.0, -_size.y / 2.0 - badge.size.y + 6)


## Invisible control over the tile that shows a tooltip on hover.
func _add_hover_area(loc: Dictionary, action: Dictionary) -> void:
	var area := Control.new()
	area.name = "HoverArea"
	area.position = -_size / 2.0
	area.size = _size
	area.mouse_filter = Control.MOUSE_FILTER_PASS
	area.tooltip_text = "%s\nRoll %s to come here.\n%s" % [loc.label, rolls_text(loc.rolls, " or "), action.text]
	area.gui_input.connect(_on_area_input)
	add_child(area)
	_hover_area = area


func _on_area_input(event: InputEvent) -> void:
	if _selectable and event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		chosen.emit(location.id)


## Pulse and accept clicks while the player picks a location.
func set_selectable(on: bool) -> void:
	_selectable = on
	if _pulse:
		_pulse.kill()
	modulate = Color.WHITE
	if _hover_area:
		_hover_area.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if on else Control.CURSOR_ARROW
	if on:
		_pulse = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
		_pulse.tween_property(self, "modulate", Color(1.5, 1.45, 1.2), 0.45)
		_pulse.tween_property(self, "modulate", Color.WHITE, 0.45)
