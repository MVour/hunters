@tool
class_name ForestBoard extends Node2D
## The night-time forest clearing the game is played in.
##
## Everything here is PLACEHOLDER pixel art generated in code: ground, trees,
## the trail ring, campfire, fog and fireflies. It's drawn at 1/4 resolution
## and scaled up 4x so it matches hand-drawn pixel art. Swap pieces for your
## own drawings whenever you like; the layout constants stay the same.
##
## @tool: the forest also shows up in the Godot editor.

const SCREEN := Vector2(1920, 1080)
const PIXEL := 4                       # 1 art pixel = 4x4 screen pixels
const ART_SIZE := Vector2i(480, 270)   # SCREEN / PIXEL
const CENTER := Vector2(960, 490)      # middle of the clearing
const RING := Vector2(420, 225)        # trail ellipse; locations sit on it
const CLEARING := Vector2(700, 420)    # where the trees start
const FIRE_POS := Vector2(960, 420)    # bottom-centre of the flames
const TRAIL_HALF_WIDTH := 16.0         # screen px
const SEED := 1337                     # same forest on every computer

# Night palette (moonlight from the top-left).
const C_GROUND_DARK := Color("0d1512")
const C_GROUND := Color("17231d")
const C_CLEARING := Color("223125")
const C_CLEARING_LIGHT := Color("2b3d2c")
const C_GRASS := Color("3e5935")
const C_GRASS_LIGHT := Color("557447")
const C_TRAIL_EDGE := Color("3a3329")
const C_TRAIL := Color("4f4537")
const C_TRAIL_LIGHT := Color("665a48")
const C_PEBBLE := Color("6d675d")
const C_PINE_DARK := Color("0a1712")
const C_PINE := Color("13291f")
const C_PINE_LIGHT := Color("24463a")
const C_PINE_MOON := Color("3a6152")
const C_TRUNK := Color("24180f")
const C_BUSH := Color("1a3324")
const C_BUSH_LIGHT := Color("2c5038")
const C_ROCK := Color("3d434a")
const C_ROCK_LIGHT := Color("5d656e")
const C_MUSHROOM := Color("9c3a30")
const C_MUSHROOM_DOT := Color("e8d9c0")
const C_FLOWER := Color("8fa6d9")
const C_LOG := Color("3a2416")
const C_LOG_LIGHT := Color("5e3b22")
const C_STONE := Color("4a4c50")
const C_STONE_LIGHT := Color("707479")


## Screen position of location 1..6, clockwise from the top-right.
static func location_position(index: int) -> Vector2:
	var angle := deg_to_rad(-60.0 + 60.0 * (index - 1))
	return CENTER + Vector2(cos(angle) * RING.x, sin(angle) * RING.y)


var _rng := RandomNumberGenerator.new()
var _noise := FastNoiseLite.new()
var _img: Image
var _fire_glow: Sprite2D
var _time := 0.0


func _ready() -> void:
	for child in get_children():
		child.queue_free()
	_rng.seed = SEED
	_noise.seed = SEED
	_noise.frequency = 0.045

	_add_ground()
	_add_location_glows()
	_add_campfire()
	_add_fog()
	_add_fireflies()
	_add_vignette()


func _process(delta: float) -> void:
	_time += delta
	if _fire_glow:
		# Flicker: two waves plus a bit of noise.
		var flicker := 0.85 + 0.08 * sin(_time * 7.3) + 0.05 * sin(_time * 13.1) + _rng.randf_range(-0.03, 0.03)
		_fire_glow.modulate.a = flicker
		_fire_glow.scale = Vector2.ONE * (1.0 + 0.03 * sin(_time * 5.0))


# --- Ground, trail, trees: one baked pixel-art image -----------------------

func _add_ground() -> void:
	_img = Image.create(ART_SIZE.x, ART_SIZE.y, false, Image.FORMAT_RGBA8)
	_paint_ground()
	_paint_trail()
	_paint_clearing_details()
	_paint_campfire_base()
	_paint_trees()

	var sprite := Sprite2D.new()
	sprite.name = "Ground"
	sprite.texture = ImageTexture.create_from_image(_img)
	sprite.centered = false
	sprite.scale = Vector2(PIXEL, PIXEL)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)


## Approximate signed distance (screen px) to an ellipse edge. <0 = inside.
func _ellipse_sdf(p: Vector2, center: Vector2, radii: Vector2) -> float:
	var d := p - center
	var u := sqrt((d.x / radii.x) ** 2 + (d.y / radii.y) ** 2)
	if u < 0.0001:
		return -min(radii.x, radii.y)
	var grad := Vector2(d.x / (radii.x * radii.x), d.y / (radii.y * radii.y)) / u
	return (u - 1.0) / max(grad.length(), 0.0001)


