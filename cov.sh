cargo clean
rm -f ./*.gcda
rm -f ./*.gcno

get_clang_root()
{
  local RET=$(clang -print-resource-dir)
  case $(uname -s) in
    Darwin*)
      echo "$RET/lib/darwin"
      ;;
    Linux*)
      echo "$RET/lib/linux"
      ;;
  esac
}

get_clang_archive()
{
  case $(uname -s) in
    Darwin*)
      echo "clang_rt.profile_osx"
      ;;
    Linux*)
      echo "clang_rt.profile-$(uname -m)"
      ;;
  esac
}


export COVERAGE_OPTIONS="-Cpasses=insert-gcov-profiling \
-Ccodegen-units=1 \
-Clink-dead-code -Cinline-threshold=0 \
-Coverflow-checks=off -L $(get_clang_root) \
-l $(get_clang_archive)"

export RUSTC_WRAPPER="./wrap.sh"
cargo test --lib -- --test-threads=1
    # && grcov . -s . -t lcov --llvm --branch --ignore-not-existing -o tests.info
    # && lcov --gcov-tool ./llvm-gcov.sh --rc lcov_branch_coverage=1 --rc lcov_excl_line=assert --extract ./tests.info "$(pwd)/src/*" -o cov.info \
    # && genhtml -branch-coverage --demangle-cpp --legend -o ./coverage ./cov.info