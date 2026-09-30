# Rules-engine prototype (2026-09-30)

Throwaway proof that Diceroll's content behaviour can run as data (design
[§4.4](../../../design/2026-09-29-distribution-v2.md), research note
[13-rules-as-data.md](../13-rules-as-data.md)). It is kept as a reference for plan step R0, not as
production code: the `.gdignore` file keeps Godot from importing this folder.

| File | What it is |
|---|---|
| `rules.gd` | the evaluator (`core/rules/rules.gd` in the prototype): compiler, condition/value nodes, effect ops, limits, resources, per-hook dispatch |
| `rules_base.json` | 41 existing rules re-expressed as data: 25 relics, all rune triggers and the Ember/Echo/Vampire effects, the Arming Sword and its 5 variants, ascension `shop_tax`, the Moon King's moon meter |
| `core-hooks.patch` | the hook points the prototype added to `core/combat.gd`, `core/game_flow.gd`, `core/item_logic.gd` and `core/run_state.gd` (applies to `core/` as of `4e78bb6` with `git apply -p0`) |
| `golden.gd`, `replay.gd` | the A/B harness: greedy-bot runs with forced relics, runes and sword variants, hashing every event list and the final state |

Result: 220 runs (72,695 commands, 90,078 rule evaluations) and `tools/sim.gd` produced identical
hashes with and without the evaluator; engine time +15–20 %, end-to-end sims +3.5 %.

To reproduce: copy the repository into two scratch projects A and B; in B, put `rules.gd` and
`rules_base.json` under `core/rules/` and apply `core-hooks.patch`; copy `golden.gd` and `replay.gd`
into both; run `godot --headless --path <A|B> -s golden.gd -- --runs=10` in each and compare the
printed hashes.
