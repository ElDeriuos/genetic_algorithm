!> EXPECTED TO FAIL (negative control): with evolution switched off, a random
!> population cannot solve OneMax-64, so this check must fail. If it ever
!> passes, the benchmark assertions are not able to detect a broken GA.
program xfail_no_evolution
  use genetic_algorithm
  use benchmarks, only: onemax
  use test_check, only: check, seed_rng
  implicit none
  type(ga_result) :: res

  call seed_rng(1)
  call ga_optimize(onemax, 64, ga_options(max_generations=0), res)
  call check(res%fitness == 64, 'OneMax-64 solved without any generation')
end program xfail_no_evolution
