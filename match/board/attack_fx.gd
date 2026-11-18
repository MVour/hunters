class_name AttackFx extends Node2D
## One attack on the board, played in three beats (see PawnLayer.play_attack):
## 1. wind-up (Rules.ATTACK_WINDUP; the server waits as long before the
##    damage): the attacker draws back, grows and glows, rings of power
##    close in at their feet, an aim line reaches out and a reticle closes
##    on the target;
## 2. the blow: a fast lunge; a flash and a shockwave on the target, blood
##    splashing out, a hard shake and the damage popping up (a miss: a grey
##    whiff and the target sidesteps). A killing blow (`lethal`): a darker
##    wind-up, a huge crescent sweep, a red flash over the whole screen;
## 3. settle: the attacker steps back home, the glow and marks fade.
## Pure visuals. Frees itself when done.

const HARM := Color("e0302a")
const MISS := Color(0.82, 0.82, 0.88)
## From a pawn's feet (its position) to the middle of its body.
const BODY := Vector2(0, -34)


## Rings of power closing in at the attacker's feet, embers rising.
class Aura extends Node2D:
	var color := HARM
	var strength := 0.0:
		set(v):
			strength = v
			queue_redraw()
	var _time := 0.0
	var _embers := []  # [position, speed, size, age]

	func _process(delta: float) -> void:
		_time += delta
		if strength > 0.3 and randf() < delta * 22.0 * strength:
			_embers.append([Vector2(randf_range(-30, 30), randf_range(-4, 6)), randf_range(50, 110), randf_range(2, 4.5), 0.0])
		for e in _embers:
			e[0].y -= e[1] * delta
			e[3] += delta
		_embers = _embers.filter(func(e): return e[3] < 0.8)
		queue_redraw()

	func _draw() -> void:
		if strength <= 0.0:
			return
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 0.4))
		draw_circle(Vector2.ZERO, 40.0, Color(color, 0.22 * strength))
		for i in 3:
			var k := fmod(_time * 1.5 + i / 3.0, 1.0)
			draw_arc(Vector2.ZERO, lerpf(78.0, 24.0, k), 0.0, TAU, 40,
				Color(color.lightened(0.2), strength * (1.0 - k) * 0.9), 5.0, true)
		draw_set_transform(Vector2.ZERO)
		for e in _embers:
			var fade: float = 1.0 - e[3] / 0.8
			draw_rect(Rect2(e[0], Vector2(e[2], e[2])), Color(1.0, 0.55, 0.3, fade * strength))


## A dashed line from the attacker to the target, drawing itself out.
class AimLine extends Node2D:
	var from := Vector2.ZERO
	var to := Vector2.ZERO
	var color := HARM
	var progress := 0.0
	var _time := 0.0

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		var tip := from.lerp(to, progress)
		var length := from.distance_to(tip)
		if length < 2.0:
			return
		var dir := (tip - from) / length
		var dash := 16.0
		var d := fmod(_time * 60.0, dash * 2.0) - dash * 2.0
		while d < length:
			var a := from + dir * maxf(d, 0.0)
			var b := from + dir * minf(d + dash, length)
			if d + dash > 0.0:
				draw_line(a, b, Color(0, 0, 0, 0.5), 7.0, true)
				draw_line(a, b, color, 3.5, true)
			d += dash * 2.0
		# Arrowhead
		var side := dir.orthogonal() * 9.0
		draw_colored_polygon(PackedVector2Array([tip + dir * 6.0, tip - dir * 12.0 + side, tip - dir * 12.0 - side]), color)


## Four brackets around the target, closing in and turning.
class Reticle extends Node2D:
	var color := HARM

	func _process(delta: float) -> void:
		rotation += delta * 1.8

	func _draw() -> void:
		for i in 4:
			var start := i * TAU / 4.0 + 0.25
			draw_arc(Vector2.ZERO, 40.0, start, start + 1.0, 12, Color(0, 0, 0, 0.5), 8.0, true)
			draw_arc(Vector2.ZERO, 40.0, start, start + 1.0, 12, color, 4.0, true)
		draw_circle(Vector2.ZERO, 4.0, color)


