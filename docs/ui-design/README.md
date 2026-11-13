# Beat Bites UI design (soft light)

Reference mockups for the Godot screens. Designed at 390 x 844 (phone size);
the game runs at 720 x 1280, so multiply mockup sizes by about 1.85.

- `png/` - screenshot of each screen (2x). Look at these first.
- `html/` - the same screens as HTML. Open in a browser, or read the inline
  styles for exact colors, font sizes, borders and spacing.

| File | Screen |
|---|---|
| 01_title | Title screen |
| 02_mode_select | Main menu: Offline / Online, Settings, Credits |
| 03_level_select | Meal list with stars and locked levels |
| 04_online_lobby | Host / join by IP, "can't reach host" error |
| 05_gameplay | Gameplay HUD: pause, score, hearts, goal bar, lanes, tap zones |
| 06_pause | Pause menu: resume, restart, sound toggle, quit |
| 07_result | Result: outcome, stars, stats grid, unlock banner, Retry/Next/Menu |
| 08_online_match | Online HUD: you vs rival, throw meter, INCOMING! warning |

Notes
- The catcher drawn in the mockups is an early placeholder (blue bowl). Use the
  axolotl sprites in res://assets/art (catcher_*.png, rival_*.png).
- Numbers shown (scores, IP, stars) are sample values.
- Build screens with Godot Control nodes + containers and one shared Theme,
  not by copying absolute positions.
