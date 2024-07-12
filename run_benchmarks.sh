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

# Initialize result arrays
bench1Results=()
bench2Results=()
bench3Results=()

# Function to run benchmark for a specific server
function runBenchmark() {
    local serviceScript="$1"
    local benchmarks=(1 2 3)

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
        graphqlEndpoint=http://$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' graphql-engine):8080/v1/graphql
    fi

    # Replace / with _
    local sanitizedServiceScriptName=$(echo "$serviceScript" | tr '/' '_')

    # Run benchmarks in parallel
    for bench in "${benchmarks[@]}"; do
        (
            local benchmarkScript="wrk/bench.sh"
            local resultFiles=("result1_${sanitizedServiceScriptName}.txt" "result2_${sanitizedServiceScriptName}.txt" "result3_${sanitizedServiceScriptName}.txt")

            bash "test_query${bench}.sh" "$graphqlEndpoint"
            # Warmup run
            bash "$benchmarkScript" "$graphqlEndpoint" "$bench" >/dev/null
            sleep 1 # Give some time for apps to finish in-flight requests from warmup
            bash "$benchmarkScript" "$graphqlEndpoint" "$bench" >/dev/null
            sleep 1
            bash "$benchmarkScript" "$graphqlEndpoint" "$bench" >/dev/null
            sleep 1

            # 3 benchmark runs
            for resultFile in "${resultFiles[@]}"; do
                echo "Running benchmark $bench for $serviceScript"
                bash "$benchmarkScript" "$graphqlEndpoint" "$bench" >"bench${bench}_${resultFile}"
                if [ "$bench" == "1" ]; then
                    bench1Results+=("bench1_${resultFile}")
                elif [ "$bench" == "2" ]; then
                    bench2Results+=("bench2_${resultFile}")
                elif [ "$bench" == "3" ]; then
                    bench3Results+=("bench3_${resultFile}")
                fi
            done
        ) &
    done

    # Wait for all background processes to finish
    wait

    # Clean up
    if [ "$serviceScript" == "graphql/apollo_server/run.sh" ]; then
        cd graphql/apollo_server/
        npm stop
        cd ../../
    elif [ "$serviceScript" == "graphql/hasura/run.sh" ]; then
        bash "graphql/hasura/kill.sh"
    else
        killServerOnPort 8000
    fi
}

# Main execution
if [ $# -eq 0 ]; then
    echo "Usage: $0 <server_name>"
    echo "Available servers: apollo_server, caliban, netflix_dgs, gqlgen, tailcall, async_graphql, hasura, graphql_jit"
    exit 1
fi

server="$1"
serviceScript="graphql/${server}/run.sh"

if [ ! -f "$serviceScript" ]; then
    echo "Error: Server script not found for $server"
    exit 1
fi

killServerOnPort 3000
sh nginx/run.sh

rm -f results.md

runBenchmark "$serviceScript"

# Print results (you may want to modify this part based on how you want to handle the results)
echo "Benchmark 1 Results: ${bench1Results[@]}"
echo "Benchmark 2 Results: ${bench2Results[@]}"
echo "Benchmark 3 Results: ${bench3Results[@]}"