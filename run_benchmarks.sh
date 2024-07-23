#!/bin/bash

# Function to kill server on a specific port
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

# Function to run benchmark for a single service
function runBenchmark() {
    local serviceScript="$1"
    local serviceName=$(basename "$serviceScript" .sh)
    
    killServerOnPort 8000
    sleep 5

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

    for bench in 1 2 3; do
        local benchmarkScript="wrk/bench.sh"
        local sanitizedServiceScriptName=$(echo "$serviceScript" | tr '/' '_')
        
        bash "test_query${bench}.sh" "$graphqlEndpoint"
        
        # Warmup run
        bash "$benchmarkScript" "$graphqlEndpoint" "$bench" >/dev/null
        sleep 1
        bash "$benchmarkScript" "$graphqlEndpoint" "$bench" >/dev/null
        sleep 1
        bash "$benchmarkScript" "$graphqlEndpoint" "$bench" >/dev/null
        sleep 1
        
        # 3 benchmark runs
        for run in 1 2 3; do
            echo "Running benchmark $bench for $serviceName (Run $run)"
            bash "$benchmarkScript" "$graphqlEndpoint" "$bench" > "bench${bench}_result${run}_${sanitizedServiceScriptName}.txt"
        done
    done

    if [[ "$serviceScript" == *"apollo_server"* ]]; then
        cd graphql/apollo_server/
        npm stop
        cd ../../
    elif [[ "$serviceScript" == *"hasura"* ]]; then
        bash "graphql/hasura/kill.sh"
    fi

    killServerOnPort 8000
}

# Main script
if [ $# -eq 0 ]; then
    echo "Usage: $0 <service1> [service2] [service3] ..."
    echo "Available services: apollo_server, caliban, netflix_dgs, gqlgen, tailcall, async_graphql, hasura, graphql_jit"
    exit 1
fi

valid_services=("apollo_server" "caliban" "netflix_dgs" "gqlgen" "tailcall" "async_graphql" "hasura" "graphql_jit")

# Validate input services
for service in "$@"; do
    if [[ ! " ${valid_services[@]} " =~ " ${service} " ]]; then
        echo "Invalid service name: $service. Available services: ${valid_services[*]}"
        exit 1
    fi
done

rm -f results.md

# Start nginx
killServerOnPort 3000
sh nginx/run.sh

# Run benchmarks in parallel
export -f runBenchmark killServerOnPort
parallel --jobs 3 runBenchmark "graphql/{}/run.sh" ::: "$@"

# Display results
for service in "$@"; do
    echo "Results for $service:"
    for bench in 1 2 3; do
        echo "Benchmark $bench"
        for run in 1 2 3; do
            cat "./bench${bench}_result${run}_graphql_${service}_run.sh.txt"
        done
        echo "End of Benchmark $bench"
        echo ""
    done
done