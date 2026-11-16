@tool
class_name ClassicBoard extends Node2D
## The ORIGINAL board (Feb 2025): the 16px path-tile loop from the first
## TileMapLayer, with the old chapel art on the locations and a panel of
## FOREST.webp as the backdrop. Shown instead of ForestBoard when
## Global.classic_art is on. Open scenes/classic_board.tscn to paint tiles.

## The old map was laid out around (816, 588); this moves it so the loop
## sits in the same screen area the current HUD and buttons expect.
const OFFSET := Vector2(112, -118)

## The old TileMapLayer's Position1..6 markers (before OFFSET).
const POSITIONS := [
	Vector2(1135, 384), Vector2(1136, 640), Vector2(1008, 768),
	Vector2(722, 792), Vector2(496, 576), Vector2(687, 384),
]

## Where pawns wait before their first move: the middle of the loop.
const START_POS := Vector2(816, 600) + OFFSET

## Which FOREST.webp panel (256x256 each, 4x4 grid) is the backdrop.
const BACKDROP_PANEL := Vector2i(0, 2)
const SCREEN := Vector2(1920, 1080)


static func location_position(index: int) -> Vector2:
	return POSITIONS[(index - 1) % POSITIONS.size()] + OFFSET


func _ready() -> void:
	$TileMapLayer.position = OFFSET
	var backdrop: Sprite2D = $Backdrop
	backdrop.region_rect = Rect2(Vector2(BACKDROP_PANEL) * 256.0, Vector2(256, 256))
	# Whole-number scale keeps the pixel art crisp; cover the screen and centre.
	var s := ceilf(maxf(SCREEN.x, SCREEN.y) / 256.0)
	backdrop.scale = Vector2(s, s)
	backdrop.position = (SCREEN - Vector2(256, 256) * s) / 2.0
