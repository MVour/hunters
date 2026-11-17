extends Node
## LobbyNet autoload: the ONLY place the lobby talks over the network. Same
## pattern as MatchNet (read that file's header):
##   UI -> action (join, choose_avatar, change_setting, start_match, kick)
##      -> request on the server (checks who's asking)
##      -> message to everyone -> GameState + SignalBus -> UI.
##
## The server's own truth (who's in, which pawn, the role counts) lives here
## in _players/_settings, separate from GameState (the store every computer,
## the host included, renders from).
##
## Online rooms (D007): the room server sets `tickets`; then every joiner must
## bring a valid ticket from the lobby service, their name comes from it (it
## can't be changed), and the ticket says who the room's owner is.

const MAX_PLAYERS := 8

# --- Server only ---------------------------------------------------------------
var _players := {}
var _settings := {}
## The lobby's owner: only they change settings, start and kick. Direct
## games: the first to join. Online rooms: whoever the ticket says (else the
## first to join; passed on when the owner leaves).
var _owner_id := 0
var _in_match := false
## Online rooms only: checks join tickets (null = direct game, no tickets).
var tickets: RoomTicket
## Online rooms can allow fewer players.
var max_players := MAX_PLAYERS


func _ready() -> void:
	Network.peer_left.connect(_on_peer_left)
	Network.session_closed.connect(_reset)
	Network.host_disconnected.connect(_reset)


func _reset() -> void:
	_players = {}
	_settings = {}
	_owner_id = 0
	_in_match = false


## Server: is a match running (for the room server's status reports).
func in_match() -> bool:
	return _in_match


## Server: the owner's player id (0 = none yet).
func owner_id() -> int:
	return _owner_id


# =============================================================================
# Actions: call these from the UI
# =============================================================================

func join() -> void: request_join.rpc_id(1, Network.ticket)
func choose_avatar(player_name: String, pawn: String) -> void: request_avatar.rpc_id(1, player_name, pawn)
func change_setting(key: String, delta: int) -> void: request_setting.rpc_id(1, key, delta)
func start_match() -> void: request_start.rpc_id(1)
func kick(player_id: int) -> void: request_kick.rpc_id(1, player_id)


# =============================================================================
# Requests: client -> server
# =============================================================================

@rpc("any_peer", "call_local", "reliable")
func request_join(ticket := "") -> void:
	if not multiplayer.is_server():
		return
	var id := Network.sender_id()
	if _players.has(id):
		return
	if _in_match or _players.size() >= max_players:
		push_warning("join refused: %s" % ("match running" if _in_match else "room full"))
		_refuse(id)
		return

	var identity := {}
	if tickets:
		identity = tickets.verify(str(ticket))
		if identity.is_empty() or _name_taken(identity.name):
			push_warning("join refused: %s" % ("bad ticket" if identity.is_empty() else "name already here"))
			_refuse(id)
			return

	var player := GameState.new_player(id)
	player.name = identity.get("name", "Player_%d" % (_players.size() + 1))
	_players[id] = player
	if identity.get("owner", false) or _owner_id == 0:
		_owner_id = id
	# Tell the newcomer who's already here, then tell everyone about them.
	for other_id in _players:
		if other_id != id:
			sync_player.rpc_id(id, _players[other_id])
	sync_player.rpc(player)
	owner_changed.rpc(_owner_id)
	ChatNet.send_history(id)
	_reset_settings()


@rpc("any_peer", "call_local", "reliable")
func request_avatar(player_name: String, pawn: String) -> void:
	if not multiplayer.is_server():
		return
	var id := Network.sender_id()
	if not _players.has(id) or _in_match:
		return
	if not Global.pawns.has(pawn) or _pawn_taken(pawn, id):
		avatar_rejected.rpc_id(id, pawn)
		return
	var player: Dictionary = _players[id]
	player_name = player_name.strip_edges().left(16)
	# Online rooms: your name is the one you logged in with.
	if player_name != "" and tickets == null:
		player.name = player_name
	player.pawn = pawn
	sync_player.rpc(player)


@rpc("any_peer", "call_local", "reliable")
func request_setting(key: String, delta: int) -> void:
	if not multiplayer.is_server() or Network.sender_id() != _owner_id or _in_match:
		return
	if not Global.SPECIES.has(key) or absi(delta) > 1:
		return
	var max_count: int = Global.deck.characters[Global.SPECIES[key].list].size()
	_settings[key] = clampi(_settings.get(key, 0) + delta, 0, max_count)
	settings_changed.rpc(_settings)


