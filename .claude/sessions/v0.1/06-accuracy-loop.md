---
session: "v0.1-06: Accuracy Iteration Loop"
status: pending
opened: 2026-09-25
parent: v0.1/meta.md
depends_on: ["v0.1/04-screener-benchmark", "v0.1/04b-screener-tuning", "sertantai-legal#161"]

summary: >
  Weekly loop: run the benchmark, rank causes, fix data (mostly in
  sertantai-legal), re-run, then do manual QA sessions with the QQ profile.
  Target ≥95% recall on in-force Making laws in QQ's register, with every
  remaining FP explained. The backend work list is sertantai-legal#161.
---

# Session: Accuracy Iteration Loop (PENDING)

Keep this loose. The benchmark results decide the order of work.

## Blocked on sertantai-legal data (2026-09-25)

Compliance-side tuning is done for now (04: benchmark; 04b: prefer-inclusion semantics, QQ reviewed agreement 68.2%). **Further tuning is blocked on legal data improvements** tracked in sertantai-legal#161:
- Making classification (163 register laws never screened)
- tree coverage (74 QQ laws; 83% of Making laws corpus-wide)
- territory-only branches (54 over-matches)
- Not and TimeWindow extraction (caveat noise)

Resume this loop as those fixes land. Re-run `mix screener.benchmark` (it reports deltas) and tune from the ranked causes.

### Updates from sertantai-legal

- **2026-09-25: geo_extent fixed** (legal#162, `106962e`) on the shared dev DB. 11,158 UK laws were updated, and devolved laws are no longer mislabelled UK (nisr → NI, ssi → S). New column `geo_extent_source`: when it's NULL the value is legacy and unverified, so treat it only as an upper bound. Compliance's type-code jurisdiction exclusion is unaffected; the QQ benchmark reported by legal is 68.0%.
- **Coming: legal#163**, columns `application_regions`, `application_source` and `application_evidence` (filled by fractalaw, e.g. England only). Proposal: the screener gates on `application_regions` when set, otherwise on `geo_extent` as an upper bound. **Compliance work when it lands:** add that gate to `Fitness.Jurisdiction`/`Screener` as a categorical exclusion (consistent with prefer-inclusion: only authoritative sources exclude), then re-run the benchmark.

## Loop (weekly checkpoints: ~3 Oct baseline, 10 Oct, 17 Oct)

1. Run `mix screener.benchmark --org qq` and diff it against the last run.
2. Rank FN and FP causes by count.
3. Fix the top causes. Most are legal-side; see sertantai-legal#161.
4. Push the data to prod (session 03's recurring push) and re-run.
5. Manual QA session: walk the QQ profile through the screener as a QQ user would. Log what surprises or confuses.

## Likely early work (from the 2026-09-25 review)

- Expression-tree coverage for laws in QQ's register (~694 of ~1,800 Making laws have trees)
- Amendment and Fees SIs: a procedural tag or Making review
- Revoked-status audit
- LAT for 19 in-force Making laws from the QQ requirements set, plus 9 deferred BMS laws
- Welsh `asc` scrape gap (legal#114) and `family_ii` nulls (legal#83)
- Confidence tuning (#17 heuristic, legal#144), once the tree data improves
- Compliance-side: hide definitions from revoked laws (#22)

## Exit criteria

- Recall target met, or the remaining gap explained and accepted
- FPs categorised and explainable to QQ
