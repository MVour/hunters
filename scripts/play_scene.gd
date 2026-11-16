class_name PlayScene extends Node2D

@onready var damage_board: DamageBoard = $DamageBoard
@onready var players_slots: Node2D = $PlayersSlots
@onready var player_hud: PlayerHud = $Hud/PlayerHud
@onready var decks_container: HBoxContainer = $DecksContainer
@onready var deck_scn : PackedScene = preload("res://scenes/card_deck.tscn")
@onready var game_map: GameMap = $Locations
@onready var end_turn_button: Button = $EndTurnButton
@onready var roll_button: Button = $DicesContainer/RollButton
@onready var game_manager: GameManager = $GameManager
@onready var playing_label: Label = $PlayingLabel

var game_finished := false
var pawn_layer: PawnLayer
var prompt_label: Label
var action_bar: HBoxContainer
var toast_label: Label
var decks := {}  # card type -> CardDeck
## Locations you may pick after rolling a 7 (empty when not choosing).
var choice_options := []
## The location action currently offered to you ("" when none).
var offered_action := ""


func _ready():
	SignalBus._end_game.connect(_on_end_game)
	SignalBus._set_character.connect(_on_set_character)
	SignalBus.set_locations.connect(_on_set_locations)
	SignalBus._attach_deck.connect(_on_attach_deck)
	SignalBus.begin_turn.connect(_on_begin_turn)
	SignalBus.end_turn.connect(_on_end_turn)
	SignalBus.pawn_moved.connect(_on_pawn_moved)
	SignalBus.choose_location.connect(_on_choose_location)
	SignalBus.damage_changed.connect(_on_damage_changed)
	game_map.location_chosen.connect(_on_location_chosen)

	# Life track down the left edge.
	damage_board.position = Vector2(8, 192)

	# Pawns draw above the locations, below the HUD.
	pawn_layer = PawnLayer.new()
	pawn_layer.name = "Pawns"
	add_child(pawn_layer)
	move_child(pawn_layer, game_map.get_index() + 1)

	SignalBus.location_action_offered.connect(_on_location_action_offered)
	SignalBus.deck_count_changed.connect(_on_deck_count_changed)
	SignalBus.question_drawn.connect(_on_question_drawn)
	SignalBus.question_asked.connect(_on_question_asked)
	SignalBus.question_passed.connect(_on_question_passed)
	SignalBus.question_answered.connect(_on_question_answered)
	SignalBus.card_drawn_secretly.connect(_on_card_drawn_secretly)
	SignalBus.card_revealed.connect(_on_card_revealed)

	action_bar = HBoxContainer.new()
	action_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	action_bar.add_theme_constant_override("separation", 10)
	action_bar.position = Vector2(560, 636)
	action_bar.size = Vector2(800, 50)
	add_child(action_bar)

	toast_label = Label.new()
	toast_label.position = Vector2(560, 196)
	toast_label.size = Vector2(800, 40)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_font_size_override("font_size", 22)
	toast_label.add_theme_color_override("font_outline_color", Color.BLACK)
	toast_label.add_theme_constant_override("outline_size", 8)
	toast_label.modulate.a = 0.0
	add_child(toast_label)

	prompt_label = Label.new()
	prompt_label.position = Vector2(560, 446)
	prompt_label.size = Vector2(800, 40)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 24)
	prompt_label.add_theme_color_override("font_outline_color", Color.BLACK)
	prompt_label.add_theme_constant_override("outline_size", 8)
	prompt_label.hide()
	add_child(prompt_label)

	playing_label.hide()
	end_turn_button.hide()
	roll_button.hide()

	# Signals are connected, so we're ready for the server's messages.
	game_manager.report_loaded.rpc_id(1)


func _on_set_locations(_locations):
	game_map.locations_spawn()
	pawn_layer.setup(game_map, GameState.players)
	damage_board.show_players(GameState.players)


func _on_damage_changed(pl_id, dmg):
	if pl_id == GameState.local_id:
		player_hud.player_damage.text = str(dmg)


func _on_attach_deck(card_type: String, count: int):
	var new_deck : CardDeck = deck_scn.instantiate()
	decks_container.add_child(new_deck)
	new_deck.add_cards(card_type, count)
	new_deck.init()
	decks[card_type] = new_deck


func _on_end_game():
	game_finished = true


func _on_set_character(_pl_id, character):
	player_hud.init(character.name, character.species, character.goal, character.ability, character.health, 0)


# --- Turn flow UI ------------------------------------------------------------

func _on_begin_turn(pl_id):
	var my_turn: bool = pl_id == GameState.local_id
	playing_label.visible = my_turn
	roll_button.visible = my_turn
	end_turn_button.hide()  # shown once you've moved


func _on_end_turn(pl_id):
	if pl_id == GameState.local_id:
		playing_label.hide()
		roll_button.hide()
		end_turn_button.hide()
		_clear_action_bar()


