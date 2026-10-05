# Initial Phase 1 balance

These are editable prototype targets. Unit statistics live in
`data/armies/*.tres`; global limits and multipliers are exported properties of
`data/balance.tres`; Fire effects are in `data/commanders/fire.tres` and
`data/bonds/wildfire.tres`. Godot's Inspector exposes defaults declared by their
custom Resource scripts; saving an override writes it into the Resource.

| Army | Group | Base HP/unit | Base damage | Attacks/s | Move px/s | Range px |
|---|---:|---:|---:|---:|---:|---:|
| Emberbow | 3 | 34 | 9 | 1.00 | 34 | 138 |
| Ashblade | 3 | 64 | 8 | 1.05 | 39 | 20 |
| Cinderwall | 1 | 220 | 7 | 0.65 | 27 | 23 |
| Flameveil | 1 | 60 | 13 | 1.55 | 62 | 19 |

| Rank | HP multiplier | Damage multiplier |
|---|---:|---:|
| 1 | 1.00 | 1.00 |
| 2 | 1.25 | 1.25 |
| 3 | 1.55 | 1.55 |

The Commander adds 5% damage after Rank multiplication. Fire attack speed is
1.05× normally and 1.30× during queued Blazing Orders. Attack intervals are
rounded upward to whole simulation ticks. Wildfire applies 3 damage each second
for three ticks (9 total) and cannot stack or refresh an active Burn. Ranged
projectiles travel at 260 px/s.

| Match parameter | Value |
|---|---:|
| Hearts | 4 per side |
| Normal Command Points | 3 per round |
| Previous-loss comeback | +1 point |
| Action / spell cost | 1 point |
| Special eligibility | 2 normal summons |
| Reinforcements | 2 per army type per match |
| Unit caps | 24/type; 72/side |
| Fixed ticks | 30/second |
| Normal battle limit | 45 seconds |
| Sudden-death damage | 8 HP/s, increasing by 4 HP/s each overtime second |

The mandatory normal offer slot is sampled uniformly without duplicate choices;
two additional slots use filtered 70% summon / 15% Reinforce / 15% Promote
category weights. Spell preparation is independent of offers.

## Tuning questions for playtesting

Measure match length, army diversity, frontline dependence, spell use and how
often special cards are chosen over summons. Test tank-heavy armies against
ranged groups; check that flankers can reach protected backlines without making
archers irrelevant. Reinforcement grows multiplicatively while normal summons
grow additively; limits and availability are deliberately shared with the AI.

Run identical seeds and actions before comparing render speeds. A change in
damage or outcome at the same fixed tick is a bug, not a balance adjustment.
The included seed replay tests validate this boundary. Competitive balance and
long-term retention are not established by the correctness test suite.
