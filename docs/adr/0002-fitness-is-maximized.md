# 2. Fitness is maximized

Date: 2026-11-12 · Status: accepted

**Decision.** The GA maximizes. To minimize `f`, the fitness returns `-f`. This matches the classic GA vocabulary ("fitness") and keeps one convention everywhere: elitism, `target_fitness`, `history`.

**Consequence.** Roulette selection must work with negative fitness, so it uses windowing (weight = fitness − worst). See ADR 4.
