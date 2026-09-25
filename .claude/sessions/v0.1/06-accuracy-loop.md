---
session: "v0.1-06: Accuracy Iteration Loop"
status: pending
opened: 2026-09-25
parent: v0.1/meta.md
depends_on: ["v0.1/04-screener-benchmark"]

summary: >
  Weekly loop: run the benchmark, rank causes, fix data (mostly in
  sertantai-legal), re-run, then do manual QA sessions with the QQ profile.
  Target ≥95% recall on in-force Making laws in QQ's register, with every
  remaining FP explained. The backend work list is sertantai-legal#161.
---

# Session: Accuracy Iteration Loop (PENDING)

Keep this loose. The benchmark results decide the order of work.

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
