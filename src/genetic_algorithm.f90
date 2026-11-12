module genetic_algorithm
  use, intrinsic :: iso_fortran_env, only: dp => real64
  implicit none
  private

  public :: decode
  public :: tournament_select, roulette_select, rank_select
  public :: one_point_crossover, two_point_crossover, uniform_crossover
  public :: bit_flip_mutation, gaussian_mutation, random_reset_mutation, creep_mutation
  public :: ga_optimize, binary_fitness, real_fitness, integer_fitness

  integer, parameter, public :: SELECT_ROULETTE = 1, SELECT_TOURNAMENT = 2, SELECT_RANK = 3
  integer, parameter, public :: CROSSOVER_ONE_POINT = 1, CROSSOVER_TWO_POINT = 2, CROSSOVER_UNIFORM = 3
  integer, parameter :: ENC_BINARY = 1, ENC_REAL = 2, ENC_INTEGER = 3

  !> Settings for one GA run; every field has a usable default.
  type, public :: ga_options
    integer  :: population_size = 50
    integer  :: max_generations = 200
    real(dp) :: crossover_rate  = 0.9_dp
    real(dp) :: mutation_rate   = -1      !< per gene; < 0 means 1/(number of genes)
    real(dp) :: mutation_scale  = 0.1_dp  !< real encoding: Gaussian sigma as a fraction of (upper - lower)
    integer  :: selection       = SELECT_TOURNAMENT
    integer  :: tournament_size = 2
    integer  :: crossover       = CROSSOVER_ONE_POINT
    integer  :: elite_count     = 1      !< best chromosomes copied unchanged each generation
    real(dp) :: target_fitness  = huge(1._dp)  !< stop once best fitness >= this
  end type ga_options

  !> Best chromosome found; only the field matching the encoding is allocated.
  type, public :: ga_result
    real(dp) :: fitness = -huge(1._dp)
    integer  :: generations = 0
    real(dp), allocatable :: history(:)   !< best fitness per generation, history(0) = initial population
    logical, allocatable :: bits(:)
    real(dp), allocatable :: reals(:)
    integer, allocatable :: ints(:)
  end type ga_result

  abstract interface
    function binary_fitness(bits) result(f)
      import :: dp
      logical, intent(in) :: bits(:)
      real(dp) :: f
    end function binary_fitness

    function real_fitness(x) result(f)
      import :: dp
      real(dp), intent(in) :: x(:)
      real(dp) :: f
    end function real_fitness

    function integer_fitness(k) result(f)
      import :: dp
      integer, intent(in) :: k(:)
      real(dp) :: f
    end function integer_fitness
  end interface

  interface ga_optimize
    module procedure ga_binary, ga_real, ga_integer
  end interface ga_optimize

