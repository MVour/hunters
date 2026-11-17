class_name GameSettings extends PanelContainer
## How many players and which teams. Pure view: shows GameState.game_settings
## (the player count is the teams' total); the owner's buttons ask the server
## through LobbyNet, and everyone's values update on
## SignalBus.lobby_settings_changed. Lobby shows the buttons to the owner only.
## A 4-column grid (name | < | value | >), so the columns line up whatever the
## language.

var _title: Label
var _names := {}    # row key -> Label
var _values := {}   # row key -> Label
var _buttons := []  # every < and > (owner only)


func _init() -> void:
	add_theme_stylebox_override("panel", LobbyStyle.panel())
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	add_child(column)
	_title = LobbyStyle.heading()
	column.add_child(_title)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	column.add_child(grid)
	_row(grid, "players", func(d): LobbyNet.change_player_count(d))
	_row(grid, "preset", func(d): LobbyNet.change_preset(d))
	for key in ["vampires_count", "werewolves_count", "humans_count"]:
		_row(grid, key, func(d): LobbyNet.change_setting(key, d))


func _ready() -> void:
	SignalBus.lobby_settings_changed.connect(func(_settings): refresh())
	Global.language_changed.connect(func(_l = null): refresh())
	refresh()


func _row(grid: GridContainer, key: String, change: Callable) -> void:
	var name_label := Label.new()
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if key in ["vampires_count", "werewolves_count", "humans_count"]:
		name_label.add_theme_color_override("font_color", Color(LobbyStyle.SIDE_COLOURS[key]))
	grid.add_child(name_label)
	_names[key] = name_label
	var dec := LobbyStyle.small_button("<")
	dec.pressed.connect(change.bind(-1))
	grid.add_child(dec)
	var value := Label.new()
	value.custom_minimum_size = Vector2(76, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.add_theme_font_size_override("font_size", 26)
	grid.add_child(value)
	_values[key] = value
	var inc := LobbyStyle.small_button(">")
	inc.pressed.connect(change.bind(1))
	grid.add_child(inc)
	_buttons.append_array([dec, inc])


## The owner's buttons (Lobby shows/hides them).
func owner_buttons() -> Array:
	return _buttons


func refresh() -> void:
	_title.text = Global.text("Game Settings")
	_names.players.text = Global.text("Players:")
	_names.preset.text = Global.text("Teams:")
	_names.vampires_count.text = Global.text("Vampires: ").strip_edges()
	_names.werewolves_count.text = Global.text("Werewolves: ").strip_edges()
	_names.humans_count.text = Global.text("Humans:")
	var settings: Dictionary = GameState.game_settings
	for key in ["vampires_count", "werewolves_count", "humans_count"]:
		_values[key].text = str(settings.get(key, 0))
	var total := LobbyNet.team_total(settings)
	_values.players.text = str(total)
	var presets: Array = Global.game_settings_default.presets.get(total, [])
	var index := LobbyNet.preset_index(settings)
	_values.preset.text = Global.text("lobby.preset_custom") if index == -1 \
		else "%d/%d" % [index + 1, presets.size()]
