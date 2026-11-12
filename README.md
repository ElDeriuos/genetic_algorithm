# genetic_algorithm

A classic genetic algorithm as one Modern Fortran module (F2018, `real64`), usable from any program via `use genetic_algorithm`.

- **Encodings:** binary (bit strings), real, integer
- **Selection:** roulette (with windowing), tournament, rank
- **Crossover:** one-point, two-point, uniform
- **Mutation:** bit-flip (binary), Gaussian clipped to bounds (real), random reset (integer)
- **Replacement:** generational with elitism; stops at `max_generations` or `target_fitness`

Terms are defined in [GLOSSARY.md](GLOSSARY.md); design decisions in [docs/adr](docs/adr).

## Add it to your project

**fpm** (`fpm.toml` of your project):

```toml
[dependencies]
genetic_algorithm = { git = "https://github.com/<you>/genetic_algorithm" }  # or { path = "../GA" }
```

**CMake:**

```cmake
add_subdirectory(GA)        # or FetchContent
target_link_libraries(your_app PRIVATE genetic_algorithm)
```

## Use it

The GA **maximizes** fitness. To minimize `f`, return `-f`.

```fortran
module my_problem
  use, intrinsic :: iso_fortran_env, only: dp => real64
contains
  function neg_sphere(x) result(f)          ! minimize sum(x**2)
    real(dp), intent(in) :: x(:)
    real(dp) :: f
    f = -sum(x**2)
  end function
end module

program demo
  use, intrinsic :: iso_fortran_env, only: dp => real64
  use genetic_algorithm
  use my_problem
  implicit none
  type(ga_result) :: res
  integer :: stat
  character(:), allocatable :: msg

  call random_init(repeatable=.true., image_distinct=.true.)   ! you own the RNG seed
  call ga_optimize(neg_sphere, [-5._dp, -5._dp], [5._dp, 5._dp], &
                   ga_options(population_size=80, selection=SELECT_RANK), res, stat, msg)
  if (stat /= 0) error stop msg
  print *, 'best x =', res%reals, ' f =', -res%fitness, ' after', res%generations, 'generations'
end program
```

One generic call, three encodings (picked by the arguments):

| Call | Fitness receives | Best result in |
|---|---|---|
| `ga_optimize(f, n_bits, opts, res [, stat, errmsg])` | `logical :: bits(:)` | `res%bits` |
| `ga_optimize(f, lower, upper, opts, res [, stat, errmsg])` with `real(real64)` bounds | `real(real64) :: x(:)` | `res%reals` |
| `ga_optimize(f, lower, upper, opts, res [, stat, errmsg])` with `integer` bounds | `integer :: k(:)` | `res%ints` |

For the classic "binary-coded reals", decode inside your fitness: `x = decode(bits, lower, upper)`.

`ga_options` fields (all have defaults): `population_size=50`, `max_generations=200`, `crossover_rate=0.9`, `mutation_rate=-1` (means 1/genes), `mutation_scale=0.1` (Gaussian sigma as a fraction of the range), `selection=SELECT_TOURNAMENT`, `tournament_size=2`, `crossover=CROSSOVER_ONE_POINT`, `elite_count=1`, `target_fitness=huge`.

`ga_result`: `fitness`, `generations`, `history(0:generations)` (best per generation), and `bits` / `reals` / `ints`.

Invalid input: with `stat` present you get `stat /= 0` and `errmsg`; without it the program stops with a message.

The operators (`roulette_select`, `rank_select`, `tournament_select`, `one_point_crossover`, `two_point_crossover`, `uniform_crossover`, `bit_flip_mutation`, `gaussian_mutation`, `random_reset_mutation`, `decode`) are public and take their random draws as arguments, so you can compose your own loop.

**Notes**
- Pass a *module* procedure as fitness. An internal procedure also works, but gfortran then needs an executable stack (trampoline).
- The library never seeds the RNG; call `random_seed`/`random_init` yourself for reproducible runs.
- The positional crossovers never invent new real values; precision on continuous problems comes from Gaussian mutation. Lower `mutation_scale` for finer results, at the cost of more risk of local optima.

## Tests

```sh
fpm test                                               # operators, benchmarks, invalid input
cmake -S . -B build/cmake && cmake --build build/cmake
ctest --test-dir build/cmake --output-on-failure       # the same, plus expected-failure tests
```

Benchmarks: OneMax-32, Sphere-3D, Rastrigin-2D (real and binary-decoded), Rosenbrock-2D, an integer target, and every selection × crossover pair. Expected-failure tests (in `test/xfail`, CMake only, since fpm cannot mark a test as expected to fail): invalid input without `stat` must stop the program, and a negative control proves the benchmark checks detect a GA that does not evolve.
