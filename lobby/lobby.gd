class_name Lobby extends Node2D
## Waiting room before a match. Pure view: it renders GameState.players and
## GameState.game_settings, re-renders on the lobby SignalBus events, and
## sends what the player does through LobbyNet. No network code here.

var lobby_code := ""

var question_mark_sprite : PackedScene = preload("res://lobby/question_mark_sprite.tscn")
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
	SignalBus._avatar_created.connect(LobbyNet.choose_avatar)
	SignalBus.lobby_player_updated.connect(_on_player_updated)
	SignalBus.lobby_player_removed.connect(_on_player_removed)
	SignalBus.lobby_start_refused.connect(func(problem): start_error_label.text = problem)
	start_error_label.text = ""
	# Players we already know about (messages can arrive before this screen).
	for player in GameState.players.values():
		_on_player_updated(player)


func lobby_init(code: String):
	lobby_code = code
	lobby_id.text = code

	# Only the host changes role counts and starts the match.
	if not multiplayer.is_server():
		for node in [start_game_button, vamp_dec, vamp_inc, were_dec, were_inc, humans_dec, humans_inc]:
			node.hide()


func _on_player_updated(player: Dictionary) -> void:
	if not q_marks.has(player.id):
		var new_q_mark = question_mark_sprite.instantiate()
		lobby_container.add_child(new_q_mark)
		new_q_mark.init(player)
		q_marks[player.id] = new_q_mark
	else:
		var q_mark = q_marks[player.id]
		q_mark.set_sprite_name(player.name)
		if player.pawn != "":
			q_mark.use_texture(player.pawn)
	_on_players_changed()


func _on_player_removed(id: int) -> void:
	if q_marks.has(id):
		q_marks[id].queue_free()
		q_marks.erase(id)
	_on_players_changed()


func _on_players_changed() -> void:
	players_in_lobby.text = str(GameState.players.size())
	SignalBus.pawns_changed.emit()


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
	# Show the problem right away; the server checks again either way.
	var problem := LobbyNet.start_problem(GameState.players, GameState.game_settings)
	start_error_label.text = problem
	if problem == "":
		LobbyNet.start_match()
