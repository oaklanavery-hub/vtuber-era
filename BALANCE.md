# Phase 2 prototype balance

All values are editable custom Resources in `data/armies/`, `data/commanders/`,
`data/bonds/` and `data/balance.tres`. The generator reproduces the shipping
initial unit values; preserve custom tuning before rebuilding assets.

| Army | Group | Base HP/unit | Damage | Attacks/s | Move px/s | Range px |
|---|---:|---:|---:|---:|---:|---:|
| Armadillos | 2 | 80 | 10 | 0.75 | 32 | 23 |
| Wood Archers | 2 | 44 | 13 | 0.65 | 28 | 150 |
| Wooden Siege | 1 | 75 | 20 | 0.2 | 17 | 220 |
| Trees | 1 | 250 | 6 | 0.55 | 22 | 25 |
| Fire Lizards | 3 | 34 | 9 | 1 | 34 | 138 |
| Red Ninjas | 1 | 60 | 13 | 1.55 | 62 | 19 |
| Fire Imps | 3 | 64 | 8 | 1.05 | 39 | 20 |
| Magma Golems | 1 | 220 | 7 | 0.65 | 27 | 23 |
| Water Wizards | 2 | 34 | 6 | 0.6 | 30 | 146 |
| Water Slimes | 3 | 52 | 6 | 0.9 | 35 | 21 |
| Snowmen | 3 | 34 | 7 | 1 | 32 | 154 |
| Ice Golems | 1 | 180 | 6 | 0.55 | 24 | 23 |
| Candle | 2 | 65 | 7 | 0.55 | 26 | 132 |
| Penguin | 2 | 72 | 4 | 0.50 | 28 | 138 |
| Pitcher Plant | 2 | 95 | 13 | 0.65 | 26 | 20 |

| Rank | HP multiplier | Damage multiplier |
|---|---:|---:|
| 1 | 1.00 | 1.00 |
| 2 | 1.25 | 1.25 |
| 3 | 1.55 | 1.55 |

Commander bonuses apply after Rank. Fire attack speed is 1.05x for Fire allies.
Water max HP
is 1.05x for all allies, with 1.10x healing/shields only on Water recipients.
Earth max HP is 1.05x only for Earth allies; incoming damage is 0.95x.
Attack intervals round up to whole 30Hz ticks.

## Commander active skills

All cost one Command Point, prepare once per round independently of offers,
and cast automatically at battle start. These replace the earlier timed buffs.
Unspecified damage, area, opening duration and wall dimensions use these initial
Resource-backed values. Commander passives remain unchanged.

| Skill | Shipping value |
|---|---|
| Meteor Rain | Exactly 6 strikes across 3×2 enemy zones; 30 damage per enemy within 34px; first impact 0.5s, then 0.22s intervals; 2s opening at normal playback |
| Frozen Field | All enemies move ×0.85 and have defence ×0.92 for the whole round; strongest movement slow wins |
| Uproot | 3 staggered 12×72px solid walls on the enemy field; blocks movement, projectiles and attack line of sight for both teams; lasts the round |

Meteors apply normal incoming-damage reduction, defence and shields without
army damage/rank multipliers, first-hit Burn or lifesteal. They trigger normal
death effects, revivals and splits. Voluntary movement waits during the opening;
Imp death blasts can still push surviving units physically;
the 45-second battle timer starts afterwards. Ice uses a global enemy modifier,
so revivals and newborn Slimes remain affected. Defence is a resistance scalar:
damage is divided by 0.92 under ice (about 8.7% more). Earth passive and ice
compose as 0.95/0.92, before shield absorption. Walls are indestructible, stand
between spawn columns and leave routes around their ends. Projectiles are
absorbed at a swept wall intersection and do not splash through the obstacle.

| Effect | Shipping value |
|---|---|
| Wildfire | First successful hit per unit: non-stacking 3s Burn, 3 HP/s |
| Tidal Recovery | Once below 50% HP: 12% max HP in three one-second ticks |
| Earthen Guard | Initial shield: 10% max HP |
| Ice Golem | Initial nearby shield: 8% max HP, 58px radius, 8s duration |
| Water Wizard | 25% movement Slow for 2s; 22px splash, 50% secondary damage |
| Water Slime | 15% actual HP-damage lifesteal; cap 2% max HP per second |
| Wooden Siege | 64px splash, 70% secondary damage; fixed landing position |
| Projectile speeds | Fire 260, Water Wizard 220, Snowman 280, Wood Archer 240, Wooden Siege 140 px/s |

Water affinity boosts Tidal Recovery to 13.2% max HP on Water units.
Healing is capped by missing HP; the lifesteal cap
includes affinity. Shield absorption, Burn and overkill do not generate lifesteal.

## Army passives

The requested percentages and intervals are retained. Unspecified sizes, damage,
lifetimes and repeat limits use these initial values; they are editable in each
army Resource or the `UnitStats` defaults. This is a correctness-tested starting
point, not a competitive balance claim.

