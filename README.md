# Ludo Nova

An offline Ludo game for Android, built with Flutter. Portrait-first,
thumb-friendly, and playable by 2–6 people on one phone or against computer
players.

* **2–4 players** play on the classic cross board (52-cell track, 4 corner bases).
* **5–6 players** play on a hexagon board (78-cell track, 6 radial bases) with
  pinch-zoom and zoom buttons.
* Every player has a **dice pod** beside their base: avatar, glowing turn ring,
  draining turn-timer ring and a tap-to-roll die. A large die in the bottom
  **thumb dock** mirrors whoever is up, so you never have to reach the top of
  the screen.
* Glossy 3D tokens bounce when they can move. Tap once to **preview the path**
  (translucent step dots and a pulsing target), tap again to move.
* Captures **shake the board** and fire a strong haptic; dice rolls, steps and
  home arrivals each have their own lighter haptic.
* A collapsible **side drawer** holds table talk (quick phrases + emoji that
  float over the sender's pod), and sound / vibration / speed toggles. Bots
  react to captures and sometimes answer back.
* Games **auto-save** after every move and can be resumed from the menu.
* No internet, no account, no ads.

> The repository is called `LudoKing`, but the app ships as **Ludo Nova**.
> "Ludo King" is another company's trademark, so it is not used as the app's
> name, package name or store listing.

---

## 1. Requirements

| Tool | Version |
|---|---|
| Flutter | 3.27 or newer (stable) |
| Dart | 3.6 or newer |
| Android SDK | compileSdk 34+ |
| Java | 17 |

## 2. First run

The Android host folder is not committed. Create it once:

```bash
git clone https://github.com/kanaksank/LudoKing.git
cd LudoKing
flutter create . --org com.kanaksank --project-name ludo_nova --platforms=android
flutter pub get
dart format lib test
flutter run
```

`flutter create .` adds `android/` without touching `lib/`, `test/` or
`pubspec.yaml`. The application ID becomes `com.kanaksank.ludo_nova`.

Then set the launcher name in `android/app/src/main/AndroidManifest.xml`:

```xml
<application android:label="Ludo Nova" ...>
```

The app locks itself to portrait in `main.dart`. No extra Android permissions
are needed (haptics use `HapticFeedback`, which does not require `VIBRATE`).

## 3. Rules implemented

| Rule | Default | Lobby toggle |
|---|---|---|
| A 6 is needed to leave base (otherwise 1 or 6) | on | yes |
| Rolling a 6 gives another roll | on | — |
| Capturing gives another roll | on | yes |
| Getting a token home gives another roll | on | yes |
| Three 6s in a row forfeit the turn | on | yes |
| Star cells are safe (start cells are always safe) | on | yes |
| Exact roll needed to finish | always | — |
| Turn timer for humans | 15 s | Off / 10 / 15 / 30 s |

When the timer runs out the game rolls, or makes a sensible move, for the
player. When every human has finished, the remaining bots are ranked by
progress instead of making you watch them play out. Tokens of different
players on the same unsafe cell: the arriving token captures all of them.

## 4. Project layout

```
lib/
  main.dart                  portrait lock, prefs bootstrap, ProviderScope
  app.dart                   MaterialApp, light/dark theme switch
  core/theme/
    app_tokens.dart          colour, surface, spacing, radius, motion tokens
    app_theme.dart           Material 3 themes built from the tokens
  game/                      ← pure Dart, no Flutter imports
    ludo_engine.dart         rules, state, JSON save format
    bot_brain.dart           easy / medium / hard move selection
    board_geometry.dart      cell, base and token coordinates for 4 or 6 arms
  services/                  settings, stats, saved game, haptics + sound
  state/
    providers.dart           Riverpod wiring
    game_controller.dart     turn flow, dice spin, step animation, timers,
                             bots, reactions, auto-save
  screens/                   menu, lobby, game, victory, settings, how to play
  widgets/
    board_painter.dart       the board (both shapes) + path preview
    board_view.dart          board + animated tokens + tap handling
    token_widget.dart        glossy pawn, bounce, safe-cell badge
    dice.dart                3D die, timer ring
    dice_pod.dart            player pod
    chat_drawer.dart         table talk + audio controls
    effects.dart             board shake, floating reactions, confetti
    neo.dart                 neumorphic box and button
test/
  engine_test.dart           rules + 100 simulated bot games
  geometry_test.dart         board geometry invariants for both boards
docs/DESIGN.md               screen specs and design tokens
```

### How the board works

A token's position is a single number, its *progress*:

| progress | meaning |
|---|---|
| −1 | in base |
| 0 … L−2 | on the shared track (0 is the player's start cell) |
| L−1 … L+3 | in the home column |
| L+4 | finished |

`L = 13 × arms`, so 52 for the classic board and 78 for the hexagon. Each arm
is a 3 × 6 strip; 13 of its cells belong to the track and 5 form the owner's
home column. Every arm is drawn pointing up and then rotated into place around
a square (4 arms) or a hexagon (6 arms), which is why one painter and one rules
engine serve both boards.

Seats: 2 players sit opposite each other, 3–4 fill the classic board
clockwise from red, 5–6 fill the hexagon.

### State management

Riverpod. `GameController` owns one session and exposes `GameUiState`:
the authoritative `LudoState` plus presentation state (the token positions
being animated, dice faces, timer, selected token, banner, reactions). The
engine is only ever called with legal input, and every rule lives in
`lib/game/`.

## 5. Testing

```bash
flutter test
flutter analyze
```

`engine_test.dart` plays 20 full bot games for every player count and checks
that each one ends with a complete ranking, and that the hard bot beats a
random mover.

## 6. Building

```bash
flutter build apk --release                 # sideload
flutter build apk --release --split-per-abi # smaller APKs
flutter build appbundle --release           # Play Store
```

For Play Store uploads, create a keystore, add `android/key.properties`
(never commit it) and wire a `signingConfigs.release` block into
`android/app/build.gradle`. Bump the number after `+` in
`pubspec.yaml`'s `version` for every upload.

## 7. Customising

* **Colours / spacing / motion:** `lib/core/theme/app_tokens.dart`.
* **Bot behaviour:** weights in `BotBrain.score`.
* **Default rules:** `GameRules` constructor defaults.
* **Sounds:** `FeedbackService` uses system sounds so no assets are needed.
  Drop in `audioplayers` and real samples there if you want richer audio.

## 8. Roadmap

| Item | Status |
|---|---|
| Classic board, 2–4 players | done |
| Hexagon board, 5–6 players, zoom | done |
| Bots (3 levels), pass & play | done |
| Path preview, haptics, capture shake | done |
| Chat drawer, floating reactions | done |
| Save / resume, stats | done |
| Custom sound assets, app icon, splash | pending |
| Online multiplayer | not planned for v1 |
