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
## Bot seats get ids from here up. Real peer ids are random in 2..2^31-1, so
## a clash is practically impossible (and checked). Never rpc_id a bot id:
## MatchServer.tell() routes a bot's messages to its BotSeat instead.
const BOT_ID_BASE := 2_100_000_000
## Bot names (a translated "(bot)" tag is shown next to them).
const BOT_NAMES := ["Ash", "Fern", "Moss", "Rowan", "Hazel", "Thorn", "Willow", "Birch", "Bramble", "Sorrel"]

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
## Owner: how many players the match is for (applies that count's default teams).
func change_player_count(delta: int) -> void: request_player_count.rpc_id(1, delta)
## Owner: the next/previous team preset for this player count.
func change_preset(delta: int) -> void: request_preset.rpc_id(1, delta)
## Owner: add bots until there are as many players as the teams need.
func fill_with_bots() -> void: request_fill_bots.rpc_id(1)
## Owner: bots easier / harder (settings.bot_level, BotWeights.EASY..HARD).
func change_bot_level(delta: int) -> void: request_bot_level.rpc_id(1, delta)
## After a match: back to this table's lobby ("Play again").
func back_to_lobby() -> void: request_lobby.rpc_id(1)


## Server: the match is over (someone won, or only bots were left). The table
## is a lobby again (BUG-009): people who left during the match are removed,
## new players may join, and the owner can start again. Players still on the
## end screen come back with back_to_lobby() or leave.
## The removals aren't sent now (clients are still showing the match); a
## client gets the whole lobby with lobby_state / start_game.
func match_over() -> void:
	if not multiplayer.is_server() or not _in_match:
		return
	_in_match = false
	var connected := multiplayer.get_peers()
	for id in _players.keys():
		var gone: bool = MatchNet.server != null and MatchNet.server.is_gone(id)
		if not is_bot(_players[id]) and id != multiplayer.get_unique_id() and (gone or not id in connected):
			_players.erase(id)
	if _human_count() == 0:
		for bot_id in _bot_ids():
			_players.erase(bot_id)
	# Lobby entries keep only lobby info: nothing from the last match (damage,
	# deaths, characters) may carry into the next one, or reach anyone.
	for id in _players:
		_players[id] = _lobby_entry(_players[id])
	_pass_owner_if_gone()


static func _lobby_entry(player: Dictionary) -> Dictionary:
	var clean := GameState.new_player(player.id)
	clean.name = player.name
	clean.pawn = player.pawn
	if is_bot(player):
		clean.bot = true
	return clean


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
	if _in_match or (_players.size() >= max_players and _bot_ids().is_empty()):
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

	# A full room makes way for a person: one bot leaves.
	if _players.size() >= max_players:
		_remove_player(_bot_ids().back())
	var player := GameState.new_player(id)
	player.name = identity.get("name", "Player_%d" % (_human_count() + 1))
	_players[id] = player
	_rename_bot_named(player.name)
	if identity.get("owner", false) or _owner_id == 0:
		_owner_id = id
	# Tell the newcomer who's already here, then tell everyone about them.
	for other_id in _players:
		if other_id != id:
			sync_player.rpc_id(id, _players[other_id])
	sync_player.rpc(player)
	owner_changed.rpc(_owner_id)
	ChatNet.send_history(id)
	_fit_settings()


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
	var wanted := clampi(_settings.get(key, 0) + delta, 0, max_count)
	if team_total(_settings) - _settings.get(key, 0) + wanted > max_players:
		return
	_settings[key] = wanted
	settings_changed.rpc(_settings)


@rpc("any_peer", "call_local", "reliable")
func request_player_count(delta: int) -> void:
	if not multiplayer.is_server() or Network.sender_id() != _owner_id or _in_match:
		return
	var count := clampi(team_total(_settings) + signi(delta), maxi(2, _human_count()), max_players)
	_apply_preset(count, 0)


