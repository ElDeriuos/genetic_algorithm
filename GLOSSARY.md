# Glossary

Terms as used in the code, tests and docs of `genetic_algorithm`.

| Term | Meaning here |
|---|---|
| **Gene** | One variable of a solution. Stored internally as `real(real64)` for every encoding. |
| **Chromosome** | The full gene vector of one individual. |
| **Encoding** | How genes are represented: **binary** (bits, 0/1), **real** (continuous in `[lower, upper]`), **integer** (whole numbers in `[lower, upper]`). |
| **Decode** | Turn a bit string into reals: each block of `size(bits)/size(lower)` bits is read most-significant-bit first and mapped linearly onto `[lower, upper]`. |
| **Gray code** | A bit encoding in which neighbouring integers differ in exactly one bit (7 = 0100, 8 = 1100). Optional in `decode` (`gray=.true.`). |
| **Hamming cliff** | Neighbouring values whose plain binary codes differ in many bits (0111 → 1000), so mutation can rarely make that small step. Gray code removes them. |
| **Fitness** | The value the user's function returns for a chromosome. The GA **maximizes** it; to minimize `f`, return `-f`. |
| **Population** | The fixed-size set of chromosomes alive in one generation. |
| **Generation** | One step of: select parents → crossover → mutate → replace the whole population (keeping elites). |
| **Selection** | Choosing parents by fitness. **Roulette**: probability proportional to `fitness - worst fitness`. **Tournament**: best of `tournament_size` random contestants. **Rank**: probability proportional to rank (worst = 1, best = N). |
| **Crossover** | Building two children from two parents by position. **One-point**: swap tails after a cut. **Two-point**: swap the segment between two cuts. **Uniform**: each gene chosen by a mask. Applied with probability `crossover_rate`. |
| **Mutation** | Random change of single genes, each with probability `mutation_rate`. **Bit-flip** (binary), **Gaussian** (real, clipped to bounds), **creep** (integer). |
| **Creep mutation** | Add a nonzero integer step whose size is spread evenly over orders of magnitude, from 1 up to `mutation_scale × (upper − lower)`, then clip to bounds. Small steps fine-tune; large ones explore. |
| **Random reset** | Replace a gene with a uniform random value in bounds. Meant for categorical values; public operator only. |
| **Elitism** | Copying the `elite_count` best chromosomes unchanged into the next generation, so the best fitness never decreases. |
| **Target fitness** | Optional stopping rule: stop as soon as the best fitness is `>= target_fitness`. |
| **History** | Best fitness per generation, `history(0)` is the initial population. |
| **Expected-failure test** | A test program that must exit with a specific error; ctest checks its output for that message. |
