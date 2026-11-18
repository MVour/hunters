class_name DeckPack extends Button
## A small face-down pack of one deck, used inside the black dialog when
## you may draw: a tight pile of card backs, "Draw" and how many are left.
## Click it to draw from that deck.

const CARD := Vector2(90, 138)  # the card art's shape (420 x 646)
const LAYERS := 4


func _init(card_type: String, count: int) -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = CARD + Vector2(LAYERS * 2 + 8, LAYERS * 3 + 30)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var info: Dictionary = Global.CARD_COLORS[card_type]
	tooltip_text = "%s (%d)" % [Global.field(info, "label").capitalize(), count]

	# Bottom cards first, each a little lower-right: reads as a thick pack.
	var back := Global.card_back(card_type)
	var layers := clampi(count, 1, LAYERS)
	for i in range(layers - 1, -1, -1):
		var card := TextureRect.new()
		card.texture = back
		card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		card.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		card.size = CARD
		card.position = Vector2(4 + i * 2, 4 + i * 3)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if i > 0:
			card.modulate = Color(0.75, 0.75, 0.75)  # the ones underneath are in shadow
		add_child(card)

	var label := Label.new()
	label.text = "%s · %d" % [Global.text("pack.draw"), count]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(0, CARD.y + LAYERS * 3 + 6)
	label.size = Vector2(custom_minimum_size.x, 22)
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(info.color).lightened(0.35))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)

	mouse_entered.connect(func(): _lift(true))
	mouse_exited.connect(func(): _lift(false))


func _lift(on: bool) -> void:
	pivot_offset = size / 2.0
	create_tween().tween_property(self, "scale", Vector2.ONE * (1.06 if on else 1.0), 0.12)