## Screen-space centre of an art pixel.
func _screen(x: int, y: int) -> Vector2:
	return Vector2(x * PIXEL + PIXEL / 2.0, y * PIXEL + PIXEL / 2.0)


func _put(x: int, y: int, color: Color) -> void:
	if x >= 0 and y >= 0 and x < ART_SIZE.x and y < ART_SIZE.y:
		_img.set_pixel(x, y, color)


func _paint_ground() -> void:
	for y in ART_SIZE.y:
		for x in ART_SIZE.x:
			var p := _screen(x, y)
			var edge := _ellipse_sdf(p, CENTER, CLEARING)
			var n := _noise.get_noise_2d(x, y)
			var color: Color
			if edge < 0.0:
				# Clearing: mossy ground with dithered lighter patches.
				var light := n > 0.15 or (n > 0.0 and (x + y) % 2 == 0)
				color = C_CLEARING_LIGHT if light else C_CLEARING
				# Darken towards the tree line.
				var shade := clampf(1.0 + edge / 120.0, 0.0, 1.0)
				color = color.lerp(C_GROUND, shade * 0.7)
			else:
				var dark := n < -0.1 or (n < 0.05 and (x + y) % 2 == 0)
				color = C_GROUND_DARK if dark else C_GROUND
			_img.set_pixel(x, y, color)


func _paint_trail() -> void:
	for y in ART_SIZE.y:
		for x in ART_SIZE.x:
			var dist := absf(_ellipse_sdf(_screen(x, y), CENTER, RING))
			if dist > TRAIL_HALF_WIDTH + 6.0:
				continue
			var wobble := _noise.get_noise_2d(x * 3.0, y * 3.0) * 5.0
			if dist > TRAIL_HALF_WIDTH + wobble:
				continue
			var color := C_TRAIL
			if dist > TRAIL_HALF_WIDTH + wobble - PIXEL * 1.2:
				color = C_TRAIL_EDGE
			elif _noise.get_noise_2d(x * 5.0, y * 5.0) > 0.25:
				color = C_TRAIL_LIGHT
			if _rng.randf() < 0.04:
				color = C_PEBBLE
			_img.set_pixel(x, y, color)


## Is this screen point free for decorations (not on the trail, a location,
## the fire, or the dice area)?
func _is_open_ground(p: Vector2) -> bool:
	if absf(_ellipse_sdf(p, CENTER, RING)) < TRAIL_HALF_WIDTH + 14.0:
		return false
	for i in range(1, 7):
		if p.distance_to(location_position(i)) < 95.0:
			return false
	if p.distance_to(FIRE_POS) < 70.0:
		return false
	if Rect2(790, 470, 340, 290).has_point(p):  # dice + buttons
		return false
	return true


func _paint_clearing_details() -> void:
	# Grass tufts
	for i in 700:
		var p := Vector2(_rng.randf_range(260, 1660), _rng.randf_range(60, 920))
		if _ellipse_sdf(p, CENTER, CLEARING) > -10.0 or not _is_open_ground(p):
			continue
		var x := int(p.x / PIXEL)
		var y := int(p.y / PIXEL)
		var c := C_GRASS_LIGHT if _rng.randf() < 0.3 else C_GRASS
		_put(x, y, c)
		_put(x - 1, y - 1, c)
		_put(x + 1, y - 1, c)
		if _rng.randf() < 0.5:
			_put(x, y - 2, c)

	# Small blue flowers, rocks and mushrooms
	for i in 260:
		var p := Vector2(_rng.randf_range(300, 1620), _rng.randf_range(80, 900))
		if _ellipse_sdf(p, CENTER, CLEARING) > -30.0 or not _is_open_ground(p):
			continue
		var x := int(p.x / PIXEL)
		var y := int(p.y / PIXEL)
		var roll := _rng.randf()
		if roll < 0.6:
			_put(x, y, C_FLOWER)
		elif roll < 0.85:
			_paint_rock(x, y, _rng.randi_range(1, 3))
		else:
			_paint_mushroom(x, y)


func _paint_rock(x: int, y: int, r: int) -> void:
	for dy in range(-r, 1):
		for dx in range(-r - 1, r + 2):
			if dx * dx + dy * dy * 2 <= r * r + 1:
				var light := dx < 0 and dy < 0
				_put(x + dx, y + dy, C_ROCK_LIGHT if light else C_ROCK)


func _paint_mushroom(x: int, y: int) -> void:
	_put(x, y, C_MUSHROOM_DOT)
	_put(x, y - 1, C_MUSHROOM_DOT)
	for dx in range(-1, 2):
		_put(x + dx, y - 2, C_MUSHROOM)
	_put(x, y - 3, C_MUSHROOM)
	_put(x - 1, y - 2, C_MUSHROOM_DOT)


