# After launch · بعد الإطلاق

Agreed with the owner: these wait for an update after the first store release.

## Leaderboards (Meta Horizon platform leaderboards)

- Use Meta's own leaderboards (player names, friends, no server of ours), not a custom server.
- Needs: the INTERNET permission, leaderboards created in the Meta developer dashboard (one per
  scored mode), and works only in store builds (test through the ALPHA channel).
- Before building: confirm the Godot Meta Toolkit version in use exposes the leaderboard API.
- Update `store/privacy.html` (scores and the Meta user name go to Meta's services) and the
  Data Use answers in `store/DATA_USE.md` before shipping it.
- Placement: a «المتصدرين / Leaderboards» page in the menu (top 10 per mode, your rank,
  All / Friends); a small card after a new personal best ("You're #12 worldwide!");
  optional: a big board beside the court in the VR park.
