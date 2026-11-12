# 3. The caller owns the random number generator

Date: 2026-11-12 · Status: accepted

**Decision.** The library draws from the intrinsic `random_number` and never calls `random_seed`/`random_init`. Callers (and tests) seed it for reproducibility.

**Rejected.** A private PRNG inside the library: more code, and it would duplicate what the intrinsic already provides (gfortran keeps per-thread RNG state).

**Consequence.** Results are reproducible for a given seed and compiler, not across compilers. Tests therefore assert tolerances, not exact trajectories.
