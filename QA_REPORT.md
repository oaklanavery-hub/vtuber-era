# Phase 2 validation — 5 October 2026

## Release configuration

Exact Godot `4.5.stable.official.876b29033`, standard GDScript, Compatibility
renderer, 640x360 with preserved 16:9 and nearest filtering. Web threads and
GDExtensions are disabled. Official engine/templates were SHA-512 verified;
exported HTML, JavaScript, WebAssembly and resource-pack files were checked.
The Web output includes `.nojekyll` and engine/font notices.

## Automated correctness

- `tests/run_tests.gd`: **1,030 checks; 0 failures**.
- `tests/elemental_tests.gd`: **16,212 checks; 0 failures**.
- `tests/ui_smoke.gd`: **0 failures**, without engine/script errors.

Coverage includes shared economy/caps/offers, all three Commanders and spells,
independent mixed loadouts, per-side AI offers/frozen snapshots, shield absorption
and expiry, affinity bonuses, non-stacking Slow and Burn, timed healing without
resurrection, actual-damage lifesteal and caps, Tidal Recovery's same-tick threshold,
siege travel/targeting/splash, assassin backline priority and version 0/1 migration.
The elemental suite completes 33 full four-Heart matches including seeded replay
across all nine ordered realm pairings and all Commanders with a mixed warband.
Every completed battle checks finite bounded HP and cleared temporary effects.

UI smoke exercises all Commander/compendium pages, incomplete/overfull loadout
rejection, mixed drafting against an independent rival, spells, real combat,
round advancement, Victory, Defeat and Rematch.

## Exported browser play

Real Chromium 151 runs the release WebAssembly/WebGL build over ordinary HTTP
at `/vtuber-era/`, without custom cross-origin isolation headers. All four final
scenarios passed complete matches, settings/loadout persistence across reload,
spell offer preservation, one-point draft actions, reinforcement confirmation,
promotions, comeback points, round Hearts, results and Rematch.

| Player warband | Rival | Rounds | Reinforcements | Promotions |
|---|---|---:|---:|---:|
| Fire | Fire | 5 | 1 | 4 |
| Water | Earth | 6 | 6 | 3 |
| Earth | Water | 5 | 2 | 2 |
| Mixed | Fire | 6 | 5 | 3 |

Each scenario recorded **zero engine, JavaScript or HTTP errors**. Screenshots
were visually inspected at 1280x720 and 1000x720. Commander cards, all twelve
army selections, pure/mixed bond information, long spell names, ranged/siege
sprites and dynamic opposing realms fit the logical layout. Space starts combat
while a card has focus. Rematch restores four Hearts, three points, no armies,
no queued spell and a new seed while retaining the chosen loadout.

The traces and real actions are in `docs/qa/phase2-browser-*.json`;
`docs/screenshots/phase2.png` shows Earth versus Water combat, and
`phase2-warband.png` shows an independent Water Commander with mixed cards.

## Balance sample

`tests/balance_simulations.gd` completed **72 full AI matches**: eight fixed seeds
for all nine ordered realm pairings, using the same AI policy and budgets on both
sides. Final results are in `docs/qa/phase2-balance.json`. All pairings produced
wins for both sides in the sample. Mean match lengths ranged from 5.25 to 6 rounds.
Initial Water/Earth dominance led to stat/splash reductions and diminishing value
for repeated assassin summons. Original Fire base stats are preserved.

This sample demonstrates varied outcomes and termination, not competitive player
balance. Additional seeds, player strategies and larger roster performance tests
remain useful.

## Publishing

The existing public source is
[oaklanavery-hub/vtuber-era](https://github.com/oaklanavery-hub/vtuber-era).
The Pages workflow installs the exact engine/templates, runs all three
correctness suites, exports and deploys to the existing
[playable URL](https://oaklanavery-hub.github.io/vtuber-era/).

## Remaining validation

Firefox, Safari and mobile performance remain untested. Portraits/art/music are
replaceable placeholders, and active matches are not saved. Versioned settings
and selected loadouts preserve existing saves without resetting them.
