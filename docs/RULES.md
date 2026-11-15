# Game rules

The design spec the code is built from. Translated from the original
Greek notes; where something isn't decided yet it says so.

## A turn

1. **Roll and move.** Roll both dice (d6 + d4). Move your pawn to the
   location whose numbers match the total (see the table below).
   - **On a 7** you may move to **any** location, but you must leave the one
     you're on.
2. **Location action.** Do what your new location offers (optional unless
   it says otherwise).
3. **Attack (optional).** Decide whether to attack someone.

> Steps 1–2 above are inferred from the location table; the original notes
> for these steps (α, β) weren't included yet.

## Attacking

- Roll both dice again. The **difference** between the two dice is the
  damage dealt to the target.
- You may only attack a player in **your own area**. The 6 locations are
  joined in pairs, forming **3 areas**.
- Exceptions to this come only from equipment a player owns.

## Locations

Shuffled around the board every game.

| Location      | Dice   | Action                                                        |
|---------------|--------|---------------------------------------------------------------|
| Lone Cabin    | 2, 3   | Draw a green card                                             |
| Widow's River | 4, 5   | Draw a card of any colour                                     |
| Old Chapel    | 6      | Draw a blue card                                              |
| *(any)*       | 7      | Move to any other location                                    |
| Cemetery      | 8      | Draw a red card                                               |
| Magic Forest  | 9      | Heal 1 on any player (yourself included), or deal 2 damage    |
| Stone Circle  | 10     | Steal an equipment card from any player                       |

## Cards

- **Events** are read aloud. If the card says **"must"**, it's carried out
  immediately; otherwise the player may choose not to.
- **Equipment** is read aloud, stays face-up in front of its owner, and is
  **always in effect**. Several pieces of equipment can add up, or cancel
  each other out.

## Characters

- Every character has an **ability**. It only works once the player
  **reveals** their character card; until then it doesn't apply.
- A player may reveal their card **whenever they like**, then uses the
  ability within that character's own limits.

## Death

- A character whose health runs out **dies** and that player is out of the
  game.
- They must reveal their character card (if they haven't already).
- The player who killed them takes **one equipment card** from the dead
  character.
