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
	# Skip players who are out.
	var playing_id: int = order[current_turn.turn_count % order.size()]
	for i in order.size():
		if not GameState.players[playing_id].dead:
			break
		current_turn.turn_count += 1
		playing_id = order[current_turn.turn_count % order.size()]
	current_turn.turn_count += 1
	current_turn.playing_id = playing_id
	current_turn.phase = TurnPhase.ROLL
	current_turn.action_used = false
	current_turn.pending_question = {}
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
	current_turn.action_used = false
	move_pawn.rpc(player_id, location_id)
	var loc: Dictionary = GameState.locations[GameState.location_index(location_id)]
	offer_location_action.rpc_id(player_id, loc.action)


# --- Location actions & drawing cards ----------------------------------------

## Which decks a location action lets you draw from.
const DRAW_ACTIONS := {
	"draw_green": ["green_cards"],
	"draw_red": ["red_cards"],
	"draw_blue": ["blue_cards"],
	"draw_any": ["green_cards", "red_cards", "blue_cards"],
}


## Server -> the player who just arrived: what this location offers.
@rpc("authority", "call_local", "reliable")
func offer_location_action(action: String) -> void:
	SignalBus.location_action_offered.emit(action)


func _location_action_of(player_id: int) -> String:
	var index := GameState.location_index(GameState.players[player_id].location)
	return GameState.locations[index].action if index != -1 else ""


@rpc("any_peer", "call_local", "reliable")
func request_skip_action() -> void:
	if multiplayer.is_server() and _is_current_player(Network.sender_id()):
		current_turn.action_used = true


@rpc("any_peer", "call_local", "reliable")
func request_draw(card_type: String) -> void:
	if not multiplayer.is_server():
		return
	var sender := Network.sender_id()
	if not _is_current_player(sender) or current_turn.phase != TurnPhase.ACTION or current_turn.action_used:
		return
	if not card_type in DRAW_ACTIONS.get(_location_action_of(sender), []):
		return
	draw_for(sender, card_type)
	current_turn.action_used = true


## Server only. A player draws a card (also used by card effects later).
func draw_for(player_id: int, card_type: String) -> void:
	var card := GameState.draw_card(card_type)
	if card.is_empty():
		return
	deck_count.rpc(card_type, GameState.deck[card_type].size())
	if card.kind == "question":
		# Green: secret. Only the drawer sees it, then picks who to ask.
		var waiting: Dictionary = current_turn.get("pending_question", {})
		if not waiting.is_empty():
			GameState.discard(waiting.card)  # never lose a card from the deck
		current_turn.pending_question = {"card": card, "from": player_id, "to": 0}
		question_drawn.rpc_id(player_id, card)
		card_drawn_secretly.rpc(player_id, card_type)
	else:
		# Red/blue: read aloud. Everyone sees it.
		card_revealed.rpc(player_id, card)
		if card.kind == "equipment":
			GameState.players[player_id].equipment.append(card)
			equipment_gained.rpc(player_id, card)
		else:
			# TODO (step 3): resolve the event's effect before discarding.
			GameState.discard(card)


@rpc("authority", "call_local", "reliable")
func deck_count(card_type: String, count: int) -> void:
	SignalBus.deck_count_changed.emit(card_type, count)


## Server -> the drawer of a green card.
@rpc("authority", "call_local", "reliable")
func question_drawn(card: Dictionary) -> void:
	SignalBus.question_drawn.emit(card)


## Server -> everyone: someone drew a card nobody else gets to see.
@rpc("authority", "call_local", "reliable")
func card_drawn_secretly(player_id: int, card_type: String) -> void:
	SignalBus.card_drawn_secretly.emit(player_id, card_type)


@rpc("authority", "call_local", "reliable")
func card_revealed(player_id: int, card: Dictionary) -> void:
	SignalBus.card_revealed.emit(player_id, card)


@rpc("authority", "call_local", "reliable")
func equipment_gained(player_id: int, card: Dictionary) -> void:
	if GameState.players.has(player_id) and not multiplayer.is_server():
		GameState.players[player_id].equipment.append(card)
	SignalBus.equipment_changed.emit(player_id)


## The asker hands their green card to another player.
@rpc("any_peer", "call_local", "reliable")
func request_give_question(target_id: int) -> void:
	if not multiplayer.is_server():
		return
	var sender := Network.sender_id()
	var q: Dictionary = current_turn.get("pending_question", {})
	if q.is_empty() or q.from != sender or q.to != 0:
		return
	if target_id == sender or not GameState.players.has(target_id) or GameState.players[target_id].dead:
		return
	q.to = target_id
	question_asked.rpc_id(target_id, sender, q.card)
	question_passed.rpc(sender, target_id)


## Server -> the player being asked.
@rpc("authority", "call_local", "reliable")
func question_asked(from_id: int, card: Dictionary) -> void:
	SignalBus.question_asked.emit(from_id, card)


## Server -> everyone: who asked whom (not what).
@rpc("authority", "call_local", "reliable")
func question_passed(from_id: int, to_id: int) -> void:
	SignalBus.question_passed.emit(from_id, to_id)


## The asked player has read the card; the server applies it.
@rpc("any_peer", "call_local", "reliable")
func request_answer_question() -> void:
	if not multiplayer.is_server():
		return
	var q: Dictionary = current_turn.get("pending_question", {})
	if q.is_empty() or q.to == 0 or Network.sender_id() != q.to:
		return
	# TODO (step 3): apply the question's effect to q.to, tell q.from the result.
	GameState.discard(q.card)
	current_turn.pending_question = {}
	question_answered.rpc(q.from, q.to)


@rpc("authority", "call_local", "reliable")
func question_answered(from_id: int, to_id: int) -> void:
	SignalBus.question_answered.emit(from_id, to_id)


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
	# You have to move before you can end your turn, and an asked question
	# has to be answered first.
	if not _is_current_player(sender) or current_turn.phase != TurnPhase.ACTION:
		return
	if not current_turn.get("pending_question", {}).is_empty():
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


# --- Health ------------------------------------------------------------------
# Server only. Cards, locations and attacks all go through these.

func apply_damage(target_id: int, amount: int, source_id := 0) -> void:
	if not multiplayer.is_server() or not GameState.players.has(target_id):
		return
	var target: Dictionary = GameState.players[target_id]
	if target.dead or amount <= 0:
		return
	target.dmg = mini(target.dmg + amount, target.character.health)
	set_damage.rpc(target_id, target.dmg)
	if target.dmg >= target.character.health:
		_kill(target_id, source_id)


func heal(target_id: int, amount: int) -> void:
	if not multiplayer.is_server() or not GameState.players.has(target_id):
		return
	var target: Dictionary = GameState.players[target_id]
	if target.dead or amount <= 0:
		return
	target.dmg = maxi(0, target.dmg - amount)
	set_damage.rpc(target_id, target.dmg)


@rpc("authority", "call_local", "reliable")
func set_damage(player_id: int, damage: int) -> void:
	if GameState.players.has(player_id):
		GameState.players[player_id].dmg = damage
	SignalBus.damage_changed.emit(player_id, damage)


## Out of health: the player is out and their card is revealed to everyone.
func _kill(player_id: int, killer_id: int) -> void:
	GameState.players[player_id].dead = true
	reveal_character.rpc(player_id, GameState.players[player_id].character)
	player_died.rpc(player_id, killer_id)
	# TODO (step 6): the killer takes one of the dead player's equipment cards.
	# TODO (step 7): check win conditions.
	if player_id == current_turn.playing_id:
		players_lock.rpc(player_id, false)
		_start_turn()


## Makes a character public (on death, or when a player reveals it).
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