func _paint_campfire_base() -> void:
	var cx := int(FIRE_POS.x / PIXEL)
	var cy := int(FIRE_POS.y / PIXEL)
	# Ring of stones
	for i in 12:
		var a := TAU * i / 12.0
		var sx := cx + int(round(cos(a) * 9.0))
		var sy := cy + int(round(sin(a) * 4.0))
		_put(sx, sy, C_STONE)
		_put(sx + 1, sy, C_STONE)
		_put(sx, sy - 1, C_STONE_LIGHT)
	# Crossed logs
	for i in range(-6, 7):
		_put(cx + i, cy + int(i * 0.35), C_LOG)
		_put(cx + i, cy - 1 + int(i * 0.35), C_LOG_LIGHT)
		_put(cx + i, cy - int(i * 0.35), C_LOG)
		_put(cx + i, cy - 1 - int(i * 0.35), C_LOG_LIGHT)


func _paint_trees() -> void:
	# Pick spots, densest far from the clearing, then draw back-to-front.
	var trees := []
	for i in 1800:
		var p := Vector2(_rng.randf_range(-40, SCREEN.x + 40), _rng.randf_range(-20, SCREEN.y + 120))
		var edge := _ellipse_sdf(p, CENTER, CLEARING)
		if edge < -20.0:
			continue
		var chance := clampf(0.35 + edge / 250.0, 0.0, 1.0)
		if _rng.randf() > chance:
			continue
		var height := int(lerpf(20.0, 42.0, clampf(edge / 300.0, 0.0, 1.0)) + _rng.randi_range(-3, 4))
		var too_close := false
		for t in trees:
			if p.distance_to(t.pos) < float(min(height, t.height)) * PIXEL * 0.45:
				too_close = true
				break
		if not too_close:
			trees.append({"pos": p, "height": height, "bush": edge < 40.0 and _rng.randf() < 0.35})

	trees.sort_custom(func(a, b): return a.pos.y < b.pos.y)
	for t in trees:
		var x := int(t.pos.x / PIXEL)
		var y := int(t.pos.y / PIXEL)
		if t.bush:
			_paint_bush(x, y, int(t.height / 4.0))
		else:
			_paint_pine(x, y, t.height)


func _paint_pine(bx: int, by: int, h: int) -> void:
	var trunk_h: int = max(2, int(h / 6.0))
	# Soft shadow at the base
	for dx in range(-int(h / 4.0), int(h / 4.0) + 1):
		_put(bx + dx, by, C_GROUND_DARK)
	for y in range(by - trunk_h, by):
		_put(bx, y, C_TRUNK)
		_put(bx + 1, y, C_TRUNK)

	var top := by - h
	var bottom := by - trunk_h + 1
	var tiers := 3 + int(h / 10.0)
	for y in range(top, bottom):
		var t := float(y - top) / float(max(1, bottom - top))
		var tier_t := fmod(t * tiers, 1.0)
		var half := (0.2 + t * 0.8) * h * 0.3 * (0.55 + 0.45 * tier_t)
		var left := int(round(bx + 0.5 - half))
		var right := int(round(bx + 0.5 + half))
		for x in range(left, right + 1):
			var c := C_PINE
			if x <= left:
				c = C_PINE_MOON if tier_t > 0.5 else C_PINE_LIGHT
			elif x < bx - half * 0.3 and tier_t > 0.6:
				c = C_PINE_LIGHT
			elif x >= right:
				c = C_PINE_DARK
			_put(x, y, c)
	_put(bx, top - 1, C_PINE_LIGHT)


func _paint_bush(bx: int, by: int, r: int) -> void:
	r = max(r, 2)
	for dy in range(-r * 2, 1):
		for dx in range(-r - 1, r + 2):
			var e := float(dx * dx) / float(r * r + 1) + float((dy + r) * (dy + r)) / float(r * r + 1)
			if e <= 1.0:
				var light := dx < 0 and dy < -r
				_put(bx + dx, by + dy, C_BUSH_LIGHT if light else C_BUSH)


# --- Glows, fire, atmosphere -------------------------------------------------

func _radial_texture(size: int, inner: Color, outer: Color) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, inner)
	gradient.set_color(1, outer)
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = size
	tex.height = size
	return tex


func _additive() -> CanvasItemMaterial:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return mat


## Soft moonlight pools under each location, so the stops stand out.
func _add_location_glows() -> void:
	var tex := _radial_texture(320, Color(0.55, 0.7, 1.0, 0.16), Color(0.55, 0.7, 1.0, 0.0))
	for i in range(1, 7):
		var glow := Sprite2D.new()
		glow.texture = tex
		glow.position = location_position(i)
		glow.scale = Vector2(1.0, 0.7)
		glow.material = _additive()
		add_child(glow)


