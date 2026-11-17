class_name Lobby extends Node2D
## Waiting room before a match. Pure view: it renders GameState.players and
## GameState.game_settings, re-renders on the lobby SignalBus events, and
## sends what the player does through LobbyNet. No network code here.
## Layout (1920×1080, built here): the room code on top; on the left the
## seats (players, then free seats up to the teams' total) and your name +
## pawn; on the right the teams, Fill with bots and Start. The chat and the
## language / sound buttons live bottom-left (main scene).

const SEAT_SIZE := Vector2(226, 168)
const LEFT_WIDTH := 980.0
const RIGHT_WIDTH := 500.0

var lobby_code := ""
## The user's animated question mark (a 2×3 sheet of 32px frames; 5 used,
## played back and forth, 0.2 s each) for seats without a pawn yet.
const QMARK_SHEET: Texture2D = preload("res://assets/ui/question_mark.png")
const QMARK_FRAMES := [Vector2(0, 0), Vector2(32, 0), Vector2(0, 32), Vector2(32, 32), Vector2(0, 64)]
var question_mark: AtlasTexture
var _qmark_step := 0

var lobby_container: GridContainer
var lobby_id: LineEdit
var start_game_button: Button
var start_error_label: Label
var copy_code_button: Button
var players_in_lobby: Label
var game_settings: GameSettings
var create_player: CreatePlayer
var fill_bots_button: Button
var back_button: Button
var _room_label: Label
var _players_title: Label

## Seat per player id.
var q_marks := {}
## The owner's "remove from the room" button on each seat.
var kick_buttons := {}
## Faint "free seat" placeholders after the players.
var _free_seats := []


func _ready():
	# One shared texture: changing its region animates every question mark.
	question_mark = AtlasTexture.new()
	question_mark.atlas = QMARK_SHEET
	question_mark.region = Rect2(QMARK_FRAMES[0], Vector2(32, 32))
	var timer := Timer.new()
	timer.wait_time = 0.2
	timer.timeout.connect(_next_qmark_frame)
	add_child(timer)
	timer.start()
	_build()
	SignalBus._avatar_created.connect(LobbyNet.choose_avatar)
	SignalBus.lobby_player_updated.connect(_on_player_updated)
	SignalBus.lobby_player_removed.connect(_on_player_removed)
	SignalBus.lobby_start_refused.connect(func(problem): start_error_label.text = Global.msg(problem))
	SignalBus.lobby_owner_changed.connect(_apply_owner)
	SignalBus.lobby_settings_changed.connect(func(_s): _refresh_free_seats())
	Global.language_changed.connect(func(_l = null): _apply_texts())
	start_error_label.text = ""
	_apply_texts()
	# Players we already know about (messages can arrive before this screen).
	for player in GameState.players.values():
		_on_player_updated(player)


