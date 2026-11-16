class_name SelectPlayerIconButton extends Button


var color = ""
#var


func _ready() -> void:
	# The menu's "Classic art" switch swaps pawn art; follow it.
	Global.art_style_changed.connect(_on_art_style_changed)


func _on_art_style_changed(_classic: bool) -> void:
	if color != "":
		use_texture()


func use_texture():
	self.icon = Global.pawns[color].sprite
