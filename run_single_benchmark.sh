#!/bin/bash

function runBenchmark() {
    local serviceScript="$1"
    local bench="$2"
    local graphqlEndpoint="$3"
    local resultFile="$4"

    local benchmarkScript="wrk/bench.sh"

    # Warmup run
    bash "$benchmarkScript" "$graphqlEndpoint" "$bench" >/dev/null
    sleep 1
    bash "$benchmarkScript" "$graphqlEndpoint" "$bench" >/dev/null
    sleep 1
    bash "$benchmarkScript" "$graphqlEndpoint" "$bench" >/dev/null
    sleep 1

    # Actual benchmark run
    echo "Running benchmark $bench for $serviceScript"
    bash "$benchmarkScript" "$graphqlEndpoint" "$bench" >"$resultFile"
}

runBenchmark "$1" "$2" "$3" "$4"