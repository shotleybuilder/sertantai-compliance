# Screener benchmark: qq (as_found)

Run 2026-09-25T10:47:09Z. Profile: priv/benchmarks/qq/profile_as_found.json. Reference: priv/benchmarks/qq/legacy_register.csv. Compared with 2026-09-25T10:27:51Z.

The legacy register is a reference, not ground truth: each disagreement is triaged in `triage.csv`.

**Corpus**: 3250 in-force UK Making laws, 546 with trees; screener applies to 349 (+64).

**Evaluable agreement**: 53.4% (+0.104) (in both, over in both + register-only laws the screener could evaluate).

## Agreement

| Agreement | Laws |
|---|---|
| both | 205 (+40) |
| register_only | 446 (-40) |
| screener_only | 144 (+24) |
| agree_no | 19 (-1) |

## Causes (ranked)

| Agreement | Side | Cause | Laws |
|---|---|---|---|
| register_only | classification | not_making | 163 |
| register_only | register | revoked | 104 |
| register_only | tree | no_tree | 74 |
| screener_only | tree | territory_branch_match | 70 |
| register_only | profile_or_tree | material_condition_miss | 37 |
| register_only | tree | generic_code_gate | 33 |
| screener_only | unknown | register_gap_or_overmatch | 28 |
| screener_only | tree | territory_only_tree | 16 |
| screener_only | tree | time_window_caveat | 15 |
| register_only | tree | gov_actor_gate | 14 |
| register_only | tree | construction_misfire | 12 |
| screener_only | tree | soft_disapplication | 8 |
| screener_only | screener | register_says_no | 7 |
| register_only | profile_or_tree | conditional_condition_miss | 3 |
| register_only | profile_or_tree | multi_condition_miss | 3 |
| register_only | profile_or_tree | territorial_condition_miss | 3 |

## Screener tiers

| Tier | Applies | In register |
|---|---|---|
| strong | 226 | 140 |
| probable | 120 | 65 |
| possible | 3 | 0 |

## Families (top 15)

| Family | Both | Register only | Screener only |
|---|---|---|---|
| 💙 OH&S: Occupational / Personal Safety | 25 | 60 | 14 |
| 💚 WASTE | 13 | 45 | 5 |
| 💚 ENVIRONMENTAL PROTECTION | 26 | 24 | 6 |
| (none) | 6 | 44 | 0 |
| 💚 CLIMATE CHANGE | 2 | 26 | 15 |
| 💚 WATER & WASTEWATER | 10 | 20 | 12 |
| 💙 FIRE: Dangerous and Explosive Substances | 7 | 16 | 7 |
| 💚 TOWN & COUNTRY PLANNING | 9 | 15 | 6 |
| 💙 PUBLIC: Consumer / Product Safety | 14 | 6 | 7 |
| 💚 WILDLIFE & COUNTRYSIDE | 9 | 10 | 8 |
| 💚 POLLUTION | 6 | 16 | 4 |
| 💙 TRANSPORT: Road Safety | 5 | 21 | 0 |
| 💚 NUCLEAR & RADIOLOGICAL | 5 | 10 | 5 |
| 💚 AIR QUALITY | 6 | 13 | 0 |
| 💚 ENERGY | 4 | 5 | 9 |
