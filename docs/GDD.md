# Beat Bites: Game Design Document

**Course:** ITSD 85, Mobile Game with Level Progression and Offline/Online Multiplayer
**Engine:** Godot 4.7 (GDScript), GL Compatibility renderer
**Platform:** Android, portrait 720 × 1280, touch controls
**Author:** _[Your name]_

---

## 1. Concept

Beat Bites is a rhythm catching game. Food falls down lanes in time with the music (3 lanes in the first meals, 4 and then 5 in the harder ones), and the player drags an axolotl catcher left and right to catch each bite as it lands on the beat. Each level is a meal of the day with its own song and tempo, and the meals get faster and trickier from Breakfast to Dessert.

**Pitch:** _"Catch your meals on the beat, one bite at a time."_

**Target player:** casual mobile players who like short music games. One level lasts about 1–1¼ minutes.

## 2. Core loop

1. Pick a mode and a meal.
2. Read the goal ("Catch 40 bites!") during the 3-2-1 countdown.
3. Catch food on the beat, keep your combo, and dodge rotten food.
4. See the result (score, judgments, stars or the rival outcome), then Retry, pick another meal, or go back.
5. Clearing a meal unlocks the next one.

## 3. Mechanics

### 3.1 Lanes and timing
- Each note in a song's melody becomes one food. The **melody's shape decides the lane**: when the melody goes up, the food moves one lane right; when it goes down, one lane left; a repeated note stays in the same lane. A big jump (more than 4 semitones) moves two lanes when there are 4 or more lanes. At the edge, the food bounces back toward the middle, and after 3 foods in one lane the next one moves toward the center, so the chart never sits on one side for long. The same chart always gives the same lanes, so both phones match online.
- **Fall speed per meal:** a food takes 2.4 s to fall onto the axolotl in Breakfast, then 2.1 s (Lunch), 1.8 s (Snack), 1.3 s (Dinner) and 1.2 s (Dessert), so it lands on the axolotl exactly on the beat. Harder meals drop food faster (about 490 px/s in Breakfast up to 980 px/s in Dessert), which also spreads the bites further apart on screen: at least about 325 px between bites in every meal.
- **Which notes become food:** `notes_per_beat` sets the grid (1 = whole beats, 2 = half beats, 4 = quarter beats) and `min_gap` is the minimum time between two foods. Whole-beat notes are kept first, then off-beat notes only where they still fit, so they fill empty spaces instead of making a stream. Dinner (quarter grid, 0.35 s) gains its syncopated "¾-beat" notes (160 foods, 2.1 per second, busier than Snack's 1.9). Dessert (half grid, 0.35 s) becomes one food every ~0.43 s (2.3 per second).
- **Lanes per meal:** Breakfast and Lunch have 3, Snack and Dinner 4, Dessert 5. The axolotl is drawn smaller (×5 or ×4 pixel scale) when there are more lanes, so it still fits one lane.
- **Controls:** put a finger anywhere and drag. The axolotl slides the same distance as the finger, and counts as being in whichever lane its center is over. Lifting the finger snaps it to the middle of that lane. (On a PC: mouse drag or the arrow keys.)
- Rotten foods use their own sprites (rotten apple, banana, juice, fish), and good foods are picked from 8 sprites, never the same one twice in a row.
- Every food takes a fixed time to fall from the top to the catch line (3 s in Breakfast, less in later meals, see below). Its position is driven by the **audio clock** (`playback position + time since last mix − output latency`), so the food stays in sync with the music even when frames drop.

### 3.2 Judgments and scoring

| Judgment | When it's caught | Points | Combo |
| --- | --- | --- | --- |
| PERFECT | ≤ 0.06 s after the beat | 100 | +1 |
| GOOD | ≤ 0.16 s after the beat | 50 | +1 |
| MISS | not caught in time | 0 | reset to 0 |

### 3.3 Lives and rotten food
- The player has **3 lives**.
- From Snack (level 3) onward, every 10th food is **rotten**. Catching it costs 1 life. Dodging it is safe and does not count as a MISS.
- At 0 lives the attempt ends immediately (in Solo).

### 3.4 Win, lose and stars
- **Win:** catch at least **40** bites and have more than 0 lives when the song ends.
- **Stars (Solo only):** 1 star for each life left on a win (0–3). The best rating for each meal is saved.

## 4. Levels

| # | Meal | Song | BPM | Length | Playable foods | Lane switches | What's new |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | Breakfast | Sunrise Bento | 90 | 64 s | 92 | 88 | Learn to catch (3 lanes, whole-beat notes) |
| 2 | Lunch | Lunchbox Letters | 100 | 77 s | 62 | 57 | Faster tempo |
| 3 | Snack | Soda Pop Sidequest | 115 | 67 s | 128 | 86 | 4 lanes, rotten food (every 10th food) |
| 4 | Dinner | Neon Noodle Rush | 125 | 77 s | 160 | 114 | Faster, off-beat (syncopated) notes, 2-lane jumps on big leaps |
| 5 | Dessert | Sugar Star Sprint | 140 | 69 s | 156 | 136 | 5 lanes, fastest drops, off-beat notes: everything at once |

_"Playable foods" and "lane switches" are counted from each level's chart with its lane settings. Levels 1–4 use whole-beat notes only, and Dessert also uses half-beat notes._

All five levels use the same scene script (`Level.gd`). Each level scene sets its own `level_number`, chart file, `lane_count` and `notes_per_beat`.

## 5. Game modes

### 5.1 Solo (campaign)
- All five meals in order, with unlocks and stars.
- Meal *n + 1* stays locked until meal *n* is cleared. Locked meals are greyed out, show "LOCKED", and can't be opened.

### 5.2 VS CPU (offline)
- Same rules, plus a simulated rival (`CpuRival`) that judges every food at the same moment as the player.
- CPU accuracy goes up each level: **55% → 63% → 71% → 79% → 87%**. When it catches a food, 75% of catches are PERFECT and the rest GOOD. It fails to dodge rotten food with the same chance it misses a good one.
- **Outcome:** a survivor beats an eliminated player; otherwise the higher score wins; otherwise it's a draw. VS CPU doesn't change unlocks or stars.
- It needs no network, so it works in airplane mode.

### 5.3 Online (2 phones)
- One phone **hosts** and the other **joins** with the host's local IP address (ENet, UDP port 24567, max 2 players).
- The host chooses the meal. All five meals are available online.
- During the match, each phone shows the rival's live score and lives.
- **Attack race:** every 10-catch combo (10, 20, 30 …) throws a rotten food at the rival. On the rival's phone, the next good food landing at least 2 seconds later turns rotten, and a big **INCOMING!** warning appears. A throw meter shows progress toward the next throw.
- **Outcome:** the same rule as VS CPU, decided by the host (see 6.3).

## 6. Online design

### 6.1 Match flow
1. **Lobby:**
   - Each player sets a username, which is saved on the phone.
   - The host announces its match once a second with a UDP broadcast on the local network (port 24568). Joiners see a live list of matches ("Ana's match · Snack") and tap one to join. Typing the host's IP is the fallback for networks that block broadcasts.
   - The connection times out after 8 s with a clear error message, and the lobby shows when the opponent joins or leaves.
   - On connecting, both phones exchange names (`share_name`), which then appear in the lobby, the match HUD and the result screen.
2. **Prepare:** the host sends a match seed and the chosen level to both phones (`prepare_match`).
3. **Load check:** each phone tells the host when its level has loaded. The host continues only when both have.
4. **Clock sync:** the joining phone measures the host's clock 5 times and keeps the sample with the shortest round trip. That gives the offset between the two phones' clocks.
5. **Synced start:** the host schedules the song start 4 seconds ahead in its own time. Each phone converts that to local time, so both countdowns and songs start together.
6. **Play:** each phone sends its score and lives whenever they change. Throws are sent as they happen.
7. **Finish:** each phone sends its final score and lives to the host. The host waits for both reports, then sends the final numbers to both phones, and each phone shows **YOU WIN! / YOU LOSE / DRAW**.
8. **Result → BACK TO LOBBY:** the connection is closed and all match data is reset, so the next match (with either phone hosting) starts clean.

### 6.2 What happens if the connection drops mid-match?
- Godot reports a lost peer (`peer_disconnected` on the host, `server_disconnected` on the joiner). The remaining phone stops the match, closes the connection and shows **OPPONENT LEFT**.
  - If the song had not started yet, it returns to the lobby with a message.
  - Otherwise it shows a Result screen with both players' last known numbers. No winner is declared.
- If a player finishes early and the rival never sends a final score, the phone stops waiting 15 seconds after the song should have ended and shows **NO RESULT**.
- A player can also leave on purpose with **LEAVE MATCH** in the pause menu, and the rival sees OPPONENT LEFT.
- ENet can take up to about 30 seconds to notice a connection that silently disappeared (for example, Wi-Fi turned off).

### 6.3 Why does the host decide the winner?
- Both phones have to agree on one result. If each phone judged the result itself, a delayed, lost or tampered message could give the two players different outcomes.
- The host is the single authority: it accepts only one final report per player, rejects impossible values (negative scores, lives outside 0–3), and sends the same final numbers to both phones.
- It also keeps the rules in one place. Clients only display what the host confirms.

### 6.4 Known limits
- Both phones must be on the same local network. There is no internet matchmaking.
- The match seed is shared but not yet used for any gameplay randomness.
- Online play can't be paused, because you can't freeze the other phone. The pause menu stays usable, but the match keeps running.

## 7. Screens and UI flow

```
Title (tap) ──► Mode Select ──► Offline Select ──► Level Select ──► Level ──► Result
                  │  │  │          (Solo / VS CPU)         ▲         │          │
                  │  │  └──► Lobby (Online) ───────────────┼─────────┘          │
                  │  │         ▲                           └──── NEXT / MENU ◄──┤
                  │  └──► Settings                         (pause)              │
                  └─────► Credits      └────────── BACK TO LOBBY ◄──────────────┘
```

| Screen | Contents |
| --- | --- |
| Title | Animated logo, food and axolotl (hops on the beat), "TAP TO START", menu music |
| Mode Select | Sound icon, Play Offline / Play Online cards, Settings, Credits, total stars |
| Offline Select | Solo / VS CPU cards, Back |
| Level Select | 5 meal cards (number, BPM, stars) or dashed LOCKED cards, star total, hint, Back |
| Lobby | Host panel (local IP, level picker, Start), Join panel (IP field), pink error panel, Back |
| Gameplay HUD | Pause, level + score, hearts, goal bar (Solo) or YOU vs RIVAL/CPU panel + tug bar; online throw meter + INCOMING! banner; judgment and combo pop-ups; drag anywhere to move |
| Pause | Level + bites caught, Resume, Restart (offline), Sound ON/OFF, Quit to Menu / Leave Match |
| Result | Outcome, stars (Solo) or rival score, score card with PERFECT/GOOD/MISS/MAX COMBO, unlock banner, Retry / Next / Menu or Back to Lobby |
| Settings | Sound ON/OFF, volume slider, audio delay (−200…+200 ms), progress summary + Reset progress (tap twice) |
| Credits | Fonts, music, art, engine |

**Visual style:** soft, light pixel art.
- **Colors:** lavender background (#FBF4FF), white panels, purple outlines and text (#5B4494 / #3B2A66), pink, blue and purple buttons.
- **Buttons:** 8 px borders with a drop shadow.
- **Fonts:** Press Start 2P for headings and buttons, Pixelify Sans for body text (28 px or larger, so it's readable on small screens).
- **Pixel art:** nearest-neighbour filtering at whole-number scales.

## 8. Progression and saving
- `GameState` (an autoload, so it persists across scenes) stores the highest unlocked meal, the best stars per meal, and the sound setting.
- They're saved to `user://save.cfg` whenever a Solo level is cleared or the sound setting changes, and loaded when the app starts, so progress survives closing the app.

## 9. Audio
- Six tracks: one menu theme plus one song per meal (see [CREDITS.md](CREDITS.md)).
- Each song has a JSON chart (`bpm`, beat times, melody notes with beat, duration and MIDI pitch) that the level turns into falling food.
- Sound on/off mutes the Master audio bus. It's available on the title screen and in the pause menu.

## 10. Lab requirements map

| Req | Requirement | Where it's implemented |
| --- | --- | --- |
| R1 | 5+ levels, each harder/different | 5 meals, rising BPM, rotten food from level 3, half-beats in level 5 (§4) |
| R2 | Goal shown at level start | "Goal: catch 40 bites!" during the countdown |
| R3 | Win/lose + result screen with Retry / Next / Menu | `result.tscn` / `Result.gd` |
| R4 | Next level locked until cleared | `LevelSelects.gd` + `GameState.unlocked_level` |
| R5 | Progress saved across app close | `GameState.save_game()` → `user://save.cfg` |
| R6 | Offline playable in airplane mode | Solo and VS CPU use no network |
| R7 | Two phones play the same match | Online mode (§5.3, §6) |
| R8 | Offline/Online menu + clear connection error | Mode Select; lobby error and timeout messages |
| R9 | Real Android phone, portrait, touch | Android export, `handheld/orientation` portrait, tap/drag lanes |
| R10 | Title, pause, sound on/off, readable text | Title, PauseMenu, sound toggle, theme fonts ≥ 28 px |

## 11. Playtesting

_[Fill in after testing: date, tester(s), device(s), what was tested, what went wrong, what you changed. Keep raw notes in `docs/playtest/`.]_

| Date | Tester | Device(s) | Mode / level | Findings | Change made |
| --- | --- | --- | --- | --- | --- |
| | | | | | |

## 12. Future ideas
- Pastel sparkle backgrounds and a styled gameplay HUD (hearts, goal bar, rival bar).
- Rematch without returning to the lobby.
- Use the shared match seed for online-only variations (e.g. random rotten food placement).
