class_name Lobby extends Node2D
## Waiting room before a match.
##
## The server owns the player list: clients ask to join or to change their
## avatar (request_* RPCs), the server checks the request and then tells
## everyone the result (sync_player).

const MAX_PLAYERS := 8

var lobby_code := ""

var question_mark_sprite : PackedScene = preload("res://scenes/question_mark_sprite.tscn")
@onready var lobby_container: GridContainer = $LobbyPanel/LobbyContainer
@onready var lobby_id: LineEdit = $GridContainer/LobbyId
@onready var start_game_button: Button = $StartGameButton
@onready var start_error_label: Label = $StartErrorLabel
@onready var copy_code_button: Button = $CopyCodeButton
@onready var players_in_lobby: Label = $GridContainer/PlayersInLobby
@onready var game_settings: GameSettings = $GameSettings
@onready var create_player: CreatePlayer = $CreatePlayer

@onready var vamp_dec: Button = $GameSettings/VBoxContainer/HBoxContainer/VampDec
@onready var vamp_inc: Button = $GameSettings/VBoxContainer/HBoxContainer/VampInc
@onready var were_dec: Button = $GameSettings/VBoxContainer/HBoxContainer2/WereDec
@onready var were_inc: Button = $GameSettings/VBoxContainer/HBoxContainer2/WereInc
@onready var humans_dec: Button = $GameSettings/VBoxContainer/HBoxContainer3/HumansDec
@onready var humans_inc: Button = $GameSettings/VBoxContainer/HBoxContainer3/HumansInc

## Avatar tile per player id.
var q_marks := {}


func _ready():
	SignalBus._avatar_created.connect(_on_avatar_created)
	Network.peer_left.connect(_on_peer_left)
	start_error_label.text = ""


func lobby_init(code: String):
	lobby_code = code
	lobby_id.text = code

	if not multiplayer.is_server():
		for node in [start_game_button, vamp_dec, vamp_inc, were_dec, were_inc, humans_dec, humans_inc]:
			node.hide()


# --- Joining / leaving -------------------------------------------------------

## The host calls this for itself; clients call it once connected.
@rpc("any_peer", "call_local", "reliable")
func request_join() -> void:
	if not multiplayer.is_server():
		return
	var id := Network.sender_id()
	if GameState.players.has(id):
		return
	if GameState.phase != GameState.Phase.LOBBY or GameState.players.size() >= MAX_PLAYERS:
		multiplayer.multiplayer_peer.disconnect_peer(id)
		return

	var player := GameState.new_player(id)
	player.name = "Player_%d" % (GameState.players.size() + 1)
	GameState.players[id] = player

	# Tell the newcomer who's already here, then tell everyone about them.
	for other_id in GameState.players:
		if other_id != id:
			sync_player.rpc_id(id, GameState.players[other_id])
	sync_player.rpc(player)


## Server -> everyone: this is a player's current public info.
@rpc("authority", "call_local", "reliable")
func sync_player(player: Dictionary) -> void:
	GameState.players[player.id] = player
	_show_player(player)
	_on_players_changed()


@rpc("authority", "call_local", "reliable")
func remove_player(id: int) -> void:
	GameState.players.erase(id)
	if q_marks.has(id):
		q_marks[id].queue_free()
		q_marks.erase(id)
	_on_players_changed()


func _on_peer_left(id: int) -> void:
	if not multiplayer.is_server() or not GameState.players.has(id):
		return
	if GameState.phase == GameState.Phase.LOBBY:
		remove_player.rpc(id)
	else:
		# TODO: handle a player dropping out mid-match.
		push_warning("Player %d left during the match." % id)


func _on_players_changed() -> void:
	players_in_lobby.text = str(GameState.players.size())
	game_settings.load_default_composition()
	SignalBus.pawns_changed.emit()


func _show_player(player: Dictionary) -> void:
	if not q_marks.has(player.id):
		var new_q_mark = question_mark_sprite.instantiate()
		# Same name on every computer, so its MultiplayerSynchronizer path matches.
		new_q_mark.name = "Player%d" % player.id
		lobby_container.add_child(new_q_mark)
		new_q_mark.init(player)
		q_marks[player.id] = new_q_mark
		return
	var q_mark = q_marks[player.id]
	q_mark.set_sprite_name(player.name)
	if player.pawn != "":
		q_mark.use_texture(player.pawn)


# --- Avatars -----------------------------------------------------------------

func _on_avatar_created(pl_name: String, pawn: String) -> void:
	request_avatar.rpc_id(1, pl_name, pawn)


@rpc("any_peer", "call_local", "reliable")
func request_avatar(pl_name: String, pawn: String) -> void:
	if not multiplayer.is_server():
		return
	var id := Network.sender_id()
	if not GameState.players.has(id) or GameState.phase != GameState.Phase.LOBBY:
		return
	if not Global.pawns.has(pawn) or GameState.is_pawn_taken(pawn, id):
		avatar_rejected.rpc_id(id, pawn)
		return

	var player: Dictionary = GameState.players[id]
	pl_name = pl_name.strip_edges().left(16)
	if pl_name != "":
		player.name = pl_name
	player.pawn = pawn
	sync_player.rpc(player)


@rpc("authority", "call_local", "reliable")
func avatar_rejected(pawn: String) -> void:
	create_player.on_avatar_rejected(pawn)


# --- Buttons -----------------------------------------------------------------

func _on_button_pressed() -> void:
	SignalBus._return_to_multiplayer_menu.emit()


func _on_copy_code_pressed() -> void:
	DisplayServer.clipboard_set(lobby_code)
	copy_code_button.text = "Copied!"
	await get_tree().create_timer(1.5).timeout
	if is_instance_valid(copy_code_button):
		copy_code_button.text = "Copy"


func _on_start_game_pressed() -> void:
	var problem := game_settings.get_problem()
	start_error_label.text = problem
	if problem == "":
		start_game.rpc()


@rpc("authority", "call_local", "reliable")
func start_game():
	GameState.phase = GameState.Phase.PLAYING
	SignalBus._start_game.emit(lobby_code)
