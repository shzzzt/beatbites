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
- Godot executable (note: `Godot_v4.7.2-stable_win64.exe` is a FOLDER; the programs are inside):
  `D:\BSIT\4TH YR\Special Topics\Lab 5\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`
  (Git Bash: `/d/BSIT/4TH YR/Special Topics/Lab 5/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe`)
- `--check-only --script` can't see autoloads (GameState, Net) and reports "Identifier not found"
  for scripts that use them. To check those, run the scene headless instead:
  `godot --headless --path . res://scenes/ui/LevelSelect.tscn --quit-after 300`.
  (Headless exit shows a harmless "music_menu.ogg still in use / leaked" warning from Title.)
- Online testing needs two Android phones on a phone hotspot.

## The game

Rhythm catching game. Food falls in lanes (3/3/4/4/5 per level) on the beat of the music; the player
drags anywhere to slide an axolotl catcher between lanes. Levels are meals:

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
  (exports: level_number, chart_path, lane_count, fall_time, notes_per_beat, min_gap).
- `Food.gd` (`FallingFood`, scenes/actors/food.tscn), `catcher.gd`, `CpuRival.gd` (RefCounted).
- UI scripts: `ModeSelect.gd`, `OfflineSelect.gd`, `LevelSelects.gd`, `Lobby.gd`, `Result.gd`.
- Scenes: `scenes/ui/ModeSelect.tscn`, `OfflineSelect.tscn`, `LevelSelect.tscn`, `Lobby.tscn`, `result.tscn`.
- Charts: `res://assets/audio/music_<meal>.json` (`bpm`, `beat_times_seconds`, `lead_notes`
  [{beat, duration_beats, midi}]). Lane comes from the melody's contour (`Level.assign_lanes`). Song time uses the audio clock
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
- Attack race: REPLACED 2026-11-17 by power food (see "Power food attacks" below).
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
- All screens restyled to the mockups (2026-11-14), checked by rendering screenshots in a 9:16
  window (not yet on a phone):
  - Theme is generated: more variations (WhiteButton, PaleButton, TapZoneLeft/Right, LockedCard,
	HudPanel, InfoPanel, HintPanel, ErrorPanel, SuccessPanel, Tile*, Num*, ChipPanel, ThrowOn/Off,
	TugBar, HeroLabel, SmallMuted, MealName, StatValue, ScoreLabel, TinyPixel).
  - `ui_heart.png` and `ui_star.png` are WHITE shapes: always tint with modulate (heart #FF8FB8,
	star #F2B230, empty #E3D4FF).
  - Level Select: `MealCard.tscn`/`MealCard.gd` (class MealCard) × 5 from `GameState.MEALS`;
	locked = lilac card + dashed border (`DashedLine` mode BOX) + lock icon; hint panel.
  - Lobby: host panel (HOST → IP box + level picker + START), join panel (IP field + JOIN),
	pink error panel (`show_error(title, text)`); joining panel hidden while hosting.
  - Gameplay: `GameHUD.tscn`/`GameHUD.gd` (class GameHUD) added by `Level.setup_hud()` into the
	level's HUD CanvasLayer; `GameBackdrop.tscn` (layer -1: sparkles, lane dividers, catch line).
	Level.gd calls `hud.show_message/show_judgment/set_*`; `refresh_hud()` pushes all numbers.
	Solo: level/score/hearts/goal bar. CPU + Online: YOU vs RIVAL/CPU panel + tug bar; online
	adds the INCOMING! banner (throw meter removed 2026-11-17). Old `$HUD/Judgment` label removed from levels.
  - Controls: see the 2026-11-16 entry below (tap zones removed, drag only).
  - Pause (06): lilac overlay, PAUSED, "LV · meal · caught/40 bites" (`PauseMenu.set_info`),
	RESUME / RESTART / SOUND [ON|OFF chip] / QUIT TO MENU; pause button top-left.
  - Result (07): level line, outcome, 3 stars (fade in), score card + 4 tiles, rival row
	(CPU/online), "X unlocked!" banner (`last_result.newly_unlocked`), RETRY / NEXT > / MENU.
  - OfflineSelect + Credits restyled to match (no mockups): cards / scrollable white panel.
  - `GameState.MEALS`, `meal_name()`, `total_stars()` shared by menus and HUD.
  - Theme is generated by `tools/make_theme.py` (run `python tools/make_theme.py
	assets/ui_theme.tres`); edit the script, not the .tres, when changing styles.
- Settings screen (decided 2026-11-14: real screen; replaces BACK on ModeSelect, so ModeSelect has
  no way back to Title): `Settings.tscn`/`Settings.gd`. Sound ON/OFF chip, master volume slider
  (`GameState.volume`, `set_volume()`, saved), Audio delay −200…+200 ms in 10 ms steps
  (`GameState.timing_offset_ms`, saved; `Level.read_song_time()` subtracts it from the clock,
  default 0), progress summary + RESET PROGRESS (tap twice within 3 s → `GameState.reset_progress()`,
  keeps settings). Slider uses a pixel grabber `assets/art/ui_slider_grabber.png`.
- Online lobby discovery + usernames (2026-11-14; tested with two copies on one PC, NOT on phones):
  - `GameState.username` (max 10, `clean_username()`, `set_username()`, saved; default "ChefNNN").
	Edited in the Lobby's YOUR NAME field (locked while hosting/joining).
  - `Net.share_name` RPC on connect → `Net.opponent_name` + `opponent_named` signal; cleared in
	`leave_game()`. Shown in Lobby status, versus HUD (`%YouName`/`%RivalName`, ellipsis) and
	Result (`last_result.opp_name`).
  - `scripts/LanDiscovery.gd` (class LanDiscovery, child of Lobby): host `advertise({name, meal})`
	broadcasts JSON (magic "beatbites-v1", random session id) every 1 s on UDP 24568 to
	255.255.255.255 and each x.y.z.255; joiners `listen()` and get `hosts_changed` (grouped by
	session id, best IP = same /24 as ours, gone after 4 s). Host stops advertising when full.
  - Lobby: match cards (tap = join), "JOIN BY IP INSTEAD" fallback row, HostIP shown small.
  - Android export: enabled change_wifi_multicast_state, access_wifi_state, access_network_state
	(needed to receive broadcasts). Needs a fresh APK export.
- Fix: `cpu.setup(level_number)` was never called, so CPU accuracy stayed 55% on all levels;
  now 55/63/71/79/87%.
- R3: Result has NEXT MEAL (Solo/CPU, when the next meal is unlocked); `last_result.level_number`.
- Docs written (2026-11-14): README.md, docs/GDD.md, docs/CREDITS.md. Placeholders `[...]` for my
  name, music/art sources and licenses, APK link, screenshots, playtest table.
  Chart fact: Lunch has 62 playable foods vs Breakfast 92 (table above says "busier chart"; it isn't).
- Gameplay changes (2026-11-16; run in Godot with screenshots, NOT on a phone):
  - Food sprites: `FallingFood.GOOD_TEXTURES` (8) / `BAD_TEXTURES` (4) + `variant`; Level picks
	variants with an RNG seeded by level_number (same foods every play and on both phones), never the
	same food twice in a row. Rotten food has no green box any more (sprite only).
  - Fall speed (revised 2026-11-17): `Level.fall_time` export → `Food.fall_time` (L1 2.4, L2 2.1,
	L3 1.8, L4 1.3, L5 1.2 s). Food now lands on the catcher (`Food.catch_y` = catcher y 1080; it
	used to reach the beat at y 960, 120 px above). `Level.min_gap` skips notes closer than that to
	the previous food (L5 0.35 → 156 foods instead of 312). Every level ≥ ~330 px between bites
	(user asked twice: harder = faster drops, bites spaced out, not crowded).
  - Note picking (2026-11-17, user: Dinner felt too slow): `Level.pick_notes()` keeps whole-beat
	notes first, then off-beat notes only if ≥ min_gap from every kept food. `notes_per_beat` can be
	4. Dinner: notes_per_beat 4, min_gap 0.35 → 160 foods, 2.1/s (was 120, 1.57/s, sparser than
	Snack 1.93/s); Dessert 156 foods 2.3/s. Foods/s now rises L3 → L4 → L5.
  - Lanes: `Level.lane_count` export (L1–2: 3, L3–4: 4, L5: 5). `Level.assign_lanes()` follows the
	melody contour (up → right, down → left, jump > 4 semitones = 2 lanes when 4+ lanes, bounce off
	walls, max 3 in a row off-center; L1–2 ignore 1-semitone steps). Old low/middle_pitch_max removed.
	Lane counts per level [L1 27/46/19, L5 20/47/43/34/12]; switches L1 88, L2 57, L3 86, L4 114, L5 136.
  - `GameBackdrop.gd` (class GameBackdrop) draws lane_count−1 dashed dividers. Food and Catcher have
	`lane_count`; `Catcher.setup(count)` scales the sprite ×6/×5/×4 for 3/4/5 lanes.
  - Controls: ◀ ▶ tap zones removed (HUD + `move_requested`). Drag anywhere: the axolotl slides by the
	finger's `relative` x, lane = column under its center, snaps to lane center on release. A plain
	tap does nothing. Arrow keys still work on PC.

- Power foods (2026-11-17; VS CPU checked in Godot with screenshots, online NOT tested; the
  send_attack RPC now has a `kind` argument, so BOTH phones need the new APK):
  - VS CPU + Online: food_index % 10 == 4 (not rotten) → `Food.power_kind` from
	`Level.POWER_KINDS` (rotten ×3, ink ×2, shield, double, life) dealt from a shuffled bag
	(`shuffled_powers()`, Fisher-Yates with an RNG seeded level_number + 1000, refills when empty;
	same on both phones, every kind in every meal). Heart ("life"): +1 life up to MAX_LIVES 3, else
	+200; `hud.show_power` flies a heart sprite to `%YouHearts`; CPU gets the same. Versus only
	(Solo stars = lives, so no hearts there). `Food._draw`: colored glow + 4 sparkles + label chip (`Food.POWERS`).
  - Catch → `Level.use_power(kind)`: shield → `has_shield`; double → `double_until` (+6 s, points ×2);
	rotten/ink → `hud.play_throw(pos, kind, blocked)` + online `Net.send_attack(kind)` RPC, or CPU:
	`cpu.shield` blocks, rotten → `cpu.incoming += 3` (extra `judge_bad_note` per processed food),
	ink → `cpu.ink_until` (−30% accuracy 4 s). CPU catches power → `cpu_use_power()`.
  - Receiving (`Level.receive_attack(kind)`): `hud.play_warning` (banner + panel wind-up); shield →
	`hud.play_blocked`; ink → `hud.play_ink_hit(4 s)` (pixel blobs drawn via the `draw` signal, HUD
	layer so they cover food); rotten → `spawn_hazards(3)`: random lane + random half-beat arrival
	≥ 0.7 s after landing, free if no food within 0.3 s in that lane; hazard = new FallingFood in
	`Level.hazards` (not active_food, so the CPU loop is unaffected), `waiting_to_land` hidden
	until `hud.toss_rotten()` lands → `Food.land()` pop + `shake_screen()`.
  - HUD: `%Status` chip (y 204: "SHIELD  x2 5s"), INCOMING! banner at y 252 with `%IncomingText`.
  - Judgment signal is bound with the food: `judgment_made.connect(_on_food_judgment.bind(food))`.
  - 10-combo throw meter removed. Not a bug: food passes UNDER the HUD (checked with a cover rect).
- Sound effects (2026-11-18; checked in Godot that each sound starts, NOT heard on a phone):
  `tools/make_sfx.py` generates 10 original 8-bit WAVs in `assets/audio/sfx/` (throw, splat,
  incoming, land, ink, shield, blocked, double, heart, bonk); edit the recipes and rerun.
  `scripts/Sfx.gd` (class Sfx): pool of 8 AudioStreamPlayers on Master, `play(name, volume_db)`
  with ±5% pitch. Level creates it in `setup_hud()` and sets `hud.sfx`; HUD plays sounds at the
  animation moments (`_sound()`); Level plays `bonk` on HIT_BAD and the CPU's powers at −6 dB.

- Endless mode + bonus song (2026-11-18; checked in Godot: loops via seeking near the song end,
  screenshots; NOT played for real or on a phone, song not heard by anyone yet):
  - `GameState.mode = "endless"`. OfflineSelect has an ENDLESS card → `EndlessSelect.tscn`/`.gd`
	(6 cards built in code; `GameState.meal_info()`, `SONG_TITLES`, `ENDLESS_LEVELS` 6).
  - Level: `spawn_loop(loop)` (refactor of the old food loop; Solo/CPU produce identical food);
	Endless spawns loops 0 and 1, `_on_song_finished` → `next_loop()`: loop_base += loop_length,
	`music.pitch_scale = loop_speed()` (1 + 0.08/loop, max 1.6), frees judged food, spawns loop+1,
	+1 heart, "LOOP n" message. `read_song_time()` multiplies real-time terms by pitch_scale and
	adds loop_base. Fall per loop = max(0.75, fall_time × 1.25 × 0.9^loop) × speed (song seconds);
	`Food.window_scale` = speed. Every 10th food rotten on every song; every 5th miss −1 heart.
	`is_versus()` now gates power foods / status chip (Endless has none).
  - HUD: Solo layout, `set_endless()` (goal text "Loop n · x1.08 speed", MISS n/5 bar), level name
	"ENDLESS · MEAL". Pause info shows the loop; pause QUIT → EndlessSelect. Result: GAME OVER /
	NEW BEST!, "Reached loop n · best …", SONGS → EndlessSelect. `GameState.record_endless()`,
	`endless_best` saved in `[endless]`, cleared by reset_progress.
  - Bonus song "Stardust Lullaby" (Midnight Snack, level_06.tscn: 92 BPM, 4 lanes, fall 2.0,
	notes_per_beat 2, min_gap 0.3, 120 foods): composed + synthesized by `tools/make_song.py`
	(pure Python, ~1 min) → `music_midnight.wav` (32 kHz mono, imported as QOA) + `.json` chart.
	D major; verses Canon progression, chorus Bm-G-D-A; music box arps, pulse lead + vibrato +
	echo, pad, bass, drums in verse2/chorus/verse3. Endless only (not in MEALS / Solo).

- Logo (2026-11-18; rendered and checked as images, NOT seen on a phone yet): `tools/LogoMaker.tscn`
  + `tools/make_logo.gd` (run NON-headless: `--path . res://tools/LogoMaker.tscn`) render the axolotl
  catching an apple (64×64 grid × whole-number scale) into `assets/branding/`: icon_512 / icon_192
  (pink rounded tile, transparent corners), adaptive icon_foreground_432 / icon_background_432, and
  logo_banner.png (1280×640, top of README). project.godot: config/icon + boot_splash image
  (lavender bg, use_filter false); export_presets.cfg: launcher icons + Android splash icon/bg.
  The Godot editor was open when these files were edited: reload the project before saving there.

## Remaining work (in order; batch related tasks together)

1. Phone-test the batch above. Fill in the Credits / docs placeholders.
2. Regression pass: all 5 levels, unlocks after app restart, airplane mode, R8 error message,
   readable layout on phone. Record results in GDD §11 playtesting.
   Ask me whether VS CPU satisfies the rubric's offline mode (it says "AI or pass-and-play").
