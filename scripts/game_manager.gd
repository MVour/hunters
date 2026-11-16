class_name GameManager extends Node
## Runs the match.
##
## Rules of the road:
## - Only the server (peer 1) decides anything. Functions starting with _
##   that change game state only run there.
## - Clients ask via request_* RPCs. The server checks WHO sent it with
##   Network.sender_id() (never trust an id passed as an argument).
## - The server tells peers what happened via "authority" RPCs.

enum TurnPhase { ROLL, CHOOSE_LOCATION, ACTION }

@onready var players_slots: PlayersSlots = $"../PlayersSlots"
@onready var dices_container: DiceManager = $"../DicesContainer"

var game_started := false
var game_finished := false

## Server only: peers that have finished loading the play scene.
var _loaded_peers := {}

var current_turn := {
	"turn_count": 0,
	"playing_id": 0,
	"phase": TurnPhase.ROLL,
	"roll": {"val6": 0, "val4": 0},
}


# --- Starting the match ------------------------------------------------------

## Every peer calls this once its play scene is ready. The server starts the
## match when all players have loaded, so no RPC hits a scene that isn't
## there yet.
@rpc("any_peer", "call_local", "reliable")
func report_loaded() -> void:
	if not multiplayer.is_server():
		return
	_loaded_peers[Network.sender_id()] = true
	if game_started:
		return
	for id in GameState.players:
		if not _loaded_peers.has(id):
			return
	_start_game()


func _start_game() -> void:
	game_started = true
	game_finished = false
	GameState.prepare_deck()
	_deal_characters()
	_send_decks()
	set_locations.rpc(GameState.locations)
	_decide_turn_order()
	players_slots.sit_players.rpc(GameState.game_info.players_turn)
	_start_turn()


## Deals each player a secret character. Only the owner is told which one.
func _deal_characters() -> void:
	var chosen := []
	for settings_key in Global.SPECIES:
		var list_name: String = Global.SPECIES[settings_key].list
		var count: int = GameState.game_settings[settings_key]
		chosen.append_array(GameState.deck.characters[list_name].slice(0, count))
	chosen.shuffle()

	if chosen.size() < GameState.players.size():
		push_error("Not enough characters for %d players (lobby should have blocked this)." % GameState.players.size())
		return

	var i := 0
	for id in GameState.players:
		GameState.players[id].character = chosen[i]
		set_character.rpc_id(id, chosen[i])
		i += 1


@rpc("authority", "call_local", "reliable")
func set_character(character: Dictionary) -> void:
	GameState.local_player.character = character
	SignalBus._set_character.emit(GameState.local_id, character)


## Clients only learn how many cards each deck has, not their order.
func _send_decks() -> void:
	for card_type in Global.CARD_TYPES:
		attach_deck.rpc(card_type, GameState.deck[card_type].size())


@rpc("authority", "call_local", "reliable")
func attach_deck(card_type: String, count: int) -> void:
	SignalBus._attach_deck.emit(card_type, count)


@rpc("authority", "call_local", "reliable")
func set_locations(locations: Array) -> void:
	GameState.locations = locations
	SignalBus.set_locations.emit(locations)


func _decide_turn_order() -> void:
	var order: Array = GameState.players.keys()
	order.shuffle()
	GameState.game_info.players_turn = order


# --- Turns -------------------------------------------------------------------

func _start_turn() -> void:
	var order: Array = GameState.game_info.players_turn
	var playing_id: int = order[current_turn.turn_count % order.size()]
	current_turn.turn_count += 1
	current_turn.playing_id = playing_id
	current_turn.phase = TurnPhase.ROLL
	@warning_ignore("integer_division")
	GameState.game_info.round = (current_turn.turn_count - 1) / order.size() + 1

	print("Starting turn %d (round %d), player %d" % [current_turn.turn_count, GameState.game_info.round, playing_id])
	players_lock.rpc(playing_id, true)


func _is_current_player(id: int) -> bool:
	return game_started and not game_finished and id == current_turn.playing_id


@rpc("any_peer", "call_local", "reliable")
func request_roll() -> void:
	if not multiplayer.is_server():
		return
	if not _is_current_player(Network.sender_id()) or current_turn.phase != TurnPhase.ROLL:
		return

	var player_id: int = current_turn.playing_id
	var here: String = GameState.players[player_id].location

	# You always move somewhere new: if the dice point at where you already
	# are, roll again. A 7 means you choose.
	var roll := {}
	var total := 0
	var destination := ""
	for attempt in 50:
		roll = dices_container.throw_dices()
		total = roll.val6 + roll.val4
		if total == Global.ROLL_ANY_LOCATION:
			break
		destination = GameState.location_for_total(total)
		if destination != here:
			break

	current_turn.roll = roll
	dices_container.roll_dices.rpc(roll.val6, roll.val4)

	if total == Global.ROLL_ANY_LOCATION:
		current_turn.phase = TurnPhase.CHOOSE_LOCATION
		var options := []
		for loc in GameState.locations:
			if loc.id != here:
				options.append(loc.id)
		prompt_choose_location.rpc_id(player_id, options)
	else:
		_move_player(player_id, destination)


## Server -> the player who rolled a 7: pick a location.
@rpc("authority", "call_local", "reliable")
func prompt_choose_location(options: Array) -> void:
	SignalBus.choose_location.emit(options)


@rpc("any_peer", "call_local", "reliable")
func request_choose_location(location_id: String) -> void:
	if not multiplayer.is_server():
		return
	var sender := Network.sender_id()
	if not _is_current_player(sender) or current_turn.phase != TurnPhase.CHOOSE_LOCATION:
		return
	if location_id == GameState.players[sender].location or GameState.location_index(location_id) == -1:
		return
	_move_player(sender, location_id)


func _move_player(player_id: int, location_id: String) -> void:
	current_turn.phase = TurnPhase.ACTION
	move_pawn.rpc(player_id, location_id)


## Server -> everyone: this player's pawn is now at this location.
@rpc("authority", "call_local", "reliable")
func move_pawn(player_id: int, location_id: String) -> void:
	if GameState.players.has(player_id):
		GameState.players[player_id].location = location_id
	SignalBus.pawn_moved.emit(player_id, location_id)


@rpc("any_peer", "call_local", "reliable")
func request_end_turn() -> void:
	if not multiplayer.is_server():
		return
	var sender := Network.sender_id()
	# You have to move before you can end your turn.
	if not _is_current_player(sender) or current_turn.phase != TurnPhase.ACTION:
		return
	players_lock.rpc(sender, false)
	_start_turn()


@rpc("authority", "call_local", "reliable")
func players_lock(playing_id: int, val: bool) -> void:
	if GameState.players.has(playing_id):
		GameState.players[playing_id].playing = val

	if val:
		SignalBus.begin_turn.emit(playing_id)
	else:
		SignalBus.end_turn.emit(playing_id)
