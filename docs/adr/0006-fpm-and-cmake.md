# 6. Package with fpm, build tests with fpm and CMake

Date: 2026-11-12 · Status: accepted

**Context.** fpm is Fortran's package manager (crate/pip equivalent; v0.13.0 released 2026-02-17, 0.12.0 via pip). No classic binary GA package was found in the fpm registry index; `pikaia` (decimal encoding) and `evortran` (real/integer) exist as git dependencies.

**Decision.** Ship `fpm.toml` (consumers add a git or path dependency) and a `CMakeLists.txt` (consumers use `add_subdirectory`/FetchContent). Tests are plain programs that `error stop` on failure, so there is no test-framework dependency. fpm cannot mark a test as expected to fail, so `auto-tests = false` and the expected-failure programs in `test/xfail` run only under ctest, matched on their exact error message.

**Upgrade path.** Move to `test-drive` (fortran-lang) if per-test reporting or continuing after a failure is needed.
