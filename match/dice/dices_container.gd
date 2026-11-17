class_name DiceManager extends Panel
## The two dice by the campfire. Pure view: the server throws them (it
## decides the result) and MatchNet tells everyone via SignalBus.dice_rolled.
## Whenever you're the one to throw (moving, attacking, Old Map), the whole
## dice area is clickable and the dice bob to say "click me".

@onready var dice_6_sided: AnimatedSprite2D = $Dice6Sided
@onready var dice_4_sided: AnimatedSprite2D = $Dice4Sided
@onready var roll_button: Button = $RollButton

var _base := {}  # die -> {"scale", "position"}
var _pulse: Tween


func _ready() -> void:
	# The dice sit on the ground by the campfire: no grey panel behind them.
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	for die in [dice_6_sided, dice_4_sided]:
		_base[die] = {"scale": die.scale, "position": die.position}
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
	tooltip_text = Global.text("dice.roll") if can_roll else ""
	_set_pulsing(can_roll)


## The dice breathe (grow a little, glow) while they wait for your click.
func _set_pulsing(on: bool) -> void:
	if _pulse:
		_pulse.kill()
		_pulse = null
	for die in _base:
		die.scale = _base[die].scale
		die.modulate = Color.WHITE
	if not on:
		return
	_pulse = create_tween().set_loops().set_parallel(true).set_trans(Tween.TRANS_SINE)
	for die in _base:
		var s: Vector2 = _base[die].scale
		_pulse.tween_property(die, "scale", s * 1.12, 0.45)
		_pulse.tween_property(die, "modulate", Color(1.35, 1.25, 1.0), 0.45)
	_pulse.chain()
	for die in _base:
		_pulse.tween_property(die, "scale", _base[die].scale, 0.45)
		_pulse.tween_property(die, "modulate", Color.WHITE, 0.45)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_roll_button_pressed()


## Ask the server to roll; it ignores us if it's not our throw.
func _on_roll_button_pressed() -> void:
	if not roll_button.visible:
		return
	roll_button.hide()  # one throw per request
	MatchNet.roll()


## Play the roll animation landing on these values: the dice jump up,
## tumble, and bounce down onto the result.
func _on_dice_rolled(val6: int, val4: int) -> void:
	for die in _base:
		_toss(die)
	dice_6_sided.roll(val6)
	dice_4_sided.roll(val4)


func _toss(die: Node2D) -> void:
	var home: Vector2 = _base[die].position
	die.position = home
	var tween := create_tween()
	tween.tween_property(die, "position:y", home.y - 70.0, 0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(die, "position:y", home.y, 0.6) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
