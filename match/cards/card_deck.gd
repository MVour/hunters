class_name CardDeck extends Control


@onready var cards: Control = $Cards
@onready var card_scn : PackedScene = preload("res://match/cards/card.tscn")

@export var offset: float = 30.0
@export var scale_between_cards: float = 0.05
@export var anim_duration: float = 0.45
@export var anim_duration_offset: float = 0.15

var first_card_pos: Vector2
var first_card_scale: Vector2

var tween: Tween
var tween_last_card: Tween
var tween_bg: Tween
var deck_locked : bool = true

func _ready() -> void:
	pass
	##init()
	#for c in cards.get_children():
		#c.put_back.connect(on_card_put_back.bind(c))
	#
	#var first_card: Button = cards.get_child(cards.get_child_count() - 1)
	#first_card_pos = first_card.position
	#first_card_scale = first_card.scale
	#
	#await get_tree().create_timer(0.5).timeout
	#
	#tween_bg_color(first_card.color)
	#
	#update_cards()
	#
	#await tween.finished
	#for c in cards.get_children():
		#c.original_position = c.global_position

## Adds face-down cards. What each card says is only revealed when drawn
## (the server sends it then), so nobody can peek at the deck order.
## Only this many cards are drawn in the stack; a number shows the real size.
const MAX_VISIBLE := 6

var _count := 0
var _count_label: Label


func add_cards(card_type: String, count: int, replace := true):
	_card_type = card_type
	if replace:
		# Drop the preview cards placed in the editor.
		for c in cards.get_children():
			cards.remove_child(c)
			c.queue_free()
		_count = count
		count = mini(count, MAX_VISIBLE)
		_update_label()
	for i in count:
		var new_card_scene = card_scn.instantiate()
		cards.add_child(new_card_scene)
		new_card_scene.card_set_type(card_type)
	
func init():
	if cards.get_child_count() == 0:
		return
	for c in cards.get_children():
		c.put_back.connect(on_card_put_back.bind(c))
	
	var first_card: Button = cards.get_child(cards.get_child_count() - 1)
	first_card_pos = first_card.position
	first_card_scale = first_card.scale
	
	await get_tree().create_timer(0.5).timeout
	
	tween_bg_color(first_card.color)
	
	update_cards()
	
	await tween.finished
	for c in cards.get_children():
		c.original_position = c.global_position
	
func tween_bg_color(new_color: Color) -> void:
	if tween_bg and tween_bg.is_running():
		tween_bg.kill()
	var bg := get_node_or_null("BG")  # optional ColorRect behind the deck
	if bg == null:
		return
	tween_bg = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tween_bg.tween_property(bg, "color", new_color, anim_duration*2.0)
	
func update_cards(thrown: bool = false, animated: bool = true) -> void:
	if tween and tween.is_running():
		tween.kill()
	tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC).set_parallel(true)
	
	var child_count: int = cards.get_child_count()
	var card_ref: Button = cards.get_child(child_count - 1)
	
	for i: int in range(child_count-1, -1, -1):
		var c: Button = cards.get_child(i)
		if c == card_ref:
			c.disabled = false
		else:
			c.disabled = true
		
		#print("Button: ", c.get_name())
		var multiplier: float = child_count-1-i
		#print("Multiplier: ", multiplier)
		var card_offset: float = offset*multiplier
		#print("Card offset: ", card_offset)
		var card_scale: float = scale_between_cards * multiplier
		#print("Card scale: ", card_scale)
		
		if not animated:
			c.position = first_card_pos - Vector2(0, card_offset)
			c.scale = first_card_scale - Vector2(card_scale, card_scale)
		else:
			var duration: float = anim_duration + (anim_duration_offset * multiplier)
			tween.tween_property(c, "position", first_card_pos - Vector2(0, card_offset), duration)
			tween.tween_property(c, "scale", first_card_scale - Vector2(card_scale, card_scale), duration)

func on_card_put_back(which: Button) -> void:
	print("Put back: ", which.get_name())
	
	var previous_card: Button = cards.get_child(cards.get_child_count()-2)
	tween_bg_color(previous_card.color)
	
	if tween_last_card and tween_last_card.is_running():
		tween_last_card.kill()
	tween_last_card = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	# Where the flicked card flies before sliding under the deck.
	var top_point = get_node_or_null("TopPoint")
	var fly_to: Vector2 = top_point.global_position if top_point else global_position + Vector2(0, -250)
	tween_last_card.tween_property(which, "global_position", fly_to - (which.size/2.0), anim_duration/2.0)
	tween_last_card.parallel().tween_property(which, "scale", Vector2(0.8, 0.8), anim_duration/2.0)
	
	# Move card to back
	tween_last_card.tween_callback(cards.move_child.bind(which, 0))
	tween_last_card.tween_callback(update_cards.bind(true))

	# Move card to back
	#%Cards.move_child(which, 0)
	
	# Recalculate positions
	#update_cards(true)

func set_cards_3D(state: bool) -> void:
	for c in cards.get_children():
		c.is_3D = state

func _on_check_button_toggled(toggled_on: bool) -> void:
	set_cards_3D(toggled_on)


var _card_type := ""
var _highlight: Tween


## Match the number of face-down cards to the real deck size.
func set_count(count: int) -> void:
	if count < _count and cards.get_child_count() > 0:
		_fly_off_top()
	_count = count
	_update_label()
	var target := mini(count, MAX_VISIBLE)
	while cards.get_child_count() > target:
		var extra: Node = cards.get_child(0)
		cards.remove_child(extra)
		extra.queue_free()
	if cards.get_child_count() < target and _card_type != "":
		add_cards(_card_type, target - cards.get_child_count(), false)
	if cards.get_child_count() > 0:
		update_cards()


## A copy of the top card lifts off the deck and fades out.
func _fly_off_top() -> void:
	var top: Control = cards.get_child(cards.get_child_count() - 1)
	var ghost = card_scn.instantiate()
	add_child(ghost)
	ghost.card_set_type(_card_type)
	ghost.global_position = top.global_position
	ghost.scale = top.scale
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tween := create_tween().set_parallel(true)
	tween.tween_property(ghost, "position:y", ghost.position.y - 140, 0.4)
	tween.tween_property(ghost, "modulate:a", 0.0, 0.4)
	tween.chain().tween_callback(ghost.queue_free)


func _update_label() -> void:
	if not _count_label:
		_count_label = Label.new()
		_count_label.add_theme_font_size_override("font_size", 26)
		_count_label.add_theme_color_override("font_outline_color", Color.BLACK)
		_count_label.add_theme_constant_override("outline_size", 8)
		_count_label.position = Vector2(12, 190)
		_count_label.z_index = 1
		add_child(_count_label)
	_count_label.text = str(_count)


## Glow while you're allowed to draw from this deck.
func set_highlight(on: bool) -> void:
	if _highlight:
		_highlight.kill()
	modulate = Color.WHITE
	if on:
		_highlight = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
		_highlight.tween_property(self, "modulate", Color(1.45, 1.45, 1.3), 0.5)
		_highlight.tween_property(self, "modulate", Color.WHITE, 0.5)
