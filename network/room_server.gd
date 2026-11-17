class_name RoomServer extends Node
## A dedicated server for ONE online room (D007). It doesn't play; it only
## runs LobbyNet + MatchNet's server side. Started by the lobby service:
##
##   <game> --headless -- --server --port=20000 --room=K7QX9P [--max-players=8]
##
## with the room's ticket secret in the BOARD2D_ROOM_SECRET environment
## variable (never on the command line: other users could read it there).
## - Listens on 127.0.0.1 only; the lobby service forwards players to it.
## - Every joiner needs a ticket signed with that secret (RoomTicket).
## - Prints one-line reports for the lobby service on stdout:
##     ROOM_READY
##     ROOM_STATUS {"players": [...], "owner": "...", "inMatch": false}
## - Quits by itself when nobody is connected for EMPTY_QUIT_SECONDS.

const EMPTY_QUIT_SECONDS := 120.0

var _port := WsTransport.DEFAULT_PORT
var _room := ""
var _max_players := LobbyNet.MAX_PLAYERS
var _empty_for := 0.0
var _last_status := ""


static func wanted() -> bool:
	return "--server" in OS.get_cmdline_user_args()


func _ready() -> void:
	name = "RoomServer"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--port="):
			_port = arg.get_slice("=", 1).to_int()
		elif arg.begins_with("--room="):
			_room = arg.get_slice("=", 1)
		elif arg.begins_with("--max-players="):
			_max_players = clampi(arg.get_slice("=", 1).to_int(), 2, LobbyNet.MAX_PLAYERS)

	var secret := OS.get_environment("BOARD2D_ROOM_SECRET")
	if secret.length() < 32 or _room == "" or _port <= 1024:
		_fail("needs --room, --port (>1024) and BOARD2D_ROOM_SECRET (32+ chars)")
		return

	Global.persist_settings = false
	Network.server_is_player = false
	LobbyNet.tickets = RoomTicket.new(secret, _room)
	LobbyNet.max_players = _max_players
	if Network.host({"transport": "ws", "port": _port, "bind": "127.0.0.1"}) != OK:
		_fail(Network.get_last_error())
		return
	GameState.reset_session(multiplayer.get_unique_id())
	print("ROOM_READY")

	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.timeout.connect(_tick)
	add_child(timer)
	timer.start()


func _tick() -> void:
	_report()
	if multiplayer.get_peers().is_empty():
		_empty_for += 1.0
		if _empty_for >= EMPTY_QUIT_SECONDS:
			print("ROOM_EXIT empty")
			_quit(0)
	else:
		_empty_for = 0.0


## Tell the lobby service who's here (only when something changed).
func _report() -> void:
	var names := []
	for player in LobbyNet.server_players().values():
		names.append(player.name)
	var owner: Dictionary = LobbyNet.server_player(LobbyNet.owner_id())
	var status := JSON.stringify({"players": names, "owner": owner.get("name", ""),
		"inMatch": LobbyNet.in_match(), "connected": multiplayer.get_peers().size()})
	if status != _last_status:
		_last_status = status
		print("ROOM_STATUS ", status)


func _fail(why: String) -> void:
	print("ROOM_ERROR ", why)
	_quit(2)


func _quit(code: int) -> void:
	MatchNet.stop()
	Network.leave()
	await get_tree().process_frame
	get_tree().quit(code)
