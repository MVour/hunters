class_name PlayerList extends PanelContainer
## Every player down the right edge, in play order (numbered), the current
## player highlighted. A row click shows their character card (card_wanted).
## While the server asks you to pick a player (attack, card target…), the
## players you can pick light up here and can be clicked (see set_pickable).
## Pure view: reads GameState, refreshes on SignalBus events.

signal player_picked(player_id: int)
## A row was clicked: show their character card.
signal card_wanted(player_id: int)

const WIDTH := 290.0
## Tall enough for 8 players without scrolling (a hidden row is easy to miss).
const MAX_HEIGHT := 680.0

var _rows := {}  # player id -> PlayerRow
var _column: VBoxContainer
var _scroll: ScrollContainer
var _title: Label


func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.35)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(6)
	add_theme_stylebox_override("panel", style)
	custom_minimum_size = Vector2(WIDTH, 0)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 4)
	add_child(outer)
	_title = Label.new()
	_title.text = Global.text("players.players")
	Global.language_changed.connect(func():
		_title.text = Global.text("players.players")
		refresh())
	_title.add_theme_font_size_override("font_size", 15)
	_title.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	outer.add_child(_title)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(_scroll)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 4)
	_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_column.resized.connect(_fit_height)
	_scroll.add_child(_column)

	SignalBus.turn_order_set.connect(build)
	for sig in [SignalBus.begin_turn, SignalBus.end_turn, SignalBus.equipment_changed,
			SignalBus.ability_used]:
		sig.connect(refresh.unbind(1))
	for sig in [SignalBus.damage_changed, SignalBus.character_revealed, SignalBus.player_died,
			SignalBus.pawn_moved, SignalBus._set_character]:
		sig.connect(refresh.unbind(2))
	if not GameState.game_info.players_turn.is_empty():
		build(GameState.game_info.players_turn)


## One row per player, in play order.
func build(order: Array) -> void:
	for row in _rows.values():
		row.queue_free()
	_rows = {}
	for i in order.size():
		var row := PlayerRow.new(order[i], i + 1)
		row.picked.connect(func(id): player_picked.emit(id))
		row.card_wanted.connect(func(id): card_wanted.emit(id))
		_column.add_child(row)
		_rows[order[i]] = row
	refresh()


func refresh() -> void:
	for row in _rows.values():
		row.refresh()


## Light up these players and let them be clicked; [] ends picking.
## Rows of the players you could attack now get a red edge.
func set_in_reach(ids: Array) -> void:
	for id in _rows:
		_rows[id].set_in_reach(id in ids)


func set_pickable(ids: Array) -> void:
	for id in _rows:
		_rows[id].set_pick_state(id in ids, not ids.is_empty())


## Grow with the rows, scroll beyond MAX_HEIGHT.
func _fit_height() -> void:
	_scroll.custom_minimum_size = Vector2(WIDTH - 12, minf(_column.size.y, MAX_HEIGHT))
	reset_size()

