# Beat Bites — project guide for Claude Code

Solo school project (ITSD 85: Mobile Game with Level Progression and Offline/Online Multiplayer).
Godot 4, GDScript 4, Android, portrait 720×1280. The student is a beginner and wants to LEARN.

## How to work with me (most important)
- Act as a step-by-step tutor. One small step at a time, then STOP and wait for me to confirm it works.
- Before editing, explain briefly what the change does and why. Name the exact script, function and lines.
- Read the current file before changing it. Never guess file contents or rewrite working features.
- Prefer showing me the code to type; edit files directly only when I say "go ahead and edit".
- Don't edit `.tscn` / `.tres` scene files unless I ask; tell me what to click in the Godot editor instead.
- You can't run the game. Ask me to press F5 (or test on two Android phones) and report what I see.
- Never claim something works until I confirm it. Never invent test results.
- After each confirmed step: give me a `git commit -am "..."` command and update the Progress section below.
- Keep Solo and VS CPU working while changing online code. Ask me to re-test them.
- Use Godot 4 syntax only (`@onready`, `@rpc`, typed vars, `signal.connect(callable)`).

## The game
Rhythm catching game. Food falls in 3 lanes on the beat of the music; the player taps/drags to move
an axolotl catcher between lanes. Levels are meals:

| # | Level | BPM | New thing |
|---|---|---|---|
| 1 | Breakfast | 90 | learn to catch (whole-beat notes) |
| 2 | Lunch | 100 | busier chart |
| 3 | Snack | 115 | rotten food (every 10th food) |
| 4 | Dinner | 125 | faster, more lane switches |
| 5 | Dessert | 140 | everything |

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

Current step — Step 97 GIVEN, NOT YET CONFIRMED: `_on_online_match_finished()` in Level.gd saves
`GameState.last_result` (mode "online", online_outcome, opp_score, opp_lives, stars 0), waits 2 s,
opens result.tscn; Result.gd shows the online outcome as heading and rival score/lives instead of
stars. Ask me whether it works before continuing.

## Remaining work (in order, one small step each)
1. Confirm Step 97 (both phones show online results; Solo and CPU results unchanged).
2. Online result buttons: Retry/Meals currently don't clean up the network. Decide with me a simple
   flow (e.g. "Back to lobby" that calls `Net.leave_game()`, or a coordinated rematch).
3. Disconnects during gameplay and while waiting for final results: show "Opponent left", don't
   wait forever, return to menu safely (rubric + guide question 2).
4. Repeated matches: reset readiness, final reports, clock and match state; test either phone hosting.
5. Online level choice: currently always Breakfast; the shared seed isn't used yet (don't claim it is).
6. Online attack race (designed, not built): 10-catch combo sends a rotten food to the rival.
7. Pause menu, sound on/off, title screen, credits screen (R10); apply the UI theme to all screens.
8. Regression pass: all 5 levels, unlocks after app restart, airplane mode, R8 error message,
   readable layout on phone. Then README, docs/GDD.md, docs/CREDITS.md.
Ask me whether VS CPU satisfies the rubric's offline mode (it says "AI or pass-and-play").