@rpc("any_peer", "call_local", "reliable")
func request_preset(delta: int) -> void:
	if not multiplayer.is_server() or Network.sender_id() != _owner_id or _in_match:
		return
	var count := team_total(_settings)
	var presets: Array = Global.game_settings_default.presets.get(count, [])
	if presets.is_empty():
		return
	var index := preset_index(_settings)  # -1 = hand-tuned: step onto the first
	_apply_preset(count, posmod(index + signi(delta), presets.size()) if index != -1 else 0)


@rpc("any_peer", "call_local", "reliable")
func request_bot_level(delta: int) -> void:
	if not multiplayer.is_server() or Network.sender_id() != _owner_id or _in_match:
		return
	var level := int(_settings.get("bot_level", BotWeights.DEFAULT_LEVEL))
	_settings["bot_level"] = clampi(level + signi(delta), BotWeights.EASY, BotWeights.HARD)
	settings_changed.rpc(_settings)


## Bots fill the seats the teams still need (people first: bots that are
## too many for the teams leave).
@rpc("any_peer", "call_local", "reliable")
func request_fill_bots() -> void:
	if not multiplayer.is_server() or Network.sender_id() != _owner_id or _in_match:
		return
	var wanted := mini(team_total(_settings), max_players)
	while _players.size() > wanted and not _bot_ids().is_empty():
		_remove_player(_bot_ids().back())
	while _players.size() < wanted:
		if not _add_bot():
			break


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
	start_game.rpc(_players.values())


## The owner removes someone from the lobby (not during a match, not themselves).
@rpc("any_peer", "call_local", "reliable")
func request_kick(player_id: int) -> void:
	if not multiplayer.is_server() or Network.sender_id() != _owner_id or _in_match:
		return
	if player_id == _owner_id or not _players.has(player_id):
		return
	if player_id == multiplayer.get_unique_id():
		return  # the host of a direct game can't kick itself off its own server
	var bot := is_bot(_players[player_id])
	_remove_player(player_id)
	if not bot:
		_refuse(player_id)


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
	_remove_player(id)
	if _human_count() == 0:  # nobody left to play with the bots
		for bot_id in _bot_ids():
			_remove_player(bot_id)
	_pass_owner_if_gone()


## The owner left: the next person in the room is the owner.
func _pass_owner_if_gone() -> void:
	if _owner_id != 0 and _players.has(_owner_id):
		return
	var humans := _players.keys().filter(func(pid): return not is_bot(_players[pid]))
	_owner_id = humans.front() if not humans.is_empty() else 0
	owner_changed.rpc(_owner_id)


## A player on the end screen pressed "Play again": send them the lobby.
@rpc("any_peer", "call_local", "reliable")
func request_lobby() -> void:
	if not multiplayer.is_server():
		return
	var sender := Network.sender_id()
	if _in_match or not _players.has(sender):
		return  # a new match already started (they're in it) or they're out
	lobby_state.rpc_id(sender, _players.values(), _settings, _owner_id)


func _remove_player(id: int) -> void:
	_players.erase(id)
	remove_player.rpc(id)
	_fit_settings()


## The teams keep their size while people come and go; they only grow when
## more players are in the room than the teams have places for.
func _fit_settings() -> void:
	if _settings.is_empty():
		_apply_preset(clampi(_players.size(), 2, max_players), 0)
	elif _players.size() > team_total(_settings):
		_apply_preset(_players.size(), 0)


func _apply_preset(count: int, index: int) -> void:
	var presets: Array = Global.game_settings_default.presets.get(count, [[0, 0, 0]])
	var counts: Array = presets[clampi(index, 0, presets.size() - 1)]
	var bot_level = _settings.get("bot_level", BotWeights.DEFAULT_LEVEL)
	_settings = {"bot_level": bot_level}
	var i := 0
	for key in Global.SPECIES:
		_settings[key] = counts[i]
		i += 1
	settings_changed.rpc(_settings)


