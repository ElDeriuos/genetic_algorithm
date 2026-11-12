!> Invalid input is rejected through stat/errmsg instead of stopping the caller.
program test_errors
  use, intrinsic :: iso_fortran_env, only: dp => real64
  use genetic_algorithm
  use benchmarks, only: onemax, neg_sphere, neg_int_distance
  use test_check, only: check
  implicit none

  type(ga_result) :: res
  integer :: stat
  character(:), allocatable :: msg
  real(dp), parameter :: lo(2) = [-1._dp, -1._dp], hi(2) = [1._dp, 1._dp]

  call ga_optimize(neg_sphere, lo, hi, ga_options(max_generations=1), res, stat, msg)
  call check(stat == 0, 'valid input gives stat = 0')

  call ga_optimize(onemax, 8, ga_options(population_size=1), res, stat, msg)
  call check(rejected('population_size'), 'population_size < 2 is rejected')

  call ga_optimize(onemax, 8, ga_options(max_generations=-1), res, stat, msg)
  call check(rejected('max_generations'), 'negative max_generations is rejected')

  call ga_optimize(onemax, 0, ga_options(), res, stat, msg)
  call check(rejected('n_bits'), 'n_bits < 1 is rejected')

  call ga_optimize(neg_sphere, lo, hi(:1), ga_options(), res, stat, msg)
  call check(rejected('size'), 'lower and upper of different size are rejected')

  call ga_optimize(neg_sphere, hi, lo, ga_options(), res, stat, msg)
  call check(rejected('lower'), 'lower > upper is rejected')

  call ga_optimize(neg_int_distance, [5], [1], ga_options(), res, stat, msg)
  call check(rejected('lower'), 'integer lower > upper is rejected')

  call ga_optimize(onemax, 8, ga_options(crossover_rate=1.5_dp), res, stat, msg)
  call check(rejected('crossover_rate'), 'crossover_rate outside [0,1] is rejected')

  call ga_optimize(onemax, 8, ga_options(mutation_rate=2._dp), res, stat, msg)
  call check(rejected('mutation_rate'), 'mutation_rate > 1 is rejected')

  call ga_optimize(neg_sphere, lo, hi, ga_options(mutation_scale=-1._dp), res, stat, msg)
  call check(rejected('mutation_scale'), 'negative mutation_scale is rejected')

  call ga_optimize(onemax, 8, ga_options(selection=99), res, stat, msg)
  call check(rejected('selection'), 'unknown selection is rejected')

  call ga_optimize(onemax, 8, ga_options(tournament_size=0), res, stat, msg)
  call check(rejected('tournament_size'), 'tournament_size < 1 is rejected')

  call ga_optimize(onemax, 8, ga_options(crossover=99), res, stat, msg)
  call check(rejected('crossover'), 'unknown crossover is rejected')

  call ga_optimize(onemax, 8, ga_options(population_size=4, elite_count=4), res, stat, msg)
  call check(rejected('elite_count'), 'elite_count >= population_size is rejected')

contains

  logical function rejected(field)
    character(*), intent(in) :: field
    rejected = stat /= 0 .and. index(msg, field) > 0
  end function rejected

end program test_errors
