class_name NetworkTransport extends RefCounted
## One way of connecting players together (direct ENet, a lobby service, ...).
##
## Game code never talks to a transport directly; it goes through the Network
## autoload. To add a lobby / matchmaking service later, write a new subclass
## and assign it to Network.transport. Nothing else has to change.

## Human-readable reason for the last failure.
var last_error := ""


## Returns a peer that hosts a game, or null on failure (see last_error).
func create_host_peer(_options: Dictionary) -> MultiplayerPeer:
	last_error = "Not implemented"
	return null


## Returns a peer connecting to the game described by invite_code, or null.
func create_client_peer(_invite_code: String) -> MultiplayerPeer:
	last_error = "Not implemented"
	return null


## The code other players enter to join this host.
func get_invite_code() -> String:
	return ""
