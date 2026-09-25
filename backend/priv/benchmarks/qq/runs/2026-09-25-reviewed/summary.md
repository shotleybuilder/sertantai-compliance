# Screener benchmark: qq (reviewed)

Run 2026-09-25T10:27:02Z. Profile: priv/benchmarks/qq/profile_reviewed.json. Reference: priv/benchmarks/qq/legacy_register.csv. Compared with 2026-09-25T10:26:35Z.

The legacy register is a reference, not ground truth: each disagreement is triaged in `triage.csv`.

**Corpus**: 3250 in-force UK Making laws, 546 with trees; screener applies to 299.

**Evaluable agreement**: 45.1% (in both, over in both + register-only laws the screener could evaluate).

## Agreement

| Agreement | Laws |
|---|---|
| both | 173 |
| register_only | 478 |
| screener_only | 126 |
| agree_no | 19 |

## Causes (ranked)

| Agreement | Side | Cause | Laws |
|---|---|---|---|
| register_only | classification | not_making | 163 |
| register_only | register | revoked | 104 |
| register_only | tree | disapplied_by_not | 79 |
| register_only | tree | no_tree | 74 |
| screener_only | unknown | register_gap_or_overmatch | 65 |
| screener_only | tree | territory_branch_match | 38 |
| register_only | tree | outside_time_window | 20 |
| screener_only | tree | territory_only_tree | 16 |
| register_only | tree | generic_code_gate | 15 |
| register_only | profile_or_tree | material_condition_miss | 9 |
| screener_only | screener | register_says_no | 7 |
| register_only | tree | construction_misfire | 6 |
| register_only | tree | gov_actor_gate | 4 |
| register_only | profile_or_tree | territorial_condition_miss | 2 |
| register_only | profile_or_tree | multi_condition_miss | 1 |
| register_only | profile_or_tree | unexplained | 1 |

## Screener tiers

| Tier | Applies | In register |
|---|---|---|
| strong | 270 | 165 |
| probable | 27 | 8 |
| possible | 2 | 0 |

## Families (top 15)

| Family | Both | Register only | Screener only |
|---|---|---|---|
| 💙 OH&S: Occupational / Personal Safety | 34 | 51 | 16 |
| 💚 WASTE | 9 | 49 | 4 |
| 💚 ENVIRONMENTAL PROTECTION | 20 | 30 | 2 |
| (none) | 4 | 46 | 0 |
| 💚 CLIMATE CHANGE | 2 | 26 | 14 |
| 💚 WATER & WASTEWATER | 9 | 21 | 12 |
| 💙 FIRE: Dangerous and Explosive Substances | 4 | 19 | 7 |
| 💚 TOWN & COUNTRY PLANNING | 6 | 18 | 5 |
| 💙 TRANSPORT: Road Safety | 5 | 21 | 2 |
| 💚 WILDLIFE & COUNTRYSIDE | 6 | 13 | 8 |
| 💙 PUBLIC: Consumer / Product Safety | 11 | 9 | 5 |
| 💚 POLLUTION | 6 | 16 | 2 |
| 💚 AIR QUALITY | 2 | 17 | 1 |
| 💙 TRANSPORT: Maritime Safety | 1 | 15 | 1 |
| 💚 NUCLEAR & RADIOLOGICAL | 5 | 10 | 2 |
