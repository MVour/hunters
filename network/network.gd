extends Node
## Network autoload: the single place that knows how players get connected.
##
## The game is server-authoritative: peer 1 (the server) makes every decision
## and clients only send requests. Two setups, chosen per game:
## - Direct: a player hosts (server_is_player), friends join by IP (ENet).
## - Online room: a dedicated server per room on the game server, reached
##   through the lobby service by WebSocket (RoomServer, WsTransport, D007).

signal connected_to_host
signal connection_failed(reason: String)
signal host_disconnected
signal peer_joined(id: int)
signal peer_left(id: int)
## We left a session on purpose (or started a new one). Session state resets.
signal session_closed

## Chosen per game: direct ENet (host on this computer / LAN / IP) or
## WebSocket (a room on the game server, D007). See host() and join().
var transport: NetworkTransport = EnetTransport.new()
## False on a dedicated room server (`-- --server`), which doesn't play itself.
var server_is_player := true
## Client of an online room: the join ticket from the room link (sent once
## to the room in LobbyNet.join()). "" otherwise.
var ticket := ""


func _ready() -> void:
	multiplayer.peer_connected.connect(func(id): peer_joined.emit(id))
	multiplayer.peer_disconnected.connect(func(id): peer_left.emit(id))
	multiplayer.connected_to_server.connect(func(): connected_to_host.emit())
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


## options: "transport" ("enet" default, or "ws" for a room server), "port", ...
func host(options := {}) -> Error:
	leave()
	transport = WsTransport.new() if options.get("transport", "enet") == "ws" else EnetTransport.new()
	ticket = ""
	var peer := transport.create_host_peer(options)
	if peer == null:
		return FAILED
	multiplayer.multiplayer_peer = peer
	return OK


## invite_code: "address:port" (direct) or a room link "wss://…/play/ROOM/TICKET".
func join(invite_code: String) -> Error:
	leave()
	var link := WsTransport.parse_link(invite_code)
	transport = WsTransport.new() if not link.is_empty() else EnetTransport.new()
	ticket = link.get("ticket", "")
	var peer := transport.create_client_peer(invite_code)
	if peer == null:
		return FAILED
	multiplayer.multiplayer_peer = peer
	return OK


func leave() -> void:
	var was_online := is_online()
	if was_online:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	if was_online:
		session_closed.emit()


func is_online() -> bool:
	return multiplayer.multiplayer_peer != null \
		and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer


func get_invite_code() -> String:
	return transport.get_invite_code()


func get_last_error() -> String:
	return transport.last_error


## Who sent the RPC currently running. Works for local (call_local) calls too.
func sender_id() -> int:
	var id := multiplayer.get_remote_sender_id()
	return id if id != 0 else multiplayer.get_unique_id()


func _on_connection_failed() -> void:
	leave()
	connection_failed.emit("Couldn't reach the host.")


func _on_server_disconnected() -> void:
	leave()
	host_disconnected.emit()
