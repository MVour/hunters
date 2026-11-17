extends Node
## MatchNet autoload: the ONLY place the match talks over the network.
## Think of it like a Pinia store's actions, around the GameState store:
##
##   UI ──action──> MatchNet.roll()          (any computer)
##        └─ request_roll.rpc_id(1)  ──────> MatchServer.roll(sender)   (server only)
##   MatchServer ──> MatchNet.move_pawn.rpc(...)  (a "message")
##        └─ on every computer: write GameState, then SignalBus.pawn_moved
##   UI <──listens── SignalBus
##
## Rules:
## - UI code calls the ACTIONS below and listens to SignalBus. It never calls
##   .rpc() itself and never writes GameState.
## - Only MESSAGES (server -> clients) write GameState on clients.
## - The server's own truth lives in MatchServer.state, not in GameState.
## - It's an autoload, so its node path (/root/MatchNet) is the same on every
##   computer no matter which scene is open; RPCs rely on that.

## Server only: the running match, or null.
var server: MatchServer


# =============================================================================
# Lifecycle (server)
# =============================================================================

## Server: set up a match from the lobby's players and settings. It starts
## once every player's match screen has loaded (see loaded()).
func create_server(lobby_players: Dictionary, lobby_settings: Dictionary) -> void:
	stop()
	server = MatchServer.new(ServerState.new(lobby_players, lobby_settings))
	add_child(server)


## Any computer: forget the match. Frees the server, which also cancels
## anything it was in the middle of (BUG-003).
func stop() -> void:
	if server:
		server.queue_free()
		server = null


func _ready() -> void:
	Network.host_disconnected.connect(stop)
	Network.session_closed.connect(stop)


# =============================================================================
# Actions: call these from the UI (any computer)
# =============================================================================

func loaded() -> void: request_loaded.rpc_id(1)
func roll() -> void: request_roll.rpc_id(1)
func choose_location(location_id: String) -> void: request_choose_location.rpc_id(1, location_id)
func draw(card_type: String) -> void: request_draw.rpc_id(1, card_type)
func use_location() -> void: request_location_action.rpc_id(1)
func skip_action() -> void: request_skip_action.rpc_id(1)
func choose(value) -> void: request_choice.rpc_id(1, value)
func give_question(target_id: int) -> void: request_give_question.rpc_id(1, target_id)
func answer_question() -> void: request_answer_question.rpc_id(1)
func attack() -> void: request_attack.rpc_id(1)
func reveal() -> void: request_reveal.rpc_id(1)
func use_ability() -> void: request_ability.rpc_id(1)
func end_turn() -> void: request_end_turn.rpc_id(1)


# =============================================================================
# Requests: client -> server. The server checks who sent it; never trust an
# id passed as an argument.
# =============================================================================

func _server_for_request() -> MatchServer:
	return server if multiplayer.is_server() else null


@rpc("any_peer", "call_local", "reliable")
func request_loaded() -> void:
	if _server_for_request(): server.peer_loaded(Network.sender_id())

@rpc("any_peer", "call_local", "reliable")
func request_roll() -> void:
	if _server_for_request(): server.roll(Network.sender_id())

@rpc("any_peer", "call_local", "reliable")
func request_choose_location(location_id: String) -> void:
	if _server_for_request(): server.choose_location(Network.sender_id(), location_id)

@rpc("any_peer", "call_local", "reliable")
func request_draw(card_type: String) -> void:
	if _server_for_request(): server.draw(Network.sender_id(), card_type)

@rpc("any_peer", "call_local", "reliable")
func request_location_action() -> void:
	if _server_for_request(): server.location_action(Network.sender_id())

@rpc("any_peer", "call_local", "reliable")
func request_skip_action() -> void:
	if _server_for_request(): server.skip_action(Network.sender_id())

@rpc("any_peer", "call_local", "reliable")
func request_choice(value) -> void:
	if _server_for_request(): server.choice(Network.sender_id(), value)

@rpc("any_peer", "call_local", "reliable")
func request_give_question(target_id: int) -> void:
	if _server_for_request(): server.give_question(Network.sender_id(), target_id)

