class_name GameSettings extends Panel
## How many players and which teams. Pure view: shows GameState.game_settings
## (the player count is the teams' total); the owner's buttons ask the server
## through LobbyNet, and everyone's labels update on
## SignalBus.lobby_settings_changed. Lobby shows the buttons to the owner only.

@onready var vampires_count: Label = $VBoxContainer/HBoxContainer/VampiresCount
@onready var humans_count: Label = $VBoxContainer/HBoxContainer3/HumansCount
@onready var werewolves_count: Label = $VBoxContainer/HBoxContainer2/WerewolvesCount
@onready var players_count: Label = $VBoxContainer/PlayersRow/PlayersCount
@onready var preset_label: Label = $VBoxContainer/PresetRow/PresetLabel

@onready var vamp_dec: Button = $VBoxContainer/HBoxContainer/VampDec
@onready var vamp_inc: Button = $VBoxContainer/HBoxContainer/VampInc
@onready var were_dec: Button = $VBoxContainer/HBoxContainer2/WereDec
@onready var were_inc: Button = $VBoxContainer/HBoxContainer2/WereInc
@onready var humans_dec: Button = $VBoxContainer/HBoxContainer3/HumansDec
@onready var humans_inc: Button = $VBoxContainer/HBoxContainer3/HumansInc
@onready var players_dec: Button = $VBoxContainer/PlayersRow/PlayersDec
@onready var players_inc: Button = $VBoxContainer/PlayersRow/PlayersInc
@onready var preset_dec: Button = $VBoxContainer/PresetRow/PresetDec
@onready var preset_inc: Button = $VBoxContainer/PresetRow/PresetInc

@onready var labels := {
	"vampires_count": vampires_count,
	"werewolves_count": werewolves_count,
	"humans_count": humans_count,
}


func _ready():
	SignalBus.lobby_settings_changed.connect(func(_settings): _refresh_labels())
	Global.language_changed.connect(_refresh_labels)
	_refresh_labels()


## The owner's buttons (Lobby shows/hides them).
func owner_buttons() -> Array:
	return [vamp_dec, vamp_inc, were_dec, were_inc, humans_dec, humans_inc,
		players_dec, players_inc, preset_dec, preset_inc]


func _refresh_labels(_lang = null) -> void:
	var settings: Dictionary = GameState.game_settings
	for key in labels:
		labels[key].text = str(settings.get(key, 0))
	var total := LobbyNet.team_total(settings)
	players_count.text = str(total)
	var presets: Array = Global.game_settings_default.presets.get(total, [])
	var index := LobbyNet.preset_index(settings)
	preset_label.text = Global.text("lobby.preset_custom") if index == -1 \
		else "%d/%d" % [index + 1, presets.size()]


func _on_vamp_dec_pressed() -> void:
	LobbyNet.change_setting("vampires_count", -1)

func _on_vamp_inc_pressed() -> void:
	LobbyNet.change_setting("vampires_count", 1)

func _on_were_dec_pressed() -> void:
	LobbyNet.change_setting("werewolves_count", -1)

func _on_were_inc_pressed() -> void:
	LobbyNet.change_setting("werewolves_count", 1)

func _on_humans_dec_pressed() -> void:
	LobbyNet.change_setting("humans_count", -1)

func _on_humans_inc_pressed() -> void:
	LobbyNet.change_setting("humans_count", 1)

func _on_players_dec_pressed() -> void:
	LobbyNet.change_player_count(-1)

func _on_players_inc_pressed() -> void:
	LobbyNet.change_player_count(1)

func _on_preset_dec_pressed() -> void:
	LobbyNet.change_preset(-1)

func _on_preset_inc_pressed() -> void:
	LobbyNet.change_preset(1)
