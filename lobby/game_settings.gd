class_name GameSettings extends Panel
## How many of each species are in the match. Pure view: shows
## GameState.game_settings; the host's +/- buttons ask the server through
## LobbyNet, and everyone's labels update on SignalBus.lobby_settings_changed.

@onready var vampires_count: Label = $VBoxContainer/HBoxContainer/VampiresCount
@onready var humans_count: Label = $VBoxContainer/HBoxContainer3/HumansCount
@onready var werewolves_count: Label = $VBoxContainer/HBoxContainer2/WerewolvesCount

@onready var vamp_dec: Button = $VBoxContainer/HBoxContainer/VampDec
@onready var vamp_inc: Button = $VBoxContainer/HBoxContainer/VampInc
@onready var were_dec: Button = $VBoxContainer/HBoxContainer2/WereDec
@onready var were_inc: Button = $VBoxContainer/HBoxContainer2/WereInc
@onready var humans_dec: Button = $VBoxContainer/HBoxContainer3/HumansDec
@onready var humans_inc: Button = $VBoxContainer/HBoxContainer3/HumansInc

@onready var labels := {
	"vampires_count": vampires_count,
	"werewolves_count": werewolves_count,
	"humans_count": humans_count,
}


func _ready():
	SignalBus.lobby_settings_changed.connect(func(_settings): _refresh_labels())
	if not multiplayer.is_server():
		for button in [vamp_dec, vamp_inc, were_dec, were_inc, humans_dec, humans_inc]:
			button.disabled = true
	_refresh_labels()


func _refresh_labels() -> void:
	for key in labels:
		labels[key].text = str(GameState.game_settings.get(key, 0))


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
