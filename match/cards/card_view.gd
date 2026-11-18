class_name CardView extends Control
## A card shown big in the middle of the screen: the whole deck art as the
## card, its name, type and text on a plate over the lower half, and a row
## of buttons (e.g. OK, or "give to").
## Usage: CardView.open(parent, card, "Hosty drew:", [["OK", callable], ...])

const BACKS := {
	"green_cards": preload("res://assets/cards/green_card.png"),
	"red_cards": preload("res://assets/cards/red_card.png"),
	"blue_cards": preload("res://assets/cards/blue_card.png"),
}
const CARD_WIDTH := 360.0
## Height / width of the card art (420 x 646): cards keep this shape.
const CARD_RATIO := 646.0 / 420.0
## Keep the card above this line: the choice panel ("use it now?") sits below.
const BOTTOM_LIMIT := 800.0
## And below the narrator bar at the top.
const TOP_LIMIT := 112.0  # the narrator: its line + the step strip

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
var _buttons: HBoxContainer


## True when the card is only shown for information (a single "OK"), so a
## newer card may replace it.
var dismissable := false
var _closing := false

## Cards waiting while one that needs an answer is on screen.
static var _queue := []


## buttons: Array of [label, Callable, optional Color]. Every button also
## closes the card. `drawn_from`: a card just drawn, from the deck at that
## screen point: it flies out and turns over (play_draw), also when it has
## to wait for the card on screen first.
static func open(parent: Node, card: Dictionary, heading: String, buttons: Array,
		drawn_from := Vector2.INF) -> CardView:
	for child in parent.get_children():
		if child is CardView and not child._closing:
			if child.dismissable:
				child.close()
			else:
				_queue.append([parent, card, heading, buttons, drawn_from])  # show after it
				return null
	var view := CardView.new()
	view.dismissable = buttons.size() == 1 and buttons[0][0] == "OK"
	parent.add_child(view)
	view._build(card, heading, buttons)
	if drawn_from != Vector2.INF:
		view.play_draw(drawn_from)
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
	title.visible = heading != ""
	_layout.add_child(title)

	# The card
	_card_panel = card_face(card, CARD_WIDTH)
	_card_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_layout.add_child(_card_panel)

	# Buttons under the card
	var row := HBoxContainer.new()
	_buttons = row
	row.visible = not buttons.is_empty()
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


## A freshly drawn card: instead of popping in, its back lifts off the deck
## at `from` (screen point), flies to where the card goes, and flips over to
## its face; then the heading and buttons fade in.
const DRAW_FLY := 0.45
const DRAW_FLIP := 0.14
var _draw: Tween
var _flying_back: TextureRect


func play_draw(from: Vector2) -> void:
	if _closing or passive:
		return
	if _pop:
		_pop.kill()
	modulate.a = 1.0
	_layout.scale = Vector2.ONE
	_layout.modulate.a = 0.0
	_dim.modulate.a = 0.0
	await get_tree().process_frame  # the column is laid out: the card's place is known
	if _closing or passive or not is_inside_tree():
		_finish_draw()
		return
	var target := Rect2(_card_panel.global_position - global_position, _card_panel.size)
	var back := TextureRect.new()
	_flying_back = back
	back.texture = Global.card_back(shown_card.get("deck", "red_cards"))
	back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE  # before the size
	back.stretch_mode = TextureRect.STRETCH_SCALE
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var start_size := Vector2(90, 90 * CARD_RATIO)
	back.size = start_size
	back.position = from - start_size / 2.0
	back.pivot_offset = start_size / 2.0
	add_child(back)
	_draw = create_tween()
	# 1. Lifts off the deck and flies over, growing, with a little spin.
	_draw.tween_property(_dim, "modulate:a", 1.0, DRAW_FLY)
	_draw.parallel().tween_property(back, "position", target.position, DRAW_FLY) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_draw.parallel().tween_property(back, "size", target.size, DRAW_FLY) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_draw.parallel().tween_property(back, "pivot_offset", target.size / 2.0, DRAW_FLY)
	_draw.parallel().tween_property(back, "rotation", 0.0, DRAW_FLY).from(-0.35)
	# 2. Turns over: the back narrows to an edge...
	_draw.tween_property(back, "scale:x", 0.0, DRAW_FLIP).set_ease(Tween.EASE_IN)
	# 3. ...and the face opens out from it.
	_draw.tween_callback(func():
		back.queue_free()
		_card_panel.pivot_offset = _card_panel.size / 2.0
		_card_panel.scale.x = 0.0
		_layout.modulate.a = 1.0
		for child in _layout.get_children():
			if child != _card_panel:
				child.modulate.a = 0.0)
	_draw.tween_property(_card_panel, "scale:x", 1.0, DRAW_FLIP).set_ease(Tween.EASE_OUT)
	for child in _layout.get_children():
		if child != _card_panel:
			_draw.parallel().tween_property(child, "modulate:a", 1.0, 0.25)


