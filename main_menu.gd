class_name MainMenu extends Control


func _ready() -> void:
	# Original art (old board, chapels, pawns, portraits, card backs) or the
	# current art. Saved on this computer; applies to the next match.
	var classic := CheckButton.new()
	classic.name = "ClassicArtToggle"
	classic.text = "Classic art"
	classic.tooltip_text = "Use the original board, chapels, pawns, animated portraits and card backs."
	classic.add_theme_font_size_override("font_size", 22)
	classic.button_pressed = Global.classic_art
	classic.toggled.connect(func(on: bool): Global.classic_art = on)
	$VBoxContainer.add_child(classic)


func _on_quit_button_pressed() -> void:
	SignalBus._exit_game.emit()


func _on_add_player_pressed() -> void:
	SignalBus._add_player.emit()


func _on_play_button_pressed() -> void:
	SignalBus._new_game.emit()
	#self.hide()
