class_name LocationSprite extends Sprite2D
## One location on the board: its art, a badge showing which dice totals
## lead here and what you can do, and a tooltip explaining it on hover.

const TILE_SIZE := 128.0

@export var location := {}
@onready var index_label: Label = $IndexLabel
@onready var location_label: Label = $LocationLabel


func set_location(loc: Dictionary, terrain: Texture2D) -> void:
	location = loc
	texture = terrain
	location_label.text = loc.label
	index_label.hide()

	var action: Dictionary = Global.LOCATION_ACTIONS[loc.action]
	_add_badge(loc.rolls, action)
	_add_hover_area(loc, action)


static func rolls_text(rolls: Array, separator := " / ") -> String:
	var parts := []
	for r in rolls:
		parts.append(str(r))
	return separator.join(parts)


## "[ 4 / 5 | icon ]" floating above the tile, in the action's colour.
func _add_badge(rolls: Array, action: Dictionary) -> void:
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

	var label := Label.new()
	label.text = rolls_text(rolls)
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
	badge.position = Vector2(-badge.size.x / 2.0, -TILE_SIZE / 2.0 - badge.size.y - 4)


## Invisible control over the tile that shows a tooltip on hover.
func _add_hover_area(loc: Dictionary, action: Dictionary) -> void:
	var area := Control.new()
	area.name = "HoverArea"
	area.position = Vector2(-TILE_SIZE / 2.0, -TILE_SIZE / 2.0)
	area.size = Vector2(TILE_SIZE, TILE_SIZE)
	area.mouse_filter = Control.MOUSE_FILTER_PASS
	area.tooltip_text = "%s\nRoll %s to come here.\n%s" % [loc.label, rolls_text(loc.rolls, " or "), action.text]
	add_child(area)
