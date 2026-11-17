extends Node
## The store: what THIS computer knows about the session (lobby + match).
## Like a Pinia store's state:
## - The UI reads it freely but never writes it.
## - Only messages from the server (LobbyNet / MatchNet) write it.
## - It holds only what this player may know: their own character, public
##   info about everyone else. The server's full truth is ServerState.
## Static data (card lists, pawn sprites, defaults) lives in Global.

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

## The lobby's owner (changes settings, starts, kicks). 0 = not known yet.
var owner_id := 0

var game_info := {
	"players_turn": [],
	"round": 0,
	"waiting_for": [],  # players the server is waiting on for a choice
}

## The board's locations, in board order. Public, every peer has them.
var locations := []


var _no_player := new_player(0)


func reset_session(my_id := 0) -> void:
	phase = Phase.LOBBY
	local_id = my_id
	players = {}
	_no_player = new_player(my_id)
	game_settings = _empty_settings()
	owner_id = 0
	game_info = {"players_turn": [], "round": 0, "waiting_for": []}
	locations = []


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
		"equipment": [],  # face-up equipment cards (public)
	}


func location_for_total(total: int) -> String:
	return Board.location_for_total(locations, total)


func location_index(location_id: String) -> int:
	return Board.location_index(locations, location_id)


func can_reach(from_id: String, to_id: String) -> bool:
	return Board.can_reach(locations, from_id, to_id)


func is_pawn_taken(pawn: String, except_id := 0) -> bool:
	for player in players.values():
		if player.id != except_id and player.pawn == pawn:
			return true
	return false


func _empty_settings() -> Dictionary:
	return {"vampires_count": 0, "werewolves_count": 0, "humans_count": 0}
