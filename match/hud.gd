extends Panel
@onready var player_hud: PlayerHud = $PlayerHud
@onready var player_cards: Panel = $PlayerCards
@onready var player_help: Panel = $PlayerHelp

@onready var animation_player: AnimationPlayer = $AnimationPlayer

func _on_toggle_hud_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		animation_player.play("ToggleHud")
	else:
		animation_player.play_backwards("ToggleHud")


func _on_toggle_help_button_pressed() -> void:
	player_hud.hide()
	player_cards.hide()
	player_help.show()


func _on_toggle_cards_button_pressed() -> void:
	player_hud.hide()
	player_cards.show()
	player_help.hide()


func _on_toggle_info_button_pressed() -> void:
	player_hud.show()
	player_cards.hide()
	player_help.hide()


# --- Tab buttons: each as wide as its text (Greek ones are longer) ---------------

@onready var _tabs: Array = [$ToggleHudButton, $ToggleInfoButton, $ToggleCardsButton, $ToggleHelpButton]


func _ready() -> void:
	Global.language_changed.connect(func(_l = null): _layout_tabs.call_deferred())
	animation_player.animation_finished.connect(func(_a): _layout_tabs())
	$ToggleHudButton.toggled.connect(func(_on): _layout_tabs.call_deferred())
	_layout_tabs.call_deferred()


func _layout_tabs() -> void:
	var x: float = _tabs[0].position.x
	for tab: Button in _tabs:
		var y: float = tab.position.y
		tab.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
		tab.size = Vector2(maxf(96.0, tab.get_combined_minimum_size().x + 18.0), tab.size.y)
		tab.position = Vector2(x, y)
		x += tab.size.x + 6.0
