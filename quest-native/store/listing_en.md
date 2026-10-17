# Store listing (English) — Dahrooj

- Character counts were measured with Python `len()` on the text between the markers.
- The limits applied are 30, 150 and 1500 characters, which fit both Meta sources (see
  `REQUIREMENTS.md`).
- Every feature listed was checked against the code:
  - modes: `scripts/ui/menu_catalog.gd`, `scripts/game/game_runtime.gd`
  - shots: `scripts/game/shot_catalog.gd`
  - looks: `scripts/game/dahrooj_looks.gd`
  - mixed-reality room modes: `ROOM_MODES` in `scripts/main.gd`

## App name (7 / 30)

```
Dahrooj
```

- Alternative, if you want both scripts in every locale (15 / 30): `دحروج — Dahrooj`.

## Short description (131 / 150)

```
Throw, blast and pop colourful jelly Dahroojs in 20 playful modes, in a sunny VR park or all around your own room in mixed reality.
```

## Long description (1379 / 1500)

```
Meet Dahrooj: a round, bouncy little friend who loves being thrown, and a whole park full of his friends.

Pick virtual reality and play in a sunny park, or pick mixed reality and play in your own room. In mixed reality, seven arcade modes burst out of your real walls and floor, all around you.

20 MODES
• Throwing courses: goal, hoop, window, cans, bowling, bricks and the fair
• Arcade: Whack-a-Dahrooj, Dahrooj Attack, Slime, Dahrooj Meteors, Giant Dahrooj, Pop Frenzy, Dahrooj Fort and the shooting gallery
• Tabletop: balance, ricochet and maze boards you tilt and turn with your hands
• The Summit climb, and Dahrooj Rain

12 SHOTS
Bolt, mini Dahrooj, bubble, firework, confetti, bouncy, laser, boomerang, water, rocket, lightning, and a spinning dallah that sprays coffee beans.

YOUR OWN DAHROOJ
Jelly, fur or bubble, 12 colours and 47 accessories: shemagh & agal, ghutra, taqiyah, a falcon, a jasmine crown, a space helmet and many more.

65 CHALLENGES
Every challenge you finish unlocks a new shot, colour or accessory.

MADE FOR EVERYONE
• Open play: no timers and no game over in the arcade modes
• Throw your way: charge with the trigger, swing your hand, or use a slingshot
• Day, dusk, night and dawn, with clear skies, rain or snow
• Fully in Arabic and English
• Stand and play: no artificial movement
• Works offline. No accounts, no ads, no in-app purchases.
```

## Feature bullets

Use these where the dashboard asks for highlights.

- 20 modes: throwing courses, arcade action, tabletop puzzles, a summit climb and Dahrooj Rain
- Play in a sunny VR park, or in mixed reality, where targets come from your room's walls and floor
- 12 shots, from a bolt and a laser to fireworks, lightning and a coffee-spraying dallah
- 3 styles (jelly, fur, bubble), 12 colours and 47 accessories, including shemagh & agal, ghutra, taqiyah, falcon and jasmine crown
- 65 challenges, each one unlocking a reward (the last: the World Cup)
- Open play, with no timers or game over in the arcade modes
- Fully bilingual: Arabic and English
- Comfortable: you stand still and nothing moves you

## Keywords / tags

```
mixed reality, passthrough, throwing, jelly, cute, casual, arcade, family friendly, party, physics, shooting gallery, bubbles, tabletop, Arabic, Saudi, offline, no ads
```

## Genres

- **Suggested:** Casual (main), Arcade, Sports.
- **Mixed reality:** if the dashboard has a mixed-reality tag or category, tick it. Seven
  modes use the room, and VR or MR is chosen at the start.

## Comfort rating

- **Suggestion: Comfortable.**
- The player is stationary. There is no artificial locomotion, no smooth turning and no
  camera motion the player does not make. The world is placed around where you stand and
  then stays put.
- The Summit is a model mountain on the court: Dahrooj climbs it, the player does not move.
- Pop Frenzy and Dahrooj Attack have brief slow-motion moments for the game objects only,
  never for the view.

## Supported player modes

- **Standing:** yes. This is the main way to play; the VR park is built around a standing
  player.
- **Roomscale:** optional. You may step toward targets inside your boundary. The game uses
  the Local Floor reference space.
- **Seated:** do not tick it until it has been tested on the headset. The VR scale assumes
  standing height.

## Supported input

- **Touch Plus / Touch controllers:** required. The triggers fire shots and a grip holds
  Dahrooj. Three throw styles: charge, hand swing and slingshot.
- **Hand tracking:** not supported. `xr/openxr/extensions/hand_tracking=false` in
  `project.godot`, and no hand-tracking code.
- **Supported devices:** Meta Quest 3 and Quest 3S only (`com.oculus.supportedDevices` =
  `quest3|quest3s`).

## Languages

- **Arabic:** full user interface and text.
- **English:** full user interface and text.
- The game follows the headset language, and the player can switch it in the menu.
- There is no voice-over.

## Internet

- Not required. The APK does not declare the INTERNET permission.

## Age rating notes (IARC questionnaire)

Answer from what the game actually contains:

- **Violence:**
  - Cartoon/fantasy only. You throw balls and fire toy-like shots (bubbles, confetti,
    fireworks, a laser and similar) at round, cute, non-human jelly characters.
  - On a hit they pop into confetti and sparkles.
  - No blood, gore, injury, death animations, or realistic weapons or people.
  - The "monsters", "Attack" and "Giant" are the same cartoon Dahroojs.
- **Fear / horror:** none.
- **Sexual content or nudity:** none.
- **Language / profanity:** none.
- **Controlled substances:** none. The "dallah" is a traditional Arabic coffee pot that
  sprays coffee beans.
- **Gambling:**
  - No real-money or simulated gambling.
  - The "fair" is a carnival throwing game that scores points. There are no casino
    mechanics, no wagers and no loot boxes.
- **User interaction:** none. No chat, no voice, no user-generated content, no multiplayer
  and no sharing.
- **Location:** not collected.
- **Personal data:** none collected, sold or shared. Progress stays on the headset.
- **Purchases:** no in-app purchases and no digital goods sold inside the app.
- **Ads:** none.
- **Expected result:** a low rating, around E / PEGI 3–7, depending on how the questionnaire
  scores mild cartoon violence. Answer honestly and let IARC decide.
- **Meta age group (upload):**
  - CI defaults to `TEENS_AND_ADULTS`.
  - `MIXED_AGES` (10–12 included) brings extra Meta obligations for pre-teens. Read Meta's
    current mixed-ages requirements first; the app does not use the Age Category API.
  - `TEENS_AND_ADULTS` is the simpler start.
