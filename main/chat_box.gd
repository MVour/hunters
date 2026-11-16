class_name ChatBox extends PanelContainer
## Small chat in the bottom-left, above the language button. Shown while
## you're in a session (lobby or match). Pure view over ChatNet.

const BOX := Vector2(345, 200)

var _log: RichTextLabel
var _input: LineEdit


func _ready() -> void:
	custom_minimum_size = BOX
	size = BOX
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.04, 0.06, 0.82)
	style.border_color = Color(1, 1, 1, 0.1)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(6)
	add_theme_stylebox_override("panel", style)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	add_child(column)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.add_theme_font_size_override("normal_font_size", 14)
	_log.add_theme_font_size_override("bold_font_size", 14)
	column.add_child(_log)
	_input = LineEdit.new()
	_input.max_length = ChatNet.MAX_LENGTH
	_input.add_theme_font_size_override("font_size", 14)
	_input.text_submitted.connect(_on_submit)
	column.add_child(_input)

	SignalBus.chat_message.connect(_on_message)
	Global.language_changed.connect(_apply_language)
	_apply_language()


func _process(_delta: float) -> void:
	var online := Network.is_online()
	if visible != online:
		visible = online
		if online:
			_rebuild()


func _apply_language() -> void:
	_input.placeholder_text = Global.text("chat.placeholder")


func _on_submit(text: String) -> void:
	ChatNet.say(text)
	_input.clear()


func _rebuild() -> void:
	_log.clear()
	for m in ChatNet.messages:
		_append(m.from, m.name, m.text)


func _on_message(player_id: int, player_name: String, text: String) -> void:
	_append(player_id, player_name, text)


func _append(player_id: int, player_name: String, text: String) -> void:
	var pawn: String = GameState.players.get(player_id, {}).get("pawn", "")
	var colour: String = Global.pawns[pawn].hex if Global.pawns.has(pawn) else "dddddd"
	_log.append_text("[b][color=#%s]%s:[/color][/b] %s\n" % [colour, player_name.replace("[", "[lb]"),
		text.replace("[", "[lb]")])  # [lb] = a literal [, so no one can inject formatting