## A bot takes the next free seat, name and pawn. False if there's no room.
func _add_bot() -> bool:
	if _players.size() >= max_players:
		return false
	var pawn := ""
	for p in Global.pawns:
		if not _pawn_taken(p, 0):
			pawn = p
			break
	var bot_name := ""
	for n in BOT_NAMES:
		if not _name_taken(n, true):
			bot_name = n
			break
	if pawn == "" or bot_name == "":
		return false
	var id := BOT_ID_BASE + 1
	while _players.has(id):
		id += 1
	var bot := GameState.new_player(id)
	bot.name = bot_name
	bot.pawn = pawn
	bot.bot = true
	_players[id] = bot
	sync_player.rpc(bot)
	return true


## A person joined with a bot's name: the bot takes another one.
func _rename_bot_named(player_name: String) -> void:
	for id in _bot_ids():
		if _players[id].name.to_lower() != player_name.to_lower():
			continue
		for n in BOT_NAMES:
			if not _name_taken(n, true):
				_players[id].name = n
				sync_player.rpc(_players[id])
				return


func _bot_ids() -> Array:
	return _players.keys().filter(func(id): return is_bot(_players[id]))


func _human_count() -> int:
	return _players.size() - _bot_ids().size()


## A player dict (lobby, GameState or ServerState) that's a bot seat.
static func is_bot(player: Dictionary) -> bool:
	return player.get("bot", false)


## How many players the chosen teams are for.
static func team_total(settings: Dictionary) -> int:
	var total := 0
	for key in Global.SPECIES:
		total += int(settings.get(key, 0))
	return total


## Which preset of this player count the teams match (-1 = hand-tuned).
static func preset_index(settings: Dictionary) -> int:
	var presets: Array = Global.game_settings_default.presets.get(team_total(settings), [])
	for i in presets.size():
		var j := 0
		var same := true
		for key in Global.SPECIES:
			same = same and int(settings.get(key, 0)) == presets[i][j]
			j += 1
		if same:
			return i
	return -1


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


## Bots give up their name to a person (see _rename_bot_named), so they only
## count when `count_bots` (picking a bot's own name).
func _name_taken(player_name: String, count_bots := false) -> bool:
	for player in _players.values():
		if (count_bots or not is_bot(player)) and player.name.to_lower() == player_name.to_lower():
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
	if GameState.phase != GameState.Phase.LOBBY:
		return  # still on the end screen: lobby_state brings everyone later
	# A copy: on the host, this dict is the server's own lobby entry (call_local),
	# and the match writes damage, deaths and characters into GameState.
	GameState.players[player.id] = player.duplicate(true)
	SignalBus.lobby_player_updated.emit(player)


@rpc("authority", "call_local", "reliable")
func remove_player(id: int) -> void:
	if GameState.phase != GameState.Phase.LOBBY:
		return
	GameState.players.erase(id)
	SignalBus.lobby_player_removed.emit(id)


## Back from a finished match: the whole lobby as it is now.
@rpc("authority", "call_local", "reliable")
func lobby_state(players: Array, settings: Dictionary, owner: int) -> void:
	GameState.phase = GameState.Phase.LOBBY
	_reset_match_info()
	var now := {}
	for player in players:
		now[player.id] = player
	for id in GameState.players.keys():
		if not now.has(id):
			GameState.players.erase(id)
			SignalBus.lobby_player_removed.emit(id)
	for player in players:
		sync_player(player)
	settings_changed(settings)
	owner_changed(owner)


func _reset_match_info() -> void:
	GameState.game_info = {"players_turn": [], "round": 0, "waiting_for": [], "step": ""}
	GameState.locations = []


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
func start_game(players: Array) -> void:
	# Fresh player info: a second match on the same table starts clean, even
	# for someone who went straight from the last end screen.
	GameState.players = {}
	for player in players:
		GameState.players[player.id] = player.duplicate(true)  # see sync_player
	_reset_match_info()
	GameState.phase = GameState.Phase.PLAYING
	SignalBus._start_game.emit("")
