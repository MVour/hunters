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
## Locations you may pick after rolling a 7 (empty when not choosing).
var choice_options := []


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

	prompt_label = Label.new()
	prompt_label.position = Vector2(700, 628)
	prompt_label.size = Vector2(520, 48)
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
