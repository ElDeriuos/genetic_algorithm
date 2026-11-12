# genetic_algorithm

A classic genetic algorithm as one Modern Fortran module (F2018, `real64`, no dependencies), usable from any program via `use genetic_algorithm`.

- **Encodings:** binary (bit strings), real, integer
- **Selection:** roulette (with windowing), tournament, rank
- **Crossover:** one-point, two-point, uniform
- **Mutation:** bit-flip (binary), Gaussian clipped to bounds (real), multi-scale creep (integer)
- **Decoding:** bit strings to reals, plain binary or Gray code
- **Replacement:** generational with elitism; stops at `max_generations` or `target_fitness`

Terms are defined in [GLOSSARY.md](GLOSSARY.md); design decisions in [docs/adr](docs/adr).

## Install

**fpm:** add to your project's `fpm.toml`, then `fpm run` / `fpm build`:

```toml
[dependencies]
genetic_algorithm = { git = "https://github.com/ElDeriuos/genetic_algorithm", tag = "v0.1.1" }
```

**CMake:** `add_subdirectory(genetic_algorithm)` then `target_link_libraries(your_app PRIVATE genetic_algorithm)`.

**Plain compiler:** compile `src/genetic_algorithm.f90` before your own files:
`gfortran genetic_algorithm.f90 your_code.f90 -o your_app`. (The `.mod` file alone is not enough: it holds no compiled code.)

## Quick start

```fortran
module my_problem
  use, intrinsic :: iso_fortran_env, only: dp => real64
  implicit none
contains
  !> The GA MAXIMIZES fitness, so return minus what you want to minimize.
  function fitness(x) result(f)
    real(dp), intent(in) :: x(:)
    real(dp) :: f
    f = -((x(1) - 3)**2 + (x(2) + 1)**2)       ! minimum at (3, -1)
  end function fitness
end module my_problem

program demo
  use, intrinsic :: iso_fortran_env, only: dp => real64
  use genetic_algorithm
  use my_problem, only: fitness
  implicit none
  type(ga_result) :: res
  integer :: stat
  character(:), allocatable :: msg

  call ga_optimize(fitness, [-10._dp, -10._dp], [10._dp, 10._dp], &
                   ga_options(population_size=80, max_generations=300), res, stat, msg)
  if (stat /= 0) error stop msg
  print *, 'best x =', res%reals, '  f =', -res%fitness
end program demo
```

## `ga_optimize`: the three call forms

The encoding is chosen by the type of the second argument.

```fortran
call ga_optimize(fitness, n_bits,       opts, res [, stat, errmsg])   ! binary
call ga_optimize(fitness, lower, upper, opts, res [, stat, errmsg])   ! real    (real(real64) bounds)
call ga_optimize(fitness, lower, upper, opts, res [, stat, errmsg])   ! integer (integer bounds)
```

| Argument | Type | Meaning |
|---|---|---|
| `fitness` | function, see below | Scores one chromosome; **higher is better**. Called `population_size` times at the start, then `population_size - elite_count` times per generation. |
| `n_bits` | `integer`, in | Binary form only: length of the bit string (≥ 1). |
| `lower`, `upper` | `real(real64)(:)` or `integer(:)`, in | One bound per variable, same size, `lower(i) <= upper(i)`. The number of variables is `size(lower)`. Real bounds must be `real64`: write `5._dp`, not `5.0`, or no specific procedure matches. |
| `opts` | `type(ga_options)`, in | Settings, required. Pass `ga_options()` for all defaults, or set only what you need: `ga_options(selection=SELECT_RANK, elite_count=2)`. |
| `res` | `type(ga_result)`, out | The best chromosome found and run statistics. Reset on every call. |
| `stat` | `integer`, out, optional | `0` = success, `1` = invalid input (nothing was run). **If omitted, invalid input stops the program** with `genetic_algorithm: <message>`. |
| `errmsg` | `character(:), allocatable`, out, optional | Set only when `stat /= 0`: which input is wrong. Must be declared deferred-length allocatable. |

### The fitness function

Write it as a **module procedure** with exactly one of these interfaces (named `binary_fitness`, `real_fitness`, `integer_fitness` in the module):

