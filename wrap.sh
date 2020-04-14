#! /bin/bash -e
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

case $(get_crate_name "$@") in
  coverage_example)
    EXTRA=$COVERAGE_OPTIONS
    ;;
  *)
    ;;
esac
exec "$@" $EXTRA