@rpc("any_peer", "call_local", "reliable")
func request_answer_question() -> void:
	if _server_for_request(): server.answer_question(Network.sender_id())

@rpc("any_peer", "call_local", "reliable")
func request_attack() -> void:
	if _server_for_request(): server.attack(Network.sender_id())

@rpc("any_peer", "call_local", "reliable")
func request_reveal() -> void:
	if _server_for_request(): server.reveal(Network.sender_id())

@rpc("any_peer", "call_local", "reliable")
func request_ability() -> void:
	if _server_for_request(): server.use_ability(Network.sender_id())

@rpc("any_peer", "call_local", "reliable")
func request_end_turn() -> void:
	if _server_for_request(): server.end_turn(Network.sender_id())


# =============================================================================
# Messages: server -> clients. Each one updates this computer's GameState
# (if it carries state) and then tells the UI through SignalBus.
# =============================================================================

## Setup -----------------------------------------------------------------------

## Only to its owner: your secret character.
@rpc("authority", "call_local", "reliable")
func set_character(character: Dictionary) -> void:
	GameState.local_player.character = character
	SignalBus._set_character.emit(GameState.local_id, character)

@rpc("authority", "call_local", "reliable")
func set_locations(locations: Array) -> void:
	GameState.locations = locations
	SignalBus.set_locations.emit(locations)

@rpc("authority", "call_local", "reliable")
func set_turn_order(order: Array) -> void:
	GameState.game_info.players_turn = order
	SignalBus.turn_order_set.emit(order)

## Clients only learn how many cards each deck has, never their order.
@rpc("authority", "call_local", "reliable")
func attach_deck(card_type: String, count: int) -> void:
	SignalBus._attach_deck.emit(card_type, count)

@rpc("authority", "call_local", "reliable")
func deck_count(card_type: String, count: int) -> void:
	SignalBus.deck_count_changed.emit(card_type, count)

## Turns & moving ---------------------------------------------------------------

@rpc("authority", "call_local", "reliable")
func turn_changed(player_id: int, playing: bool, round_number: int) -> void:
	if GameState.players.has(player_id):
		GameState.players[player_id].playing = playing
	GameState.game_info.round = round_number
	GameState.game_info.step = ""
	if playing:
		SignalBus.begin_turn.emit(player_id)
	else:
		SignalBus.end_turn.emit(player_id)

## Which step of the turn player's turn we're at (public): "roll",
## "choose_location", "location", "attack_or_end", "end".
@rpc("authority", "call_local", "reliable")
func turn_step(player_id: int, step: String) -> void:
	GameState.game_info.step = step
	SignalBus.turn_step.emit(player_id, step)

@rpc("authority", "call_local", "reliable")
func dice_rolled(val6: int, val4: int) -> void:
	SignalBus.dice_rolled.emit(val6, val4)

## Only to the player who rolled a 7.
@rpc("authority", "call_local", "reliable")
func prompt_choose_location(options: Array) -> void:
	SignalBus.choose_location.emit(options)

@rpc("authority", "call_local", "reliable")
func move_pawn(player_id: int, location_id: String) -> void:
	if GameState.players.has(player_id):
		GameState.players[player_id].location = location_id
	SignalBus.pawn_moved.emit(player_id, location_id)

## Only to the player who just arrived.
@rpc("authority", "call_local", "reliable")
func offer_location_action(action: String) -> void:
	SignalBus.location_action_offered.emit(action)

## Choices & messages ----------------------------------------------------------

## Only to the player who has to choose.
@rpc("authority", "call_local", "reliable")
func present_choice(prompt: Dictionary, options: Array, allow_skip: bool) -> void:
	SignalBus.choice_requested.emit(prompt, options, allow_skip)

## Only to the player who has to throw the dice (attack, Old Map's second roll).
@rpc("authority", "call_local", "reliable")
func prompt_roll(prompt: Dictionary) -> void:
	SignalBus.roll_requested.emit(prompt)

