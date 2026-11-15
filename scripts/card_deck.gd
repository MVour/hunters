class_name CardDeck extends Control


@onready var cards: Control = $Cards
@onready var card_scn : PackedScene = preload("res://scenes/card.tscn")

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
func add_cards(card_type: String, count: int):
	# Drop the preview cards placed in the editor.
	for c in cards.get_children():
		cards.remove_child(c)
		c.queue_free()
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
