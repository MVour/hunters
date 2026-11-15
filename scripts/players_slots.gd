class_name PlayersSlots extends Node2D
## Seats players around the table. Every computer sees itself in Slot1
## (bottom), with the others following in turn order.

@onready var player_slot_info_scn = preload("res://scenes/player_slot_info.tscn")

var active_chairs : Array


@rpc("authority", "call_local", "reliable")
func sit_players(decided_turn: Array):
	GameState.game_info.players_turn = decided_turn
	decide_chairs()
	assign_chairs()


## Picks the preconfigured set of chairs for this many players.
func decide_chairs():
	active_chairs = []
	var players_num := GameState.players.size()
	var chairs_set: Array = Global.game_settings_default.chairs_config.get(players_num, [])
	for chair in chairs_set:
		# "slot3" -> node "Slot3"
		active_chairs.append({"slot": get_node("S" + chair.substr(1))})


func assign_chairs():
	# Rotate so this computer's player comes first. Only local: the real
	# turn order is untouched.
	var local_turn := rotate_to_element(GameState.game_info.players_turn, GameState.local_id)

	for i in min(local_turn.size(), active_chairs.size()):
		var player_info = player_slot_info_scn.instantiate()
		add_child(player_info)
		player_info.position = active_chairs[i].slot.position
		player_info.sit(GameState.players[local_turn[i]])
		active_chairs[i]["scene"] = player_info


# Utility function
func rotate_to_element(arr : Array, target) -> Array:
	var index = arr.find(target)
	if index == -1:
		return arr
	return arr.slice(index) + arr.slice(0, index)
