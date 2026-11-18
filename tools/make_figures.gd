extends SceneTree
## Writes the map figures (assets/pawns/figures/<kind>_<colour>.png, 64x64,
## like the pawns): what a player's pawn turns into once their character is
## revealed (vampire, werewolf, human) and once they die (grave). Drawn after
## the portraits (tools/make_portraits.gd) in the hooded pawns' style: a
## 32x32 grid at 2x, the player's colour ramp read from that colour's pawn,
## the pawn's game-piece base copied under each figure.
## Rows are LEFT HALVES (16 chars), mirrored; the mirror map swaps lit
## letters for shaded ones on the right. Overlays add asymmetric details.
## Run: godot --headless --path . --script tools/make_figures.gd
## Then open the editor once (or run check_project) so Godot imports them.

const OUT := "res://assets/pawns/figures/%s_%s.png"

const COLOURS := ["red", "blue", "green", "yellow", "purple", "orange", "light_blue", "white"]

const COMMON := {
	"O": "120d14",
	"n": "2a2030", "m": "40324a",  # dark cloth
	"k": "1a1420", "h": "3a3050",
}

## Vampire after the new portrait: spiky hair with a silver streak, pale
## lavender skin, red eyes, violet suit, white cravat, cape in player colour.
const VAMPIRE := {
	"pal": {"k": "1a1420", "h": "3a3050", "L": "8e88aa", "p": "e6dcef", "s": "b4a2c8",
		"r": "c01818", "R": "ff5a4a", "w": "f4ecf4", "x": "5a1020",
		"v": "4a3466", "V": "5a4288", "n": "2e2042"},
	"mirror": {"B": "C", "V": "v", "L": "k", "h": "k"},
	"rows": [
		"................",
		"..........O...O.",
		"..........OkO.Ok",
		".........Okkhkkk",
		".....O..OkLLkkkk",
		".....OO.OkLLpppk",
		".....OBOOkLppppp",
		"....OBDOsOpppppp",
		"....OBDDOOpkkkpp",
		"....OBDDnOprRkpp",
		"....OBDDnOppppps",
		"....OBDDnnOpppxx",
		"....OBDDnnnOppwp",
		"....OBDDnnnnOOpp",
		"...OBDDDnnnnnwOO",
		"...OBDDDDDDvVwww",
		"...OBDDDDDDvVvww",
		"...OBDDDDDDvVvvr",
		"...OBDDDDDDpVvvv",
		"..OBDDDDDDDvVvvv",
		"..OBDDDDCDDvVvvv",
		"..OBDDDCDDDvVvvv",
		".OBDDDCDDDDvVvvv",
		".OBDDCDDDCDvVvvv",
		"OBDDCDDDCDDvVvvv",
		"OBOODOODOODvVvvv",
		".O..O...........",
	],
	"overlay": [],
}

## Werewolf after the painting: grey-violet fur, yellow eyes, pale chest
## ruff, fangs; a torn sash and the loincloth in the player's colour.
const WEREWOLF := {
	"pal": {"g": "8a86b0", "f": "5e5a86", "e": "3e3a5e", "i": "9a6a8a",
		"y": "ffc020", "Y": "fff0a0", "l": "75719c", "x": "1a1420", "t": "f2ecd0",
		"w": "e0dcf2", "v": "a8a4c8"},
	"mirror": {"B": "C", "g": "f", "f": "e", "w": "v"},
	"rows": [
		"........O.......",
		"........OO......",
		"........OgO.....",
		"........OgiO....",
		".......OggiiOOOO",
		".......Oggiggggg",
		"......Oggggeeeff",
		"......OgggyYefff",
		"....Ogggggggffll",
		".....OgfffffOlll",
		".......OffffOlll",
		"..O.O....OffOllx",
		".OgOgOOOOOOOxtxx",
		"OggggfgwwwwwOlll",
		"OggggfgwwwwwwOOO",
		"Oggggfegwwvwwwww",
		"Oggggfeggwvwwvww",
		"Ogggffeggggvwwvw",
		"Ogggffegggggfggf",
		"OgfffeOggggfgggf",
		"OftfOOggggfggggf",
		"OtOtOOBDDDDDDDDD",
		"...OggBDDDDDDDDD",
		"...OggfBDDDDDDDD",
		"...OggffOBDDDDDD",
		"...OggffOOBDDDDD",
		"...OOO..........",
	],
	"overlay": [],
	"sash": true,
}

