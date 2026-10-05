# VTuber Era — Phase 1 game design

The Convergence Festival is a friendly fantasy contest. A defeated unit
disperses into sparks and returns next round; the Commander stays in the UI.

## Match

Select Fire Commander → confirm four distinct Fire cards → Command Phase →
automatic battle → Heart result → repeat until one side has zero of four Hearts.
Both sides get three points in Round 1. Later winners get three and losers four.
Unused points disappear. No actions, positioning or targeting are allowed during
combat. Rematch creates fresh armies and Hearts with a new seed.

## Fire identity

The Commander grants +5% base attack damage to all allies and +5% attack speed to
Fire allies. Blazing Orders costs exactly one point, can be queued once per
round, leaves offers intact and adds +25% attack speed for the first six seconds
of only the next battle.

| Card | Role | Units per summon |
|---|---|---:|
| Emberbow Rangers | Fast single-target backline | 3 |
| Ashblade Warriors | Aggressive melee frontline | 3 |
| Cinderwall Guardians | High-HP interceptor | 1 |
| Flameveil Stalkers | Fast ranged-priority flanker | 1 |

Equipping four unique cards sharing `set_id=fire` activates Wildfire. Each unit's
first successful hit applies a non-stacking three-second Burn. An already active
Burn is neither multiplied nor refreshed. Missed projectiles do not use up the
attacker's first successful hit.

## Drafting

Three unique offers always include a normal card. Remaining slots choose among
available categories with editable 70/15/15 weights. Empty special categories
are filtered out and the remaining weights renormalized. The mandatory normal
slot means overall observed frequencies need not equal 70/15/15.

After two normal summons of an army, Reinforcement and Promotion are eligible.
Reinforcement doubles its current count, preserves Rank, and has a two-use
per-army limit. A proposed double exceeding 24 units/type or 72 units/side is
ineligible; it is not silently clamped. The player sees old and new counts and
confirms before spending a point. Promotion increases Rank to a maximum of 3 and
upgrades current and future units without changing count. Counts, Ranks, normal
summon history and Reinforcement history survive rounds.

Capped normal cards stay visible but disabled, preserving unique three-choice
offers even at the cap. No reroll exists. Start battle to discard unused points.

## Combat and fairness

The simulation is independent of Nodes and rendering. A single RNG owned by the
match drives offers. Combat itself uses no random numbers. It advances at 30
fixed ticks/second, preserves accumulated ticks at slow rendering rates, and
uses stable unit IDs to break distance ties. Both sides read start-of-tick
positions, move, and accumulate attack damage before simultaneous resolution.

Tanks spawn ahead of melee; archers occupy rear rows. Assassins follow upper or
lower flank waypoints before hunting ranged targets, then exposed melee, then
tanks. Melee and tanks select the nearest reachable enemy in the unobstructed
arena. Archers attack their nearest enemy within range; arrows travel and hit
inside the simulation. Friendly separation keeps silhouettes readable.

At 45 seconds, remaining HP as a fraction of each side's initial total decides
the round; surviving count is the next comparison. Exact ties enter escalating
damage sudden death. If both sides ultimately disperse in the same tick, a
visible draw consumes no Hearts and grants no comeback point. No coin flip or
unit-ID initiative awards a winner.

The AI spends the same legal offered actions, point costs, spell, rank and unit
limits. It scores frontline need, army size, upgrade value, opposing ranged
concentration and the previous loss. Its opponent snapshot is taken at the start
of the Command Phase; it cannot inspect player actions from that phase. F3
exposes the selected actions and scores.

## Presentation and extension

Parchment, warm brown outlines, honey, coral, orange and moss frame a sunny
woodland clearing. Original 32×32 chibi atlases contain six frames. Defeat is
harmless sparks. Reduced effects removes bounces, flashes and particles.

The match/offer/combat/view boundaries and custom Resources allow later content
to replace Fire data without changing the screen flow. Phase 2 still requires
new Water/Earth Resources, effect handlers, mixed-Warband selection and broader
AI tuning. These systems are not claimed as implemented in Phase 1.
