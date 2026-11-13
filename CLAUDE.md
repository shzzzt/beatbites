# Beat Bites — project guide for Claude Code

Solo school project (ITSD 85: Mobile Game with Level Progression and Offline/Online Multiplayer).
Godot 4, GDScript 4, Android, portrait 720×1280. I'm a beginner: build efficiently, but explain what you did.

## How to work with me (most important)

- Work through whole tasks on your own: plan, edit the files directly, check them, and keep going
  through several steps. Don't stop after every small change to ask me.
- Read the current file before changing it. Never guess file contents or rewrite working features.
- Check your own work before handing it to me:
  - Parse-check every script you changed with Godot in headless mode, e.g.
	`godot --headless --path . --check-only --script res://scripts/Level.gd`
	(the Godot executable path is in "Local setup" below). Fix every error it reports.
  - Run the project headless briefly (`godot --headless --path . --quit-after 300`) and read the
	output for script errors.
  - Re-read your diff for typos, wrong node paths, and signals connected twice.
- You may edit `.tscn` files for simple, safe changes (adding a node, a button, a label). For layout
  and styling work, describe what you changed so I can check it in the editor.
- Commit after each finished, checked task with a clear message. Never push without asking.
- Only stop and ask me when:
  - a design decision is mine to make (e.g. how online rematch should work), or
  - something needs a real device: two-phone online tests, Android export, touch feel, audio sync.
	Then batch it: give me ONE short test checklist covering everything since my last test.
- Never claim something works on a phone until I confirm it. Never invent test results.
- After each batch, give me a short summary: what changed, in which files, and why (I'm still learning,
  so explain new Godot ideas in a sentence or two). Then update the Progress section below.
- Keep Solo and VS CPU working while changing online code; include them in my test checklist.
- Use Godot 4 syntax only (`@onready`, `@rpc`, typed vars, `signal.connect(callable)`).

## Local setup

- Windows. Project: `D:\BSIT\4TH YR\Special Topics\Lab 5\beat-bites`
- Godot executable: [D:\BSIT\4TH YR\Special Topics\Lab 5\Godot_v4.7.2-stable_win64.exe]
  (the `_console.exe` version isn't in that folder; put it next to this one so output shows in
  the terminal. Claude's shell has so far been blocked from launching Godot, so I check scripts
  in the editor.)
- Online testing needs two Android phones on a phone hotspot.

## The game

Rhythm catching game. Food falls in 3 lanes on the beat of the music; the player taps/drags to move
an axolotl catcher between lanes. Levels are meals:

| #   | Level     | BPM | New thing                         |
| --- | --------- | --- | --------------------------------- |
| 1   | Breakfast | 90  | learn to catch (whole-beat notes) |
| 2   | Lunch     | 100 | busier chart                      |
| 3   | Snack     | 115 | rotten food (every 10th food)     |
| 4   | Dinner    | 125 | faster, more lane switches        |
| 5   | Dessert   | 140 | everything                        |

Rules: PERFECT (≤0.06 s late) = 100 pts, GOOD (≤0.16 s) = 50, else MISS (breaks combo).
Rotten food caught = lose 1 of 3 lives; dodging it is not a MISS. Goal: catch 40 bites.
Win = 40+ caught and lives > 0 when the song ends. Stars (Solo only) = lives left on a win.
Modes: Solo (campaign + unlocks), VS CPU (`CpuRival`, accuracy rises per level), Online (2 phones).

## Lab requirements (all must pass)

