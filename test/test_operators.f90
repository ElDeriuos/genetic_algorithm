program test_operators
  use, intrinsic :: iso_fortran_env, only: dp => real64
  use genetic_algorithm
  use test_check, only: check
  implicit none

  logical, parameter :: T = .true., F = .false.

  ! --- decode: bits -> reals, MSB first, linear onto [lower, upper]
  call check(near(decode([T,T,T,T], [0._dp], [15._dp]), [15._dp]), 'decode all ones gives upper bound')
  call check(near(decode([F,F,F,F], [-5._dp], [5._dp]), [-5._dp]), 'decode all zeros gives lower bound')
  call check(near(decode([T,F,F,F], [0._dp], [15._dp]), [8._dp]), 'decode reads most significant bit first')
  call check(near(decode([F,T,T,F], [-1._dp, 10._dp], [2._dp, 13._dp]), [0._dp, 12._dp]), &
             'decode splits bits evenly across variables')

  ! --- tournament: each column of contestants is one tournament, fittest wins
  call check(all(tournament_select([5._dp, 1._dp, 9._dp, 3._dp], &
                                   reshape([2,4, 1,3, 4,4], [2,3])) == [4, 3, 4]), &
             'tournament picks the fittest contestant of each tournament')

  ! --- roulette: weight = fitness - worst; one uniform draw r in [0,1) per pick
  ! weights [0,1,2,3], cumulative [0,1,3,6]
  call check(all(roulette_select([1._dp, 2._dp, 3._dp, 4._dp], [0._dp, .1_dp, .2_dp, .5_dp, .99_dp]) &
                 == [2, 2, 3, 4, 4]), 'roulette picks proportionally to fitness above the worst')
  ! weights [0,6,3], cumulative [0,6,9]
  call check(all(roulette_select([-10._dp, -4._dp, -7._dp], [.5_dp, .7_dp]) == [2, 3]), &
             'roulette handles negative fitness')
  call check(all(roulette_select([2._dp, 2._dp, 2._dp, 2._dp], [0._dp, .3_dp, .99_dp]) == [1, 2, 4]), &
             'roulette picks uniformly when all fitness is equal')

  ! --- rank: weight = rank (worst 1 .. best N); ranks [3,1,2], cumulative [3,4,6]
  call check(all(rank_select([10._dp, -3._dp, 7._dp], [0._dp, .5_dp, .6_dp, .9_dp]) == [1, 2, 2, 3]), &
             'rank selection picks proportionally to rank')
  call check(all(rank_select([1e6_dp, -3._dp, 7._dp], [0._dp, .5_dp, .6_dp, .9_dp]) == [1, 2, 2, 3]), &
             'rank selection ignores fitness magnitude')

  ! --- crossover: positional exchange between parents, genes never altered
  block
    real(dp) :: p1(5), p2(5), c1(5), c2(5)
    p1 = [1, 2, 3, 4, 5]
    p2 = [6, 7, 8, 9, 10]

    call one_point_crossover(p1, p2, 2, c1, c2)
    call check(all(c1 == [1, 2, 8, 9, 10]) .and. all(c2 == [6, 7, 3, 4, 5]), &
               'one-point crossover swaps tails after the cut')

    call two_point_crossover(p1, p2, 1, 3, c1, c2)
    call check(all(c1 == [1, 7, 8, 4, 5]) .and. all(c2 == [6, 2, 3, 9, 10]), &
               'two-point crossover swaps the segment between the cuts')

    call uniform_crossover(p1, p2, [T, F, T, F, F], c1, c2)
    call check(all(c1 == [1, 7, 3, 9, 10]) .and. all(c2 == [6, 2, 8, 4, 5]), &
               'uniform crossover takes genes from the first parent where mask is true')
  end block

  ! --- mutation: only genes where mask is true change
  block
    real(dp) :: g(4)

    g = [1, 0, 1, 0]
    call bit_flip_mutation(g, [T, T, F, F])
    call check(all(g == [0, 1, 1, 0]), 'bit-flip mutation flips masked bits only')

    g = [.5_dp, .5_dp, .5_dp, .5_dp]
    call gaussian_mutation(g, [T, T, T, F], [.2_dp, .9_dp, -.8_dp, .3_dp], [0._dp, 0._dp, 0._dp, 0._dp], &
                           [1._dp, 1._dp, 1._dp, 1._dp])
    call check(near(g, [.7_dp, 1._dp, 0._dp, .5_dp]), 'gaussian mutation adds noise and clips to bounds')

    g = [3, 3, 3, 3]
    call random_reset_mutation(g, [T, T, F, T], [0._dp, .99_dp, .5_dp, .5_dp], [1._dp, 1._dp, 1._dp, -2._dp], &
                               [6._dp, 6._dp, 6._dp, 2._dp])
    call check(all(g == [1, 6, 3, 0]), 'random-reset mutation draws a whole number within bounds')
  end block

  ! --- creep mutation: |step| = round(max_step**r) spans 1 .. max_step on a log scale, sign from s
  block
    real(dp) :: g(5)
    g = [50, 50, 50, 50, 50]
    call creep_mutation(g, [T, T, T, F, T], [0._dp, .5_dp, .5_dp, .5_dp, .999_dp], [.9_dp, .1_dp, .9_dp, .9_dp, .9_dp], &
                        [100._dp, 100._dp, 100._dp, 100._dp, 1._dp], spread(0._dp, 1, 5), spread(55._dp, 1, 5))
    call check(all(g == [51, 40, 55, 50, 51]), &
               'creep mutation steps by 1..max_step on a log scale, never 0, clipped to bounds')
  end block

  ! --- Gray decoding: neighbouring integers differ in exactly one bit
  call check(near(decode([F,T,F,F], [0._dp], [15._dp], gray=.true.), [7._dp]) .and. &
             near(decode([T,T,F,F], [0._dp], [15._dp], gray=.true.), [8._dp]), &
             'Gray decode maps 0100 to 7 and 1100 to 8 (one bit apart)')
  call check(near(decode([T,T,T,F], [0._dp, 0._dp], [3._dp, 3._dp], gray=.true.), [2._dp, 3._dp]), &
             'Gray decode converts each variable block separately')

contains

  logical function near(a, b)
    real(dp), intent(in) :: a(:), b(:)
    near = size(a) == size(b)
    if (near) near = all(abs(a - b) < 1e-12_dp)
  end function near

end program test_operators
