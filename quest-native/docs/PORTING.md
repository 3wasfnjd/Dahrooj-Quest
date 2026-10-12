# Porting the web game to quest-native (Godot 4.6, GDScript)

The web game in the repository root (`src/reference/*`) is the specification. The owner
asked for a 100% faithful port: same numbers, same rules, same timings, same look.
Port line by line; keep the original's comments; do not "improve" behaviour.

## Units and time
- Game units as in the web code (ball radius `Ball.BR = 0.24`, gravity `Ball.GRAV = 13`).
- Stages are `Node3D`s placed at the game origin under GameRoot; build geometry in game units.
- Game time: the runtime calls `collide` / `update` with game seconds (three sub-steps per step).

## Stage interface (reference stage object -> GDScript)
A stage script `extends Node3D`, built in `_init()` (no scene file), with:
- `var aim_z` (aimZ), `var far_z = null` (farZ), `var reach_z = null` (reachZ),
  `var friction = null`, `var shot_time = null` (shotTime), `var ctx: GameCtx`.
- `func collide(b: Ball)`, `func update(b: Ball, dt: float)` — required.
- Optional: `on_respawn()`, `on_throw()`, `touched() -> bool`, `ball_contact(b)`,
  `behind(p) -> bool`, `deactivate()`, `shoot(node: Node3D, point: Vector3, dir: Vector3) -> bool`
  (a blaster shot hit `node`, a MeshInstance3D of this stage), `ft(speed)`.
- Ball rules: `b.success()`, `b.miss()`, `b.ooh()`, `b.hit(n, speed, contact)`, `b.react(kind, dur)`,
  `b.seg_collide(a, b, r, e)`, `b.point_collide(cp, r, e)`, fields `b.pos, b.vel, b.side, b.prev,
  b.shot, b.shot_t, b.scored_t, b.miss_t, b.grounded, b.held`.
- Everything else from `ctx` goes through `GameCtx` (`scripts/game/game_ctx.gd`): `ctx.sfx(name, k, pos)`,
  `ctx.add_count(mode, reset)`, `ctx.ch_progress(id, value)`, `ctx.toast(text)`,
  `ctx.confetti(pos, radius, elev, scale)`, `ctx.time`, `ctx.lang`, `ctx.t(ar, en)`, `GameCtx.ar_digits(n)`.
- Drawing helpers: `StageArt` (`ground_line`, `bar`, `net_grid` / `net_poke` / `net_update`, materials).
  Add a helper there (e.g. `rbox`, `ground_arc`) only if the stage needs it; keep the original's look.
- See `scripts/game/stages/goal_stage.gd` as the worked example (port of `stages/goal.js`).

## Sounds
Stage-local Web Audio functions (e.g. a can's clang) are rendered to WAV files offline by the audio
port; in GDScript call `ctx.sfx("<stage>_<function>", k, pos)` where `k` is the function's main
argument (0..1 or its natural value — document it) and pos the sound's place in game units.

## Materials and colour
Colours: `Color("hex")` (Godot linearises them as three.js does). Lit stage objects use
`StandardMaterial3D` with the reference roughness/metalness; unlit ones `SHADING_MODE_UNSHADED`.

## Tests
Each stage gets headless checks in its own file `tests/stage_<id>_test.gd`:
`static func run(check: Callable) -> void`, calling `check.call(ok: bool, what: String)`.
Drive the real rules: build the stage, a `Ball`, `ball.set_stage(stage, id)`, throw with a
velocity that should score and one that should not, step `ball.step(1.0/72.0)`, and assert the
outcome (the success/miss signal, counts, knocked objects). Free the stage afterwards.
Run the suite with `tools/run_tests.sh` (Godot 4.6.3 is installed as `godot`).
