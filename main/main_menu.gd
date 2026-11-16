class_name MainMenu extends Control


func _ready() -> void:
	# Original art (old board, chapels, pawns, portraits, card backs) or the
	# current art. Saved on this computer; applies to the next match.
	var classic := CheckButton.new()
	classic.name = "ClassicArtToggle"
	var texts := func():
		classic.text = Global.text("menu.classic_art")
		classic.tooltip_text = Global.text("menu.classic_art_tooltip")
	texts.call()
	Global.language_changed.connect(texts)
	classic.add_theme_font_size_override("font_size", 22)
	classic.button_pressed = Global.classic_art
	classic.toggled.connect(func(on: bool): Global.classic_art = on)
	$VBoxContainer.add_child(classic)


func _on_quit_button_pressed() -> void:
	SignalBus._exit_game.emit()


func _on_play_button_pressed() -> void:
	SignalBus._new_game.emit()
	#self.hide()
