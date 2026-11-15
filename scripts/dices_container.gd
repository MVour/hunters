class_name DiceManager extends Panel

@onready var dice_6_sided: AnimatedSprite2D = $Dice6Sided
@onready var dice_4_sided: AnimatedSprite2D = $Dice4Sided
@onready var game_manager: GameManager = $"../GameManager"


## Ask the server to roll; it ignores us if it's not our turn.
func _on_roll_button_pressed() -> void:
	game_manager.request_roll.rpc_id(1)


## Server -> everyone: play the roll animation landing on these values.
@rpc("authority", "call_local", "reliable")
func roll_dices(val6: int, val4: int):
	dice_6_sided.roll(val6)
	dice_4_sided.roll(val4)


## Server only: decide the result.
func throw_dices() -> Dictionary:
	return {"val6": dice_6_sided.throw(), "val4": dice_4_sided.throw()}
