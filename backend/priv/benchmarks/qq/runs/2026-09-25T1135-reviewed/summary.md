# Screener benchmark: qq (reviewed)

Run 2026-09-25T11:35:19Z. Profile: priv/benchmarks/qq/profile_reviewed.json. Reference: priv/benchmarks/qq/legacy_register.csv. Compared with 2026-09-25T10:47:10Z.

The legacy register is a reference, not ground truth: each disagreement is triaged in `triage.csv`.

**Corpus**: 3250 in-force UK Making laws, 546 with trees; screener applies to 394 (-40).

**Evaluable agreement**: 68.4% (+0.002) (in both, over in both + register-only laws the screener could evaluate).

## Agreement

| Agreement | Laws |
|---|---|
| both | 262 |
| register_only | 389 |
| screener_only | 132 (-40) |
| agree_no | 18 |

## Causes (ranked)

| Agreement | Side | Cause | Laws |
|---|---|---|---|
| register_only | classification | not_making | 163 |
| register_only | register | revoked | 104 |
| register_only | tree | no_tree | 73 |
| screener_only | unknown | register_gap_or_overmatch | 42 |
| screener_only | tree | territory_branch_match | 35 |
| screener_only | tree | soft_disapplication | 23 |
| register_only | tree | generic_code_gate | 21 |
| screener_only | tree | territory_only_tree | 15 |
| register_only | profile_or_tree | material_condition_miss | 10 |
| screener_only | tree | time_window_caveat | 9 |
| register_only | tree | construction_misfire | 8 |
| screener_only | screener | register_says_no | 8 |
| register_only | tree | gov_actor_gate | 5 |
| register_only | profile_or_tree | territorial_condition_miss | 3 |
| register_only | profile_or_tree | multi_condition_miss | 1 |
| register_only | register | outside_jurisdiction | 1 |

## Screener tiers

| Tier | Applies | In register |
|---|---|---|
| strong | 248 | 165 |
| probable | 144 | 97 |
| possible | 2 | 0 |

## Families (top 15)

| Family | Both | Register only | Screener only |
|---|---|---|---|
| 💙 OH&S: Occupational / Personal Safety | 45 | 40 | 4 |
| 💚 WASTE | 16 | 42 | 5 |
| 💚 ENVIRONMENTAL PROTECTION | 28 | 22 | 7 |
| (none) | 8 | 42 | 0 |
| 💚 WATER & WASTEWATER | 13 | 17 | 15 |
| 💚 CLIMATE CHANGE | 3 | 25 | 16 |
| 💚 TOWN & COUNTRY PLANNING | 10 | 14 | 6 |
| 💙 TRANSPORT: Road Safety | 9 | 17 | 2 |
| 💙 PUBLIC: Consumer / Product Safety | 15 | 5 | 7 |
| 💚 WILDLIFE & COUNTRYSIDE | 9 | 10 | 8 |
| 💚 POLLUTION | 7 | 15 | 4 |
| 💙 FIRE: Dangerous and Explosive Substances | 10 | 13 | 2 |
| 💚 NUCLEAR & RADIOLOGICAL | 6 | 9 | 5 |
| 💚 AIR QUALITY | 6 | 13 | 1 |
| 💚 ENERGY | 5 | 4 | 9 |
