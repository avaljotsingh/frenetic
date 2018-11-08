#!/bin/bash
SCRIPT_DIR="$(dirname $(readlink -f $0))"
ROOT_DIR="${SCRIPT_DIR}/../../"
PROBNETKAT="dune exec probnetkat.bayonet --profile release"
CPS="true"
INPUT="${SCRIPT_DIR}/$1"
RESULT_FILE="${SCRIPT_DIR}/${1%.dot}.probnetkat.log"
TIMEOUT=3600

if [[ -z $1 ]]; then
  echo "usage: $0 <dot-file>"
  exit 1
fi

if [ ! -f $RESULT_FILE ]; then
    echo "analyzing: $INPUT"
    cd ${ROOT_DIR}
    { { time timeout $TIMEOUT $PROBNETKAT $INPUT $CPS; } 2>&1; } > $RESULT_FILE
    RC="$?"
    tail $RESULT_FILE
    exit $RC
else
    echo "skipping $INPUT; $RESULT_FILE already exists."
    tail $RESULT_FILE
fi