| Encoding | Interface | Gets |
|---|---|---|
| binary | `real(real64) function f(bits)` with `logical, intent(in) :: bits(:)` | `n_bits` bits |
| real | `real(real64) function f(x)` with `real(real64), intent(in) :: x(:)` | values in `[lower, upper]` |
| integer | `real(real64) function f(k)` with `integer, intent(in) :: k(:)` | whole numbers in `[lower, upper]` |

- **Minimizing:** return `-f`. Fitness may be negative.
- **Extra data** (coefficients, measurements…): keep it in module variables and set them before calling `ga_optimize`, since the fitness receives only the chromosome.
- **Continuous problem with classic bit strings:** use the binary form and decode inside the fitness, for example `x = decode(bits, lower, upper, gray=.true.)`. Gray code is recommended (see [Choosing an encoding](#choosing-an-encoding)).
- **Internal procedures** (after `contains` inside a program) also work, but gfortran then needs an executable stack. Prefer module procedures.

## `ga_options`: settings

| Field | Type | Default | Meaning | Valid |
|---|---|---|---|---|
| `population_size` | integer | `50` | Chromosomes per generation. | ≥ 2 |
| `max_generations` | integer | `200` | Upper limit on generations. `0` evaluates only the random initial population. | ≥ 0 |
| `crossover_rate` | real64 | `0.9` | Probability that a parent pair is recombined; otherwise the children are copies. | [0, 1] |
| `mutation_rate` | real64 | `-1` | Probability that **each gene** mutates. Negative means `1 / number of genes` (the classic default). | ≤ 1 |
| `mutation_scale` | real64 | `0.1` | Size of mutation steps relative to the range. **Real:** Gaussian step σ = `mutation_scale × (upper − lower)`. **Integer:** largest creep step = `mutation_scale × (upper − lower)` (at least 1); step sizes are spread evenly over orders of magnitude between 1 and that. Results are clipped to the bounds. Smaller gives finer real results but a higher risk of local optima. Unused for binary. | ≥ 0 |
| `selection` | integer | `SELECT_TOURNAMENT` | `SELECT_ROULETTE`: probability ∝ fitness − worst. `SELECT_TOURNAMENT`: best of `tournament_size` random picks. `SELECT_RANK`: probability ∝ rank, so only the fitness order matters. | one of the 3 |
| `tournament_size` | integer | `2` | Contestants per tournament, drawn with replacement. Larger means stronger selection pressure. | ≥ 1 |
| `crossover` | integer | `CROSSOVER_ONE_POINT` | `CROSSOVER_ONE_POINT`: swap tails after a random cut. `CROSSOVER_TWO_POINT`: swap a random middle segment. `CROSSOVER_UNIFORM`: each gene from either parent, 50/50. | one of the 3 |
| `elite_count` | integer | `1` | Best chromosomes copied unchanged into the next generation. With ≥ 1, the best fitness never decreases. | 0 … `population_size − 1` |
| `target_fitness` | real64 | `huge` (off) | Stop as soon as the best fitness is `>= target_fitness`. | any |

## `ga_result`: output

| Field | Type | Meaning |
|---|---|---|
| `fitness` | real64 | Best fitness found. For a minimized `f`, the minimum is `-res%fitness`. |
| `generations` | integer | Generations actually run (less than `max_generations` if `target_fitness` was reached). |
| `history(0:generations)` | real64 array | Best fitness of each generation; `history(0)` is the initial population. |
| `bits(:)` | logical array | Best chromosome, **binary** form only. |
| `reals(:)` | real64 array | Best chromosome, **real** form only. |
| `ints(:)` | integer array | Best chromosome, **integer** form only. |

Only the array matching the call form is allocated; after invalid input (`stat /= 0`) none is.

## Choosing an encoding

Choose by what your variables are. With a realistic fitness function, run time is (number of fitness calls) × (cost of one call); the GA's own work per generation is about the same for real and integer (binary is ~4× more, for 16 bits per variable).

Generations needed to reach the exact optimum of `sum((x-3)**2)`, 10 variables, median of 8 seeds, default settings:

| Range | integer | real (until rounding gives the optimum) | binary, Gray (16 bits/var) | binary, plain |
|---|---|---|---|---|
| [-20, 20] | **80** | 205 | 89 | never |
| [-100, 100] | 276 | 1139 | **157** | never |
| [-1000, 1000] | 530 | never (3000 cap) | **288** | never |

- **Integer variables** (counts, sizes, ordered levels): use the integer form; it hits the exact optimum and can stop there with `target_fitness`.
- **Continuous variables:** real is the simplest. Binary with `gray=.true.` reached the region of the optimum faster in this test, but its precision is limited to `(upper − lower) / (2**bits − 1)`.
- **Plain binary** gets stuck at "Hamming cliffs" (for example 0111…1 → 1000…0 needs every bit to flip). Prefer `gray=.true.`.
- **Categorical integers** (codes where 3 is not "between" 2 and 4): neighbouring steps are meaningless, so write your own loop with `random_reset_mutation`.

## Reproducible runs

The library never seeds the random number generator; you do, before calling:

```fortran
! Option A: same results on every run
call random_init(repeatable=.true., image_distinct=.true.)

! Option B: a seed of your choice (declare  integer :: n, i)
call random_seed(size=n)
call random_seed(put=[(42 + i, i = 1, n)])
```

## Building blocks (optional)

To write your own GA loop, the operators are public. Each takes its random numbers as arguments, so it is deterministic and testable. Genes are `real(real64)` arrays: bits are 0/1, integers are whole numbers.

| Procedure | Arguments → result | What it does |
|---|---|---|
| `decode(bits, lower, upper [, gray])` | `logical(:)`, `real64(:)`, `real64(:)`, `logical` → `real64(size(lower))` | Splits bits evenly per variable (`size(bits)/size(lower)` each, most significant bit first) and maps each block linearly onto `[lower, upper]`. `gray=.true.` reads each block as Gray code; the default is plain binary. |
| `roulette_select(fitness, r)` | `real64(:)`, `r(:)` uniform in [0,1) → `integer(size(r))` | One pick per `r`; weight = fitness − worst. |
| `rank_select(fitness, r)` | same | One pick per `r`; weight = rank (worst 1 … best N). |
| `tournament_select(fitness, contestants)` | `real64(:)`, `integer(k, m)` → `integer(m)` | Each column of indices is one tournament; returns each column's fittest. |
| `one_point_crossover(p1, p2, cut, c1, c2)` | `1 <= cut < n` | `c1 = [p1(:cut), p2(cut+1:)]`, `c2` the mirror. |
| `two_point_crossover(p1, p2, cut1, cut2, c1, c2)` | `0 <= cut1 < cut2 <= n` | Swaps genes `cut1+1 … cut2`. |
| `uniform_crossover(p1, p2, mask, c1, c2)` | `logical mask(n)` | `c1` takes `p1` where `mask`, else `p2`; `c2` the mirror. |
| `bit_flip_mutation(genes, mask)` | inout `genes`, `logical mask` | Flips 0↔1 where `mask`. |
| `gaussian_mutation(genes, mask, noise, lower, upper)` | inout `genes`, arrays | `genes + noise` where `mask`, clipped to bounds. |
| `creep_mutation(genes, mask, r, s, max_step, lower, upper)` | inout `genes`, `r`, `s` in [0,1) | Integer step of size `round(max_step**r)` (1 … `max_step`, never 0), downward if `s < 0.5`, where `mask`; clipped to bounds. Used by the integer GA. |
| `random_reset_mutation(genes, mask, r, lower, upper)` | inout `genes`, `r` in [0,1) | `lower + floor(r × (upper − lower + 1))` where `mask`. Suits categorical integers, where neighbouring values mean nothing. |

## Tests

```sh
fpm test                                               # operators, benchmarks, invalid input
cmake -S . -B build/cmake && cmake --build build/cmake
ctest --test-dir build/cmake --output-on-failure       # the same, plus expected-failure tests
```

Benchmarks: OneMax-32, Sphere-3D, Rastrigin-2D (real and binary-decoded), Rosenbrock-2D, an integer target, a wide-range shifted sphere (integer exact optimum, integer faster than real, Gray-coded binary), and every selection × crossover pair. Expected-failure tests (in `test/xfail`, CMake only, since fpm cannot mark a test as expected to fail): invalid input without `stat` must stop the program, and a negative control proves the benchmark checks detect a GA that does not evolve.

## License

[MIT](LICENSE): free to use, modify and redistribute, including commercially; keep the copyright notice.
