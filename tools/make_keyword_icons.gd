extends SceneTree
## Writes the keyword icons (assets/icons/kw_*.png): 12x12 pixel drawings at
## 2x (24 px), the dark outline and chunky pixels of the other icons there.
## Card and ability texts show them before their keywords (see Keywords).
## Run: godot --headless --path . --script tools/make_keyword_icons.gd
## Edit a drawing below and run again; or replace a PNG by hand.

const SCALE := 2
const OUT := "res://assets/icons/kw_%s.png"
const OUTLINE := "1a1418"

## Each: palette (k is the outline, . is clear) and 12 rows of 12.
const ICONS := {
	"damage": {"m": "d8302a", "l": "ff8a70", "d": "8a1414", "rows": [
		".....kk.....",
		"....kmmk....",
		"....kmmk....",
		"...kmmmmk...",
		"...kmlmmk...",
		"..kmlmmmmk..",
		"..kmlmmmmk..",
		".kmmmmmmmdk.",
		".kmmmmmmmdk.",
		".kdmmmmmddk.",
		"..kddmmddk..",
		"...kkkkkk...",
	]},
	"heal": {"m": "3fbf5a", "l": "b8f5b0", "d": "1f7a35", "rows": [
		"............",
		"..kk....kk..",
		".kmmk..kmmk.",
		"kmllmkkmmmmk",
		"kmlmmmmmmmmk",
		"kmmmmmmmmmdk",
		"kmmmmmmmmmdk",
		".kmmmmmmmdk.",
		"..kmmmmmdk..",
		"...kmmmdk...",
		"....kmdk....",
		".....kk.....",
	]},
	"attack": {"m": "e0e4ee", "d": "8890a0", "g": "c89a40", "rows": [
		"..........kk",
		".........kmk",
		"........kmdk",
		".......kmdk.",
		"......kmdk..",
		".....kmdk...",
		".k..kmdk....",
		".kgkmdk.....",
		"..kgdk......",
		".kgkgk......",
		"kgk..k......",
		"kk..........",
	]},
	"vampire": {"m": "a83030", "d": "5a1018", "l": "ffcc66", "rows": [
		"............",
		"....k..k....",
		"...kmkkmk...",
		"k..kmmmmk..k",
		"kk.kmlmlk.kk",
		"kmkkmmmmkkmk",
		"kmmkmmmmkmmk",
		"kmmmmmmmmmmk",
		"kmkmmmmmmkmk",
		"kk.kmmmmk.kk",
		"k...kddk...k",
		".....kk.....",
	]},
	"werewolf": {"m": "e0a84c", "d": "9a6a20", "rows": [
		"...kk..kk...",
		"..kmmkkmmk..",
		"..kmmkkmmk..",
		"kk.kk..kk.kk",
		"kmk......kmk",
		"kmk.kkkk.kmk",
		".k.kmmmmk.k.",
		"..kmmmmmmk..",
		".kmmmmmmmmk.",
		".kmmmmmmmmk.",
		"..kmmddmmk..",
		"...kk..kk...",
	]},
	"human": {"m": "8fb8e0", "l": "d0e6fa", "d": "4a78a8", "rows": [
		"....kkkk....",
		"...kmmmmk...",
		"..kmlmmmmk..",
		"..kmmmmmmk..",
		"..kmmmmmdk..",
		"...kmmmdk...",
		"....kkkk....",
		"..kkmmmmkk..",
		".kmmmmmmmmk.",
		"kmlmmmmmmmdk",
		"kmmmmmmmmmdk",
		"kkkkkkkkkkkk",
	]},
	"equipment": {"m": "e8c060", "l": "fff0b0", "d": "a07820", "rows": [
		"..kkkkkkkk..",
		"..kllllllk..",
		"..klmmmmdk..",
		"..kmmkkmdk..",
		"..kmkllkdk..",
		"..kmkllkdk..",
		"..kmmkkmdk..",
		"..kmmmmmdk..",
		"..kmmmmmdk..",
		"..kmmmmmdk..",
		"..kdddddk...",
		"..kkkkkkk...",
	]},
	"reach": {"m": "7ac8f0", "l": "d8f2ff", "rows": [
		"....kkkk....",
		"..kkmmmmkk..",
		".kmmkkkkmmk.",
		".kmk....kmk.",
		"kmk..kk..kmk",
		"kmk.klmk.kmk",
		"kmk.kmmk.kmk",
		"kmk..kk..kmk",
		".kmk....kmk.",
		".kmmkkkkmmk.",
		"..kkmmmmkk..",
		"....kkkk....",
	]},
	"dice": {"m": "f0ece0", "d": "b0a890", "rows": [
		".kkkkkkkkkk.",
		"kmmmmmmmmmdk",
		"kmkkmmmmmmdk",
		"kmkkmmmmmmdk",
		"kmmmmmmmmmdk",
		"kmmmmkkmmmdk",
		"kmmmmkkmmmdk",
		"kmmmmmmmmmdk",
		"kmmmmmmmkkdk",
		"kmmmmmmmkkdk",
		"kddddddddddk",
		".kkkkkkkkkk.",
	]},
	"secret": {"m": "b07ae8", "l": "ffffff", "d": "6a3aa0", "rows": [
		"............",
		"............",
		"....kkkk....",
		"..kkmmmmkk..",
		".kmmkkkkmmk.",
		"kmmkllkkkmmk",
		"kmmklkkkkmmk",
		".kmmkkkkmmk.",
		"..kkddddkk..",
		"....kkkk....",
		"............",
		"............",
	]},
}


func _init() -> void:
	for icon_name in ICONS:
		var icon: Dictionary = ICONS[icon_name]
		var rows: Array = icon.rows
		var image := Image.create(12 * SCALE, 12 * SCALE, false, Image.FORMAT_RGBA8)
		image.fill(Color(0, 0, 0, 0))
		for y in 12:
			var row: String = rows[y]
			assert(row.length() == 12, "%s row %d" % [icon_name, y])
			for x in 12:
				var ch := row[x]
				if ch == ".":
					continue
				var colour := Color(OUTLINE if ch == "k" else icon[ch])
				image.fill_rect(Rect2i(x * SCALE, y * SCALE, SCALE, SCALE), colour)
		var path := OUT % icon_name
		image.save_png(ProjectSettings.globalize_path(path))
		print("wrote ", path)
	quit()
