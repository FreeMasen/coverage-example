# Rust Coverage via llvm
This project is an example of how to generate a code coverage report
directly from `cargo test`.

inspired by [this](https://jbp.io/2017/07/19/measuring-test-coverage-of-rust-programs#only-profiling-relevent-code) blog post by ctz

# How To
## 1. First you need to make sure you have the required dependencies.
- clang
    - Macos: install the Xcode Command Line tools
    - Debian: `apt-get install clang`
- lcov
    - Macos: `brew install lcov`
    - Debian: `apt-get install lcov`
## 2. Validate your required binaries are working.
```sh
lcov -v 
lcov: LCOV version 1.14
llvm-cov --version
Apple LLVM version 11.0.0 (clang-1100.0.33.17)
  Optimized build.
  Default target: x86_64-apple-darwin19.2.0
  Host CPU: skylake
```
## 3. Find your library paths
Depending on your version of clang, these can be in a different location.
We are going to make a note of these values and use them in a later step.
- clang_rt.profile
    - This is where the code coverage functions we will be linking to live
    - Macos
        - link path: `/Library/Developer/CommandLineTools/usr/lib/clang/{version}/lib/darwin`
        - library name: `clang_rt.profile_osx`
    - Debian
        - link path `/usr/lib/llvm-{version}/lib/clang/{full-version}/lib/linux`
        - library name: `clang_rt.profile-{arch}`
        - note: here the {version} is a 1 dot version number (10.0) where {full-version} is a 2 dot version (10.0.1). {arch} is the system's archetecure (x86_64)

## 4. Setup a wrapper script for `rustc`

This will be used by cargo to actually call `rustc`, we can use this to 
selectively insert the code coverage information into our project only.
It should look something like this.

```sh
#! /bin/sh -e
# ./wrap.sh
# this fn will extract the crate name being compiled
# at this step
get_crate_name()
{
  while [[ $# -gt 1 ]] ; do
    v=$1
    case $v in
      --crate-name)
        echo $2
        return
        ;;
    esac
    shift
  done
}
# here we are checking for _our_ crate name and 
# adding additional arguments onto cargo's arguments
case $(get_crate_name "$@") in
  coverage-example)
    EXTRA=$COVERAGE_OPTIONS
    ;;
  *)
    ;;
esac
# here we are actually calling rustc
exec "$@" $EXTRA
```

## 5. Setup the env varianbles

We tell cargo to use our script instead of rustc direction
by setting the env variable `RUSTC_WRAPPER`

```sh
export RUSTC_WRAPPER="$PWD/wrap.sh"
```
We will also need to pass that script the extra arguments
we want to pass to rustc. This is where we are going to use
the paths we looked up before. We need to add the following
arguments for _our_ crate.


1. Where to find the clang libraries: `-L /Library/Developer/CommandLineTools/usr/lib/clang/11.0.0/lib/darwin` (be sure to use the path you looked up for your system)
2. Where to find the coverage symbols: `-l clang_rt.profile_osx`
3. Ask cargo to only crate 1 compilation unit: `-C codegen-units=1`
4. Ask cargo to not remove dead code: `-C link-dead-code`
5. Ask cargo to insert gcov profiling: `-C passes=insert-gcov-profiling`
All together it looks something like this.

```sh
export COVERAGE_OPTIONS="-C codegen-units=1 -C link-dead-code -C passes=insert-gcov-profiling -L /Library/Developer/CommandLineTools/usr/lib/clang/11.0.0/lib/darwin -l clang_rt.profile_osx"
```


## 6. Run our tests
As a note, your library, binary, and integration
tests will all need to be run seperatly otherwise
the coverage tool will get confused. See the linked
blog post above for how to merge these runs all together.

```sh
cargo test --lib
```

## 7. Gather All Coverage Information
At this point, your project folder will be full of a bunch of files
that end in `.gcda` and `.gcno`. We are going to point the tool `lcov`
at these but we need to provide a shim from gcov to llvm-cov. We are
going to create a script to do that like this.

```sh
#!/bin/sh -e
# ./llvm-gcov.sh
llvm-cov gcov $@
```
This simply passes the arguments that would have been provided
to `gcov` on to `llvm-cov`'s sub comand `gcov`. A little convoluded
but here we are.

With that complete we can run the following
```sh
lcov \
    --gcov-tool ./llvm-gcov.sh \ 
    --rc lcov_branch_coverage=1 \
    --rc lcov_excl_line=assert \
    --capture \
    --directory . \
    --base-directory . \
    -o ./tests.info

```
The arguments here do the following
- `--gcov-tool`: direct lcov to our shim
- `--rc lcov_branch_coverage=1`: turn on branch coverage
- `--rc lcov_excl_line=assert`: turn on line coverage
- `--capture`: indicate that this is the capture faze of the process
- `--directory`: where to look
- `--base-directory`: for relative path resolution
- `-o ./tests.info`: where to put the output

## 8. Filter out and map our coverage
Next we want to tell the coverage tool what we care about and where it lives
we can do this by executing `lcov` again with the `--extract` flag like this.

```sh
lcov \
  --gcov-tool ./llvm-gcov.sh \
  --rc lcov_branch_coverage=1 \
  --rc lcov_excl_line=assert \
  --extract ./tests.info "$(pwd)/*" \
  -o cov.info
```

Most of the arguments are the same as above, we have removed the
directory arguments and swapped `--capture` for `--extract`. The
new flag does take two arguments, the first is the locaiton of 
and existing capture pass output, the second is a pattern
for where it should look. Our patternis `$(pwd)/*`, which means
look in any folders in the present working directory. This will
exculue and information that might have been captured from
the standard library or other dependencies.

## 9. Render HTML
At this point, we can render this render a static website to explore
our coverage, we do this with the `genhtml` command. It looks something
like this.

```sh
genhtml \
  --branch-coverage \
  --demangle-cpp \
  --legend \
  -o ./coverage \
  ./cov.info
```
The arguments we are passing in help to inform what our report looks like.

- `--branch-coverage`: Enable branch coverage reporting
- `--demangle-cpp`: Demangle the symbols so they look like the original names
- `--legend`: Include a legend at the top so we know what the report means
- `-o ./coverage`: Where to put the files
- `./cov.info`: What file to use as input

[And with that we should have nice code coverage report.](https://freemasen.github.io/coverage-example)