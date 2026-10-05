# Phase 2 prototype balance

All values are editable custom Resources in `data/armies/`, `data/commanders/`,
`data/bonds/` and `data/balance.tres`. The generator reproduces the shipping
initial unit values; preserve custom tuning before rebuilding assets.

| Army | Group | Base HP/unit | Damage | Attacks/s | Move px/s | Range px |
|---|---:|---:|---:|---:|---:|---:|
| Ironroot Warriors | 2 | 80 | 10 | 0.75 | 32 | 23 |
| Runestone Marksmen | 2 | 44 | 13 | 0.65 | 28 | 150 |
| Runewood Trebuchet | 1 | 75 | 20 | 0.2 | 17 | 220 |
| Stoneguard Sentinels | 1 | 250 | 6 | 0.55 | 22 | 25 |
| Emberbow Rangers | 3 | 34 | 9 | 1 | 34 | 138 |
| Flameveil Stalkers | 1 | 60 | 13 | 1.55 | 62 | 19 |
| Ashblade Warriors | 3 | 64 | 8 | 1.05 | 39 | 20 |
| Cinderwall Guardians | 1 | 220 | 7 | 0.65 | 27 | 23 |
| Tidecallers | 2 | 34 | 6 | 0.6 | 30 | 146 |
| Waveblade Fighters | 3 | 52 | 6 | 0.9 | 35 | 21 |
| Moonwater Rangers | 3 | 34 | 7 | 1 | 32 | 154 |
| Coral Wardens | 1 | 180 | 6 | 0.55 | 24 | 23 |

| Rank | HP multiplier | Damage multiplier |
|---|---:|---:|
| 1 | 1.00 | 1.00 |
| 2 | 1.25 | 1.25 |
| 3 | 1.55 | 1.55 |

Commander bonuses apply after Rank. Fire attack speed is 1.05x for Fire allies,
1.30x during Blazing Orders; other realms receive the spell's 1.25x. Water max HP
is 1.05x for all allies, with 1.10x healing/shields only on Water recipients.
Earth max HP is 1.05x only for Earth allies; incoming damage is 0.95x normally
and 0.76x during Stonewall. Attack intervals round up to whole 30Hz ticks.

| Effect | Shipping value |
|---|---|
| Wildfire | First successful hit per unit: non-stacking 3s Burn, 3 HP/s |
| Tidal Recovery | Once below 50% HP: 12% max HP in three one-second ticks |
| Earthen Guard | Initial shield: 10% max HP |
| Coral Warden | Initial nearby shield: 8% max HP, 58px radius, 8s duration |
| Tidecaller | 25% movement Slow for 2s; 22px splash, 50% secondary damage |
| Waveblade | 15% actual HP-damage lifesteal; cap 2% max HP per second |
| Runewood | 34px splash, 70% secondary damage; fixed landing position |
| Projectile speeds | Fire 260, Tide 220, Moonwater 280, Runestone 240, Runewood 140 px/s |

Water affinity boosts Tidal Recovery to 13.2% and five Healing Current ticks to
16.5% max HP on Water units. Healing is capped by missing HP; the lifesteal cap
includes affinity. Shield absorption, Burn and overkill do not generate lifesteal.

| Match parameter | Value |
|---|---:|
| Hearts | 4 per side |
| Command Points | 3 per round; previous loser +1 |
| Action / spell cost | 1 point |
| Special eligibility | 2 normal summons |
| Reinforcements | 2 per army per match |
| Unit caps | 24 per army; 72 per side |
| Fixed ticks | 30/s |
| Normal battle limit | 45s |
| Sudden-death damage | 8 HP/s plus 4 HP/s per overtime second |

Three unique offers include one mandatory normal offer. Remaining category slots
use filtered 70% summon / 15% reinforce / 15% promote weights. Spell preparation
is independent of the offers. Commander choice and warband realm are independent.

## Balance sample

`tests/balance_simulations.gd` runs both sides with the same NormalAI and shared
budgets over eight fixed seeds for every ordered realm pairing (72 full matches).
The release sample is retained in `docs/qa/phase2-balance.json`. It measures this
AI policy and seed sample, not competitive player win rates. First-pass tuning
reduced the new armies' excessive durability and splash damage, and added
diminishing value to repeated assassin purchases. Fire's original base stats
remain unchanged. More player testing and a larger seed sample remain useful.

Correctness replay tests require identical outcomes for identical seeds/actions.
Balance tuning must never change results solely because of rendering speed.

| Player / rival | Player wins / 8 | Mean rounds |
|---|---:|---:|
| Fire / Fire | 4 | 6.00 |
| Fire / Water | 5 | 5.38 |
| Fire / Earth | 6 | 5.50 |
| Water / Fire | 6 | 5.75 |
| Water / Water | 4 | 5.50 |
| Water / Earth | 2 | 5.75 |
| Earth / Fire | 3 | 5.25 |
| Earth / Water | 7 | 5.62 |
| Earth / Earth | 4 | 5.62 |
