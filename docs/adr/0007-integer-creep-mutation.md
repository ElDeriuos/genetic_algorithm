# 7. Integer encoding uses multi-scale creep mutation

Date: 2026-11-12 · Status: accepted (supersedes random reset as the integer GA's mutation)

**Context.** The integer GA used random reset (a gene jumps to a uniform value in bounds). Textbooks reserve random reset for categorical values and recommend creep (small ± steps) for ordered ones. Measured on `sum((k-3)**2)`, 10 variables, 8 seeds, generations to the exact optimum: random reset needed 444 / 2575 / never on ranges ±20 / ±100 / ±1000, while real mode needed 205 / 1139 / never.

**Options measured.** (B) Gaussian step σ = `mutation_scale × range`, rounded, at least 1: 118 / 519 / 1 of 8 solved. (D) step size `round(max_step**r)`, r uniform, so sizes spread evenly over orders of magnitude from 1 to `max_step = mutation_scale × range`: **80 / 276 / 530**, all 8 solved. D gives what bit-flips give a binary GA (one small and one large step size per bit position) without an encoding, similar in spirit to the Breeder GA mutation (Mühlenbein & Schlierkamp-Voosen 1993). A step is never 0, which avoids the integer "fixation" reported for rounding-based schemes.

**Decision.** The integer GA uses D (`creep_mutation`). `random_reset_mutation` stays public for categorical problems.

**Consequences.** Integer runs differ from 0.1.x for the same seed. The GA's own cost per generation is about equal to real mode.
