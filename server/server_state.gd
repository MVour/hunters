class_name ServerState extends RefCounted
## The server's own copy of a match: the whole truth, including every
## player's secret character and the order of the decks. Only MatchServer
## and CardEffects touch it. Clients never see this object; they get what
## they're allowed to know through MatchNet messages into their GameState.

## Every player, keyed by peer id (same fields as GameState.new_player(),
## plus server-only ones like "kills" and "hope_side").
var players := {}
## Species counts chosen in the lobby.
var settings := {}
## Board order, shuffled per match.
var locations := []
## Player ids in turn order.
var turn_order := []
var round := 0
## Shuffled copies of the card lists, and the used cards per deck.
var deck := {}
var discards := {}


func _init(lobby_players: Dictionary, lobby_settings: Dictionary) -> void:
	players = lobby_players.duplicate(true)
	settings = lobby_settings.duplicate(true)


## Copies the master card lists so shuffling and dealing never touch Global.deck.
func prepare_deck() -> void:
	deck = Global.deck.duplicate(true)
	discards = {}
	for card_type in Global.CARD_TYPES:
		for card in deck[card_type]:
			card.deck = card_type
		deck[card_type].shuffle()
		discards[card_type] = []
	for species_list in deck.characters.values():
		species_list.shuffle()
	deck.locations.shuffle()
	locations = deck.locations


## Top card of a deck; reshuffles the discards when it's empty.
func draw_card(card_type: String) -> Dictionary:
	if deck[card_type].is_empty():
		deck[card_type] = discards[card_type]
		discards[card_type] = []
		deck[card_type].shuffle()
	if deck[card_type].is_empty():
		return {}
	return deck[card_type].pop_back()


func discard(card: Dictionary) -> void:
	discards[card.deck].append(card)


func location_for_total(total: int) -> String:
	return Board.location_for_total(locations, total)


func location_index(location_id: String) -> int:
	return Board.location_index(locations, location_id)


func location_label(location_id: String) -> String:
	return Board.location_label(locations, location_id)


func can_reach(from_id: String, to_id: String) -> bool:
	return Board.can_reach(locations, from_id, to_id)


func next_location(location_id: String) -> String:
	return Board.next_location(locations, location_id)


func name_of(player_id: int) -> String:
	return players.get(player_id, {}).get("name", "?")
