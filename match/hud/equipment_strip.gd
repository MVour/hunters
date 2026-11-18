class_name EquipmentStrip extends VBoxContainer
## Someone's equipment at a glance: a row of micro cards (click one to see
## it big), and under them what each one does, one line per card with its
## keywords marked. Used by the player hub's Equipment tab and by the
## character card popup. Pure view: set_cards().

var card_size := Vector2(70, 108)
var _row: HBoxContainer
var _effects: RichTextLabel
var _empty: Label
var _font_px := 14


func _init(mini_size := Vector2(70, 108), font_px := 14) -> void:
	card_size = mini_size
	_font_px = font_px
	add_theme_constant_override("separation", 6)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_empty = Label.new()
	_empty.add_theme_font_size_override("font_size", font_px + 1)
	_empty.add_theme_color_override("font_color", Color(0.62, 0.62, 0.66))
	add_child(_empty)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 8)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row)
	_effects = Keywords.label("", font_px)
	_effects.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_effects)


func set_cards(cards: Array) -> void:
	for child in _row.get_children():
		child.queue_free()
	_empty.text = Global.text("match.no_equipment_yet")
	_empty.visible = cards.is_empty()
	_row.visible = not cards.is_empty()
	_effects.visible = not cards.is_empty()
	var lines := []
	for card in cards:
		var mini := CardView.mini_card(card, card_size)
		mini.pressed.connect(func():
			var view := CardView.open(_popup_parent(), card, "", [["OK", func(): pass]])
			if view:
				view.z_index = 27)  # over the character card popup (24) it may sit in
		_row.add_child(mini)
		var colour := Color(Global.CARD_COLORS.get(card.get("deck", ""), {}).get("color", "c8a85a")).lightened(0.3)
		lines.append("[color=#%s]%s[/color]  %s" % [colour.to_html(false),
			Global.field(card, "name").replace("[", "[lb]"), Keywords.bbcode(Global.field(card, "text"), _font_px)])
	_effects.text = "\n".join(lines)


## Big cards open over the whole match screen.
func _popup_parent() -> Node:
	var scene := get_tree().root.find_child("PlayScene", true, false)
	return scene if scene else get_tree().root
