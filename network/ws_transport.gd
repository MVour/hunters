class_name WsTransport extends NetworkTransport
## WebSocket connection, for online rooms on the game server (D007). Works in
## the browser build and the desktop build alike.
##
## - Host side: a dedicated room server (`-- --server`, see RoomServer). It
##   listens on localhost only; the lobby service is the one exposed to the
##   internet and forwards each player's connection here.
## - Client side: the invite code is the room's link,
##   `wss://<domain>/play/<ROOM>/<TICKET>`. The ticket is single-use and
##   proves to the lobby service and to the room who you are.

const DEFAULT_PORT := 20000

var port := DEFAULT_PORT
var _room := ""


static func is_link(code: String) -> bool:
	var c := code.strip_edges()
	return c.begins_with("wss://") or c.begins_with("ws://")


## "wss://host/play/ROOM/TICKET" -> {"room", "ticket"} ({} if not a room link).
static func parse_link(code: String) -> Dictionary:
	var c := code.strip_edges()
	var at := c.find("/play/")
	if not is_link(c) or at == -1:
		return {}
	var parts := c.substr(at + 6).split("/", false)
	if parts.size() != 2:
		return {}
	return {"room": parts[0], "ticket": parts[1]}


func create_host_peer(options: Dictionary) -> MultiplayerPeer:
	port = options.get("port", DEFAULT_PORT)
	var peer := WebSocketMultiplayerPeer.new()
	# Small inputs only: a board game never needs big messages.
	peer.inbound_buffer_size = 256 * 1024
	peer.max_queued_packets = 1024
	var err := peer.create_server(port, options.get("bind", "127.0.0.1"))
	if err != OK:
		last_error = "Couldn't listen on port %d (%s)." % [port, error_string(err)]
		return null
	return peer


func create_client_peer(invite_code: String) -> MultiplayerPeer:
	var link := parse_link(invite_code)
	if link.is_empty():
		last_error = "That isn't a room link."
		return null
	_room = link.room
	var peer := WebSocketMultiplayerPeer.new()
	var err := peer.create_client(invite_code.strip_edges())
	if err != OK:
		last_error = "Couldn't connect (%s)." % error_string(err)
		return null
	return peer


## The room code (never the ticket: that's private and single-use).
func get_invite_code() -> String:
	return _room
