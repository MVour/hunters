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
## A player's damage changed: (player_id, damage)
signal damage_changed
## A character card is now public: (player_id, character)
signal character_revealed
## A player died and is out: (player_id, killer_id) - killer 0 = no one
signal player_died

# Cards
## Your new location offers this action (e.g. "draw_green"): (action)
signal location_action_offered
## A deck's size changed: (card_type, count)
signal deck_count_changed
## You drew a green question card: (card)
signal question_drawn
## Someone drew a card only they can see: (player_id, card_type)
signal card_drawn_secretly
## A red/blue card was read aloud: (player_id, card)
signal card_revealed
## Someone gave you a question: (from_id, card)
signal question_asked
## Public: who asked whom (from_id, to_id)
signal question_passed
## Public: the question was answered (from_id, to_id)
signal question_answered
## A player's equipment (or protection) changed: (player_id)
signal equipment_changed
## The server asks you to pick: (prompt, options, allow_skip)
signal choice_requested
## Public message: (text)
signal notice
## Something only you learn: (title, text)
signal private_info
## You get to see someone's character: (player_id, character)
signal private_character

## Avatar Creation signals (might include avatar movement or actions as well)
signal _avatar_created
## Someone's pawn choice changed, so refresh which pawns are still free.
signal pawns_changed


# Navigation
signal _return_to_main_menu
signal _return_to_multiplayer_menu