func _build() -> void:
	var root := Control.new()
	root.size = Vector2(1920, 1080)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var bg := ColorRect.new()
	bg.color = LobbyStyle.BG
	bg.size = root.size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)

	back_button = LobbyStyle.big_button(52)
	back_button.custom_minimum_size.x = 150
	back_button.position = Vector2(40, 34)
	back_button.pressed.connect(_on_button_pressed)
	root.add_child(back_button)

	# The room code, centred at the top.
	var room := PanelContainer.new()
	room.add_theme_stylebox_override("panel", LobbyStyle.panel())
	root.add_child(room)
	var room_row := HBoxContainer.new()
	room_row.add_theme_constant_override("separation", 14)
	room.add_child(room_row)
	_room_label = Label.new()
	_room_label.add_theme_font_size_override("font_size", 22)
	_room_label.add_theme_color_override("font_color", Color("ffd27a"))
	room_row.add_child(_room_label)
	lobby_id = LineEdit.new()
	lobby_id.editable = false
	lobby_id.custom_minimum_size = Vector2(560, 44)
	lobby_id.add_theme_font_size_override("font_size", 18)
	room_row.add_child(lobby_id)
	copy_code_button = LobbyStyle.big_button(44)
	copy_code_button.custom_minimum_size.x = 150
	copy_code_button.pressed.connect(_on_copy_code_pressed)
	room_row.add_child(copy_code_button)
	room.resized.connect(func(): room.position = Vector2(960 - room.size.x / 2.0, 28))

	# Left: seats, then you. Right: teams and the buttons.
	var main := HBoxContainer.new()
	main.add_theme_constant_override("separation", 36)
	main.position = Vector2((1920 - LEFT_WIDTH - RIGHT_WIDTH - 36) / 2.0, 130)
	root.add_child(main)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(LEFT_WIDTH, 0)
	left.add_theme_constant_override("separation", 20)
	main.add_child(left)
	var seats := PanelContainer.new()
	seats.add_theme_stylebox_override("panel", LobbyStyle.panel())
	left.add_child(seats)
	var seats_column := VBoxContainer.new()
	seats_column.add_theme_constant_override("separation", 12)
	seats.add_child(seats_column)
	var header := HBoxContainer.new()
	seats_column.add_child(header)
	_players_title = LobbyStyle.heading()
	_players_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_players_title)
	players_in_lobby = LobbyStyle.heading()
	header.add_child(players_in_lobby)
	lobby_container = GridContainer.new()
	lobby_container.columns = 4
	lobby_container.add_theme_constant_override("h_separation", 14)
	lobby_container.add_theme_constant_override("v_separation", 14)
	seats_column.add_child(lobby_container)
	create_player = CreatePlayer.new()
	left.add_child(create_player)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(RIGHT_WIDTH, 0)
	right.add_theme_constant_override("separation", 16)
	main.add_child(right)
	game_settings = GameSettings.new()
	right.add_child(game_settings)
	fill_bots_button = LobbyStyle.big_button(58)
	fill_bots_button.pressed.connect(_on_fill_bots_pressed)
	right.add_child(fill_bots_button)
	start_game_button = LobbyStyle.big_button(84, true)
	start_game_button.pressed.connect(_on_start_game_pressed)
	right.add_child(start_game_button)
	start_error_label = Label.new()
	start_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	start_error_label.custom_minimum_size = Vector2(RIGHT_WIDTH, 0)
	start_error_label.add_theme_font_size_override("font_size", 20)
	start_error_label.add_theme_color_override("font_color", Color("ff8a7a"))
	right.add_child(start_error_label)


func _next_qmark_frame() -> void:
	_qmark_step = (_qmark_step + 1) % 8  # 0 1 2 3 4 3 2 1
	var frame: int = _qmark_step if _qmark_step <= 4 else 8 - _qmark_step
	question_mark.region = Rect2(QMARK_FRAMES[frame], Vector2(32, 32))


func _apply_texts() -> void:
	back_button.text = Global.text("Back")
	_room_label.text = Global.text("Lobby:")
	copy_code_button.text = Global.text("Copy")
	_players_title.text = Global.text("Pl in Lobby:").trim_suffix(":")
	fill_bots_button.text = Global.text("Fill with bots")
	start_game_button.text = Global.text("START GAME")
	for id in q_marks:
		_refresh_seat(id)
	_refresh_free_seats()


func lobby_init(code: String):
	lobby_code = code
	lobby_id.text = code
	_apply_owner()


## Only the owner changes the teams, adds bots, starts the match and kicks players.
func _apply_owner(_id := 0) -> void:
	var mine := GameState.owner_id == GameState.local_id and GameState.local_id != 0
	for node in [start_game_button, fill_bots_button] + game_settings.owner_buttons():
		node.visible = mine
	for id in kick_buttons:
		kick_buttons[id].visible = mine and id != GameState.local_id


# --- Seats -----------------------------------------------------------------------

## A seat: name, pawn (a question mark until picked), a tag (you / bot);
## the owner's ✕ sits in its corner, clear of the name.
func _make_seat() -> Control:
	var seat := Control.new()
	seat.custom_minimum_size = SEAT_SIZE
	var card := PanelContainer.new()
	card.name = "Card"
	card.size = SEAT_SIZE
	card.add_theme_stylebox_override("panel", LobbyStyle.panel(Color(1, 1, 1, 0.12)))
	seat.add_child(card)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 4)
	card.add_child(column)
	var name_label := Label.new()
	name_label.name = "Name"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.custom_minimum_size = Vector2(SEAT_SIZE.x - 70, 0)
	name_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	name_label.add_theme_font_size_override("font_size", 19)
	column.add_child(name_label)
	var pawn := TextureRect.new()
	pawn.name = "Pawn"
	pawn.custom_minimum_size = Vector2(0, 76)
	pawn.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pawn.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pawn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	column.add_child(pawn)
	var tag := Label.new()
	tag.name = "Tag"
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override("font_size", 14)
	tag.add_theme_color_override("font_color", Color("e8c060"))
	column.add_child(tag)
	return seat


