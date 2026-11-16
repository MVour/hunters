class_name CardView extends Control
## A card shown big in the middle of the screen: deck art on top, English +
## Greek name, type, text, and a row of buttons (e.g. OK, or "give to").
## Usage: CardView.open(parent, card, "Hosty drew:", [["OK", callable], ...])

const BACKS := {
	"green_cards": preload("res://assets/cards/green_card.png"),
	"red_cards": preload("res://assets/cards/red_card.png"),
	"blue_cards": preload("res://assets/cards/blue_card.png"),
}
const CARD_WIDTH := 380.0
## Keep the card above this line: the choice panel ("use it now?") sits below.
const BOTTOM_LIMIT := 800.0

## Heading, card and buttons stacked, so buttons always sit under the text
## however long the card is.
var _layout: VBoxContainer
var _dim: ColorRect
var _pop: Tween
## Shrunk into the bottom-right corner, not blocking the screen (see make_passive).
var passive := false
## The card this popup shows (so the dialog can take it over).
var shown_card := {}
const PASSIVE_SCALE := 0.5
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
	shown_card = card
	z_index = 20
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_STOP  # the card is modal

	var dim := ColorRect.new()
	_dim = dim
	dim.color = Color(0, 0, 0, 0.55)
	dim.size = size
	add_child(dim)

	_layout = VBoxContainer.new()
	_layout.add_theme_constant_override("separation", 14)
	_layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_layout)

	var title := Label.new()
	title.text = heading
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 8)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size = Vector2(800, 0)
	_layout.add_child(title)

	# The card
	_card_panel = card_face(card, CARD_WIDTH, 180.0)
	_card_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_layout.add_child(_card_panel)

	# Buttons under the card
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_layout.add_child(row)
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

	_layout.resized.connect(_place)
	_place()

	# Pop in (the whole column: a container would reset a child's scale)
	_layout.scale = Vector2(0.4, 0.4)
	modulate.a = 0.0
	_pop = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pop.tween_property(_layout, "scale", Vector2.ONE, 0.35)
	_pop.tween_property(self, "modulate:a", 1.0, 0.2)


## Shrink into the bottom-right corner and stop blocking the screen, e.g.
## while the player has to click someone on the board. Buttons still work.
func make_passive() -> void:
	if passive or _closing:
		return
	passive = true
	if _pop:
		_pop.kill()
	modulate.a = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.hide()
	_ignore_mouse(_layout)
	_place()


func _ignore_mouse(node: Node) -> void:
	if node is Control and not node is BaseButton:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)


## Centre the column on screen, keeping its bottom above the choice panel.
## Passive: small, in the bottom-right corner.
func _place() -> void:
	_layout.reset_size()
	var s := _layout.size
	if passive:
		_layout.pivot_offset = Vector2.ZERO
		_layout.scale = Vector2.ONE * PASSIVE_SCALE
		# Bottom-right: the chat and language button live bottom-left.
		_layout.position = Vector2(1920.0 - 16.0 - s.x * PASSIVE_SCALE, 1080.0 - 16.0 - s.y * PASSIVE_SCALE)
		return
	var y := clampf((1080.0 - s.y) / 2.0 - 60.0, 20.0, maxf(20.0, BOTTOM_LIMIT - s.y))
	_layout.position = Vector2(960.0 - s.x / 2.0, y)
	_layout.pivot_offset = s / 2.0


## A card face (frame in the deck colour, art, name, type, text) in the
## current language. Used by this popup and inside the choice dialog.
## `width` / `art_height` set its size; text scales with the width.
static func card_face(card: Dictionary, width: float, art_height: float) -> PanelContainer:
	var s := width / CARD_WIDTH
	var accent := Color(Global.CARD_COLORS.get(card.get("deck", ""), {}).get("color", "c8a85a"))
	var panel := PanelContainer.new()
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0.05, 0.05, 0.08)
	frame.border_color = accent
	frame.set_border_width_all(maxi(2, roundi(4 * s)))
	frame.set_corner_radius_all(roundi(14 * s))
	panel.add_theme_stylebox_override("panel", frame)
	panel.custom_minimum_size = Vector2(width, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", roundi(6 * s))
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(column)

	if art_height > 0 and card.has("deck"):
		var art := TextureRect.new()
		art.texture = Global.card_back(card.deck)
		art.custom_minimum_size = Vector2(0, art_height)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(art)

	var title := Label.new()
	title.text = Global.field(card, "name")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", maxi(14, roundi(28 * s)))
	column.add_child(title)

	if card.has("kind"):
		var kind := Label.new()
		kind.text = _kind_text(card)
		kind.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		kind.add_theme_font_size_override("font_size", maxi(11, roundi(15 * s)))
		kind.add_theme_color_override("font_color", accent.lightened(0.3))
		column.add_child(kind)

	var text := Label.new()
	text.text = Global.field(card, "text")
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.custom_minimum_size = Vector2(width - 40 * s, 0)
	text.add_theme_font_size_override("font_size", maxi(12, roundi(18 * s)))
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, roundi(16 * s))
	margin.add_child(text)
	column.add_child(margin)
	return panel


static func _kind_text(card: Dictionary) -> String:
	var deck_label: String = Global.field(Global.CARD_COLORS[card.deck], "label").to_upper()
	match card.kind:
		"question":
			return "%s · %s" % [deck_label, Global.t("QUESTION", "ΕΡΩΤΗΣΗ")]
		"equipment":
			return "%s · %s" % [deck_label, Global.t("EQUIPMENT", "ΕΞΟΠΛΙΣΜΟΣ")]
		_:
			var must := " · " + Global.t("MUST", "ΥΠΟΧΡΕΩΤΙΚΟ") if card.get("must", false) else ""
			return "%s · %s%s" % [deck_label, Global.t("EVENT", "ΓΕΓΟΝΟΣ"), must]


func close() -> void:
	if _closing:
		return
	_closing = true
	queue_free()
	if not _queue.is_empty():
		var next: Array = _queue.pop_front()
		if is_instance_valid(next[0]):
			CardView.open(next[0], next[1], next[2], next[3])
