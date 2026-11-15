class_name GameSettings extends Panel
## How many of each species are in the match. Only the host can change it;
## the labels reach clients through the lobby's MultiplayerSynchronizer.

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
	load_default_composition()
	manage_settings_access()


func manage_settings_access():
	if not multiplayer.is_server():
		for button in [vamp_dec, vamp_inc, were_dec, were_inc, humans_dec, humans_inc]:
			button.disabled = true


func load_default_composition():
	var defaults: Dictionary = Global.game_settings_default["players"]
	var preset: Dictionary = defaults.get(GameState.players.size(), {})
	for key in labels:
		GameState.game_settings[key] = preset.get(key, 0)
	_refresh_labels()


## Why the match can't start yet, or "" if it can.
func get_problem() -> String:
	var player_count := GameState.players.size()
	if player_count < 2:
		return "Need at least 2 players."

	for player in GameState.players.values():
		if player.pawn == "":
			return "Waiting for %s to pick an avatar." % player.name

	var total := 0
	for key in Global.SPECIES:
		var wanted: int = GameState.game_settings[key]
		var list_name: String = Global.SPECIES[key].list
		var available: int = Global.deck.characters[list_name].size()
		if wanted > available:
			return "Only %d %s characters exist. Design more, or lower the count!" % [available, Global.SPECIES[key].species]
		total += wanted

	if total != player_count:
		return "Roles add up to %d, but there are %d players." % [total, player_count]
	return ""


func _change(key: String, delta: int) -> void:
	var list_name: String = Global.SPECIES[key].list
	var max_count: int = Global.deck.characters[list_name].size()
	GameState.game_settings[key] = clampi(GameState.game_settings[key] + delta, 0, max_count)
	_refresh_labels()


func _refresh_labels() -> void:
	for key in labels:
		labels[key].text = str(GameState.game_settings[key])


func _on_vamp_dec_pressed() -> void:
	_change("vampires_count", -1)

func _on_vamp_inc_pressed() -> void:
	_change("vampires_count", 1)

func _on_were_dec_pressed() -> void:
	_change("werewolves_count", -1)

func _on_were_inc_pressed() -> void:
	_change("werewolves_count", 1)

func _on_humans_dec_pressed() -> void:
	_change("humans_count", -1)

func _on_humans_inc_pressed() -> void:
	_change("humans_count", 1)
