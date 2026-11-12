# 4. Public operators take their random draws as arguments

Date: 2026-11-12 · Status: accepted

**Decision.** Selection, crossover and mutation are public `pure` procedures that receive their randomness (uniform draws, cut points, masks, noise) as arguments. The GA loop draws the numbers and calls the same public procedures.

**Why.** Users can compose their own loop from the operators, and tests can check each operator against literal expected values without seeding.

**Roulette.** Weight = fitness − worst fitness (windowing); uniform when all are equal. **Rank.** Weight = rank, worst 1 … best N, O(N²) ranking (fine up to a few thousand individuals).