func _on_player_updated(player: Dictionary) -> void:
	if not q_marks.has(player.id):
		var seat := _make_seat()
		lobby_container.add_child(seat)
		q_marks[player.id] = seat
		var kick := Button.new()
		kick.text = "✕"
		kick.flat = true
		kick.tooltip_text = Global.text("lobby.kick")
		kick.size = Vector2(32, 32)
		kick.position = Vector2(SEAT_SIZE.x - 36, 4)
		kick.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
		var id: int = player.id
		kick.pressed.connect(func(): LobbyNet.kick(id))
		seat.add_child(kick)
		kick_buttons[id] = kick
		_apply_owner()
	_refresh_seat(player.id)
	_on_players_changed()


func _refresh_seat(id: int) -> void:
	var player: Dictionary = GameState.players.get(id, {})
	var seat: Control = q_marks.get(id)
	if player.is_empty() or seat == null:
		return
	var card: PanelContainer = seat.get_node("Card")
	var name_label: Label = card.find_child("Name", true, false)
	var pawn: TextureRect = card.find_child("Pawn", true, false)
	var tag: Label = card.find_child("Tag", true, false)
	name_label.text = player.name if player.name != "" else "…"
	name_label.tooltip_text = player.name
	var pawn_info: Dictionary = Global.pawns.get(player.pawn, {})
	pawn.texture = pawn_info.get("sprite", question_mark)
	var me: bool = id == GameState.local_id
	var tags := []
	if me:
		tags.append(Global.text("players.you").strip_edges().trim_prefix("(").trim_suffix(")"))
	if LobbyNet.is_bot(player):
		tags.append(Global.text("lobby.bot_tag"))
	tag.text = " · ".join(tags)
	var border := LobbyStyle.GOLD if me else Color(pawn_info.get("hex", "ffffff"), 0.55 if not pawn_info.is_empty() else 0.12)
	var style := LobbyStyle.panel(border)
	style.set_border_width_all(3 if me else 2)
	card.add_theme_stylebox_override("panel", style)


func _on_player_removed(id: int) -> void:
	if q_marks.has(id):
		q_marks[id].queue_free()
		q_marks.erase(id)
		kick_buttons.erase(id)
	_on_players_changed()


func _on_players_changed() -> void:
	SignalBus.pawns_changed.emit()
	_refresh_free_seats()


## Free seats up to the teams' total, after the players, so everyone sees
## how many are still missing (the count shows players / seats).
func _refresh_free_seats() -> void:
	if lobby_container == null:
		return
	for seat in _free_seats:
		lobby_container.remove_child(seat)  # now, so new seats line up after the players
		seat.queue_free()
	_free_seats = []
	var total := LobbyNet.team_total(GameState.game_settings)
	players_in_lobby.text = "%d / %d" % [GameState.players.size(), maxi(total, GameState.players.size())]
	for i in maxi(0, total - GameState.players.size()):
		var seat := _make_seat()
		seat.modulate = Color(1, 1, 1, 0.35)
		var card: PanelContainer = seat.get_node("Card")
		card.find_child("Pawn", true, false).texture = question_mark
		card.find_child("Name", true, false).text = Global.text("lobby.free_seat")
		lobby_container.add_child(seat)
		_free_seats.append(seat)


func _on_fill_bots_pressed() -> void:
	LobbyNet.fill_with_bots()


# --- Buttons -----------------------------------------------------------------

func _on_button_pressed() -> void:
	SignalBus._return_to_multiplayer_menu.emit()


func _on_copy_code_pressed() -> void:
	DisplayServer.clipboard_set(lobby_code)
	copy_code_button.text = Global.text("lobby.copied")
	await get_tree().create_timer(1.5).timeout
	if is_instance_valid(copy_code_button):
		copy_code_button.text = Global.text("Copy")


func _on_start_game_pressed() -> void:
	# Show the problem right away; the server checks again either way.
	var problem := LobbyNet.start_problem(GameState.players, GameState.game_settings)
	start_error_label.text = Global.msg(problem)
	if problem.is_empty():
		LobbyNet.start_match()
