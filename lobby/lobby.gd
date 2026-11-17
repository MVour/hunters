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

@onready var fill_bots_button: Button = $FillBotsButton

## Avatar tile per player id.
var q_marks := {}
## The owner's "remove from the room" button on each tile.
var kick_buttons := {}


func _ready():
	SignalBus._avatar_created.connect(LobbyNet.choose_avatar)
	SignalBus.lobby_player_updated.connect(_on_player_updated)
	SignalBus.lobby_player_removed.connect(_on_player_removed)
	SignalBus.lobby_start_refused.connect(func(problem): start_error_label.text = Global.msg(problem))
	SignalBus.lobby_owner_changed.connect(_apply_owner)
	start_error_label.text = ""
	# Players we already know about (messages can arrive before this screen).
	for player in GameState.players.values():
		_on_player_updated(player)


func lobby_init(code: String):
	lobby_code = code
	lobby_id.text = code

	_apply_owner()


## Only the owner changes the teams, adds bots, starts the match and kicks players.
func _apply_owner(_id := 0) -> void:
	var mine := GameState.owner_id == GameState.local_id and GameState.local_id != 0
	for node in [start_game_button, fill_bots_button] + game_settings.owner_buttons():
		node.visible = mine
	for id in kick_buttons:
		kick_buttons[id].visible = mine and id != GameState.local_id


func _on_player_updated(player: Dictionary) -> void:
	if not q_marks.has(player.id):
		var new_q_mark = question_mark_sprite.instantiate()
		lobby_container.add_child(new_q_mark)
		new_q_mark.init(player)
		q_marks[player.id] = new_q_mark
		# The tile is a VBox: anything added to it squeezes the pawn, so the bot
		# tag and the ✕ sit on top of its panel instead.
		var tile_panel: Control = new_q_mark.get_node("Panel")
		if LobbyNet.is_bot(player):
			var tag := Label.new()
			tag.text = Global.text("lobby.bot_tag")
			tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			tag.add_theme_font_size_override("font_size", 14)
			tag.add_theme_color_override("font_color", Color("e8c060"))
			tag.add_theme_color_override("font_outline_color", Color.BLACK)
			tag.add_theme_constant_override("outline_size", 4)
			tile_panel.add_child(tag)
			tag.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
			tag.offset_top = -20
		var kick := Button.new()
		kick.text = "✕"
		kick.tooltip_text = Global.text("lobby.kick")
		kick.custom_minimum_size = Vector2(28, 28)
		kick.size = Vector2(28, 28)
		kick.position = Vector2(-6, -6)
		kick.z_index = 2
		var id: int = player.id
		kick.pressed.connect(func(): LobbyNet.kick(id))
		tile_panel.add_child(kick)
		kick_buttons[id] = kick
		_apply_owner()
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
		kick_buttons.erase(id)
	_on_players_changed()


func _on_players_changed() -> void:
	players_in_lobby.text = str(GameState.players.size())
	SignalBus.pawns_changed.emit()


func _on_fill_bots_pressed() -> void:
	LobbyNet.fill_with_bots()


# --- Buttons -----------------------------------------------------------------

func _on_button_pressed() -> void:
	SignalBus._return_to_multiplayer_menu.emit()


func _on_copy_code_pressed() -> void:
	DisplayServer.clipboard_set(lobby_code)
	copy_code_button.text = Global.text("lobby.copied")
	await get_tree().create_timer(1.5).timeout
	if is_instance_valid(copy_code_button):
		copy_code_button.text = "Copy"


func _on_start_game_pressed() -> void:
	# Show the problem right away; the server checks again either way.
	var problem := LobbyNet.start_problem(GameState.players, GameState.game_settings)
	start_error_label.text = Global.msg(problem)
	if problem.is_empty():
		LobbyNet.start_match()
