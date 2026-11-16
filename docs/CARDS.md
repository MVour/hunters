# Cards

The card set, following the rules in RULES.md. Each card has an English
and a Greek name and description (the Greek texts live in `scripts/cards.gd`,
as `name_el` / `text_el`). Keep this file and the data in
sync when editing.

- **Green (Πράσινες): questions.** The drawer reads it secretly and gives
  it to another player. That player reads it secretly and must react
  truthfully for their faction. The game applies the effect automatically
  (the server knows everyone's species), so nobody can lie by mistake.
  Only the giver and the receiver see the card; everyone sees the result.
- **Red (Κόκκινες): hostile.** Events and equipment that cause damage,
  sometimes to the drawer too.
- **Blue (Μπλε): helpful.** Events and equipment that never hurt you.
- **Events** marked **(must)** happen immediately; the others are optional.
- **Equipment** stays face-up in front of its owner and is always active.

## Green: questions (14)

| # | Name | Όνομα | Effect on the receiver |
|---|------|-------|------------------------|
| 2 | Silver Coin | Ασημένιο Νόμισμα | If you are a **werewolf**, take 1 damage. |
| 2 | Garlic Bread | Σκορδόψωμο | If you are a **vampire**, take 1 damage. |
| 2 | Clean Hands | Καθαρά Χέρια | If you are a **human**, heal 1 damage. Otherwise take 1 damage. |
| 1 | Full Moon Rising | Πανσέληνος | If you are a **werewolf** or a **human**, take 1 damage. |
| 1 | Cold Skin | Παγωμένο Δέρμα | If you are a **vampire** or a **human**, take 1 damage. |
| 1 | Blood Debt | Χρέος Αίματος | If you are a **vampire**, give the asker one equipment card, or take 1 damage if you have none. |
| 1 | Pack Tax | Φόρος της Αγέλης | If you are a **werewolf**, give the asker one equipment card, or take 1 damage if you have none. |
| 1 | Night Watch | Νυχτερινή Σκοπιά | If you are **not** a human, take 1 damage. |
| 1 | Hunter's Hunch | Προαίσθημα του Κυνηγού | If you are **not** a werewolf, heal 1 damage. Otherwise take 2 damage. |
| 1 | Mirror in the Hall | Ο Καθρέφτης του Διαδρόμου | If you are a **vampire**, show your character card to the asker only. |
| 1 | Whispered Name | Ψιθυριστό Όνομα | Tell the asker your character's starting health, truthfully. |

## Red: hostile (16)

### Equipment (6)

| Name | Όνομα | Effect (always active) |
|------|-------|------------------------|
| Silver Dagger | Ασημένιο Στιλέτο | Your attacks deal +1 damage. |
| Hunter's Crossbow | Βαλλίστρα του Κυνηγού | You may attack players at **any** location (ignores reach). |
| Wolfsbane Axe | Τσεκούρι του Λυκοκτόνου | Your attacks deal +1 damage. |
| Barbed Gauntlet | Αγκαθωτό Γάντι | When you attack, roll only the d6: the result is the damage (no difference). |
| Rusty Bear Trap | Σκουριασμένη Παγίδα | Anyone who attacks you takes 1 damage. |
| Cursed Ring | Καταραμένο Δαχτυλίδι | Your attacks deal +2 damage, but you take 1 damage at the start of each of your turns. |

### Events (10)

| # | Name | Όνομα | Effect |
|---|------|-------|--------|
| 2 | Swarm of Bats (must) | Σμήνος Νυχτερίδων | Deal 2 damage to a player of your choice, and heal 1 yourself. |
| 1 | Forest Fire (must) | Φωτιά στο Δάσος | Everyone at your location and the next one (including you) takes 2 damage. |
| 1 | Bad Mushrooms (must) | Χαλασμένα Μανιτάρια | You take 2 damage. |
| 1 | Blood Moon (must) | Ματωμένο Φεγγάρι | Every player except you takes 1 damage. |
| 2 | Ambush | Ενέδρα | Deal 3 damage to a player within reach; you take 1 damage. |
| 1 | Thief in the Night | Κλέφτης της Νύχτας | Steal one equipment card from any player. |
| 1 | Wolf's Bite (must) | Δάγκωμα Λύκου | Choose a player: they take 2 damage. If they are a vampire, they take 3 instead. |
| 1 | Grave Robbery | Τυμβωρυχία | Take one equipment card of your choice from a dead player. |

## Blue: helpful (16)

### Equipment (6)

| Name | Όνομα | Effect (always active) |
|------|-------|------------------------|
| Lucky Rabbit Foot | Γούρικο Ποδαράκι Λαγού | Attacks against you deal 1 less damage. |
| Holy Amulet | Ιερό Φυλαχτό | Red events can't damage you. |
| Healer's Satchel | Σακίδιο του Θεραπευτή | At the start of your turn, heal 1 damage. |
| Widow's Lantern | Το Φανάρι της Χήρας | Your reach extends to the location **before** yours too. |
| Old Map | Παλιός Χάρτης | When you roll to move, you may roll a second time and pick either result. |
| Iron Shield | Σιδερένια Ασπίδα | You can't take more than 3 damage from a single attack. |

### Events (10)

| # | Name | Όνομα | Effect |
|---|------|-------|--------|
| 2 | Healing Spring | Ιαματική Πηγή | Heal 2 damage. |
| 1 | Campfire Rest | Ανάπαυση στη Φωτιά | Every player at your location heals 1 damage. |
| 1 | Second Wind | Δεύτερη Ανάσα | If you have 5 or more damage, heal 3. Otherwise heal 1. |
| 1 | Guardian Spirit (must) | Πνεύμα Φύλακας | Until your next turn, nobody can attack you. |
| 1 | Shortcut | Κρυφό Μονοπάτι | Move to any location (like rolling a 7). |
| 1 | Moonlit Insight | Φεγγαρόφωτη Ματιά | Secretly look at another player's character card. |
| 1 | Lucky Find | Τυχερό Εύρημα | Draw a card of any colour. |
| 1 | Peace Offering | Δώρο Ειρήνης | Give one of your equipment cards to another player; both of you heal 1. |
| 1 | Sanctuary | Καταφύγιο | Heal 1 damage on any player of your choice. |