contains

  !> Classic GA on bit strings of length n_bits. Result in res%bits.
  !> Invalid input: sets stat /= 0 and errmsg if stat is present, else error stop.
  subroutine ga_binary(fitness, n_bits, opts, res, stat, errmsg)
    procedure(binary_fitness) :: fitness
    integer, intent(in) :: n_bits
    type(ga_options), intent(in) :: opts
    type(ga_result), intent(out) :: res
    integer, intent(out), optional :: stat
    character(:), allocatable, intent(out), optional :: errmsg

    call run(ENC_BINARY, spread(0._dp, 1, n_bits), spread(1._dp, 1, n_bits), opts, res, stat, errmsg, &
             fit_bin=fitness)
  end subroutine ga_binary

  !> Real-coded GA on x in [lower, upper]. Result in res%reals.
  subroutine ga_real(fitness, lower, upper, opts, res, stat, errmsg)
    procedure(real_fitness) :: fitness
    real(dp), intent(in) :: lower(:), upper(:)
    type(ga_options), intent(in) :: opts
    type(ga_result), intent(out) :: res
    integer, intent(out), optional :: stat
    character(:), allocatable, intent(out), optional :: errmsg

    call run(ENC_REAL, lower, upper, opts, res, stat, errmsg, fit_real=fitness)
  end subroutine ga_real

  !> Integer-coded GA on k in [lower, upper]. Result in res%ints.
  subroutine ga_integer(fitness, lower, upper, opts, res, stat, errmsg)
    procedure(integer_fitness) :: fitness
    integer, intent(in) :: lower(:), upper(:)
    type(ga_options), intent(in) :: opts
    type(ga_result), intent(out) :: res
    integer, intent(out), optional :: stat
    character(:), allocatable, intent(out), optional :: errmsg

    call run(ENC_INTEGER, real(lower, dp), real(upper, dp), opts, res, stat, errmsg, fit_int=fitness)
  end subroutine ga_integer

  !> The GA loop shared by all encodings. Genes are stored as real(dp):
  !> bits as 0/1, integers as whole numbers. The user's fitness is passed as
  !> an optional dummy (not wrapped in an internal procedure) to avoid
  !> gfortran trampolines / executable stacks.
  subroutine run(enc, lower, upper, opts, res, stat, errmsg, fit_bin, fit_real, fit_int)
    integer, intent(in) :: enc
    real(dp), intent(in) :: lower(:), upper(:)
    type(ga_options), intent(in) :: opts
    type(ga_result), intent(inout) :: res
    integer, intent(out), optional :: stat
    character(:), allocatable, intent(out), optional :: errmsg
    procedure(binary_fitness), optional :: fit_bin
    procedure(real_fitness), optional :: fit_real
    procedure(integer_fitness), optional :: fit_int
    real(dp), allocatable :: pop(:,:), next(:,:), fit(:), next_fit(:)
    real(dp) :: c1(size(lower)), c2(size(lower)), pm, u, hist(0:max(0, opts%max_generations))
    integer, allocatable :: parents(:)
    logical :: taken(max(0, opts%population_size))
    character(:), allocatable :: msg
    integer :: n, np, ne, g, i, k

    msg = invalid_input()
    if (present(stat)) stat = merge(1, 0, len(msg) > 0)
    if (len(msg) > 0) then
      if (.not. present(stat)) error stop 'genetic_algorithm: '//msg
      if (present(errmsg)) errmsg = msg
      return
    end if

    n = size(lower)
    np = opts%population_size
    pm = opts%mutation_rate
    if (pm < 0) pm = 1._dp / n
    allocate(pop(n, np), next(n, np), fit(np), next_fit(np))

    call random_number(pop)
    if (enc == ENC_REAL) then
      pop = spread(lower, 2, np) + pop * spread(upper - lower, 2, np)
    else
      pop = spread(lower, 2, np) + floor(pop * spread(upper - lower + 1, 2, np))
    end if
    do i = 1, np
      fit(i) = evaluate(pop(:, i))
    end do

    g = 0
    hist(0) = maxval(fit)
    do while (g < opts%max_generations .and. hist(g) < opts%target_fitness)
      g = g + 1
      ne = opts%elite_count
      taken = .false.
      do i = 1, ne
        k = maxloc(fit, 1, mask=.not. taken)
        taken(k) = .true.
        next(:, i) = pop(:, k)
        next_fit(i) = fit(k)
      end do
      parents = select_parents(np - ne + mod(np - ne, 2))
      i = ne + 1
      k = 1
      do while (i <= np)
        call random_number(u)
        if (u < opts%crossover_rate .and. n > 1) then
          call crossover(pop(:, parents(k)), pop(:, parents(k+1)), c1, c2)
        else
          c1 = pop(:, parents(k))
          c2 = pop(:, parents(k+1))
        end if
        k = k + 2
        call mutate(c1)
        call mutate(c2)
        next(:, i) = c1
        next_fit(i) = evaluate(c1)
        if (i < np) then
          next(:, i+1) = c2
          next_fit(i+1) = evaluate(c2)
        end if
        i = i + 2
      end do
      pop = next
      fit = next_fit
      hist(g) = maxval(fit)
    end do

    i = maxloc(fit, 1)
    select case (enc)
    case (ENC_BINARY)
      res%bits = pop(:, i) > 0.5_dp
    case (ENC_REAL)
      res%reals = pop(:, i)
    case (ENC_INTEGER)
      res%ints = nint(pop(:, i))
    end select
    res%fitness = fit(i)
    res%generations = g
    allocate(res%history(0:g))
    res%history = hist(0:g)

  contains

    !> Empty string when input is valid, else what is wrong (names the field).
    function invalid_input() result(msg)
      character(:), allocatable :: msg
      msg = ''
      if (size(lower) < 1) then
        msg = 'need at least one gene (n_bits >= 1, size(lower) >= 1)'
      else if (size(lower) /= size(upper)) then
        msg = 'lower and upper must have the same size'
      else if (any(lower > upper)) then
        msg = 'lower must be <= upper'
      else if (opts%population_size < 2) then
        msg = 'population_size must be >= 2'
      else if (opts%max_generations < 0) then
        msg = 'max_generations must be >= 0'
      else if (opts%crossover_rate < 0 .or. opts%crossover_rate > 1) then
        msg = 'crossover_rate must be in [0, 1]'
      else if (opts%mutation_rate > 1) then
        msg = 'mutation_rate must be <= 1 (< 0 means 1/genes)'
      else if (opts%mutation_scale < 0) then
        msg = 'mutation_scale must be >= 0'
      else if (all(opts%selection /= [SELECT_ROULETTE, SELECT_TOURNAMENT, SELECT_RANK])) then
        msg = 'selection must be SELECT_ROULETTE, SELECT_TOURNAMENT or SELECT_RANK'
      else if (opts%tournament_size < 1) then
        msg = 'tournament_size must be >= 1'
      else if (all(opts%crossover /= [CROSSOVER_ONE_POINT, CROSSOVER_TWO_POINT, CROSSOVER_UNIFORM])) then
        msg = 'crossover must be CROSSOVER_ONE_POINT, CROSSOVER_TWO_POINT or CROSSOVER_UNIFORM'
      else if (opts%elite_count < 0 .or. opts%elite_count >= opts%population_size) then
        msg = 'elite_count must be in [0, population_size - 1]'
      end if
    end function invalid_input

    real(dp) function evaluate(genes)
      real(dp), intent(in) :: genes(:)
      select case (enc)
      case (ENC_BINARY)
        evaluate = fit_bin(genes > 0.5_dp)
      case (ENC_REAL)
        evaluate = fit_real(genes)
      case (ENC_INTEGER)
        evaluate = fit_int(nint(genes))
      end select
    end function evaluate

    function select_parents(m) result(idx)
      integer, intent(in) :: m
      integer :: idx(m)
      real(dp) :: r(m), rt(opts%tournament_size, m)
      select case (opts%selection)
      case (SELECT_ROULETTE)
        call random_number(r)
        idx = roulette_select(fit, r)
      case (SELECT_RANK)
        call random_number(r)
        idx = rank_select(fit, r)
      case default
        call random_number(rt)
        idx = tournament_select(fit, min(np, 1 + int(rt*np)))
      end select
    end function select_parents

    subroutine crossover(p1, p2, c1, c2)
      real(dp), intent(in) :: p1(:), p2(:)
      real(dp), intent(out) :: c1(:), c2(:)
      real(dp) :: u(n)
      integer :: cut
      call random_number(u)
      cut = 1 + int(u(1)*(n - 1))                ! 1 .. n-1
      select case (opts%crossover)
      case (CROSSOVER_TWO_POINT)
        call two_point_crossover(p1, p2, cut, cut + 1 + int(u(2)*(n - cut)), c1, c2)
      case (CROSSOVER_UNIFORM)
        call uniform_crossover(p1, p2, u < 0.5_dp, c1, c2)
      case default
        call one_point_crossover(p1, p2, cut, c1, c2)
      end select
    end subroutine crossover

    subroutine mutate(genes)
      real(dp), intent(inout) :: genes(:)
      real(dp) :: u(n), z(n), s(n)
      call random_number(u)
      select case (enc)
      case (ENC_BINARY)
        call bit_flip_mutation(genes, u < pm)
      case (ENC_REAL)
        z = normal(n)
        call gaussian_mutation(genes, u < pm, z * opts%mutation_scale * (upper - lower), lower, upper)
      case (ENC_INTEGER)
        call random_number(z)
        call random_number(s)
        call creep_mutation(genes, u < pm, z, s, opts%mutation_scale * (upper - lower), lower, upper)
      end select
    end subroutine mutate

    !> n standard normal draws (Box-Muller).
    function normal(n) result(z)
      integer, intent(in) :: n
      real(dp) :: z(n), u1(n), u2(n)
      real(dp), parameter :: pi = acos(-1._dp)
      call random_number(u1)
      call random_number(u2)
      z = sqrt(-2*log(1 - u1)) * cos(2*pi*u2)
    end function normal

  end subroutine run

  !> Binary genes (0/1): flip where mask is true.
  pure subroutine bit_flip_mutation(genes, mask)
    real(dp), intent(inout) :: genes(:)
    logical, intent(in) :: mask(:)

    where (mask) genes = 1 - genes
  end subroutine bit_flip_mutation

  !> Real genes: add noise where mask is true, then clip to [lower, upper].
  pure subroutine gaussian_mutation(genes, mask, noise, lower, upper)
    real(dp), intent(inout) :: genes(:)
    logical, intent(in) :: mask(:)
    real(dp), intent(in) :: noise(:), lower(:), upper(:)

    where (mask) genes = min(max(genes + noise, lower), upper)
  end subroutine gaussian_mutation

  !> Integer genes: where mask is true, replace by lower + floor(r*(upper-lower+1)), r in [0,1).
  pure subroutine random_reset_mutation(genes, mask, r, lower, upper)
    real(dp), intent(inout) :: genes(:)
    logical, intent(in) :: mask(:)
    real(dp), intent(in) :: r(:), lower(:), upper(:)

    where (mask) genes = lower + floor(r*(upper - lower + 1))
  end subroutine random_reset_mutation

  !> Integer genes: where mask is true, step by round(max_step**r) (so 1 .. max_step,
  !> spread evenly over orders of magnitude, never 0), downward if s < 0.5,
  !> then clip to [lower, upper]. r and s are uniform draws in [0,1).
  pure subroutine creep_mutation(genes, mask, r, s, max_step, lower, upper)
    real(dp), intent(inout) :: genes(:)
    logical, intent(in) :: mask(:)
    real(dp), intent(in) :: r(:), s(:), max_step(:), lower(:), upper(:)

    where (mask) genes = min(max(genes + sign(anint(max(1._dp, max_step)**r), s - 0.5_dp), lower), upper)
  end subroutine creep_mutation

  !> Children swap tails after gene `cut` (1 <= cut < size(p1)).
  pure subroutine one_point_crossover(p1, p2, cut, c1, c2)
    real(dp), intent(in) :: p1(:), p2(:)
    integer, intent(in) :: cut
    real(dp), intent(out) :: c1(:), c2(:)

    c1 = [p1(:cut), p2(cut+1:)]
    c2 = [p2(:cut), p1(cut+1:)]
  end subroutine one_point_crossover

  !> Children swap genes cut1+1 .. cut2 (0 <= cut1 < cut2 <= size(p1)).
  pure subroutine two_point_crossover(p1, p2, cut1, cut2, c1, c2)
    real(dp), intent(in) :: p1(:), p2(:)
    integer, intent(in) :: cut1, cut2
    real(dp), intent(out) :: c1(:), c2(:)

    c1 = [p1(:cut1), p2(cut1+1:cut2), p1(cut2+1:)]
    c2 = [p2(:cut1), p1(cut1+1:cut2), p2(cut2+1:)]
  end subroutine two_point_crossover

  !> c1 takes p1's gene where mask is true, else p2's; c2 the opposite.
  pure subroutine uniform_crossover(p1, p2, mask, c1, c2)
    real(dp), intent(in) :: p1(:), p2(:)
    logical, intent(in) :: mask(:)
    real(dp), intent(out) :: c1(:), c2(:)

    c1 = merge(p1, p2, mask)
    c2 = merge(p2, p1, mask)
  end subroutine uniform_crossover

  !> Linear ranking: weight = rank (worst 1 .. best N, ties broken by position),
  !> so only the order of fitness values matters.
  pure function rank_select(fitness, r) result(picks)
    real(dp), intent(in) :: fitness(:), r(:)
    integer :: picks(size(r))
    real(dp) :: ranks(size(fitness))
    integer :: i

    ! shortcut: O(N^2) ranking, fine for populations up to a few thousand; sort if larger
    do i = 1, size(fitness)
      ranks(i) = 1 + count(fitness < fitness(i)) + count(fitness(1:i-1) == fitness(i))
    end do
    picks = pick_by_weight(ranks, r)
  end function rank_select

  !> Fitness-proportionate selection with windowing: weight = fitness - worst,
  !> so negative fitness works and the worst is never picked (unless all equal).
  !> r holds one uniform draw in [0,1) per pick.
  pure function roulette_select(fitness, r) result(picks)
    real(dp), intent(in) :: fitness(:), r(:)
    integer :: picks(size(r))

    picks = pick_by_weight(fitness - minval(fitness), r)
  end function roulette_select

  !> Pick indices with probability proportional to non-negative weights;
  !> uniform when all weights are zero.
  pure function pick_by_weight(w, r) result(picks)
    real(dp), intent(in) :: w(:), r(:)
    integer :: picks(size(r))
    real(dp) :: cum(size(w))
    integer :: i, k

    cum(1) = w(1)
    do i = 2, size(w)
      cum(i) = cum(i-1) + w(i)
    end do
    do k = 1, size(r)
      if (cum(size(w)) > 0) then
        picks(k) = findloc(cum > r(k)*cum(size(w)), .true., 1)
      else
        picks(k) = min(size(w), 1 + int(r(k)*size(w)))
      end if
    end do
  end function pick_by_weight

  !> Each column of contestants (tournament_size x n_picks) is one tournament;
  !> the fittest contestant wins (first one on ties).
  pure function tournament_select(fitness, contestants) result(winners)
    real(dp), intent(in) :: fitness(:)
    integer, intent(in) :: contestants(:,:)
    integer :: winners(size(contestants, 2))
    integer :: j

    do j = 1, size(contestants, 2)
      winners(j) = contestants(maxloc(fitness(contestants(:, j)), 1), j)
    end do
  end function tournament_select

  !> Map a bit string onto reals: size(bits)/size(lower) bits per variable,
  !> most significant bit first, scaled linearly onto [lower, upper].
  !> gray=.true. reads each block as Gray code (neighbouring values differ in one bit).
  pure function decode(bits, lower, upper, gray) result(x)
    logical, intent(in) :: bits(:)
    real(dp), intent(in) :: lower(:), upper(:)
    logical, intent(in), optional :: gray
    real(dp) :: x(size(lower))
    integer :: i, j, m
    real(dp) :: v
    logical :: use_gray, b

    use_gray = .false.
    if (present(gray)) use_gray = gray
    m = size(bits) / size(lower)
    do i = 1, size(lower)
      v = 0
      b = .false.
      do j = (i - 1)*m + 1, i*m
        b = merge(b .neqv. bits(j), bits(j), use_gray)   ! Gray -> binary: bit = previous bit xor Gray bit
        v = 2*v + merge(1, 0, b)
      end do
      x(i) = lower(i) + (upper(i) - lower(i)) * v / (2._dp**m - 1)
    end do
  end function decode

end module genetic_algorithm
