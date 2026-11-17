# Eggheads vs. Meatheads — Proof of Concept

A playable grey-box slice of the design docs in this repo: **"The Foundry of Force"**.

![Gameplay screenshot (Web build)](docs/screenshot.png)

It covers the scope set out in *Proof of Concept Readiness Assessment.txt*:

| PoC requirement | What's in the build |
|---|---|
| Flat arena, 10 Eggheads vs 1 Meathead (scaled-down 10:1) | 40×40 arena; you + 9 bot Eggheads vs 1 Meathead |
| One Egghead objective | Push iron blocks onto **The Forge**, stand on it and **type the engineering term** (TRUSS, CANTILEVER, TENSILE…) to temper one. Temper **5** before the **3:00** clock runs out. |
| One Meathead disruption | **Charge** (cracks Eggheads), **belly-flop** (area stun), **grab & yeet** (wall splat = stun), **grease spill** |
| Stealth-learning mechanics | **HABEAS CORPUS** terminal: type the writ to free a captured Egghead, stun the Meathead and raise a barrier. **SUBPOENA** podium: type it to drag the Meathead across the arena to the Witness Stand and pin it there. Tiles: **ALLEGRO** (fast), **ADAGIO** (slow but grab- and charge-proof), **OBSIDIAN** (immune to belly-flop). |
| Pre-match Firewall | On the title screen the Meathead side picks **OPEN BOOK** (no sabotage) or **NO VOWELS**: every word Eggheads must type is shown with A/E/I/O/U blanked out (`F_LCR_M`), so they have to know it. |
| Title / how-to-play | The game opens paused on a title screen explaining both sides, the learning mechanics, and the Firewall choice. |
| Fragile vs clumsy physics | Eggheads crack and respawn in the Library after 4s. The Meathead has deliberately delayed input, sluggish turning while charging, and is winded after a belly-flop. |
| Scoring | Eggheads: blocks tempered (IQ). Meathead: **Heat** from cracks, yeets, splats and flops. |
| Feedback | Synthesized sound effects for every action and a trauma-based screen shake that scales with impact (cracks, splats and belly-flops hit hardest). |

## Controls

**Egghead (you, the gold egg with the marker):** `WASD` move · walk onto a station and type the
word shown (movement is frozen while typing) · `Esc` step away · mash `WASD` to wriggle out of a grab.

**Meathead:** an AI plays it by default so you can test solo. A second player takes over automatically
when they touch its controls:
- Keyboard: arrow keys move · `Enter` charge · `Right Shift` grab/yeet · `Right Ctrl` grease · `/` belly-flop
- Gamepad: left stick · `A` charge · `X` grab/yeet · `B` grease · `Y` belly-flop
- `F2` toggles the Meathead between AI and human.

`F3` toggles screen shake · `F4` mutes sound.

**Title screen:** Left/Right picks the Meathead's Firewall, `Enter` / `Space` / gamepad `A` starts.
After a round: `R` for a rematch (same Firewall, skips the title), `T` back to the title screen.

## Running it

Requires **Godot 4.2.x** (standard build, not .NET). Open `EggheadsVsMeatheads/project.godot` in the
editor and press **F5**, or run it from the command line:

```bash
cd EggheadsVsMeatheads && godot
```

The project uses the **Compatibility** renderer so the same build runs on desktop and in the browser.

## Tests

The headless test suite loads the real `main.tscn` and steps physics, covering grab/yeet/wall-splat,
charge-crack/respawn, belly-flop vs Obsidian, Allegro, grease, Habeas Corpus, Esc-to-cancel, the forge
win condition, the timer loss, struggle-free, Subpoena, Adagio, the No Vowels firewall, the title-screen
flow, sound synthesis, screen shake, and a 40-second AI-vs-bots soak:

```bash
cd EggheadsVsMeatheads && godot --headless --fixed-fps 60 -s res://tests/test_suite.gd
```

Run a subset with `TESTS=test_grease,test_timer_expiry` in front of that command.

## Web build / CI

`.github/workflows/deploy.yml` runs the tests on every PR and push. On `main` it then exports the
Web build and publishes it to GitHub Pages. In the repo settings, set Pages' source to
**GitHub Actions** for the deploy step to work.

## Project layout (`EggheadsVsMeatheads/`)

| File | Role |
|---|---|
| `main.tscn` / `game.gd` | Match controller: spawning, timer, score/Heat, HUD, win/lose, restart |
| `egghead.gd` | Player + bot Egghead: movement, crack/respawn, stun, grease, being held, bot AI |
| `meathead.gd` | Meathead: clumsy movement, charge, grab/yeet, grease, belly-flop, AI |
| `typing_station.gd` | Shared "stand here and type" logic |
| `title_screen.gd` | Title / how-to-play screen and the Firewall picker |
| `terminal.gd` | HABEAS CORPUS terminal |
| `subpoena_station.gd`, `witness_stand.tscn` | SUBPOENA podium and where it sends the Meathead |
| `forge.gd`, `foundry_block.gd` | The objective |
| `effect_tile.gd` | ALLEGRO / ADAGIO / OBSIDIAN floor tiles |
| `grease_spill.gd` | Meathead grease |
| `controls.gd` | Autoload that defines every input binding |
| `sfx.gd` | Autoload that synthesizes all sound effects at startup (no audio files) |
| `camera.gd` | Arena camera with screen shake (`add_trauma`) |
| `tests/test_suite.gd` | Headless gameplay tests |

## Not in the PoC (deliberately)

Online multiplayer (44 players), hardware detection, the rest of the "Pick Your Poison" firewall options,
progression/unboxing, and the other learning modules. The input, station and tile scripts are built
so those can be added without rework.
