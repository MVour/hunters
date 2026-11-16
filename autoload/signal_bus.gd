extends Node
## Every cross-scene event. UI listens here; LobbyNet/MatchNet emit after
## updating GameState. (Like store subscriptions.)

# Game Function signals
signal _exit_game
signal _new_game
signal _start_game
signal begin_turn
signal end_turn

signal _set_character
signal _attach_deck
signal set_locations
## The match's turn order is known: (player ids)
signal turn_order_set
## The dice were thrown: (val6, val4)
signal dice_rolled
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
## The server is waiting on these players to choose something: (player ids)
signal waiting_changed
## Public message: (text)
signal notice
## Something only you learn: (title, text)
signal private_info
## You get to see someone's character: (player_id, character)
signal private_character

# Lobby
## The local player picked a name + pawn in the avatar picker: (name, pawn)
signal _avatar_created
## A lobby player joined or changed: (player)
signal lobby_player_updated
## A lobby player left: (player_id)
signal lobby_player_removed
## The role counts changed: (settings)
signal lobby_settings_changed
## The server refused your pawn (someone took it first): (pawn)
signal avatar_rejected
## The server refused to start: (reason)
signal lobby_start_refused
## Someone's pawn choice changed, so refresh which pawns are still free.
signal pawns_changed


# Chat
## Someone said something: (player_id, player_name, text)
signal chat_message

# Navigation
signal _return_to_main_menu
signal _return_to_multiplayer_menu

# Combat & end
## An attack landed: (attacker_id, target_id, damage)
signal attack_happened
## A player used their once-per-game ability: (player_id)
signal ability_used
## The game ended: (faction "vampire"/"werewolf"/"none", winner ids)
signal game_over
## Leave the finished match and go back to the main menu.
signal leave_match
