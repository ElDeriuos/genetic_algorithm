!> Standard GA benchmark functions, written as fitness (to maximize).
!> Module procedures, not internal ones: passing internal procedures makes
!> gfortran build a trampoline, which needs an executable stack.
module benchmarks
  use, intrinsic :: iso_fortran_env, only: dp => real64
  use genetic_algorithm, only: decode
  implicit none
  private
  public :: onemax, neg_sphere, neg_int_distance, INT_TARGET
  public :: neg_rastrigin, neg_rastrigin_bits, neg_rosenbrock

  real(dp), parameter :: pi = acos(-1._dp)

  integer, parameter :: INT_TARGET(5) = [3, -7, 12, 0, 5]

contains

  !> OneMax: number of 1-bits; optimum = all ones.
  function onemax(bits) result(f)
    logical, intent(in) :: bits(:)
    real(dp) :: f
    f = count(bits)
  end function onemax

  !> Sphere (De Jong F1), negated: optimum 0 at x = 0.
  function neg_sphere(x) result(f)
    real(dp), intent(in) :: x(:)
    real(dp) :: f
    f = -sum(x**2)
  end function neg_sphere

  !> Integer problem: negated squared distance to INT_TARGET; optimum 0 at k = INT_TARGET.
  function neg_int_distance(k) result(f)
    integer, intent(in) :: k(:)
    real(dp) :: f
    f = -sum((k - INT_TARGET)**2)
  end function neg_int_distance

  !> Rastrigin, negated: optimum 0 at x = 0, local optima near every integer point.
  function neg_rastrigin(x) result(f)
    real(dp), intent(in) :: x(:)
    real(dp) :: f
    f = -(10*size(x) + sum(x**2 - 10*cos(2*pi*x)))
  end function neg_rastrigin

  !> Rastrigin-2D on bit strings: 16 bits per variable decoded onto [-5.12, 5.12].
  function neg_rastrigin_bits(bits) result(f)
    logical, intent(in) :: bits(:)
    real(dp) :: f
    f = neg_rastrigin(decode(bits, [-5.12_dp, -5.12_dp], [5.12_dp, 5.12_dp]))
  end function neg_rastrigin_bits

  !> Rosenbrock (De Jong F2), negated: optimum 0 at x = 1, inside a narrow curved valley.
  function neg_rosenbrock(x) result(f)
    real(dp), intent(in) :: x(:)
    real(dp) :: f
    associate (a => x(:size(x)-1), b => x(2:))
      f = -sum(100*(b - a**2)**2 + (1 - a)**2)
    end associate
  end function neg_rosenbrock

end module benchmarks
