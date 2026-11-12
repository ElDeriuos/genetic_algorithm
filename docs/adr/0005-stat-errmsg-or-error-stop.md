# 5. Invalid input: optional stat/errmsg, else error stop

Date: 2026-11-12 · Status: accepted

**Decision.** Follow the intrinsic `allocate(stat=, errmsg=)` convention: if `stat` is present, invalid input sets `stat = 1` and `errmsg` (naming the offending field) and returns; if absent, `error stop 'genetic_algorithm: <message>'`.

**Why.** A library must not kill a host program that wants to handle errors, yet silent failure is worse than stopping when nobody checks.
