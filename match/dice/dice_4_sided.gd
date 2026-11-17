extends AnimatedSprite2D

@onready var dice_right: AnimatedSprite2D = $DiceRight

@export var roll_animation_frames = 15

#var roll_set = []

func _ready():
	self.animation = str(2)
	

func throw():
	return randi() % 4 + 1
	
	

func roll(target : int):
	await roll_animation()
	set_sides(target)
	
	
func roll_animation():
	#var animated_frame = 1
	var prev_top = 5
	var frame_right = 5
	for i in range(roll_animation_frames):
		var animated_frame = 5
		while animated_frame == prev_top:
			animated_frame = randi() % 4 + 1
			frame_right = randi() % 4 + 1
		self.animation = str(animated_frame)
		dice_right.animation = str(frame_right)
		# Fast at first, then slowing down as the die settles.
		var t: float = float(i) / roll_animation_frames
		if not is_inside_tree():
			return  # the match screen closed mid-roll (e.g. Play again)
		await get_tree().create_timer(lerpf(0.03, 0.12, t * t)).timeout
		#await self.animation_finished
	
func set_sides(target):
	var right_val = randi() % 4 + 1
	while right_val == target:
		right_val = randi() % 4 + 1
	dice_right.animation = str(right_val)
	self.animation = str(target)
	
	


func _on_roll_button_pressed() -> void:
	roll(throw())