## Public: which players the server is waiting on for a choice (not what).
@rpc("authority", "call_local", "reliable")
func waiting_for(player_ids: Array) -> void:
	GameState.game_info.waiting_for = player_ids
	SignalBus.waiting_changed.emit(player_ids)

@rpc("authority", "call_local", "reliable")
func notice(message: Dictionary) -> void:
	SignalBus.notice.emit(message)

## Only to one player: something only they get to know.
@rpc("authority", "call_local", "reliable")
func private_info(title: Dictionary, text: Dictionary) -> void:
	SignalBus.private_info.emit(title, text)

## Only to one player: a look at someone's character card.
@rpc("authority", "call_local", "reliable")
func private_character(player_id: int, character: Dictionary) -> void:
	SignalBus.private_character.emit(player_id, character)

## Cards -----------------------------------------------------------------------

## Only to the drawer of a green card.
@rpc("authority", "call_local", "reliable")
func question_drawn(card: Dictionary) -> void:
	SignalBus.question_drawn.emit(card)

@rpc("authority", "call_local", "reliable")
func card_drawn_secretly(player_id: int, card_type: String) -> void:
	SignalBus.card_drawn_secretly.emit(player_id, card_type)

@rpc("authority", "call_local", "reliable")
func card_revealed(player_id: int, card: Dictionary) -> void:
	SignalBus.card_revealed.emit(player_id, card)

## Only to the player being asked.
@rpc("authority", "call_local", "reliable")
func question_asked(from_id: int, card: Dictionary) -> void:
	SignalBus.question_asked.emit(from_id, card)

@rpc("authority", "call_local", "reliable")
func question_passed(from_id: int, to_id: int) -> void:
	SignalBus.question_passed.emit(from_id, to_id)

@rpc("authority", "call_local", "reliable")
func question_answered(from_id: int, to_id: int) -> void:
	SignalBus.question_answered.emit(from_id, to_id)

@rpc("authority", "call_local", "reliable")
func set_equipment(player_id: int, equipment: Array) -> void:
	if GameState.players.has(player_id):
		GameState.players[player_id].equipment = equipment
	SignalBus.equipment_changed.emit(player_id)

@rpc("authority", "call_local", "reliable")
func set_protected(player_id: int, on: bool) -> void:
	if GameState.players.has(player_id):
		GameState.players[player_id].protected = on
	SignalBus.equipment_changed.emit(player_id)

## Health, combat, abilities ---------------------------------------------------

@rpc("authority", "call_local", "reliable")
func set_damage(player_id: int, damage: int) -> void:
	if GameState.players.has(player_id):
		GameState.players[player_id].dmg = damage
	SignalBus.damage_changed.emit(player_id, damage)

@rpc("authority", "call_local", "reliable")
func attack_fx(attacker: int, target: int, damage: int) -> void:
	SignalBus.attack_happened.emit(attacker, target, damage)

## A character becomes public (revealed, or on death).
@rpc("authority", "call_local", "reliable")
func reveal_character(player_id: int, character: Dictionary) -> void:
	if GameState.players.has(player_id):
		GameState.players[player_id].character = character
		GameState.players[player_id].hidden = false
	SignalBus.character_revealed.emit(player_id, character)

@rpc("authority", "call_local", "reliable")
func player_died(player_id: int, killer_id: int) -> void:
	if GameState.players.has(player_id):
		GameState.players[player_id].dead = true
	SignalBus.player_died.emit(player_id, killer_id)

@rpc("authority", "call_local", "reliable")
func ability_used(player_id: int) -> void:
	if GameState.players.has(player_id):
		GameState.players[player_id].ability_used = true
	SignalBus.ability_used.emit(player_id)

@rpc("authority", "call_local", "reliable")
func game_over(faction: String, winners: Array, characters: Dictionary) -> void:
	GameState.phase = GameState.Phase.ENDED
	for id in characters:
		if GameState.players.has(id):
			GameState.players[id].character = characters[id]
			GameState.players[id].hidden = false
	SignalBus.game_over.emit(faction, winners)
