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
- grcov
    - `cargo install grcov`
    - alternate: [download from GH Releases](https://github.com/mozilla/grcov/releases)
## 2. Validate your required binaries are working.
checking the versions of the following should look something like
this, keeping in mind the version numbers may change
```sh
lcov -v 
lcov: LCOV version 1.14
grcov --version
grcov 0.5.9
clang --version
clang version 9.0.0-2 (tags/RELEASE_900/final)
Target: x86_64-pc-linux-gnu
Thread model: posix
InstalledDir: /usr/bin
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
It should look something like this. `$COVERAGE_OPTIONS` will need to be
set when this process kicks off, we will do that in just a moment.
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
by setting the env variable `RUSTC_WRAPPER` and disable
incremental compilation by setting the  `CARGO_INCREMENTAL` env variable to 0

```sh
export RUSTC_WRAPPER="$PWD/wrap.sh"
export CARGO_INCREMENTAL=0
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
6. Ask cargo to not inline anythings: `-C inline-threshold=0`
7. Ask cargo to not insert overflow checks: `-C overflow-checks=off`
All together it looks something like this.

```sh
export COVERAGE_OPTIONS="-C codegen-units=1 -C link-dead-code -C passes=insert-gcov-profiling -L /Library/Developer/CommandLineTools/usr/lib/clang/11.0.0/lib/darwin -l clang_rt.profile_osx -C inline-threshold=0 -C overflow-checks=off"
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
that end in `.gcda` and `.gcno`. We are going to point the tool `grcov`
at these like this.

```sh
grcov . -s . -t lcov --llvm --branch --ignore-not-existing -o tests.info
```

This will generate a file called `tests.info` with our coverage information mapped
to the files here. the `-s` flag is for the source directory or where we executed the cargo
command that generated or `gc*` files. The `-t` flag is for the type, here we are using `lcov`
because there is more work we might want to do on the output. If you are using a service like
codecov.io, this is a type of file they could except. If you wanted to you could use the `html`
type but this would have a bunch of extra noise in the file that we want to filter out.

## 8. Filter outour coverage
Next we want to tell the coverage tool what we care about
we can do this by executing `lcov` with the `--extract` flag like this.

First we need to create a wrapper that leverages the llvm-cov tool, we will put that in a file called llvm-gcov.sh, which looks like this.

```sh
#!/bin/sh -e
echo $*
llvm-cov gcov $@
```
With that, we can now run the extraction with the following.

```sh
lcov \
  --gcov-tool ./llvm-gcov.sh \
  --rc lcov_branch_coverage=1 \
  --rc lcov_excl_line=assert \
  --extract ./tests.info "$(pwd)/*" \
  -o cov.info
```
The argument here:
- `--gcov-tool`: this points llvm-cov at our wrapper. note: this may not be in your path but will be available to lcov.
- `--rc lcov_branch_coverage=1`: enables branch coverage
- `--rc lcov_excl_line=assert`: enables line coverage
- `--extract ./tests.info "$(pwd)/src/*"`: removes any of the coverage infor that doesn't apply to the current working directory's src directory
- `-o cov.info`: puts the extracted coverage informaiton into a new file

The `--extract` flag does take two arguments, the first is the locaiton of 
and existing `.info` file, the second is a pattern
for where it should look. Our pattern is `$(pwd)/src/*`, which means
look in any folders in the src folder present working directory. This will
exculue and information that might have been captured from
the standard library, dependencies, build.rs files, or integraton tests located in the tests folder.

## 9. Render HTML
At this point, we can render this as a static website to explore
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