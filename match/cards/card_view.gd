class_name CardView extends Control
## A card shown big in the middle of the screen: deck art on top, English +
## Greek name, type, text, and a row of buttons (e.g. OK, or "give to").
## Usage: CardView.open(parent, card, "Hosty drew:", [["OK", callable], ...])

const BACKS := {
	"green_cards": preload("res://assets/cards/green_card.png"),
	"red_cards": preload("res://assets/cards/red_card.png"),
	"blue_cards": preload("res://assets/cards/blue_card.png"),
}
const CARD_SIZE := Vector2(380, 560)

var _card_panel: PanelContainer


## True when the card is only shown for information (a single "OK"), so a
## newer card may replace it.
var dismissable := false
var _closing := false

## Cards waiting while one that needs an answer is on screen.
static var _queue := []


## buttons: Array of [label, Callable, optional Color]. Every button also
## closes the card.
static func open(parent: Node, card: Dictionary, heading: String, buttons: Array) -> CardView:
	for child in parent.get_children():
		if child is CardView and not child._closing:
			if child.dismissable:
				child.close()
			else:
				_queue.append([parent, card, heading, buttons])  # show after it
				return null
	var view := CardView.new()
	view.dismissable = buttons.size() == 1 and buttons[0][0] == "OK"
	parent.add_child(view)
	view._build(card, heading, buttons)
	return view


func _build(card: Dictionary, heading: String, buttons: Array) -> void:
	z_index = 20
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_STOP  # the card is modal

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.size = size
	add_child(dim)

	var accent := Color(Global.CARD_COLORS[card.deck].color)

	var title := Label.new()
	title.text = heading
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 8)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(800, 40)
	title.position = Vector2(960 - 400, 150)
	add_child(title)

	# The card
	_card_panel = PanelContainer.new()
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0.05, 0.05, 0.08)
	frame.border_color = accent
	frame.set_border_width_all(4)
	frame.set_corner_radius_all(14)
	_card_panel.add_theme_stylebox_override("panel", frame)
	_card_panel.size = CARD_SIZE
	_card_panel.position = Vector2(960, 200) - Vector2(CARD_SIZE.x / 2.0, 0)
	_card_panel.pivot_offset = CARD_SIZE / 2.0
	add_child(_card_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_card_panel.add_child(column)

	var art := TextureRect.new()
	art.texture = Global.card_back(card.deck)
	art.custom_minimum_size = Vector2(0, 200)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	column.add_child(art)

	var name_en := Label.new()
	name_en.text = card.name
	name_en.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_en.add_theme_font_size_override("font_size", 28)
	column.add_child(name_en)

	var name_el := Label.new()
	name_el.text = card.get("name_el", "")
	name_el.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_el.add_theme_font_size_override("font_size", 18)
	name_el.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	column.add_child(name_el)

	var kind := Label.new()
	kind.text = _kind_text(card)
	kind.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kind.add_theme_font_size_override("font_size", 15)
	kind.add_theme_color_override("font_color", accent.lightened(0.3))
	column.add_child(kind)

	var text := Label.new()
	text.text = card.text
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.custom_minimum_size = Vector2(CARD_SIZE.x - 40, 0)
	text.add_theme_font_size_override("font_size", 20)
	text.add_theme_font_size_override("font_size", 18)

	var text_el := Label.new()
	text_el.text = card.get("text_el", "")
	text_el.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_el.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_el.custom_minimum_size = Vector2(CARD_SIZE.x - 40, 0)
	text_el.add_theme_font_size_override("font_size", 16)
	text_el.add_theme_color_override("font_color", Color(0.72, 0.74, 0.8))

	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", 10)
	texts.add_child(text)
	texts.add_child(text_el)
	var text_margin := MarginContainer.new()
	for side in ["left", "right", "top"]:
		text_margin.add_theme_constant_override("margin_" + side, 16)
	text_margin.add_child(texts)
	column.add_child(text_margin)

	# Buttons under the card
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size = Vector2(1200, 50)
	row.position = Vector2(960 - 600, 200 + CARD_SIZE.y + 20)
	add_child(row)
	for b in buttons:
		var button := Button.new()
		button.text = b[0]
		button.custom_minimum_size = Vector2(150, 46)
		button.add_theme_font_size_override("font_size", 20)
		if b.size() > 2:
			button.add_theme_color_override("font_color", b[2])
		var callback: Callable = b[1]
		button.pressed.connect(func():
			close()
			callback.call())
		row.add_child(button)

	# Pop in
	_card_panel.scale = Vector2(0.4, 0.4)
	modulate.a = 0.0
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_card_panel, "scale", Vector2.ONE, 0.35)
	tween.tween_property(self, "modulate:a", 1.0, 0.2)


static func _kind_text(card: Dictionary) -> String:
	var deck_label: String = Global.CARD_COLORS[card.deck].label.to_upper()
	match card.kind:
		"question":
			return "%s · QUESTION · ΕΡΩΤΗΣΗ" % deck_label
		"equipment":
			return "%s · EQUIPMENT · ΕΞΟΠΛΙΣΜΟΣ" % deck_label
		_:
			var must := " · MUST · ΥΠΟΧΡΕΩΤΙΚΟ" if card.get("must", false) else ""
			return "%s · EVENT · ΓΕΓΟΝΟΣ%s" % [deck_label, must]


func close() -> void:
	if _closing:
		return
	_closing = true
	queue_free()
	if not _queue.is_empty():
		var next: Array = _queue.pop_front()
		if is_instance_valid(next[0]):
			CardView.open(next[0], next[1], next[2], next[3])