@rpc("any_peer", "call_local", "reliable")
func request_start() -> void:
	if not multiplayer.is_server():
		return
	var sender := Network.sender_id()
	if sender != _owner_id or _in_match:
		return
	var problem := start_problem(_players, _settings)
	if not problem.is_empty():
		start_refused.rpc_id(sender, problem)
		return
	_in_match = true
	MatchNet.create_server(_players, _settings)
	start_game.rpc()


## The owner removes someone from the lobby (not during a match, not themselves).
@rpc("any_peer", "call_local", "reliable")
func request_kick(player_id: int) -> void:
	if not multiplayer.is_server() or Network.sender_id() != _owner_id or _in_match:
		return
	if player_id == _owner_id or not _players.has(player_id):
		return
	if player_id == multiplayer.get_unique_id():
		return  # the host of a direct game can't kick itself off its own server
	_players.erase(player_id)
	remove_player.rpc(player_id)
	_refuse(player_id)
	_reset_settings()


func _refuse(id: int) -> void:
	if id != multiplayer.get_unique_id():
		multiplayer.multiplayer_peer.disconnect_peer(id)


func _on_peer_left(id: int) -> void:
	if not multiplayer.is_server() or not _players.has(id):
		return
	if _in_match:
		# BUG-001: the player is out of the match; it goes on without them.
		if MatchNet.server:
			MatchNet.server.player_left(id)
		return
	_players.erase(id)
	if id == _owner_id:
		_owner_id = _players.keys().front() if not _players.is_empty() else 0
		owner_changed.rpc(_owner_id)
	remove_player.rpc(id)
	_reset_settings()


## Role counts go back to the preset for this many players.
func _reset_settings() -> void:
	var preset: Dictionary = Global.game_settings_default.players.get(_players.size(), {})
	_settings = {}
	for key in Global.SPECIES:
		_settings[key] = preset.get(key, 0)
	settings_changed.rpc(_settings)


## Server: a player as the lobby knows them ({} if not in the session).
func server_player(id: int) -> Dictionary:
	return _players.get(id, {})


## Server: everyone in the session (room status reports).
func server_players() -> Dictionary:
	return _players


func _pawn_taken(pawn: String, except_id: int) -> bool:
	for player in _players.values():
		if player.id != except_id and player.pawn == pawn:
			return true
	return false


func _name_taken(player_name: String) -> bool:
	for player in _players.values():
		if player.name.to_lower() == player_name.to_lower():
			return true
	return false


## Why a match with these players and role counts can't start, as a Msg
## ({} = it can). The lobby screen shows it too; the server always re-checks.
static func start_problem(players: Dictionary, settings: Dictionary) -> Dictionary:
	if players.size() < 2:
		return Msg.make("lobby.need_two")
	for player in players.values():
		if player.pawn == "":
			return Msg.make("lobby.waiting_avatar", {"player": player.name})
	var total := 0
	for key in Global.SPECIES:
		var wanted: int = settings.get(key, 0)
		var available: int = Global.deck.characters[Global.SPECIES[key].list].size()
		if wanted > available:
			return Msg.make("lobby.not_enough_characters", {"count": available,
				"species": Msg.species(Global.SPECIES[key].species)})
		total += wanted
	if total != players.size():
		return Msg.make("lobby.roles_mismatch", {"roles": total, "players": players.size()})
	return {}


# =============================================================================
# Messages: server -> clients (update GameState, then tell the UI)
# =============================================================================

@rpc("authority", "call_local", "reliable")
func sync_player(player: Dictionary) -> void:
	GameState.players[player.id] = player
	SignalBus.lobby_player_updated.emit(player)


@rpc("authority", "call_local", "reliable")
func remove_player(id: int) -> void:
	GameState.players.erase(id)
	SignalBus.lobby_player_removed.emit(id)


@rpc("authority", "call_local", "reliable")
func owner_changed(id: int) -> void:
	GameState.owner_id = id
	SignalBus.lobby_owner_changed.emit(id)


@rpc("authority", "call_local", "reliable")
func settings_changed(settings: Dictionary) -> void:
	GameState.game_settings = settings.duplicate()
	SignalBus.lobby_settings_changed.emit(settings)


@rpc("authority", "call_local", "reliable")
func avatar_rejected(pawn: String) -> void:
	SignalBus.avatar_rejected.emit(pawn)


@rpc("authority", "call_local", "reliable")
func start_refused(problem: Dictionary) -> void:
	SignalBus.lobby_start_refused.emit(problem)


@rpc("authority", "call_local", "reliable")
func start_game() -> void:
	GameState.phase = GameState.Phase.PLAYING
	SignalBus._start_game.emit("")