func _on_pawn_moved(pl_id, _location_id):
	if pl_id == GameState.local_id and GameState.local_player.playing:
		roll_button.hide()
		end_turn_button.show()


## Rolled a 7: light up every other location and wait for a click.
func _on_choose_location(options: Array) -> void:
	choice_options = options
	roll_button.hide()
	prompt_label.text = "You rolled 7! Pick any other location."
	prompt_label.show()
	game_map.set_choosable(options)


func _on_location_chosen(location_id: String) -> void:
	if not location_id in choice_options:
		return
	choice_options = []
	prompt_label.hide()
	game_map.set_choosable([])
	game_manager.request_choose_location.rpc_id(1, location_id)


func _on_end_turn_button_pressed() -> void:
	game_manager.request_end_turn.rpc_id(1)


# --- Location actions & cards ------------------------------------------------

func _player_name(id: int) -> String:
	return GameState.players.get(id, {}).get("name", "?")


func _player_color(id: int) -> Color:
	var pawn: String = GameState.players.get(id, {}).get("pawn", "")
	return Color(Global.pawns[pawn].hex) if Global.pawns.has(pawn) else Color.WHITE


func toast(text: String) -> void:
	toast_label.text = text
	var tween := create_tween()
	tween.tween_property(toast_label, "modulate:a", 1.0, 0.2)
	tween.tween_interval(2.8)
	tween.tween_property(toast_label, "modulate:a", 0.0, 0.5)


func _clear_action_bar() -> void:
	for child in action_bar.get_children():
		child.queue_free()
	offered_action = ""
	prompt_label.hide()
	for deck in decks.values():
		deck.set_highlight(false)


func _add_action_button(text: String, color: Color, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(170, 46)
	button.add_theme_font_size_override("font_size", 19)
	button.add_theme_color_override("font_color", color)
	button.pressed.connect(func():
		_clear_action_bar()
		callback.call())
	action_bar.add_child(button)


## You arrived somewhere: offer what the location lets you do.
func _on_location_action_offered(action: String) -> void:
	_clear_action_bar()
	offered_action = action
	var loc_label := ""
	for loc in GameState.locations:
		if loc.id == GameState.local_player.location:
			loc_label = loc.label
	prompt_label.text = "%s: %s" % [loc_label, Global.LOCATION_ACTIONS[action].text]
	prompt_label.show()

	var draws: Array = GameManager.DRAW_ACTIONS.get(action, [])
	for card_type in draws:
		var info: Dictionary = Global.CARD_COLORS[card_type]
		_add_action_button("Draw %s" % info.label, Color(info.color).lightened(0.3),
			func(): game_manager.request_draw.rpc_id(1, card_type))
		decks[card_type].set_highlight(true)
	if draws.is_empty():
		prompt_label.text += "  (coming soon)"
	_add_action_button("Skip", Color(0.8, 0.8, 0.8),
		func(): game_manager.request_skip_action.rpc_id(1))


func _on_deck_count_changed(card_type: String, count: int) -> void:
	if decks.has(card_type):
		decks[card_type].set_count(count)


## You drew a green question: read it, then pick who to ask.
func _on_question_drawn(card: Dictionary) -> void:
	var buttons := []
	for id in GameState.game_info.players_turn:
		var player: Dictionary = GameState.players[id]
		if id != GameState.local_id and not player.dead:
			buttons.append([player.name, func(): game_manager.request_give_question.rpc_id(1, id), _player_color(id)])
	CardView.open(self, card, "Your question. Who do you ask?  ·  Σε ποιον τη δίνεις;", buttons)


## Someone asked you a question.
func _on_question_asked(from_id: int, card: Dictionary) -> void:
	CardView.open(self, card, "%s asks you:  ·  Σε ρωτάει:" % _player_name(from_id),
		[["Answer", func(): game_manager.request_answer_question.rpc_id(1)]])


func _on_question_passed(from_id: int, to_id: int) -> void:
	if to_id != GameState.local_id:
		toast("%s gave a green card to %s" % [_player_name(from_id), _player_name(to_id)])


func _on_question_answered(from_id: int, to_id: int) -> void:
	toast("%s answered %s's question" % [_player_name(to_id), _player_name(from_id)])


func _on_card_drawn_secretly(pl_id: int, card_type: String) -> void:
	if pl_id != GameState.local_id:
		toast("%s drew a %s card" % [_player_name(pl_id), Global.CARD_COLORS[card_type].label])


## Red/blue cards are read aloud: everyone sees them.
func _on_card_revealed(pl_id: int, card: Dictionary) -> void:
	var who := "You" if pl_id == GameState.local_id else _player_name(pl_id)
	CardView.open(self, card, "%s drew:" % who, [["OK", func(): pass]])
