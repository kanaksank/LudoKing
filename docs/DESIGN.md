# Ludo Nova — design spec

Android, portrait only. Every value below is defined in
`lib/core/theme/app_tokens.dart`; this file is the human-readable copy.

## Tokens

### Player colours

| Seat | Token | Hex |
|---|---|---|
| Red | `LudoPalette.red` | `#FF3B30` |
| Green | `LudoPalette.green` | `#34C759` |
| Yellow | `LudoPalette.yellow` | `#FFCC00` |
| Blue | `LudoPalette.blue` | `#007AFF` |
| Purple | `LudoPalette.purple` | `#AF52DE` |
| Orange | `LudoPalette.orange` | `#FF9500` |
| Unused seat | `LudoPalette.inactive` | `#B8BEC9` |
| Winner / safe badge | `LudoPalette.gold` | `#FFD60A` |

Glossy fills use a three-stop gradient: colour lightened 12 %, colour,
colour darkened 12 % (`glossy()` in `widgets/neo.dart`).

### Surfaces

| Token | Dark | Light |
|---|---|---|
| background | `#151923` | `#E9EDF3` |
| surface | `#1D2330` | `#EFF2F7` |
| raised | `#252C3B` | `#F7F9FC` |
| boardPlate | `#2B3346` | `#DDE3EC` |
| tile | `#F4F6FA` | `#FFFFFF` |
| tileBorder | `#D5DAE3` | `#D3D9E3` |
| textPrimary | `#F5F7FB` | `#1B2130` |
| textSecondary | `#9AA4B8` | `#647086` |
| shadowLight | `#FFFFFF` @ 8 % | `#FFFFFF` |
| shadowDark | `#000000` @ 55 % | `#536480` @ 20 % |

Board tiles stay light in both themes for contrast.

### Spacing, radius, motion

| Spacing | xs 4 · sm 8 · md 12 · lg 16 · xl 24 · xxl 32 |
|---|---|
| Radius | sm 10 · md 16 · lg 24 · pill 999 |
| Token step | 170 ms (fast mode 105 ms) |
| Dice roll | 620 ms, face changes every 70 ms |
| Reaction float | 1.9 s, rises 34 dp, fades after 70 % |
| Capture shake | 420 ms, ±9 dp horizontal, decaying |
| Button press | 110 ms, scale 0.96 |

Neumorphic depth: light shadow offset (−3.5, −3.5) blur 10, dark shadow
offset (5, 5) blur 12; pressed state reduces both to 30 %.

## Haptic map

| Event | Feedback |
|---|---|
| Dice roll | light impact + click |
| Each token step | selection click |
| Token selected (path preview) | selection click + click |
| Token reaches home | medium impact |
| Capture | two heavy impacts 120 ms apart + alert sound + board shake |
| Player finishes / game over | medium then heavy impact |

## Screens

### 1. Main menu
Title tiles (L-U-D-O in red, green, yellow, blue) and a gradient "NOVA".
Stats card (played / wins / captures). All actions sit in the lower third:
Continue (only when a save exists), Play vs Computer, Pass & Play, then How to
play and Settings side by side. Four faint dice drift in the background.

### 2. Lobby
* Board preview (live mini board) with name and track size.
* Player count chips 2–6; the preview switches to the hexagon at 5.
* One card per seat in board colour: tap avatar to cycle emoji, name field,
  Human/Bot segmented control, bot level dropdown.
* House rules in a collapsible panel, turn timer segmented control.
* Full-width Start button pinned to the bottom.

### 3. Classic board (2–4 players)
```
┌ pause ─ Classic · 4 players ─ chat ┐
│ [Red pod]              [Green pod] │
│ ┌────────────────────────────────┐ │
│ │            15 × 15             │ │
│ │           board                │ │
│ └────────────────────────────────┘ │
│ [Blue pod]            [Yellow pod] │
│ ● hint text…              ( die )  │ ← thumb dock
└────────────────────────────────────┘
```
Pods sit next to their base corner. Right-hand pods mirror so the die is
always nearest the board centre line. Unused seats leave an empty slot so
pods always line up with their bases. The banner (captures, bonus rolls,
no moves) slides in over the top edge of the board.

### 4. Hexagon board (5–6 players)
Same frame with three pods above (red, green, yellow) and three below
(orange, purple, blue), matching the bases at 210°, 270°, 330° and 150°,
90°, 30°. The board sits in an `InteractiveViewer` (1×–3×) with zoom in,
zoom out and fit buttons in the bottom-right corner of the board area.

### 5. Victory
Winner-coloured radial glow, confetti, trophy, "<name> wins!", animated
podium (2nd, 1st, 3rd), full ranking list with captures, Rematch (same
seats, new random first player) and Main menu.

### Supporting screens
Settings (sound, vibration, dark mode, path preview, auto-move, fast
animations, discard save, reset stats) and How to play (rule cards).

## Board geometry

Units are cells. Each arm is 3 × 6. The centre is a regular polygon of side 3
(square or hexagon, apothem `3 / (2·tan(π/n))`). Arm *k* points at
`180° + k·360°/n`; its base sits at `+180°/n`. Classic bases are 5.6-cell
rounded squares centred 6.36 cells from the middle; hexagon bases are circles
of radius 2.15 centred 7.6 cells out. Start cells are the second cell from the
outer end on the right-hand column of the owner's arm; star cells are 8 steps
further on.

## Assets

The UI is drawn in code (CustomPainter + Material icons + emoji), so the APK
needs no image assets. For store graphics, export at:

| Asset | Size |
|---|---|
| Launcher icon (adaptive foreground) | 432 × 432 px, safe zone 264 px |
| Play Store icon | 512 × 512 px PNG |
| Feature graphic | 1024 × 500 px |
| Screenshots | 1080 × 2400 px portrait |

`flutter_launcher_icons` can generate all Android densities from one
1024 × 1024 source.
