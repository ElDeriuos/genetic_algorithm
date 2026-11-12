program test_benchmarks
  use, intrinsic :: iso_fortran_env, only: dp => real64
  use genetic_algorithm
  use benchmarks
  use test_check, only: check, seed_rng
  implicit none

  type(ga_options) :: opts
  type(ga_result) :: res

  ! --- OneMax: maximize the number of 1-bits; optimum = all ones
  call seed_rng(1)
  call ga_optimize(onemax, 32, opts, res)
  call check(count(res%bits) == 32 .and. res%fitness == 32, 'binary GA solves OneMax-32')

  ! --- elitism: best fitness never decreases between generations
  call seed_rng(2)
  call ga_optimize(onemax, 64, ga_options(max_generations=30), res)
  call check(lbound(res%history, 1) == 0 .and. ubound(res%history, 1) == res%generations, &
             'history holds the best fitness of every generation, from 0')
  call check(all(res%history(1:) >= res%history(:res%generations-1)) &
             .and. res%history(res%generations) == res%fitness, &
             'with elitism the best fitness never decreases')

  ! --- target fitness: stop as soon as it is reached
  call seed_rng(3)
  call ga_optimize(onemax, 32, ga_options(target_fitness=32), res)
  call check(res%fitness == 32 .and. res%generations < 200, 'GA stops early once target fitness is reached')
  call ga_optimize(onemax, 32, ga_options(target_fitness=0), res)
  call check(res%generations == 0, 'GA does not evolve when the initial population meets the target')

  ! --- Sphere (De Jong F1): minimum 0 at x = 0
  call seed_rng(4)
  call ga_optimize(neg_sphere, spread(-5.12_dp, 1, 3), spread(5.12_dp, 1, 3), opts, res)
  call check(size(res%reals) == 3 .and. -res%fitness < 1e-2_dp, 'real GA minimizes Sphere-3D below 1e-2')

  ! --- integer encoding: recover an exact integer vector
  call seed_rng(5)
  call ga_optimize(neg_int_distance, spread(-20, 1, 5), spread(20, 1, 5), opts, res)
  call check(all(res%ints == INT_TARGET) .and. res%fitness == 0, 'integer GA finds the exact integer optimum')

  ! --- integer creep mutation: exact optimum on a wide range (random reset never got there)
  call seed_rng(21)
  call ga_optimize(neg_shifted_sphere_int, spread(-1000, 1, 10), spread(1000, 1, 10), &
                   ga_options(target_fitness=0._dp, max_generations=1500), res)
  call check(res%fitness == 0 .and. all(res%ints == 3), &
             'integer GA hits the exact optimum on [-1000,1000]^10 within 1500 generations')

  ! --- integer vs real on the same problem: exact optimum vs. close enough that rounding gives it
  block
    integer :: gen_int
    logical :: int_solved
    call seed_rng(22)
    call ga_optimize(neg_shifted_sphere_int, spread(-100, 1, 10), spread(100, 1, 10), &
                     ga_options(target_fitness=0._dp, max_generations=3000), res)
    int_solved = res%fitness == 0
    gen_int = res%generations
    call seed_rng(22)
    call ga_optimize(neg_shifted_sphere, spread(-100._dp, 1, 10), spread(100._dp, 1, 10), &
                     ga_options(target_fitness=-0.25_dp, max_generations=3000), res)
    call check(int_solved .and. gen_int < res%generations, &
               'integer GA reaches the integer optimum in fewer generations than real GA')
  end block

  ! --- Gray-coded binary: no Hamming cliffs, so it converges on a wide range
  call seed_rng(23)
  call ga_optimize(neg_shifted_sphere_gray, 16*10, ga_options(target_fitness=-0.25_dp, max_generations=1000), res)
  call check(-res%fitness < 0.25_dp, 'binary GA with Gray decoding converges on [-1000,1000]^10 within 1000 generations')

  ! --- Rastrigin: multimodal; < 0.1 means the global basin (nearest local optimum ~0.995)
  call seed_rng(6)
  call ga_optimize(neg_rastrigin, spread(-5.12_dp, 1, 2), spread(5.12_dp, 1, 2), opts, res)
  call check(-res%fitness < 0.1_dp, 'real GA finds the global basin of Rastrigin-2D')
  call seed_rng(7)
  call ga_optimize(neg_rastrigin_bits, 32, opts, res)
  call check(-res%fitness < 0.1_dp, 'binary GA with decoding finds the global basin of Rastrigin-2D')

  ! --- Rosenbrock: narrow curved valley, optimum at x = 1
  call seed_rng(8)
  call ga_optimize(neg_rosenbrock, spread(-2.048_dp, 1, 2), spread(2.048_dp, 1, 2), opts, res)
  call check(-res%fitness < 1e-2_dp, 'real GA minimizes Rosenbrock-2D below 1e-2')

  ! --- every selection x crossover combination solves OneMax-32
  block
    integer :: s, c
    integer, parameter :: sel_id(3) = [SELECT_ROULETTE, SELECT_TOURNAMENT, SELECT_RANK]
    integer, parameter :: crs_id(3) = [CROSSOVER_ONE_POINT, CROSSOVER_TWO_POINT, CROSSOVER_UNIFORM]
    character(len=*), parameter :: sel(3) = ['roulette  ', 'tournament', 'rank      ']
    character(len=*), parameter :: crs(3) = ['one-point', 'two-point', 'uniform  ']
    do s = 1, 3
      do c = 1, 3
        call seed_rng(10*s + c)
        call ga_optimize(onemax, 32, ga_options(selection=sel_id(s), crossover=crs_id(c)), res)
        call check(res%fitness == 32, 'OneMax-32 solved with '//trim(sel(s))//' selection + '//trim(crs(c))//' crossover')
      end do
    end do
  end block

end program test_benchmarks
