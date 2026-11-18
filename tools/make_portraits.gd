extends SceneTree
## Writes the character portraits (assets/portraits/*.png): 6-frame loops in
## a 2x3 sheet, played by the character card at 5 fps.
##  vampire.png  76x76 frames: the classic vampire (legacy remaster) recoloured
##               toward the modern painting, scale2x + light/shadow, on a
##               blood-moon night; blood drips, eyes flare, bats.
##  human.png    76x76 frames: the first human portrait (legacy human_v1),
##               scale2x + lantern light, in a dark forest; the lantern glow
##               pulses, fireflies, eyes in the dark.
##  werewolf.png 57x65 frames: the modern painted werewolf (legacy
##               werewolf_modern) with clouds over the moon, eye pulse, rain.
## Run: godot --headless --path . --script tools/make_portraits.gd
## Then open the editor once (or run check_project) so Godot reimports them.

const OUT := "res://assets/portraits/%s.png"
const VAMP_SRC := "res://assets/legacy/portraits/vampire_remaster.png"
const HUMAN_SRC := "res://assets/legacy/portraits/human_v1.png"
const WOLF_MODERN := "res://assets/legacy/portraits/werewolf_modern.png"

const VAMP_BG := ["0e0c1d", "2723a7", "1a184d", "2d29b8"]
const VAMP_REMAP := {
	"edc250": "e6dcef", "cba76f": "b4a2c8", "d5cdcd": "cfcbe0", "b7b0d3": "9e98bc",
	"cf0000": "c41e38", "ff4a4a": "f04a58", "b30c2f": "7a0f24", "ad0b0b": "8a0a18",
	"4b396c": "4a3466", "493a85": "5a4288", "32244a": "2e2042", "35296a": "3a2c6a",
	"ffffff": "f4ecf4", "9e9e9e": "a898b0", "000000": "0c0610", "0d0c2f": "1a0a20",
}
const OUTLINE_KEYS := ["000000", "120d14"]
## Colours that glow and are not shaded.
const NO_SHADE := ["ff2a3a", "8a1020", "ffd15a", "ff8a2a", "fff4c2", "d6b34a", "ffb0a0"]

func _init() -> void:
	_save(_sheet(_vampire_layers(), 2, "vampire"), "vampire")
	_save(_sheet(_human_layers(), 2, "human"), "human")
	_save(_wolf_anim(), "werewolf")
	print("portraits written")
	quit()


func _save(img: Image, name: String) -> void:
	img.save_png(ProjectSettings.globalize_path(OUT % name))


# ------------------------------------------------------------------ helpers

