class_name TurnCards extends VBoxContainer
## The cards of the current turn, kept small in a row: what was drawn (by
## anyone), your green card, a green card someone asked you. Click one to
## see it big again. Cleared when the next turn begins.
## Pure view, from SignalBus events this screen already gets.

const MAX_CARDS := 3
const CARD_SIZE := Vector2(88, 128)
## Sits between the player hub and the right column, bottom of the screen.
const AREA := Rect2(1320, 860, 292, 210)

var _row: HBoxContainer
var _title: Label
## [{"card": Dictionary, "key": heading key, "who": player id}]
var _cards := []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 4)
	alignment = BoxContainer.ALIGNMENT_END
	position = AREA.position
	size = AREA.size
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 14)
	_title.add_theme_color_override("font_color", Color(0.85, 0.82, 0.7))
	_title.add_theme_color_override("font_outline_color", Color.BLACK)
	_title.add_theme_constant_override("outline_size", 5)
	add_child(_title)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 6)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row)

	SignalBus.begin_turn.connect(func(_id): _clear())
	SignalBus.card_revealed.connect(func(id, card):
		_add(card, "match.you_drew" if id == GameState.local_id else "match.someone_drew", id))
	SignalBus.question_drawn.connect(func(card): _add(card, "match.your_question"))
	SignalBus.question_asked.connect(func(from_id, card): _add(card, "match.asks_you", from_id))
	SignalBus.game_over.connect(func(_f, _w): hide())
	Global.language_changed.connect(_rebuild.unbind(1))
	_rebuild()


func _name(id: int) -> String:
	return GameState.players.get(id, {}).get("name", "?")


func _clear() -> void:
	_cards.clear()
	_rebuild()


## `heading_key`: the popup's heading when shown again (with `who`'s name if
## it has a %s), looked up on click so it's in the current language.
func _add(card: Dictionary, heading_key: String, who := 0) -> void:
	for entry in _cards:
		if entry.card.get("uid", "?") == card.get("uid", "!"):
			return
	_cards.append({"card": card, "key": heading_key, "who": who})
	if _cards.size() > MAX_CARDS:
		_cards.pop_front()
	_rebuild()


func _rebuild() -> void:
	for child in _row.get_children():
		child.queue_free()
	_title.text = Global.text("cards.this_turn")
	visible = not _cards.is_empty()
	for entry in _cards:
		_row.add_child(_mini(entry))


## A small card: deck-coloured frame, art, name. Click: see it big.
func _mini(entry: Dictionary) -> Button:
	var card: Dictionary = entry.card
	var accent := Color(Global.CARD_COLORS.get(card.get("deck", ""), {}).get("color", "c8a85a"))
	var button := Button.new()
	button.custom_minimum_size = CARD_SIZE
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

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.position = Vector2(4, 4)
	column.size = CARD_SIZE - Vector2(8, 8)
	button.add_child(column)
	var art := TextureRect.new()
	art.texture = Global.card_back(card.get("deck", "red_cards"))
	art.custom_minimum_size = Vector2(0, 62)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(art)
	var title := Label.new()
	title.text = Global.field(card, "name")
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size = Vector2(CARD_SIZE.x - 8, 0)
	title.add_theme_font_size_override("font_size", 12)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(title)

	button.pressed.connect(func():
		var heading := Global.text(entry.key)
		if "%s" in heading:
			heading = heading % _name(entry.who)
		CardView.open(get_parent(), card, heading, [["OK", func(): pass]]))
	return button