- R1 5+ levels, each harder/different · R2 goal text shown at level start
- R3 win/lose + result screen with Retry / Next / Menu
- R4 level n+1 locked until n cleared (lock icon, can't open) · R5 progress saved, survives app close
- R6 offline playable in airplane mode · R7 online: two phones play the same match
- R8 main menu Offline/Online + clear error (not a crash) when online can't connect
- R9 runs on a real Android phone, fixed portrait, touch controls
- R10 title screen, pause menu, sound on/off, readable text on small screens
  Rubric also rewards: disconnects handled, host decides the winner, credits screen, playtesting.
  Deliverables: repo with `README.md`, `docs/GDD.md`, `docs/CREDITS.md`; APK; demo video; paper.
  Guide questions to keep in mind: what happens if internet drops mid-match? why the host decides the winner?

## Code map

- Autoloads: `res://autoload/Net.gd` (`Net`), `GameState` (mode, unlocked_level, best_stars,
  last_result, complete_level()).
- `res://scripts/Level.gd` — gameplay, used by `scenes/levels/level_01..05.tscn`
  (exports: level_number, chart_path, low/middle_pitch_max, notes_per_beat).
- `Food.gd` (`FallingFood`, scenes/actors/food.tscn), `catcher.gd`, `CpuRival.gd` (RefCounted).
- UI scripts: `ModeSelect.gd`, `OfflineSelect.gd`, `LevelSelects.gd`, `Lobby.gd`, `Result.gd`.
- Scenes: `scenes/ui/ModeSelect.tscn`, `OfflineSelect.tscn`, `LevelSelect.tscn`, `Lobby.tscn`, `result.tscn`.
- Charts: `res://assets/audio/music_<meal>.json` (`bpm`, `beat_times_seconds`, `lead_notes`
  [{beat, duration_beats, midi}]). Lane comes from pitch. Song time uses the audio clock
  (`get_playback_position() + get_time_since_last_mix() - output_latency`).
- Online uses ENet, port 24567, max 2 players. Test over a phone hotspot (school Wi-Fi blocks it).

## UI design (soft light pixel style)

Background #FBF4FF with pastel sparkles · panels #FFFFFF · outline/text #5B4494 / #3B2A66 ·
buttons pink #FFCCE5, blue #BFE2FF, purple #DCCCFF · stars #F2B230 · accent text #D9468F, #2667B0.
Buttons: StyleBoxFlat, 0 radius, 8 px #5B4494 border, shadow #D9C8F5 offset (0,12); min height 96.
Fonts: Press Start 2P (titles/buttons, multiples of 8 px), Pixelify Sans (body, ≥28 px).
Pixel art: texture filter Nearest, whole-number scales only (food 16×16 ×6, catcher 32×24 ×6).
Sprite sheets (32×24 frames side by side): `catcher_catch`/`rival_catch` = 3 frames (96×24),
`catcher_hurt`/`rival_hurt` = 2 frames (64×24); `*_idle` = 1 frame. Never use a sheet as a
whole texture: cut frames with AtlasTexture, or Sprite2D `hframes`.
Screens: Title, Mode select, Level select (cards with stars/locks), Lobby (host IP / join field /
error panel), Gameplay HUD (pause, score, hearts, goal bar, tap zones), Pause (resume, restart,
sound, quit), Result (outcome, stats grid, stars, Retry/Next/Menu), Online HUD (you vs rival bar,
throw meter, INCOMING! warning). Current scenes are plain/functional; styling comes later.

## Progress

Done and confirmed:

- Chart loading, 3 lanes, catcher, judgments, score/combo/lives, rotten food from level 3.
- Offline countdown, audio clock, Solo unlocks + stars + saving, VS CPU, Result screen, APK on phone.
- Online steps 77–96: lobby host/join/IP/timeout/errors, opponent join/leave in lobby, shared seed
  (`prepare_match`), both-loaded check, clock sampling (best of 5), scheduled synced start,
  live opponent score/lives, both players report final score (`report_match_finished`),
  host shares final numbers and each phone gets YOU WIN!/YOU LOSE/DRAW (`get_online_outcome`:
  survivor beats eliminated, then higher score, else draw).

CODE ADDED 2026-11-13, NOT YET PHONE-CONFIRMED and not Godot parse-checked (Claude's shell can't
launch the Godot exe; `_console.exe` is missing). Waiting for one combined phone test:

- Step 97: `_on_online_match_finished()` saves `GameState.last_result` (mode "online",
  online_outcome, opp_score, opp_lives, stars 0), waits 2 s, opens Result; Result shows the outcome
  and rival score/lives instead of stars.
- Online result flow (decided: "Back to lobby"): Result hides Retry, Meals becomes BACK TO LOBBY →
  `Net.leave_game()` + Lobby. No rematch.
- Disconnects: Level listens to `peer_disconnected`/`server_disconnected` → `end_online_early()`:
  stops, `Net.leave_game()`, shows OPPONENT LEFT; before the song started → Lobby with
  `Net.lobby_message`; after → Result (no winner). Waiting for final results times out at song end
  + 15 s → "NO RESULT".
- Repeated matches: `Net.reset_match_state()` (loaded/finished reports, clock data) runs in
  `leave_game()` and `prepare_match()`.
- Online level (decided: host picks): Lobby `LevelPick` OptionButton (host only) →
  `prepare_match(seed, level)` → `Net.match_level` → loads `level_0N.tscn`. All 5 levels are
  playable online, even if they're still locked in Solo. The seed is still unused.
- Attack race: every 10-catch combo (10, 20, 30…) → `Net.send_attack` RPC → rival's
  `_on_attack_received()` turns their next good food landing ≥2 s ahead rotten
  (`FallingFood.make_rotten()`) and shows INCOMING! for 1.5 s. Throw meter label
  "Throw [###-------] 3/10" under the opponent numbers. MISS resets it (combo breaks).
- R10 screens: `Title.tscn` is now the main scene (PLAY / SOUND / CREDITS, menu music);
  `Credits.tscn` has [PLACEHOLDERS] for my name, music and art sources. BACK buttons on
  ModeSelect → Title and OfflineSelect → ModeSelect.
- Sound: `GameState.sound_on` saved in save.cfg [settings]; `toggle_sound()` mutes the Master bus.
- Pause: `PauseMenu.tscn`/`PauseMenu.gd` (class `PauseMenu`, process_mode Always) added by
  `Level.setup_pause_menu()`. Offline: pauses the tree + music, countdown skips paused time,
  RESUME / RESTART / SOUND / QUIT TO MEALS. Online: menu doesn't pause ("The match keeps going!"),
  no Restart, LEAVE MATCH → `Net.leave_game()` → Lobby. Android back button opens/closes it; going
  to the home screen pauses offline levels.
- Theme: `assets/ui_theme.tres` set as project theme (gui/theme/custom). Mockups live in
  `docs/ui-design/` (png + html, 390 wide → multiply sizes by ~1.85). Theme type variations:
  - Buttons: `Button` (pink, default), `BlueButton`, `PurpleButton`, `IconButton` (lilac square,
	use with `expand_icon` for 12 px icons ×4). 8 px #5B4494 border, shadow (0,12) #D9C8F5.
  - Labels: default body (Pixelify 28), `TitleLabel` (Press Start 40), `LogoLabel` (pink 32 +
	shadow), `SectionLabel` (Press Start 24 #6B58A0), `CardTitle` (Press Start 32),
	`CardBody` (Pixelify semibold 32), `MutedLabel` (Pixelify 32 #6B58A0).
  - `PanelContainer`: white card. Inset button highlights from the mockup aren't possible with
	StyleBoxFlat, so they're left out.
  - Press Start 2P imported without antialiasing (crisp pixels).
- `scripts/Sparkles.gd` (class `Sparkles`): full-screen Control that draws the mockup's pastel
  sparkles; add it as the first child of a UI scene.
- ModeSelect restyled to `02_mode_select.png` (2026-11-14): containers, logo + sound icon
  toggle, Offline (blue) / Online (pink) cards with apple/fish icons, BACK + CREDITS row (mockup
  says SETTINGS, but there's no settings screen yet), catcher, "N / 15 stars collected".
  Nodes use unique names (`%Offline`, `%Sound`…).
- Title restyled to `01_title.png` (2026-11-14): tap anywhere (or Enter) → ModeSelect; no buttons.
  Layered "BEAT" (pink) / "BITES" (blue) Press Start 80 (a back label offset 16 px + a font
  shadow offset 8 px), tagline, apple/blueberry/donut, axolotl on a pink dashed line
  (`scripts/DashedLine.gd`, reusable `@tool` Control), blinking "TAP TO START" with pink arrow
  icons, "v0.1 · ITSD 85". Sound + Credits now only on ModeSelect; Credits BACK → ModeSelect.
- Title animations (Tweens in Title.gd): intro (logo bounces in, rest fades in ~1.6 s), idle
  float (logo words + food), axolotl hops on every beat of the menu song (80 BPM, audio clock,
  handles looping), 0.25 s fade-out on tap. `Sparkles.twinkle` export (on for Title only).
- Fix: `cpu.setup(level_number)` was never called, so CPU accuracy stayed 55% on all levels;
  now 55/63/71/79/87%.
- R3: Result has NEXT MEAL (Solo/CPU, when the next meal is unlocked); `last_result.level_number`.
- Docs written (2026-11-14): README.md, docs/GDD.md, docs/CREDITS.md. Placeholders `[...]` for my
  name, music/art sources and licenses, APK link, screenshots, playtest table.
  Chart fact: Lunch has 62 playable foods vs Breakfast 92 (table above says "busier chart"; it isn't).

## Remaining work (in order; batch related tasks together)

1. Phone-test the batch above. Fill in the Credits / docs placeholders.
2. Restyle the other screens to their mockups using the shared theme:
   03 Level select, 04 Lobby, 05 Gameplay HUD, 06 Pause, 07 Result, 08 Online HUD.
   Decide with me: SETTINGS button (real screen or keep BACK).
3. Regression pass: all 5 levels, unlocks after app restart, airplane mode, R8 error message,
   readable layout on phone. Record results in GDD §11 playtesting.
   Ask me whether VS CPU satisfies the rubric's offline mode (it says "AI or pass-and-play").