func _load(path: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	img.convert(Image.FORMAT_RGBA8)
	return img


func _key(c: Color) -> String:
	return c.to_html(false)


func _frame_of(sheet: Image, i: int, size: int) -> Image:
	return sheet.get_region(Rect2i((i % 2) * size, (i / 2) * size, size, size))


func _f0(sheet: Image, size: int) -> Image:
	return _frame_of(sheet, 0, size)


func _hash(x: int, y: int) -> float:
	var h := (x * 374761393 + y * 668265263) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float(h % 1000) / 1000.0


# ------------------------------------------------------------- figure layers

## Vampire: the classic figure on a transparent layer, recoloured; eyes
## pulse on frames 2-3, a blood drop falls. Also records the outer outline.
func _vampire_layers() -> Array:
	var src := _load(VAMP_SRC).get_region(Rect2i(0, 0, 38, 38))
	var mask := {}
	var todo := [Vector2i(19, 22)]
	while not todo.is_empty():
		var p: Vector2i = todo.pop_back()
		if mask.has(p) or p.x < 0 or p.y < 0 or p.x >= 38 or p.y >= 38:
			continue
		if _key(src.get_pixelv(p)) in VAMP_BG:
			continue
		mask[p] = true
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			todo.append(p + d)
	for y in 38:
		for x in 38:
			if _key(src.get_pixel(x, y)) == "ad0b0b":
				mask[Vector2i(x, y)] = true
	var layers := []
	for i in 6:
		var layer := Image.create(38, 38, false, Image.FORMAT_RGBA8)
		for p in mask:
			var k := _key(src.get_pixelv(p))
			var c: Color = Color(VAMP_REMAP[k]) if VAMP_REMAP.has(k) else Color(src.get_pixelv(p), 1.0)
			if k == "ff2a3a" and (i == 2 or i == 3):
				c = Color("ffb0a0") if i == 2 else Color("ff6a6a")
			layer.set_pixelv(p, c)
		layers.append(layer)
	return layers


## Human: everything enclosed by the dark outline, per frame (the lantern
## flame flickers in the source).
func _human_layers() -> Array:
	var sheet := _load(HUMAN_SRC)
	var layers := []
	for i in 6:
		var src := _frame_of(sheet, i, 38)
		var outside := {}
		var todo := []
		for k in 38:
			todo.append_array([Vector2i(k, 0), Vector2i(k, 37), Vector2i(0, k), Vector2i(37, k)])
		while not todo.is_empty():
			var p: Vector2i = todo.pop_back()
			if outside.has(p) or p.x < 0 or p.y < 0 or p.x >= 38 or p.y >= 38:
				continue
			if _key(src.get_pixelv(p)) in OUTLINE_KEYS:
				continue
			outside[p] = true
			for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				todo.append(p + d)
		var layer := Image.create(38, 38, false, Image.FORMAT_RGBA8)
		for y in 38:
			for x in 38:
				if not outside.has(Vector2i(x, y)):
					layer.set_pixel(x, y, src.get_pixel(x, y))
		layers.append(layer)
	return layers


# ----------------------------------------------------------- build a sheet

func _sheet(layers: Array, scale: int, who: String) -> Image:
	var n := 38 * scale
	var sheet := Image.create(n * 2, n * 3, false, Image.FORMAT_RGBA8)
	for i in 6:
		var frame := Image.create(n, n, false, Image.FORMAT_RGBA8)
		if who == "vampire":
			_vamp_bg(frame, scale, i)
		else:
			_human_bg(frame, scale, i)
		var fig: Image = layers[i]
		# light source: the moon (vampire), the lantern (human)
		var light: Vector2 = Vector2(0.8, -0.6) if who == "vampire" else Vector2(1.0, 0.15)
		if scale == 2:
			fig = _detail(fig, light.normalized())
		frame.blend_rect(fig, Rect2i(0, 0, n, n), Vector2i.ZERO)
		if who == "vampire" and scale == 2:
			_blood(frame, i)
		sheet.blit_rect(frame, Rect2i(0, 0, n, n), Vector2i((i % 2) * n, (i / 2) * n))
	return sheet


## Blood at 76 px: a drop gathers at each hand, stretches, falls and splashes
## (the left hand half a loop behind); a trickle runs from a fang.
const DRIP_R := Vector2i(62, 58)
const DRIP_L := Vector2i(11, 58)
const POOL_Y := 73
const FANG := Vector2i(43, 31)


func _blood(img: Image, i: int) -> void:
	_drip(img, DRIP_R, i)
	_drip(img, DRIP_L, (i + 3) % 6)
	var red := Color("c41e38")
	var dark := Color("8a0a18")
	var length: int = [1, 2, 3, 4, 4, 2][i]
	for k in length:
		img.set_pixel(FANG.x, FANG.y + k, red if k < length - 1 else dark)


func _drip(img: Image, at: Vector2i, i: int) -> void:
	var red := Color("c41e38")
	var light := Color("ff6a6a")
	var dark := Color("8a0a18")
	match i:
		0:
			img.set_pixelv(at + Vector2i(0, 1), red)
		1:
			img.set_pixelv(at + Vector2i(0, 1), red)
			img.set_pixelv(at + Vector2i(0, 2), red)
			img.set_pixelv(at + Vector2i(1, 2), dark)
		2:
			img.set_pixelv(at + Vector2i(0, 1), red)
			img.set_pixelv(at + Vector2i(0, 2), red)
			img.set_pixelv(at + Vector2i(0, 3), red)
			img.set_pixelv(at + Vector2i(1, 3), dark)
			img.set_pixelv(at + Vector2i(0, 3), light)
		3:
			img.set_pixelv(at + Vector2i(0, 1), dark)
			for p in [Vector2i(0, 6), Vector2i(0, 7), Vector2i(1, 7)]:
				img.set_pixelv(at + p, red)
			img.set_pixelv(at + Vector2i(0, 6), light)
		4:
			for p in [Vector2i(0, 11), Vector2i(0, 12), Vector2i(1, 12)]:
				img.set_pixelv(at + p, red)
			img.set_pixelv(at + Vector2i(0, 11), light)
		5:
			var y := POOL_Y
			for p in [Vector2i(-2, -1), Vector2i(2, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 0), Vector2i(-3, -2), Vector2i(3, -2)]:
				var q: Vector2i = Vector2i(at.x, y) + p
				img.set_pixelv(q, red if p.y > -2 else light)


## 2x detail: scale2x (smooth diagonals), thin outer outline, rim light on
## the side facing the light, shadow on the far side, soft cloth texture.
func _detail(fig: Image, light: Vector2) -> Image:
	var big := _scale2x(fig)
	var n := 76
	var res := big.duplicate()
	var is_fig := func(x: int, y: int) -> bool:
		return x >= 0 and y >= 0 and x < n and y < n and big.get_pixel(x, y).a > 0
	var is_line := func(x: int, y: int) -> bool:
		return x >= 0 and y >= 0 and x < n and y < n and _key(big.get_pixel(x, y)) in ["0c0610", "120d14"]
	for y in n:
		for x in n:
			var c = big.get_pixel(x, y)
			if c.a == 0:
				continue
			var k := _key(c)
			if k in ["0c0610", "120d14"]:
				# Thin the outer outline: keep only pixels touching the outside.
				var touches_out := false
				var inner := Color(0, 0, 0, 0)
				for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var q = Vector2i(x, y) + d
					if not is_fig.call(q.x, q.y):
						touches_out = true
					elif not is_line.call(q.x, q.y):
						inner = big.get_pixelv(q)
				if not touches_out and inner.a > 0:
					var outer := false
					for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
						var q2 = Vector2i(x, y) + d * 2
						if not is_fig.call(q2.x, q2.y):
							outer = true
					if outer:
						res.set_pixel(x, y, inner.darkened(0.35))
				continue
			if k in NO_SHADE:
				continue
			# Light: how close is the edge toward / away from the light?
			var lit = 0.0
			for s in [1, 2, 3]:
				var q = Vector2(x, y) + light * s * 1.5
				if not is_fig.call(int(q.x), int(q.y)) or is_line.call(int(q.x), int(q.y)):
					lit = [0.0, 0.30, 0.18, 0.08][s]
					break
			var shade := 0.0
			for s in [1, 2, 3]:
				var q = Vector2(x, y) - light * s * 1.5
				if not is_fig.call(int(q.x), int(q.y)) or is_line.call(int(q.x), int(q.y)):
					shade = [0.0, 0.22, 0.14, 0.06][s]
					break
			var v = c
			if lit > 0.0:
				v = v.lightened(lit)
			if shade > 0.0:
				v = v.darkened(shade)
			v = v.darkened(0.12 * float(y) / n)  # a little darker toward the feet
			var noise = (_hash(x, y) - 0.5) * 0.06
			v = v.lightened(noise) if noise > 0 else v.darkened(-noise)
			res.set_pixel(x, y, Color(v, 1.0))
	return res


func _scale2x(src: Image) -> Image:
	var w = src.get_width()
	var h := src.get_height()
	var dst := Image.create(w * 2, h * 2, false, Image.FORMAT_RGBA8)
	var at := func(x: int, y: int) -> Color:
		return src.get_pixel(clampi(x, 0, w - 1), clampi(y, 0, h - 1))
	for y in h:
		for x in w:
			var p: Color = at.call(x, y)
			var a: Color = at.call(x, y - 1)
			var b: Color = at.call(x + 1, y)
			var c: Color = at.call(x - 1, y)
			var d: Color = at.call(x, y + 1)
			var e1 = p
			var e2 = p
			var e3 = p
			var e4 = p
			if c == a and c != d and a != b:
				e1 = a
			if a == b and a != c and b != d:
				e2 = b
			if d == c and d != b and c != a:
				e3 = c
			if b == d and b != a and d != c:
				e4 = d
			dst.set_pixel(x * 2, y * 2, e1)
			dst.set_pixel(x * 2 + 1, y * 2, e2)
			dst.set_pixel(x * 2, y * 2 + 1, e3)
			dst.set_pixel(x * 2 + 1, y * 2 + 1, e4)
	return dst


# ------------------------------------------------------------- backgrounds

## Blood-moon night. All positions in 38-px units times `s`.
func _vamp_bg(img: Image, s: int, i: int) -> void:
	var n := 38 * s
	var top := Color("14061c")
	var mid := Color("34102a")
	var low := Color("6a1830")
	# figure halo centre (behind the shoulders) for contrast
	var halo := Vector2(19, 20) * s
	for y in n:
		var t := float(y) / (n - 1)
		var c = top.lerp(mid, t / 0.55) if t < 0.55 else mid.lerp(low, (t - 0.55) / 0.45)
		for x in n:
			var v = c
			var hd = Vector2(x, y).distance_to(halo) / (16.0 * s)
			if hd < 1.0:
				v = v.lerp(Color("5a1838"), (1.0 - hd) * 0.45)
			if s == 2:
				var dn = (_hash(x, y) - 0.5) * 0.05
				v = v.lightened(dn) if dn > 0 else v.darkened(-dn)
			elif (x + y) % 2 == 0:
				v = v.lightened(0.015)
			img.set_pixel(x, y, v)
	# stars
	var stars := [[3, 2], [8, 5], [13, 1], [22, 3], [36, 2], [33, 18], [5, 9], [24, 0], [37, 8]]
	for st in stars:
		var tw = (i + st[0]) % 3 != 0
		var col = Color("ffc8d0") if tw else Color("a06070")
		img.fill_rect(Rect2i(st[0] * s, st[1] * s, 1 if s == 2 else 1, 1), col)
		if s == 2 and tw:
			img.set_pixel(st[0] * s + 1, st[1] * s, Color(col, 0.5))
	# moon
	var centre := Vector2(29.5, 10.5) * s
	var r := 7.0 * s
	for y in n:
		for x in n:
			var p = Vector2(x + 0.5, y + 0.5)
			var d = p.distance_to(centre)
			if d > r:
				if d < r + 2.5 * s:
					var g = 0.35 * (1.0 - (d - r) / (2.5 * s))
					img.set_pixel(x, y, img.get_pixel(x, y).lerp(Color("d8323a"), g))
				continue
			var rel = (p - centre) / s
			var c = Color("d8323a")
			if rel.x + rel.y < -6.0:
				c = Color("ff7060")
			elif rel.x + rel.y < -3.5:
				c = Color("ec4a46")
			elif rel.x + rel.y > 6.5:
				c = Color("a01e2c")
			if s == 2:
				var mn = (_hash(x * 3, y * 7) - 0.5) * 0.08
				c = c.lightened(mn) if mn > 0 else c.darkened(-mn)
			img.set_pixel(x, y, c)
	for cr in [[31, 8, 1.2], [27, 12, 1.0], [32.5, 13, 1.4], [28, 6, 0.8], [25.5, 9.5, 0.7]]:
		var cc = Vector2(cr[0], cr[1]) * s
		for y in range(int(cc.y - 2 * s), int(cc.y + 2 * s) + 1):
			for x in range(int(cc.x - 2 * s), int(cc.x + 2 * s) + 1):
				if x >= 0 and y >= 0 and x < n and y < n and Vector2(x + 0.5, y + 0.5).distance_to(cc) <= cr[2] * s:
					img.set_pixel(x, y, Color("a01e2c"))
	# thin clouds drifting across the moon
	for cl in [[18, 13, 14], [24, 16, 13], [28, 4, 10]]:
		var cx: float = cl[0] + i * 0.5
		var cy: int = cl[1] * s
		var ln: int = cl[2] * s
		for k in ln:
			var x = int(cx * s) + k
			if x >= n:
				continue
			var thick = 1 if s == 1 else (2 if k > 2 and k < ln - 3 else 1)
			for t in thick:
				img.set_pixel(x, cy + t, img.get_pixel(x, cy + t).lerp(Color("1a0614"), 0.75))
	# castle: towers at the sides, one tall spire cutting the moon
	var castle := Color("0c0410")
	var towers := [[0, 3, 21], [3, 2, 17], [5, 2, 24], [31, 2, 25], [33, 3, 7], [36, 2, 15]]
	for tw in towers:
		var x0: int = tw[0] * s
		var w: int = tw[1] * s
		var y0: int = tw[2] * s
		img.fill_rect(Rect2i(x0, y0, w, n - y0), castle)
		# pointed roof
		for k in range(1, 3 * s):
			var inset = int(k * w / (6.0 * s))
			if w - inset * 2 > 0:
				img.fill_rect(Rect2i(x0 + inset, y0 - k, w - inset * 2, 1), castle)
	img.fill_rect(Rect2i(34 * s, 4 * s - 1, max(1, s / 2), 3 * s), castle)  # spire tip
	for win in [[1, 24], [34, 12], [37, 19], [32, 28]]:
		var lit = (i + win[0]) % 4 != 0
		img.fill_rect(Rect2i(win[0] * s, win[1] * s, s, s), Color("ff8a3a") if lit else Color("6a2010"))
	# ground mist
	for y in range(30 * s, n):
		for x in n:
			var m = 0.25 * (float(y - 30 * s) / (8 * s)) * (0.7 + 0.3 * sin((x + i * 2 * s) * 0.4 / s))
			img.set_pixel(x, y, img.get_pixel(x, y).lerp(Color("9a2a44"), m))
	# bats
	var up := i % 2 == 0
	for b in [[18 + i * 3, 4 - (i % 3)], [36 - i * 2, 15 + (i % 2)], [6 + i * 2, 11 - (i % 2)]]:
		var bx: int = b[0] % 40 - 2
		var by: int = b[1]
		var shape := [[0, 0], [1, 1], [2, 1], [3, 0]] if up else [[0, 1], [1, 0], [2, 0], [3, 1]]
		for sp in shape:
			var px: int = (bx + sp[0]) * s
			var py: int = (by + sp[1]) * s
			if px >= 0 and px < n and py >= 0 and py < n:
				img.fill_rect(Rect2i(px, py, s, s), Color("0a0208"))


## Dark, threatening forest lit by the lantern (right, low): twisted trees
## with clawing branches, eyes in the dark, thorns, solid ground with the
## figure's shadow, a lantern glow that pulses, fireflies.
const H_LAMP := Vector2(29.5, 22.5)
const H_GROUND := 33.0        # ground line, in 38-px units
const H_FEET := Vector2(19.0, 35.8)


func _human_bg(img: Image, s: int, i: int) -> void:
	var n := 38 * s
	var lamp = H_LAMP * s
	var pulse = [0.78, 0.88, 1.0, 1.0, 0.9, 0.8][i]
	var top := Color("05090b")
	var mid := Color("0b1614")
	var low := Color("122019")
	for y in n:
		var t := float(y) / (n - 1)
		for x in n:
			var v = top.lerp(mid, t / 0.6) if t < 0.6 else mid.lerp(low, (t - 0.6) / 0.4)
			var dn = (_hash(x, y) - 0.5) * 0.05
			v = v.lightened(dn) if dn > 0 else v.darkened(-dn)
			img.set_pixel(x, y, v)
	# far trees: a hazy row of thin trunks
	var far := Color("15271f")
	for k in 14:
		var fx = int(_hash(k, 91) * n)
		var fw = 1 + int(_hash(k, 17) * 2) * (s / 2 + 1)
		img.fill_rect(Rect2i(fx, 0, fw, int(H_GROUND * s)), far)
	# mist between far and near trees
	for y in range(16 * s, int(H_GROUND * s)):
		for x in n:
			var m = 0.22 * (float(y - 16 * s) / (18.5 * s)) * (0.6 + 0.4 * sin((x + i * s) * 0.3 / s))
			img.set_pixel(x, y, img.get_pixel(x, y).lerp(Color("2e4a40"), m))
	# eyes watching from the dark (blink on some frames)
	var eyes = [[7.0, 19.0, Color("ff3a2a"), [0, 1, 2, 4, 5]], [24.0, 9.0, Color("ffd040"), [0, 1, 3, 4]], [3.5, 28.0, Color("ff3a2a"), [1, 2, 3, 4, 5]]]
	for e in eyes:
		if not (i in e[3]):
			continue
		for side in [0, 3]:
			var ex = int((e[0] + side * 0.5) * s)
			var ey = int(e[1] * s)
			img.set_pixel(ex, ey, e[2])
			pass
			for d in [Vector2i.LEFT, Vector2i.RIGHT]:
				var q = Vector2i(ex, ey) + d
				img.set_pixelv(q, img.get_pixelv(q).lerp(e[2], 0.18))
	# near trees: twisted trunks at the sides
	var trunk := Color("030606")
	var bark := Color("0a1110")
	var trunks = [[0.0, 4.5, 0.8], [31.5, 3.0, -0.6], [35.0, 3.5, 0.5], [10.5, 1.5, 0.4]]
	for tr in trunks:
		for y in int(H_GROUND * s) + 2:
			var sway = sin(y * 0.18 / s + tr[0]) * tr[2] * s
			var x0 = int(tr[0] * s + sway)
			var w = int(tr[1] * s * (1.0 + 0.25 * (float(y) / n)))  # roots widen
			img.fill_rect(Rect2i(x0, y, w, 1), trunk)
			if _hash(x0, y) > 0.7:
				img.set_pixel(x0 + w / 2, y, bark)
			# edge lit: lantern-warm on the side facing it, cold moon on the other
			var lit_x = x0 if x0 + w / 2 > lamp.x else x0 + w - 1
			var near = clampf(1.0 - Vector2(lit_x, y).distance_to(lamp) / (20.0 * s), 0.0, 1.0)
			img.set_pixel(lit_x, y, Color("1c2a26").lerp(Color("6a4a22"), near))
	# clawing branches across the top
	var branches = [[4.0, 6.0, 1.0, 9], [4.0, 13.0, 1.0, 6], [32.0, 4.0, -1.0, 10], [35.0, 10.0, -1.0, 6], [11.5, 3.0, 1.0, 5]]
	for br in branches:
		var bx = br[0] * s
		var by = br[1] * s
		for k in br[3] * s:
			bx += br[2]
			by += -0.35 + sin(k * 0.5 / s) * 0.5
			var px = int(bx)
			var py = int(by)
			if px >= 0 and px < n and py >= 0 and py < n:
				img.set_pixel(px, py, trunk)
				if k < br[3] * s / 2:
					img.set_pixel(px, py + 1, trunk)
			# twigs like fingers near the tip
			if k > br[3] * s * 0.6 and k % (2 * s) == 0:
				for t in 2 * s:
					var tx = px + int(br[2] * t * 0.5)
					var ty = py - t
					if tx >= 0 and tx < n and ty >= 0:
						img.set_pixel(tx, ty, trunk)
	# ground: dark earth with a ragged grass edge
	var gy = int(H_GROUND * s)
	var earth := Color("101c13")
	var grass := Color("1f3a27")
	for x in n:
		var tuft = int(_hash(x, 5) * 3.0 * s / 2)
		for y in range(gy - tuft, n):
			img.set_pixel(x, y, grass if y < gy + s else earth)
		if _hash(x, 77) > 0.85:  # stones / roots
			img.set_pixel(x, gy + 2 * s, Color("1a221e"))
	# thorny brambles in the bottom corners
	for side in [-1, 1]:
		var cx = 0 if side == -1 else n - 1
		for k in 7 * s:
			var bx = cx - side * k
			var by = n - 1 - int(abs(sin(k * 0.7 / s)) * 4 * s) - k / 3
			if bx >= 0 and bx < n and by >= 0:
				img.set_pixel(bx, by, trunk)
				if k % (2 * s) == 1 and by - 1 >= 0:
					img.set_pixel(bx, by - 1, trunk)  # thorn
	# the figure's shadow on the ground
	var sh = H_FEET * s
	for y in range(int(sh.y - 3 * s), int(sh.y + 3 * s)):
		for x in range(int(sh.x - 10 * s), int(sh.x + 10 * s)):
			if x < 0 or x >= n or y < 0 or y >= n:
				continue
			var dx = (x - sh.x) / (9.0 * s)
			var dy = (y - sh.y) / (1.6 * s)
			var dd = dx * dx + dy * dy
			if dd < 1.0:
				img.set_pixel(x, y, img.get_pixel(x, y).darkened(0.55 * (1.0 - dd)))
	# lantern glow: same size every frame, brightness pulses
	for y in n:
		for x in n:
			var d = Vector2(x, y).distance_to(lamp) / (12.0 * s)
			if d < 1.0:
				var g = (1.0 - d) * (1.0 - d) * 0.5 * pulse
				img.set_pixel(x, y, img.get_pixel(x, y).lerp(Color("ffb050"), g))
	# fireflies: drifting on small loops, each glowing in its own rhythm
	var flies = [[5.0, 22.0], [9.5, 30.0], [33.5, 15.0], [21.5, 5.5], [14.0, 31.5], [27.0, 29.0], [2.5, 12.0], [17.0, 13.0]]
	for fi in flies.size():
		var ang = TAU * i / 6.0 + fi
		var fx = int((flies[fi][0] + cos(ang) * 0.8) * s)
		var fy = int((flies[fi][1] + sin(ang) * 0.6) * s)
		var b = 0.5 + 0.5 * sin(TAU * i / 6.0 + fi * 1.7)
		if b < 0.2:
			continue
		var core := Color("f0f890")
		img.set_pixel(fx, fy, img.get_pixel(fx, fy).lerp(core, 0.6 + 0.4 * b))
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var r = Vector2(dx, dy).length()
				if r == 0 or r > 2.3:
					continue
				var q = Vector2i(fx + dx, fy + dy)
				if q.x < 0 or q.y < 0 or q.x >= n or q.y >= n:
					continue
				img.set_pixelv(q, img.get_pixelv(q).lerp(Color("c8e070"), b * (0.4 if r <= 1.0 else 0.15)))


# ---------------------------------------------------------- werewolf loop

const W_MOON := Vector2(27.5, 13.5)
const W_MOON_R := 11.8
const W_EYE := Vector2i(37, 20)


## The modern painted werewolf (57x65) in 6 frames: clouds drift across the
## moon, the eye pulses, rain falls.
func _wolf_anim() -> Image:
	var base := _load(WOLF_MODERN)
	var w := base.get_width()
	var h := base.get_height()
	var sheet := Image.create(w * 2, h * 3, false, Image.FORMAT_RGBA8)
	for i in 6:
		var f: Image = base.duplicate()
		# clouds: dark bands that only show over the bright moon
		for band in [[-14.0, 9, 3, 18], [-4.0, 16, 2, 14], [-24.0, 5, 2, 12]]:
			var x0: float = band[0] + i * 3.0
			var y0: int = band[1]
			var thick: int = band[2]
			var ln: int = band[3]
			for k in ln:
				var x := int(W_MOON.x - W_MOON_R + x0 + k)
				var t := int(thick * (0.6 + 0.4 * sin(k * 0.5)))
				for dy in t:
					var y := y0 + dy
					if x < 0 or x >= w or y < 0 or y >= h:
						continue
					var c := f.get_pixel(x, y)
					if c.get_luminance() > 0.55 and Vector2(x + 0.5, y + 0.5).distance_to(W_MOON) <= W_MOON_R + 1.0:
						var edge := k == 0 or k == ln - 1
						f.set_pixel(x, y, c.lerp(Color("2a3a70"), 0.45 if edge else 0.7))
		# eye pulse
		var glow: float = [0.0, 0.3, 0.7, 1.0, 0.6, 0.2][i]
		f.set_pixelv(W_EYE, Color("ffc020").lerp(Color("fff4b0"), glow))
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var q: Vector2i = W_EYE + d
			f.set_pixelv(q, f.get_pixelv(q).lerp(Color("ffc020"), 0.35 * glow))
		# rain: slanted streaks falling down-left; each drop moves h/6 per
		# frame so the loop closes after 6 frames.
		for drop in 34:
			var x0 := int(_hash(drop, 7) * (w + 12))
			var y0 := int(_hash(drop, 13) * h)
			var far := _hash(drop, 29) < 0.5  # far drops: shorter, fainter
			var travel := (y0 + i * h / 6.0)
			var y := int(fmod(travel, h))
			var x := int(fposmod(x0 - travel * 0.35, w + 12)) - 6
			var length := 2 if far else 3
			var alpha := 0.28 if far else 0.5
			for k in length:
				var px := x - int(k * 0.35)
				var py := y - k
				if px >= 0 and px < w and py >= 0 and py < h:
					f.set_pixel(px, py, f.get_pixel(px, py).lerp(Color("b8c8f0"), alpha * (1.0 - k * 0.25)))
		# a few splashes on the ground line
		for sp in 4:
			if (i + sp) % 3 == 0:
				var sx := int(_hash(sp, i + 40) * w)
				var sy := h - 2 - int(_hash(sp, 3) * 4)
				for d in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1)]:
					var q: Vector2i = Vector2i(sx, sy) + d
					if q.x >= 0 and q.x < w:
						f.set_pixelv(q, f.get_pixelv(q).lerp(Color("b8c8f0"), 0.4))
		sheet.blit_rect(f, Rect2i(0, 0, w, h), Vector2i((i % 2) * w, (i / 2) * h))
	return sheet


