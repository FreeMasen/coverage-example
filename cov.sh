cargo clean
rm -rf ./*.gcda
rm -rf ./*.gcno
export LINK_FLAGS="-L /Library/Developer/CommandLineTools/usr/lib/clang/11.0.0/lib/darwin -l clang_rt.profile_osx"
FLAGS="-Ccodegen-units=1 -Clink-dead-code -Cpasses=insert-gcov-profiling $LINK_FLAGS"
export COVERAGE_OPTIONS=$FLAGS
# export RUSTFLAGS=$FLAGS
export RUSTC_WRAPPER="./wrap.sh"
cargo test --lib \
    && lcov --gcov-tool ./llvm-gcov.sh --rc lcov_branch_coverage=1 --rc lcov_excl_line=assert --capture --directory . --base-directory . -o ./tests.info \
    && lcov --gcov-tool ./llvm-gcov.sh --rc lcov_branch_coverage=1 --rc lcov_excl_line=assert --extract ./tests.info "$(pwd)/*" -o cov.info \
    && genhtml -branch-coverage --demangle-cpp --legend -o ./coverage ./cov.info