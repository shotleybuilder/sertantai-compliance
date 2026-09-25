# Screener benchmark: qq (as_found)

Run 2026-09-25T10:27:51Z. Profile: priv/benchmarks/qq/profile_as_found.json. Reference: priv/benchmarks/qq/legacy_register.csv.

The legacy register is a reference, not ground truth: each disagreement is triaged in `triage.csv`.

**Corpus**: 3250 in-force UK Making laws, 546 with trees; screener applies to 285.

**Evaluable agreement**: 43.0% (in both, over in both + register-only laws the screener could evaluate).

## Agreement

| Agreement | Laws |
|---|---|
| both | 165 |
| register_only | 486 |
| screener_only | 120 |
| agree_no | 20 |

## Causes (ranked)

| Agreement | Side | Cause | Laws |
|---|---|---|---|
| register_only | classification | not_making | 163 |
| register_only | register | revoked | 104 |
| register_only | tree | no_tree | 74 |
| screener_only | tree | territory_branch_match | 70 |
| register_only | profile_or_tree | material_condition_miss | 36 |
| register_only | tree | outside_time_window | 30 |
| screener_only | unknown | register_gap_or_overmatch | 28 |
| register_only | tree | generic_code_gate | 24 |
| register_only | tree | disapplied_by_not | 23 |
| screener_only | tree | territory_only_tree | 16 |
| register_only | tree | construction_misfire | 11 |
| register_only | tree | gov_actor_gate | 11 |
| screener_only | screener | register_says_no | 6 |
| register_only | profile_or_tree | conditional_condition_miss | 3 |
| register_only | profile_or_tree | multi_condition_miss | 3 |
| register_only | profile_or_tree | territorial_condition_miss | 2 |
| register_only | profile_or_tree | personal_condition_miss | 1 |
| register_only | profile_or_tree | unexplained | 1 |

## Screener tiers

| Tier | Applies | In register |
|---|---|---|
| strong | 226 | 140 |
| probable | 56 | 25 |
| possible | 3 | 0 |

## Families (top 15)

| Family | Both | Register only | Screener only |
|---|---|---|---|
| 💙 OH&S: Occupational / Personal Safety | 23 | 62 | 13 |
| 💚 WASTE | 9 | 49 | 5 |
| (none) | 5 | 45 | 0 |
| 💚 ENVIRONMENTAL PROTECTION | 22 | 28 | 0 |
| 💚 CLIMATE CHANGE | 1 | 27 | 12 |
| 💚 WATER & WASTEWATER | 8 | 22 | 10 |
| 💙 FIRE: Dangerous and Explosive Substances | 4 | 19 | 6 |
| 💚 TOWN & COUNTRY PLANNING | 8 | 16 | 5 |
| 💚 WILDLIFE & COUNTRYSIDE | 9 | 10 | 8 |
| 💙 PUBLIC: Consumer / Product Safety | 13 | 7 | 6 |
| 💙 TRANSPORT: Road Safety | 3 | 23 | 0 |
| 💚 POLLUTION | 5 | 17 | 3 |
| 💚 AIR QUALITY | 4 | 15 | 0 |
| 💙 TRANSPORT: Maritime Safety | 1 | 15 | 2 |
| 💚 NUCLEAR & RADIOLOGICAL | 4 | 11 | 3 |
