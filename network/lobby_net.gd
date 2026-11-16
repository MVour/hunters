extends Node
## LobbyNet autoload: the ONLY place the lobby talks over the network. Same
## pattern as MatchNet (read that file's header):
##   UI -> action (join, choose_avatar, change_setting, start_match)
##      -> request on the server (checks who's asking)
##      -> message to everyone -> GameState + SignalBus -> UI.
##
## The server's own truth (who's in, which pawn, the role counts) lives here
## in _players/_settings, separate from GameState (the store every computer,
## the host included, renders from).

const MAX_PLAYERS := 8

# --- Server only ---------------------------------------------------------------
var _players := {}
var _settings := {}
## The lobby's owner (first to join): only they change settings and start.
var _owner_id := 0
var _in_match := false


func _ready() -> void:
	Network.peer_left.connect(_on_peer_left)
	Network.session_closed.connect(_reset)
	Network.host_disconnected.connect(_reset)


func _reset() -> void:
	_players = {}
	_settings = {}
	_owner_id = 0
	_in_match = false


# =============================================================================
# Actions: call these from the UI
# =============================================================================

func join() -> void: request_join.rpc_id(1)
func choose_avatar(player_name: String, pawn: String) -> void: request_avatar.rpc_id(1, player_name, pawn)
func change_setting(key: String, delta: int) -> void: request_setting.rpc_id(1, key, delta)
func start_match() -> void: request_start.rpc_id(1)


# =============================================================================
# Requests: client -> server
# =============================================================================

@rpc("any_peer", "call_local", "reliable")
func request_join() -> void:
	if not multiplayer.is_server():
		return
	var id := Network.sender_id()
	if _players.has(id):
		return
	if _in_match or _players.size() >= MAX_PLAYERS:
		multiplayer.multiplayer_peer.disconnect_peer(id)
		return
	if _owner_id == 0:
		_owner_id = id

	var player := GameState.new_player(id)
	player.name = "Player_%d" % (_players.size() + 1)
	_players[id] = player
	# Tell the newcomer who's already here, then tell everyone about them.
	for other_id in _players:
		if other_id != id:
			sync_player.rpc_id(id, _players[other_id])
	sync_player.rpc(player)
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
	if player_name != "":
		player.name = player_name
	player.pawn = pawn
	sync_player.rpc(player)


@rpc("any_peer", "call_local", "reliable")
func request_setting(key: String, delta: int) -> void:
	if not multiplayer.is_server() or Network.sender_id() != _owner_id or _in_match:
		return
	if not Global.SPECIES.has(key):
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
	if problem != "":
		start_refused.rpc_id(sender, problem)
		return
	_in_match = true
	MatchNet.create_server(_players, _settings)
	start_game.rpc()


func _on_peer_left(id: int) -> void:
	if not multiplayer.is_server() or not _players.has(id):
		return
	if _in_match:
		# BUG-001: a player dropping out mid-match isn't handled yet.
		push_warning("Player %d left during the match." % id)
		return
	_players.erase(id)
	if id == _owner_id:
		_owner_id = _players.keys().front() if not _players.is_empty() else 0
	remove_player.rpc(id)
	_reset_settings()


## Role counts go back to the preset for this many players.
func _reset_settings() -> void:
	var preset: Dictionary = Global.game_settings_default.players.get(_players.size(), {})
	_settings = {}
	for key in Global.SPECIES:
		_settings[key] = preset.get(key, 0)
	settings_changed.rpc(_settings)


func _pawn_taken(pawn: String, except_id: int) -> bool:
	for player in _players.values():
		if player.id != except_id and player.pawn == pawn:
			return true
	return false


## Why a match with these players and role counts can't start, or "".
## The lobby screen shows it too; the server always re-checks.
static func start_problem(players: Dictionary, settings: Dictionary) -> String:
	if players.size() < 2:
		return "Need at least 2 players."
	for player in players.values():
		if player.pawn == "":
			return "Waiting for %s to pick an avatar." % player.name
	var total := 0
	for key in Global.SPECIES:
		var wanted: int = settings.get(key, 0)
		var available: int = Global.deck.characters[Global.SPECIES[key].list].size()
		if wanted > available:
			return "Only %d %s characters exist. Design more, or lower the count!" % [available, Global.SPECIES[key].species]
		total += wanted
	if total != players.size():
		return "Roles add up to %d, but there are %d players." % [total, players.size()]
	return ""


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
func settings_changed(settings: Dictionary) -> void:
	GameState.game_settings = settings.duplicate()
	SignalBus.lobby_settings_changed.emit(settings)


@rpc("authority", "call_local", "reliable")
func avatar_rejected(pawn: String) -> void:
	SignalBus.avatar_rejected.emit(pawn)


@rpc("authority", "call_local", "reliable")
func start_refused(problem: String) -> void:
	SignalBus.lobby_start_refused.emit(problem)


@rpc("authority", "call_local", "reliable")
func start_game() -> void:
	GameState.phase = GameState.Phase.PLAYING
	SignalBus._start_game.emit("")
