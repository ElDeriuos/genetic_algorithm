!> EXPECTED TO FAIL: without stat, invalid input must stop the program with a message.
program xfail_invalid_input_without_stat
  use genetic_algorithm
  use benchmarks, only: onemax
  implicit none
  type(ga_result) :: res

  call ga_optimize(onemax, 8, ga_options(population_size=1), res)
  print '(a)', 'not reached: invalid input was accepted'
end program xfail_invalid_input_without_stat