## Human after the new portrait, hood pulled down: brown hair, face, the
## hood bunched round the neck and the cloak in the player's colour, tan
## strap, belt and buckle, lantern.
const HUMAN := {
	"pal": {"u": "7a4e2c", "U": "5b3820", "q": "eeb97f", "z": "c48a55", "k": "1a1020",
		"l": "c4b690", "L": "7e7058", "e": "5b3820", "Y": "ffd15a", "Z": "ff8a2a"},
	"mirror": {"B": "C", "l": "L", "u": "U"},
	"rows": [
		"................",
		"................",
		"............OOOO",
		"...........Ouuuu",
		"..........Ouuuuu",
		"..........Ouuqqq",
		"..........Ouqqqq",
		"..........Ouqkqq",
		"..........Ouqqqq",
		"...........Oqqqz",
		"........OBDDOqqq",
		".......OBDDDDOzz",
		"......OBBBBBBBBB",
		"......OCDDDDDDCl",
		"......OBDDDDDDDl",
		"......OBDDDDDDDl",
		"......OBDDDDDDDl",
		"......OBDqDDDDDl",
		"......OBDDDDDeeY",
		".....OBDDDDDDDDl",
		".....OBDDDDDDDDl",
		"....OBDDDDDDDDDl",
		"....OBDDDDDDDDDl",
		"...OBDDCDDDDDDDl",
		"...OBDDCDDDDCDDl",
		"...OBDDCDDDDCDDl",
	],
	## The lantern, held out on the right: [row, col, letter].
	"overlay": [
		[14, 26, "O"], [15, 26, "q"], [15, 27, "O"],
		[16, 26, "O"], [16, 27, "O"],
		[17, 25, "O"], [17, 26, "k"], [17, 27, "k"], [17, 28, "O"],
		[18, 25, "O"], [18, 26, "Y"], [18, 27, "Z"], [18, 28, "O"],
		[19, 25, "O"], [19, 26, "Y"], [19, 27, "Z"], [19, 28, "O"],
		[20, 25, "O"], [20, 26, "k"], [20, 27, "k"], [20, 28, "O"],
		[21, 26, "O"], [21, 27, "O"],
	],
}

## Gravestone: a gothic stone with a crack; the whole cross in the player's
## colour (lit left half, shaded right), set into the stone with a dark rim.
const GRAVE := {
	"pal": {"T": "b4b4c0", "S": "8a8a96", "U": "5a5a66",
		"e": "3a2e26", "f": "5a4636", "G": "3a6a3a", "H": "5a8a4a"},
	"mirror": {"T": "U", "B": "C", "f": "e"},
	"rows": [  # 4 rows lower than drawn before: the mound sits where pawn bases stand
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"...............O",
		"..............OT",
		".............OTT",
		"............OTTS",
		"...........OTTSS",
		"..........OTTSSU",
		".........OTTSSUB",
		"........OTTSUUUB",
		"........OTTUDDDB",
		"........OTTUDDDB",
		"........OTTSUUUB",
		"........OTTSSSUB",
		"........OTTSSSUB",
		"........OTTSSSUB",
		"........OTTSSSUB",
		"........OTTSSSSU",
		"........OTTSSSSS",
		"........OTTSSSSS",
		"........OTTSSSSS",
		"........OTTSSSSS",
		"........OTTSSSSS",
		"......OGHGffffff",
		".....OHGfeeeeeee",
		"......OOOOOOOOOO",
	],
	"overlay": [[19, 20, "O"], [20, 20, "O"], [21, 21, "O"], [22, 21, "O"], [23, 20, "O"], [24, 21, "O"]],
}



func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/pawns/figures"))
	for colour in COLOURS:
		var pawn := Image.load_from_file(ProjectSettings.globalize_path("res://assets/pawns/%s.png" % colour))
		pawn.convert(Image.FORMAT_RGBA8)
		var ramp := {"B": pawn.get_pixel(26, 6), "D": pawn.get_pixel(26, 8), "C": pawn.get_pixel(36, 6)}
		var figures := {
			"vampire": _figure(VAMPIRE, ramp, pawn),
			"werewolf": _figure(WEREWOLF, ramp, pawn),
			"human": _figure(HUMAN, ramp, pawn),
			"grave": _figure(GRAVE, ramp, null),
		}
		for kind in figures:
			figures[kind].save_png(ProjectSettings.globalize_path(OUT % [kind, colour]))
	print("figures written")
	quit()


func _full_rows(spec: Dictionary) -> Array:
	var grid := []
	for r in spec.rows.size():
		var line: String = spec.rows[r]
		if line.length() == 16:
			var right := ""
			for i in range(15, -1, -1):
				var ch := line[i]
				right += spec.mirror.get(ch, ch)
			line += right
		if line.length() != 32:
			push_error("row %d is %d wide: %s" % [r, line.length(), line])
		grid.append(line)
	for p in spec.overlay:
		var line: String = grid[p[0]]
		grid[p[0]] = line.substr(0, p[1]) + p[2] + line.substr(p[1] + 1)
	# A torn sash from the left shoulder down to the right hip, over the fur.
	if spec.get("sash", false):
		for k in 7:
			var r := 15 + k
			var c := 6 + 2 * k
			for cell in [[r, c, "B"], [r, c + 1, "D"]]:
				var line: String = grid[cell[0]]
				if cell[1] < 32 and line[cell[1]] in ["g", "f", "e", "w", "v"]:
					grid[cell[0]] = line.substr(0, cell[1]) + cell[2] + line.substr(cell[1] + 1)
	return grid


func _figure(spec: Dictionary, ramp: Dictionary, base_from: Image) -> Image:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	if base_from != null:
		img.blit_rect(base_from, Rect2i(0, 52, 64, 12), Vector2i(0, 52))
	var grid := _full_rows(spec)
	for r in grid.size():
		var line: String = grid[r]
		for c in line.length():
			var ch := line[c]
			if ch == ".":
				continue
			var col: Color
			if ramp.has(ch):
				col = ramp[ch]
			elif spec.pal.has(ch):
				col = Color(spec.pal[ch])
			elif COMMON.has(ch):
				col = Color(COMMON[ch])
			else:
				push_error("unknown letter %s in row %d" % [ch, r])
				continue
			img.fill_rect(Rect2i(c * 2, r * 2, 2, 2), col)
	return img


