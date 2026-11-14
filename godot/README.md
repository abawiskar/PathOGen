# PathOGen (Godot)

The Godot 4 version of PathOGen. The web version is built separately; both use the same game data from the team spreadsheet.

Open this `godot` folder in Godot 4.4 or newer. Press Play to see the debug screen, which lists everything that loaded and plays a quick test run of the first puzzle.

## Game data

All cards, puzzles, monsters and LifeSavers come from the **PathOGen: Puzzle Card Lists** sheet. Each tab is exported as a CSV into `data/`:

| Sheet tab | File |
|---|---|
| Puzzles | `data/puzzles.csv` |
| Puzzle Cards | `data/puzzle_cards.csv` |
| Cards | `data/cards.csv` |
| Monsters | `data/monsters.csv` |
| LifeSavers | `data/lifesavers.csv` |

Columns are matched by **header name**, so columns can be reordered or added in the sheet. Renaming a header means updating the matching `from_row()` in `scripts/data/`.

To test new numbers without touching the repo, drop the CSVs in the user data folder (`%APPDATA%\Godot\app_userdata\PathOGen\data\` on Windows). Those files win over the ones in `res://data/`. Press **F5** on the debug screen to reload.

Check the data from the command line:

```
godot --headless -s res://tests/run_checks.gd
```

It exits with code 1 if a puzzle lists an unknown card or monster, or two cards share a slot.

## Layout

```
data/              CSV exports from the sheet (imported as "keep", not translations)
scenes/            debug_main.tscn for now
scripts/autoload/  game_db.gd: the GameDB autoload that loads the CSVs
scripts/data/      CardData, MonsterData, LifeSaverData, PuzzleData, PuzzleCardEntry, enums, CSV reader
scripts/combat/    DamageCalc, PlayerState (hearts, energy, attack statuses), PuzzleSession (turns, draws, LifeSavers, stars)
scripts/debug/     the debug screen and report
tests/             headless data check
```

## Rules as currently coded (all still open for discussion)

- **Damage** = the sum of card damage on the path to the output × the number of items in the output × the monster's type modifier (×2 if weak, ×0.5 if it resists).
- **Lag:** if the output has more items than the puzzle's item cap, the definition deals no damage and the player loses a heart.
- **Monster turns:** an "Attack" intent takes hearts. Any other intent uses the monster's signature attack (Blurred Vision, Icon Curse, Scramble, Locked Component, Time Pressure), which lasts 1 or 2 turns.
- **Wrong moves** cost a heart unless Second Chance is armed.
- **Stars:** 1 for winning, +1 for finishing within par, +1 for using no LifeSavers that cost stars.
- **Deck:** puzzles draw one card per turn in the order the sheet lists them (no shuffle), so puzzles stay predictable.

## Not built yet

The canvas and node slots, the card hand UI, wiring and port checks, the Rhino-style viewport, and the UI side of the attacks and LifeSavers (blurring, hiding labels, timers, hints).