func _add_campfire() -> void:
	_fire_glow = Sprite2D.new()
	_fire_glow.name = "FireGlow"
	_fire_glow.texture = _radial_texture(640, Color(1.0, 0.55, 0.2, 0.42), Color(1.0, 0.4, 0.1, 0.0))
	_fire_glow.position = FIRE_POS + Vector2(0, -20)
	_fire_glow.material = _additive()
	add_child(_fire_glow)

	var frames := SpriteFrames.new()
	frames.set_animation_speed("default", 9.0)
	for f in 6:
		frames.add_frame("default", ImageTexture.create_from_image(_flame_frame(f)))
	var fire := AnimatedSprite2D.new()
	fire.name = "Fire"
	fire.sprite_frames = frames
	fire.scale = Vector2(PIXEL, PIXEL)
	fire.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fire.centered = true
	fire.offset = Vector2(0, -12)  # stand on the logs
	fire.position = FIRE_POS
	add_child(fire)
	fire.play("default")


func _flame_frame(f: int) -> Image:
	var w := 18
	var h := 24
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var core := Color("fff2b0")
	var mid := Color("ffb13b")
	var outer := Color("e8592a")
	var tip := Color("a8321e")
	for y in h:
		var t := float(y) / float(h - 1)  # 0 top .. 1 bottom
		var half := 8.0 * pow(t, 0.75) * (0.85 + 0.15 * sin(f * 1.9 + y * 0.8))
		var cx := w / 2.0 + sin(f * 2.3 + y * 0.55) * (1.0 - t) * 1.6
		for x in w:
			var d := absf(x + 0.5 - cx)
			if d > half:
				continue
			var r := d / maxf(half, 0.01)
			var c := outer
			if t < 0.3:
				c = tip
			elif r < 0.35 and t > 0.45:
				c = core
			elif r < 0.7:
				c = mid
			img.set_pixel(x, y, c)
	# A couple of sparks
	var spark_rng := RandomNumberGenerator.new()
	spark_rng.seed = SEED + f
	for i in 2:
		img.set_pixel(spark_rng.randi_range(2, w - 3), spark_rng.randi_range(0, 5), mid)
	return img


func _add_fog() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = SEED
	noise.frequency = 0.012
	var noise_tex := NoiseTexture2D.new()
	noise_tex.width = 256
	noise_tex.height = 256
	noise_tex.seamless = true
	noise_tex.noise = noise

	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform vec4 fog_color : source_color = vec4(0.62, 0.72, 0.85, 1.0);
uniform float density = 0.16;
uniform vec2 art_size = vec2(480.0, 270.0);

void fragment() {
	// Snap to the art pixel grid so the fog looks pixelated too.
	vec2 uv = floor(UV * art_size) / art_size;
	vec2 p = uv * vec2(1.8, 1.0);
	float n = texture(noise_tex, p + TIME * vec2(0.010, 0.003)).r * 0.6
			+ texture(noise_tex, p * 2.1 - TIME * vec2(0.014, 0.006)).r * 0.4;
	float a = smoothstep(0.45, 0.8, n) * density;
	a = floor(a * 40.0) / 40.0;
	COLOR = vec4(fog_color.rgb, a);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("noise_tex", noise_tex)
	add_child(_fullscreen_rect("Fog", mat))


func _add_fireflies() -> void:
	var p := CPUParticles2D.new()
	p.name = "Fireflies"
	p.amount = 36
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.position = CENTER
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(CLEARING.x * 0.95, CLEARING.y * 0.95)
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 14.0
	p.texture = _radial_texture(24, Color(0.85, 1.0, 0.55, 1.0), Color(0.6, 1.0, 0.3, 0.0))
	p.material = _additive()
	# Fade in, blink, fade out.
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 0.5, 0.75, 1.0])
	ramp.colors = PackedColorArray([
		Color(1, 1, 1, 0), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.3), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0),
	])
	p.color_ramp = ramp
	add_child(p)


func _add_vignette() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform vec2 art_size = vec2(480.0, 270.0);

void fragment() {
	vec2 uv = floor(UV * art_size) / art_size;
	vec2 d = (uv - vec2(0.5, 0.45)) * vec2(1.0, 0.8) * 2.0;
	float v = smoothstep(0.6, 1.4, length(d));
	v = floor(v * 6.0) / 6.0;
	COLOR = vec4(0.01, 0.02, 0.05, v * 0.8);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	add_child(_fullscreen_rect("Vignette", mat))


func _fullscreen_rect(node_name: String, mat: Material) -> ColorRect:
	var rect := ColorRect.new()
	rect.name = node_name
	rect.size = SCREEN
	rect.material = mat
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect
