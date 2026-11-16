extends Node
## Everything that changes during a session (lobby + match).
## Static data (card lists, pawn sprites, defaults) lives in Global.
##
## The server's copy is the truth. Clients hold what they've been told, and
## for hidden roles that means: only their own character.

enum Phase { LOBBY, PLAYING, ENDED }

var phase := Phase.LOBBY

## Peer id of the player sitting at this computer.
var local_id := 0

## Public info about every player, keyed by peer id. See new_player().
var players := {}

## The player sitting at this computer.
var local_player: Dictionary:
	get:
		return players.get(local_id, _no_player)

var game_settings := _empty_settings()

var game_info := {
	"players_turn": [],
	"round": 0,
}

## The board's locations, in board order. Public, every peer has them.
var locations := []

## Server only: this match's shuffled copy of Global.deck.
var deck := {}

var _no_player := new_player(0)


func reset_session(my_id := 0) -> void:
	phase = Phase.LOBBY
	local_id = my_id
	players = {}
	_no_player = new_player(my_id)
	game_settings = _empty_settings()
	game_info = {"players_turn": [], "round": 0}
	locations = []
	deck = {}


func new_player(id: int) -> Dictionary:
	return {
		"id": id,
		"name": "",
		"pawn": "",
		"character": {},  # on clients: only filled for yourself (until revealed)
		"hidden": true,
		"playing": false,
		"dmg": 0,
		"location": "",  # location id, "" = still at the campfire
		"dead": false,
	}


## Which location a dice total sends you to ("" for 7 = your choice).
func location_for_total(total: int) -> String:
	for loc in locations:
		if total in loc.rolls:
			return loc.id
	return ""


## Board position (0-5) of a location, or -1 if unknown.
func location_index(location_id: String) -> int:
	for i in locations.size():
		if locations[i].id == location_id:
			return i
	return -1


## Reach: every location is grouped with the next one clockwise
## (1->2, 2->3, ... 6->1). From a location you reach players there and at
## the next location. Attacks use this; equipment may extend it later.
func can_reach(from_id: String, to_id: String) -> bool:
	var from := location_index(from_id)
	var to := location_index(to_id)
	if from == -1 or to == -1:
		return false
	return to == from or to == (from + 1) % locations.size()


## Server only. Copies the master card lists so shuffling and dealing never
## touch Global.deck.
func prepare_deck() -> void:
	deck = Global.deck.duplicate(true)
	for card_type in Global.CARD_TYPES:
		deck[card_type].shuffle()
	for species_list in deck.characters.values():
		species_list.shuffle()
	deck.locations.shuffle()
	locations = deck.locations


func is_pawn_taken(pawn: String, except_id := 0) -> bool:
	for player in players.values():
		if player.id != except_id and player.pawn == pawn:
			return true
	return false


func _empty_settings() -> Dictionary:
	return {"vampires_count": 0, "werewolves_count": 0, "humans_count": 0}