## Skip to the end of the draw (the card is about to move or close).
func _finish_draw() -> void:
	if _draw:
		_draw.kill()
	if is_instance_valid(_flying_back):
		_flying_back.queue_free()
	_dim.modulate.a = 1.0
	_layout.modulate.a = 1.0
	_card_panel.scale = Vector2.ONE
	for child in _layout.get_children():
		child.modulate.a = 1.0


## Shrink into the bottom-right corner and stop blocking the screen, e.g.
## while the player has to click someone on the board. Buttons still work.
func make_passive() -> void:
	if passive or _closing:
		return
	_finish_draw()
	passive = true
	if _pop:
		_pop.kill()
	modulate.a = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.hide()
	_ignore_mouse(_layout)
	_place()


## Keep the card big while the choice dialog under it asks about it ("use
## it now?"): its own buttons go, clicks pass through to the dialog. The
## dialog closes it when answered.
func hold() -> void:
	if _closing:
		return
	dismissable = false
	_buttons.hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ignore_mouse(_layout)


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
		# Bottom-right, just above this turn's cards (TurnCards) and left of the
		# game log, so neither is covered.
		_layout.position = Vector2(TurnCards.AREA.end.x - s.x * PASSIVE_SCALE, TurnCards.AREA.position.y - 8.0 - s.y * PASSIVE_SCALE)
		return
	var y := clampf((1080.0 - s.y) / 2.0 - 60.0, TOP_LIMIT, maxf(TOP_LIMIT, BOTTOM_LIMIT - s.y))
	_layout.position = Vector2(960.0 - s.x / 2.0, y)
	_layout.pivot_offset = s / 2.0