## The impact: a bright flash and a shockwave ring.
class Burst extends Node2D:
	var color := HARM
	var big := 1.0
	var progress := 0.0:
		set(v):
			progress = v
			queue_redraw()

	func _draw() -> void:
		var fade := 1.0 - progress
		draw_circle(Vector2.ZERO, lerpf(14.0, 56.0, progress) * big, Color(1.0, 0.95, 0.85, fade * 0.85))
		draw_circle(Vector2.ZERO, lerpf(8.0, 40.0, progress) * big, Color(color.lightened(0.3), fade * 0.7))
		draw_arc(Vector2.ZERO, lerpf(24.0, 120.0, progress) * big, 0.0, TAU, 48,
			Color(color, fade), maxf(1.0, 9.0 * fade), true)


## Drops flying out of the hit and falling.
class Splash extends Node2D:
	const LIFE := 0.9
	var drops := []  # [position, velocity, radius]
	var _age := 0.0

	func _init(count: int, away: Vector2) -> void:
		for i in count:
			var angle := away.angle() + randf_range(-1.3, 1.3)
			drops.append([Vector2.ZERO, Vector2.from_angle(angle) * randf_range(140, 380) + Vector2(0, -120),
				randf_range(2.5, 6.0)])

	func _process(delta: float) -> void:
		_age += delta
		if _age >= LIFE:
			queue_free()
			return
		for d in drops:
			d[1].y += 900.0 * delta
			d[0] += d[1] * delta
		queue_redraw()

	func _draw() -> void:
		var fade := 1.0 - _age / LIFE
		for d in drops:
			draw_line(d[0], d[0] - d[1] * 0.03, Color(0.6, 0.03, 0.04, fade), d[2], true)
			draw_circle(d[0], d[2], Color(0.75, 0.06, 0.05, fade))


## A huge crescent cut across the target (killing blows).
class Sweep extends Node2D:
	var progress := 0.0:
		set(v):
			progress = v
			queue_redraw()

	func _draw() -> void:
		var head := lerpf(-2.4, 0.9, minf(progress * 1.6, 1.0))
		var tail := lerpf(-2.4, 0.9, maxf(0.0, progress * 1.6 - 0.6))
		var fade := 1.0 - maxf(0.0, progress - 0.6) / 0.4
		if head - tail < 0.02:
			return
		draw_arc(Vector2.ZERO, 120.0, tail, head, 40, Color(0, 0, 0, 0.5 * fade), 26.0, true)
		draw_arc(Vector2.ZERO, 120.0, tail, head, 40, Color(0.9, 0.1, 0.08, fade), 16.0, true)
		draw_arc(Vector2.ZERO, 120.0, tail, head, 40, Color(1, 0.85, 0.75, fade), 5.0, true)


