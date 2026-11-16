class_name DiceManager extends Panel
## The two dice by the campfire. Pure view: the server throws them (it
## decides the result) and MatchNet tells everyone via SignalBus.dice_rolled.

@onready var dice_6_sided: AnimatedSprite2D = $Dice6Sided
@onready var dice_4_sided: AnimatedSprite2D = $Dice4Sided


func _ready() -> void:
	# The dice sit on the ground by the campfire: no grey panel behind them.
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	# Don't block clicks on locations behind the (invisible) panel.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	SignalBus.dice_rolled.connect(_on_dice_rolled)


## Ask the server to roll; it ignores us if it's not our turn.
func _on_roll_button_pressed() -> void:
	$RollButton.hide()  # one roll per turn
	MatchNet.roll()


## Play the roll animation landing on these values.
func _on_dice_rolled(val6: int, val4: int) -> void:
	dice_6_sided.roll(val6)
	dice_4_sided.roll(val4)
