class_name TurnCards extends VBoxContainer
## The cards of the current turn, kept small in a row: what was drawn (by
## anyone), your green card, a green card someone asked you. Click one to
## see it big again. Cleared when the next turn begins.
## Pure view, from SignalBus events this screen already gets.

const MAX_CARDS := 3
const CARD_SIZE := Vector2(84, 129)  # the card art's shape (420 x 646)
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


## A small card: the whole art in a deck-coloured frame, its name on a
## dark strip at the bottom. Click: see it big.
func _mini(entry: Dictionary) -> Button:
	var card: Dictionary = entry.card
	var button := CardView.mini_card(card, CARD_SIZE)
	button.pressed.connect(func():
		var heading := Global.text(entry.key)
		if "%s" in heading:
			heading = heading % _name(entry.who)
		CardView.open(get_parent(), card, heading, [["OK", func(): pass]]))
	return button