| Army | Passive |
|---|---|
| Fire Lizard | Every projectile splashes a 16px radius, full primary / 50% secondary damage |
| Fire Imp | Death explosion: 24px radius, 100% current attack damage, 12px radial pushback, independent 3 HP/s Burn for 2s; enemies only. Multiple blasts refresh rather than stack Burn |
| Magma Golem | Moving 48px fire ring, matching the Ice Golem radius: 3 HP/s to enemies inside; strongest overlapping ring wins; stops on leaving or Golem death |
| Red Ninja | Two-second charge (60 combat ticks), then one collision-safe teleport behind enemy lines per battle. Resurrects once at 30% actual max HP; does not reset a spent teleport. Reachable defenders take priority over distant targets |
| Water Wizard | Each splash projectile pushes affected enemies 12px; simultaneous pushes cap at 24px per tick and stop at bodies/walls/arena edges |
| Ice Golem | Moving 48px radius aura: enemy movement ×0.85 and attack cooldown progress ×0.85 while inside; does not stack with other Golems or stronger slows; ends on leaving or Golem death |
| Water Slime | Splits once into 2 mini Slimes, each 50% parent's current attack damage and max HP; children retain lifesteal and cannot split again |
| Snowman | On death throws its head at the nearest surviving enemy; impact has a 24px radius and 100% current attack damage |
| Tree | Every 2s, heals itself and living allies within 48px for 5% of each recipient's max HP, before any healing affinity |
| Armadillo | Bounces every 3s; enemies within 36px receive 20% attack-speed Slow for 2s; strongest value wins |
| Wood Archer | Every 5s when in range with clear line of sight, fires 3 arrows sharing one attack's total damage; prefers distinct visible enemies, repeats targets when fewer than 3 |
| Wooden Siege | Every stone explodes over a huge 64px radius, retaining 70% secondary damage |
| Candle | Full attack damage across a 24px splash. Leaves a stationary 3s fire pool: 3 HP/s while inside; pools do not stack and cannot burn through a wall |
| Penguin | Full attack damage across a 30px splash. Each stationary puddle lasts 3s and heals living allies in range for 5% actual max HP at 1s, 2s and 3s. Every puddle heals independently, so overlaps stack. Recipient affinity applies and HP clamps at max |
| Pitcher Plant | First available pull after 1s, then 5s cast cooldown. Prefers visible ranged/mage/siege prey within 154px; distinct plants claim distinct targets. 0.5s root windup, then up to 2s of 180px/s swept pulling, stopping at bodies/walls/arena bounds. One attack's melee damage on reaching contact; otherwise releases without a remote bite |

Wizard movement Slow and Golem aura are independent; only the strongest active
value affects speed. Armadillo attack Slow and the aura also use the strongest value. Attack Slow reduces progress on the ongoing attack
cooldown as well as subsequent cycles. Fire-ring damage, Candle ground Burn,
Imp-blast Burn and Wildfire are independent. Ground pools survive their caster's
death and clear at their lifetime or round end. Death pushback enters the next swept movement
tick, capped with other simultaneous pushes at 24px, and stops at bodies, walls
and arena edges. Rank and commander damage bonuses carry through split arrows,
children and death blasts. Births use free collision positions and do not change
persistent draft counts, summon caps, reinforcements or promotions. Last-unit
resurrection/splitting and thrown heads settle before elimination resolves.

| Match parameter | Value |
|---|---:|
| Arena | 600×280; nine 24px-spaced spawn rows; movement bounds (16,28)–(584,258) |
| Hearts | 4 per side |
| Command Points | 3 per round; previous loser +1 |
| Action / spell cost | 1 point |
| Special eligibility | 2 normal summons |
| Reinforcements | 2 per army per match |
| Unit caps | Per army: ranged 8, melee 10, tanks 3, mages 5, assassins 3, siege 4. Specialist overrides: Candle 4, Penguin 4, Pitcher Plant 6. 72 per side safety ceiling |
| Fixed ticks | 30/s |
| Normal battle limit | 45s |
| Sudden-death damage | 8 HP/s plus 4 HP/s per overtime second |

Normal summons and reinforcements fill the remaining slots below these caps.
Cards and confirmation show the exact gain; saturated armies cannot spend points
on more units. Promotions are unaffected. Slime children are combat-only.

Three unique legal offers include a summon whenever units can still be added.
Remaining slots use filtered 50% summon / 15% reinforce / 15% promote / 20% power
weights. If all army counts are capped, a power replaces the guaranteed summon;
if counts and ranks are capped, all three offers are powers. Each army-wide
power costs one Command Point and adds 15% HP, 10% damage, 12% defence or 10%
attack speed for the match. Repeats add percentages; defence divides damage by
`1 + 0.12 × cards`, and other bonuses multiply rank/commander-adjusted stats.
The AI buys powers through the same pool, points and rules. Spell preparation
preserves offers. Commander choice and warband realm remain independent.

## Balance sample

The table below is historical evidence from **before solid collision and army passives**. The
creature update preserves all base stats and roles, but new passives, its larger
arena and permanent body blocking change engagements; these earlier win rates
must not be treated as measurements of the new movement system. Melee contact
uses a 7.2px solid body footprint, reduced 70% in each dimension from 24px;
spawn spacing remains 24px and ranged reach remains centre-to-centre.

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
