class_name BotWeights
## Every number the bots decide with, in one place, so playtests can tune
## them without touching the logic (server/bots/bot_brain.gd).
##
## Scores are "how much the bot wants this". Relations run from -1 (sure
## enemy) to +1 (sure friend); "enmity" is minus the relation.

# --- Pacing (seconds) -----------------------------------------------------------
## Pause before each bot action, so people can follow what happened.
const THINK_MIN := 0.7
const THINK_MAX := 1.4
## Longer pause before a bot's turn starts.
const TURN_START := 1.0

# --- Attacking ------------------------------------------------------------------
## Attack when the best target scores above this.
const ATTACK_THRESHOLD := 0.15
## How eager each goal is to attack someone it knows nothing about.
const AGGRESSION := {
	"no_werewolves": 0.3,   # vampires
	"no_vampires": 0.3,     # werewolves
	"hunter": 0.2,          # Elias
	"neighbour_wins": 0.0,  # Hope
	"survive": -0.35,       # Ada, Iris: only fight back
}
## Aggression grows a little every round, so games end.
const AGGRESSION_PER_ROUND := 0.04
## Never attack someone this friendly.
const NEVER_ATTACK_ABOVE := 0.4
## Bonus for a target that could die from this hit.
const KILL_BONUS := 0.6
## Hunter (Elias) bonus for finishing off a likely monster (his goal).
const HUNTER_KILL_BONUS := 0.8
## Frederick/Gregor use their one-die attack on a target at least this hostile.
const ABILITY_DIE_ENMITY := 0.45

# --- Beliefs (server/bots/bot_mind.gd) -------------------------------------------
## Someone hit me: how much more likely they're on the other side.
const HIT_ME_ENEMY := 1.8
const HIT_ME_FRIEND := 0.55
## Someone hit / helped a player whose side is fairly clear.
const HIT_OTHER_ENEMY := 1.4
const HIT_OTHER_FRIEND := 0.7
const HELP_FRIEND := 1.5
const HELP_ENEMY := 0.7
## A side counts as "fairly clear" from this probability up.
const CLEAR_SIDE := 0.7
## Soft evidence never pushes past these multipliers.
const LEAN_MIN := 0.15
const LEAN_MAX := 6.0
## Each damage point someone did to me makes them this much more an enemy
## (relation), up to GRUDGE_MAX. Healing me works the other way.
const GRUDGE_PER_DAMAGE := 0.15
const GRUDGE_MAX := 0.6
const THANKS_PER_HEAL := 0.15
const THANKS_MAX := 0.4

# --- Moving & location actions ----------------------------------------------------
const DECK_VALUE := {
	"green_cards": 0.5,  # questions: + how much is still unknown
	"red_cards": 0.5,    # + for fighters
	"blue_cards": 0.6,   # + when hurt
}
const GREEN_PER_UNKNOWN := 0.4
const RED_FIGHTER_BONUS := 0.3
const BLUE_PER_DAMAGE := 0.12
const MAGIC_FOREST_BASE := 0.4
const STEAL_BASE := 0.7
## Moving: value of having a likely enemy within reach (fighters) or of
## staying out of enemies' reach (survivors).
const REACH_ENEMY := 0.5
const AVOID_ENEMY := 0.4

# --- Questions --------------------------------------------------------------------
## Value of learning about someone (per unit of uncertainty) vs. hurting them.
const QUESTION_INFO := 0.6
const QUESTION_HARM := 0.5

# --- Abilities --------------------------------------------------------------------
## Ada heals everything once she has this much damage.
const FULL_HEAL_AT := 4
## Iris heals someone (maybe herself) with at least this much damage.
const HEAL_OTHER_AT := 3
## Volco/Bran reveal (to turn on their passive) from this round, when attacking.
const REVEAL_PASSIVE_ROUND := 3
## Elias peeks from this round on.
const PEEK_ROUND := 2
## Selene drains a merely likely enemy from this round on (a clear one any time).
const DRAIN_ROUND := 3
