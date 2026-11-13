# Beat Bites: Game Design Document

**Course:** ITSD 85, Mobile Game with Level Progression and Offline/Online Multiplayer
**Engine:** Godot 4.7 (GDScript), GL Compatibility renderer
**Platform:** Android, portrait 720 × 1280, touch controls
**Author:** _[Your name]_

---

## 1. Concept

Beat Bites is a rhythm catching game. Food falls down three lanes in time with the music, and the player moves an axolotl catcher left, middle or right to catch each bite as it lands on the beat. Each level is a meal of the day with its own song and tempo, and the meals get faster and trickier from Breakfast to Dessert.

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
- Each note in a song's melody becomes one food. The note's **pitch decides its lane**: low notes go left, middle notes go center, high notes go right.
- Every food takes 3 seconds to fall from the top to the catch line. Its position is driven by the **audio clock** (`playback position + time since last mix − output latency`), so the food stays in sync with the music even when frames drop.

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
| 1 | Breakfast | Sunrise Bento | 90 | 64 s | 92 | 50 | Learn to catch (whole-beat notes) |
| 2 | Lunch | Lunchbox Letters | 100 | 77 s | 62 | 38 | Faster tempo |
| 3 | Snack | Soda Pop Sidequest | 115 | 67 s | 128 | 53 | Rotten food (every 10th food) |
| 4 | Dinner | Neon Noodle Rush | 125 | 77 s | 120 | 75 | Faster, more lane switches |
| 5 | Dessert | Sugar Star Sprint | 140 | 69 s | 312 | 175 | Half-beat notes: everything at once |

_"Playable foods" and "lane switches" are counted from each level's chart with its lane settings. Levels 1–4 use whole-beat notes only, and Dessert also uses half-beat notes._

All five levels use the same scene script (`Level.gd`). Each level scene sets its own `level_number`, chart file, pitch-to-lane limits and `notes_per_beat`.

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
1. **Lobby:** host/join, connection timeout (8 s) with a clear error message, and opponent join/leave notices.
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
| Gameplay HUD | Pause, level + score, hearts, goal bar (Solo) or YOU vs RIVAL/CPU panel + tug bar; online throw meter + INCOMING! banner; judgment and combo pop-ups; ◀ ▶ tap zones |
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
