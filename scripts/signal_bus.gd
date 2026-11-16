extends Node

#Test
signal _add_player

# Game Function signals
signal _exit_game
signal _new_game
signal _start_game
signal begin_turn
signal end_turn
signal _end_game

signal _set_character
signal _attach_deck
signal set_locations
## A player's pawn moved to a location: (player_id, location_id)
signal pawn_moved
## You rolled a 7: pick one of these location ids. (options: Array)
signal choose_location

## Avatar Creation signals (might include avatar movement or actions as well)
signal _avatar_created
## Someone's pawn choice changed, so refresh which pawns are still free.
signal pawns_changed


# Navigation
signal _return_to_main_menu
signal _return_to_multiplayer_menu
