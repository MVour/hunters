# Game rules

The design spec the code is built from. Translated from the original
Greek notes; where something isn't decided yet it says so.

## A turn

1. **Roll and move.** Roll both dice (d6 + d4). Move your pawn to the
   location whose numbers match the total (see the table below).
   - **On a 7** you may move to **any** location, but you must leave the one
     you're on.
2. **Location action.** Do what your new location offers. Drawing is a
   must: at a drawing location you click a deck (no skipping, and no ending
   the turn first). Magic Forest and Stone Circle are optional (D011).
3. **Attack (optional).** Decide whether to attack someone.

> Confirmed: steps 1–2 are the original steps α and β. If the dice point at
> the location you are already on, roll again: you always move somewhere new.

## Attacking

- Roll both dice again. The **difference** between the two dice is the
  damage dealt to the target.
- You may only attack a player **within reach**: at your own location or at
  the **next location clockwise** (1→2, 2→3 … 6→1). Since locations are
  shuffled every game, so are these groupings.
- Exceptions to this come only from equipment a player owns.

## Locations

Shuffled around the board every game.

| Location | Dice | Action |
|---|---|---|
| Lone Cabin · Μοναχική Καλύβα | 2, 3 | Draw a green card |
| Widow's River · Ποτάμι της Χήρας | 4, 5 | Draw a card of any colour |
| Old Chapel · Παλιό Παρεκκλήσι | 6 | Draw a blue card |
| *(any)* | 7 | Move to any other location |
| Cemetery · Νεκροταφείο | 8 | Draw a red card |
| Magic Forest · Μαγικό Δάσος | 9 | Heal 1 on any player (yourself included), or deal 2 damage |
| Stone Circle · Πέτρινος Κύκλος | 10 | Steal an equipment card from any player |

Names and action texts in both languages live in `autoload/global.gd`
(`deck.locations` `label` / `label_el`, `LOCATION_ACTIONS` `text` / `text_el`).

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
- *As built:* a player who **leaves** (disconnects) during a match is out
  the same way, with no killer: their card is revealed and nobody takes
  their equipment. Anything waiting on them is skipped; the game goes on.

## Characters (Χαρακτήρες)

Data with English + Greek texts: `data/characters.gd`.

| Side | Character | Health | Ability | Goal |
|------|-----------|--------|---------|------|
| Vampire | Volco · Βόλκο | 13 | *Passive:* heal 2 whenever your attack deals damage | No werewolves left standing |
| Vampire | Mel · Μελ | 14 | *When attacked:* strike back right away (not against the attack that kills you) | No werewolves left standing |
| Vampire | Selene · Σελήνη | 11 | *Once, your turn:* deal 1 damage to a player within reach, heal 1 | No werewolves left standing |
| Werewolf | Frederick · Φρειδερίκος | 12 | *Once, when attacking:* the damage is the d6 alone | No vampires left standing |
| Werewolf | Gregor · Γρηγόρης | 14 | *Once, when attacking:* the damage is the d4 alone | No vampires left standing |
| Werewolf | Bran · Μπραν | 13 | *Passive:* your attacks deal +1 damage | No vampires left standing |
| Human | Ada · Άντα | 8 | *Once, your turn:* heal all your damage | Survive until the end |
| Human | Hope · Ελπίδα | 8 | *Once, any time:* switch from backing the player on your right to the one on your left | Win if the player on your right wins |
| Human | Elias · Ηλίας | 10 | *Once, your turn:* secretly look at another player's character | Kill a vampire or a werewolf |
| Human | Iris · Ίρις | 9 | *Once, your turn:* heal 3 damage on any player | Survive until the end |

- **Abilities need a revealed card.** Using one reveals you. Passive
  abilities only work once you're revealed (the HUD has a Reveal button).
- **Right / left** (for Hope): the player on your right is the one who
  plays **after** you; the player on your left plays **before** you.

## Taking your turn (as built)

1. **Roll** — move to a new location (or choose, on a 7).
2. **Location action** — draw (a must), or Magic Forest / Stone Circle (or skip those).
3. **Attack** (optional, once) — pick a player within reach, then press
   the dice to throw them (so does a striking-back Mel, and Old Map's second
   roll). Equipment modifies the damage: +damage, d6 only, −1, at most 3, or hitting back.
4. **End turn.**

## End of the game

- The game ends when **all vampires** or **all werewolves** are dead.
- Then everyone checks their own goal: vampires/werewolves win as a side
  (dead members too), humans by their personal goal. Every character is
  revealed on the end screen.
