class_name DiceManager extends Panel
## The two dice by the campfire. Pure view: the server throws them (it
## decides the result) and MatchNet tells everyone via SignalBus.dice_rolled.
## On your turn the whole dice area is clickable, not just the Roll button.

@onready var dice_6_sided: AnimatedSprite2D = $Dice6Sided
@onready var dice_4_sided: AnimatedSprite2D = $Dice4Sided
@onready var roll_button: Button = $RollButton


func _ready() -> void:
	# The dice sit on the ground by the campfire: no grey panel behind them.
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	SignalBus.dice_rolled.connect(_on_dice_rolled)
	roll_button.visibility_changed.connect(_update_click_area)
	gui_input.connect(_on_gui_input)
	_update_click_area()


## Clickable only while you can roll; otherwise clicks go to the locations
## behind the (invisible) panel, e.g. picking one after a 7.
func _update_click_area() -> void:
	var can_roll := roll_button.visible
	mouse_filter = Control.MOUSE_FILTER_STOP if can_roll else Control.MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if can_roll else Control.CURSOR_ARROW
	tooltip_text = "Roll  ·  Ρίξε" if can_roll else ""


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_roll_button_pressed()


## Ask the server to roll; it ignores us if it's not our turn.
func _on_roll_button_pressed() -> void:
	if not roll_button.visible:
		return
	roll_button.hide()  # one roll per turn
	MatchNet.roll()


## Play the roll animation landing on these values.
func _on_dice_rolled(val6: int, val4: int) -> void:
	dice_6_sided.roll(val6)
	dice_4_sided.roll(val4)
