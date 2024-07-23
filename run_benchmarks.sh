#!/bin/bash

# Start services and run benchmarks
function killServerOnPort() {
    local port="$1"
    local pid=$(lsof -t -i:"$port")
    if [ -n "$pid" ]; then
        kill "$pid"
        echo "Killed process running on port $port"
    else
        echo "No process found running on port $port"
    fi
}

bench1Results=()
bench2Results=()
bench3Results=()

killServerOnPort 3000
sh nginx/run.sh

function runBenchmark() {
    killServerOnPort 8000
    sleep 5
    local serviceScript="$1"
    local benchmarks=(1 2 3)
    if [[ "$serviceScript" == *"hasura"* ]]; then
        bash "$serviceScript" # Run synchronously without background process
    else
        bash "$serviceScript" & # Run in daemon mode
    fi
    sleep 15 # Give some time for the service to start up

    local graphqlEndpoint="http://localhost:8000/graphql"
    if [[ "$serviceScript" == *"hasura"* ]]; then
        graphqlEndpoint=http://127.0.0.1:8080/v1/graphql
    fi

    # Replace / with _
    local sanitizedServiceScriptName=$(echo "$serviceScript" | tr '/' '_')

    # Use GNU Parallel to run test queries in parallel
    parallel --jobs 3 --results parallel_results bash ::: \
        "test_query1.sh" "test_query2.sh" "test_query3.sh" ::: "$graphqlEndpoint"

    # Warmup runs in parallel
    parallel --jobs 3 --results parallel_results bash "wrk/bench.sh" "$graphqlEndpoint" ::: 1 2 3 ::: >/dev/null
    sleep 1
    parallel --jobs 3 --results parallel_results bash "wrk/bench.sh" "$graphqlEndpoint" ::: 1 2 3 ::: >/dev/null
    sleep 1
    parallel --jobs 3 --results parallel_results bash "wrk/bench.sh" "$graphqlEndpoint" ::: 1 2 3 ::: >/dev/null
    sleep 1

    # Actual benchmark runs in parallel
    parallel --jobs 9 --results parallel_results bash "wrk/bench.sh" "$graphqlEndpoint" {1} ">" "bench{1}_result{2}_${sanitizedServiceScriptName}.txt" ::: 1 2 3 ::: 1 2 3

    # Collect results
    for bench in "${benchmarks[@]}"; do
        bench${bench}Results+=($(ls bench${bench}_result*_${sanitizedServiceScriptName}.txt))
    done
}

rm "results.md"

# Main script
if [ $# -eq 0 ]; then
    echo "Usage: $0 <service_name>"
    echo "Available services: apollo_server, caliban, netflix_dgs, gqlgen, tailcall, async_graphql, hasura, graphql_jit"
    exit 1
fi

service="$1"
valid_services=("apollo_server" "caliban" "netflix_dgs" "gqlgen" "tailcall" "async_graphql" "hasura" "graphql_jit")

if [[ ! " ${valid_services[@]} " =~ " ${service} " ]]; then
    echo "Invalid service name. Available services: ${valid_services[*]}"
    exit 1
fi

runBenchmark "graphql/${service}/run.sh"

echo "Benchmark 1"
cat ./bench1_result1_graphql_${service}_run.sh.txt
cat ./bench1_result2_graphql_${service}_run.sh.txt
cat ./bench1_result3_graphql_${service}_run.sh.txt
echo "End of Benchmark 1"
echo ""

echo "Benchmark 2"
cat ./bench2_result1_graphql_${service}_run.sh.txt
cat ./bench2_result2_graphql_${service}_run.sh.txt
cat ./bench2_result3_graphql_${service}_run.sh.txt
echo "End of Benchmark 2"
echo ""

echo "Benchmark 3"
cat ./bench3_result1_graphql_${service}_run.sh.txt
cat ./bench3_result2_graphql_${service}_run.sh.txt
cat ./bench3_result3_graphql_${service}_run.sh.txt
echo "End of Benchmark 3"
echo ""

if [ "$service" == "apollo_server" ]; then
    cd graphql/apollo_server/
    npm stop
    cd ../../
elif [ "$service" == "hasura" ]; then
    bash "graphql/hasura/kill.sh"
fi