func play(attacker: Sprite2D, target: Sprite2D, damage: int, lethal := false) -> void:
	z_index = 19
	var a := attacker
	var t := target
	var home := a.position
	var gap := t.position - home
	var dir := gap.normalized() if gap.length() > 1.0 else Vector2.RIGHT
	var base_scale := a.scale
	var windup := Rules.ATTACK_WINDUP
	var hit := damage > 0

	# --- 1. Wind-up ---
	var aura := Aura.new()
	aura.show_behind_parent = true
	aura.scale = Vector2.ONE / a.scale  # undo the pawn's scale: board pixels
	a.add_child(aura)
	var charge := create_tween().set_parallel(true)
	charge.tween_property(a, "position", home - dir * 26.0, windup * 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	charge.tween_property(a, "scale", base_scale * 1.12, windup * 0.7).set_trans(Tween.TRANS_SINE)
	charge.tween_property(a, "modulate", Color(1.9, 0.5, 0.45) if lethal else Color(1.6, 0.8, 0.7), windup * 0.7)
	charge.tween_property(aura, "strength", 1.0, windup * 0.5)

	var aim := AimLine.new()
	aim.from = home + BODY
	aim.to = t.position + BODY - dir * 46.0
	add_child(aim)
	create_tween().tween_property(aim, "progress", 1.0, windup * 0.6).set_delay(windup * 0.15) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var reticle := Reticle.new()
	reticle.position = t.position + BODY
	reticle.scale = Vector2.ONE * 2.4
	reticle.modulate.a = 0.0
	add_child(reticle)
	var close_in := create_tween().set_parallel(true)
	close_in.tween_property(reticle, "scale", Vector2.ONE, windup * 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	close_in.tween_property(reticle, "modulate:a", 1.0, windup * 0.4)

	await get_tree().create_timer(windup).timeout
	if not is_instance_valid(a) or not is_instance_valid(t):
		queue_free()
		return

	# --- 2. The blow ---
	var strike := home + dir * maxf(gap.length() - 34.0, 18.0)
	var lunge := create_tween()
	lunge.tween_property(a, "position", strike, 0.1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	await lunge.finished
	if not is_instance_valid(t):
		queue_free()
		return
	var impact := t.position + BODY
	var burst := Burst.new()
	burst.color = HARM if hit else MISS
	burst.big = 1.0 + clampf(damage, 0, 6) * 0.12 if hit else 0.6
	burst.position = impact
	add_child(burst)
	create_tween().tween_property(burst, "progress", 1.0, 0.5).set_ease(Tween.EASE_OUT)

	if lethal:
		_killing_blow(impact)
	var base := t.position
	var shake := create_tween()
	if hit:
		var splash := Splash.new(8 + damage * 4 + (14 if lethal else 0), dir)
		splash.position = impact
		add_child(splash)
		var strength := 6.0 + mini(damage, 6) * 2.0
		for i in 8:
			var falloff := 1.0 - i / 8.0
			shake.tween_property(t, "position", base + Vector2(strength * falloff * (1 if i % 2 == 0 else -1), randf_range(-2, 2)), 0.04)
		shake.tween_property(t, "position", base, 0.05)
		t.modulate = Color(2.2, 0.45, 0.45)
		create_tween().tween_property(t, "modulate", Color.WHITE, 0.7)
	else:
		# A whiff: the target sidesteps.
		var side := dir.orthogonal() * 22.0
		shake.tween_property(t, "position", base + side, 0.1).set_ease(Tween.EASE_OUT)
		shake.tween_property(t, "position", base, 0.3).set_ease(Tween.EASE_IN_OUT).set_delay(0.15)
	_pop_number(impact, damage)

	var marks := create_tween().set_parallel(true)
	marks.tween_property(aim, "modulate:a", 0.0, 0.2)
	marks.tween_property(reticle, "scale", Vector2.ONE * 1.5, 0.25)
	marks.tween_property(reticle, "modulate:a", 0.0, 0.25)

	# --- 3. Settle ---
	var settle := create_tween().set_parallel(true)
	settle.tween_property(a, "position", home, 0.55).set_delay(0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	settle.tween_property(a, "scale", base_scale, 0.55).set_delay(0.25)
	settle.tween_property(a, "modulate", Color.WHITE, 0.8)
	settle.tween_property(aura, "strength", 0.0, 0.7)
	await get_tree().create_timer(1.6).timeout
	if is_instance_valid(aura):
		aura.queue_free()
	queue_free()


## A crescent sweep across the target and a red flash over the screen.
func _killing_blow(at: Vector2) -> void:
	var sweep := Sweep.new()
	sweep.position = at
	sweep.rotation = randf_range(-0.4, 0.4)
	add_child(sweep)
	var s := create_tween()
	s.tween_property(sweep, "progress", 1.0, 0.55).set_ease(Tween.EASE_OUT)
	s.tween_callback(sweep.queue_free)
	var flash := ColorRect.new()
	flash.color = Color(0.7, 0.0, 0.0, 0.0)
	flash.size = Vector2(1920, 1080)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.z_index = 40
	add_child(flash)
	flash.global_position = Vector2.ZERO
	var f := create_tween()
	f.tween_property(flash, "color:a", 0.38, 0.06)
	f.tween_property(flash, "color:a", 0.0, 0.7)
	f.tween_callback(flash.queue_free)


## "-3" (or "Miss") pops up big over the target, then floats away.
func _pop_number(at: Vector2, damage: int) -> void:
	var label := Label.new()
	label.text = "-%d" % damage if damage > 0 else Global.text("match.miss")
	label.add_theme_font_size_override("font_size", 38 if damage > 0 else 30)
	label.add_theme_color_override("font_color", Color("ff5a4a") if damage > 0 else MISS)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 10)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(160, 50)
	label.pivot_offset = label.size / 2.0
	label.position = at + Vector2(-80, -95)
	label.scale = Vector2.ONE * 0.3
	add_child(label)
	var pop := create_tween()
	pop.tween_property(label, "scale", Vector2.ONE * 1.5, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(label, "scale", Vector2.ONE, 0.2)
	pop.tween_property(label, "position:y", label.position.y - 55.0, 1.0).set_ease(Tween.EASE_OUT)
	pop.parallel().tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.5)
	pop.tween_callback(label.queue_free)