## A micro card: the whole art in a deck-coloured frame, its name on a dark
## strip at the bottom; a button (the caller decides what a click does,
## usually showing it big). Used by this turn's cards and equipment strips.
static func mini_card(card: Dictionary, card_size: Vector2) -> Button:
	var accent := Color(Global.CARD_COLORS.get(card.get("deck", ""), {}).get("color", "c8a85a"))
	var button := Button.new()
	button.custom_minimum_size = card_size
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = Global.field(card, "name")
	for state in ["normal", "hover", "pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.05, 0.05, 0.08, 0.95).lightened(0.1 if state == "hover" else 0.0)
		style.border_color = accent.lightened(0.3) if state == "hover" else accent
		style.set_border_width_all(2)
		style.set_corner_radius_all(6)
		button.add_theme_stylebox_override(state, style)

	var art := TextureRect.new()
	art.texture = Global.card_back(card.get("deck", "red_cards"))
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE  # before the size: else it can't shrink
	art.position = Vector2(2, 2)
	art.size = card_size - Vector2(4, 4)
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(art)
	var plate := PanelContainer.new()
	var plate_style := StyleBoxFlat.new()
	plate_style.bg_color = Color(0.03, 0.03, 0.05, 0.85)
	plate_style.set_content_margin_all(3)
	plate.add_theme_stylebox_override("panel", plate_style)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.position = Vector2(2, 0)
	plate.custom_minimum_size = Vector2(card_size.x - 4, 0)
	button.add_child(plate)
	# Keep it at the bottom whatever height its name needs.
	plate.resized.connect(func(): plate.position.y = card_size.y - 2 - plate.size.y)
	var title := Label.new()
	title.text = Global.field(card, "name")
	# Two lines at most, whole words (a long Greek name would otherwise break
	# into letters and its plate grow over the art).
	title.autowrap_mode = TextServer.AUTOWRAP_WORD
	title.max_lines_visible = 2  # (not clip_text: a wrapping label then measures 0 high)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size = Vector2(card_size.x - 10, 0)
	title.add_theme_font_size_override("font_size", 12 if card_size.x >= 80 else 10)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(title)
	return button


## A card face in the current language. With art: card-shaped (the whole
## deck art, uncropped), with the name, type and text on a dark plate over
## its lower part. Without: a plain frame in the deck colour with the text
## (small clickable cards, e.g. equipment to steal).
## Text scales with `width`.
static func card_face(card: Dictionary, width: float, with_art := true) -> PanelContainer:
	var s := width / CARD_WIDTH
	var accent := Color(Global.CARD_COLORS.get(card.get("deck", ""), {}).get("color", "c8a85a"))
	var panel := PanelContainer.new()
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0.05, 0.05, 0.08)
	frame.border_color = accent
	frame.set_border_width_all(maxi(2, roundi(4 * s)))
	frame.set_corner_radius_all(roundi(14 * s))
	panel.custom_minimum_size = Vector2(width, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", roundi(6 * s))
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The column's width: the card's minus the frames around it.
	var text_width := width - 2 * maxi(2, roundi(4 * s))
	var text_margin := roundi(16 * s)

	if with_art and card.has("deck"):
		# The art draws its own border: no frame, just its shape.
		frame.set_border_width_all(0)
		frame.set_corner_radius_all(roundi(10 * s))
		frame.set_content_margin_all(0)
		panel.custom_minimum_size = Vector2(width, roundf(width * CARD_RATIO))
		var art := TextureRect.new()
		art.texture = Global.card_back(card.deck)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(art)
		# Inside the art's border, at the bottom: a dark plate for the text.
		var inside := MarginContainer.new()
		inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var border := roundi(width * 0.085)
		for side in ["left", "right", "top", "bottom"]:
			inside.add_theme_constant_override("margin_" + side, border)
		panel.add_child(inside)
		var plate := PanelContainer.new()
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plate.size_flags_vertical = Control.SIZE_SHRINK_END
		var plate_style := StyleBoxFlat.new()
		plate_style.bg_color = Color(0.03, 0.03, 0.05, 0.86)
		plate_style.border_color = accent.darkened(0.2)
		plate_style.set_border_width_all(maxi(1, roundi(2 * s)))
		plate_style.set_corner_radius_all(roundi(8 * s))
		plate_style.set_content_margin_all(roundi(10 * s))
		plate.add_theme_stylebox_override("panel", plate_style)
		inside.add_child(plate)
		plate.add_child(column)
		text_width = width - 2 * border - 2 * roundi(10 * s) - 2 * maxi(1, roundi(2 * s))
		text_margin = roundi(6 * s)
	else:
		panel.add_child(column)
	panel.add_theme_stylebox_override("panel", frame)

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

	# Keywords marked with an icon and a colour (Keywords).
	var text := Keywords.label(Global.field(card, "text"), maxi(12, roundi(18 * s)), true,
		Color(0.94, 0.92, 0.88))
	text.custom_minimum_size = Vector2(text_width - 2 * text_margin, 0)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, text_margin)
	margin.add_child(text)
	column.add_child(margin)
	return panel


static func _kind_text(card: Dictionary) -> String:
	var deck_label: String = Global.field(Global.CARD_COLORS[card.deck], "label").to_upper()
	match card.kind:
		"question":
			return "%s · %s" % [deck_label, Global.text("card.question")]
		"equipment":
			return "%s · %s" % [deck_label, Global.text("card.equipment")]
		_:
			var must := " · " + Global.text("card.must") if card.get("must", false) else ""
			return "%s · %s%s" % [deck_label, Global.text("card.event"), must]


func close() -> void:
	if _closing:
		return
	_closing = true
	queue_free()
	if not _queue.is_empty():
		var next: Array = _queue.pop_front()
		if is_instance_valid(next[0]):
			CardView.open(next[0], next[1], next[2], next[3], next[4])
