# 1. One GA loop for binary, real and integer encodings

Date: 2026-11-12 · Status: accepted

**Context.** Users asked for binary, real and integer chromosomes. Selection only needs fitness values, and the positional crossovers work for any gene type; only initialization, mutation and the fitness call differ.

**Decision.** Store every gene as `real(real64)` (bits as 0/1, integers as whole numbers) and run one private loop (`run`). `ga_optimize` is a generic with three specifics, chosen by the bounds arguments (`n_bits` scalar, real arrays or integer arrays). The user's fitness reaches `run` as one of three optional dummy procedures, not wrapped in an internal procedure: gfortran implements internal procedures passed as arguments with trampolines, which need an executable stack (observed: `ld: requires executable stack`).

**Consequences.** One loop to test and maintain. Gene values are converted (`> 0.5`, `nint`) on each fitness call, which is negligible next to any real fitness function. Integers are exact up to 2^53.
