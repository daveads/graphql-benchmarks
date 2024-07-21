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
        graphqlEndpoint=http://127.0.0.1:8080/v1/graphql
    fi
    
    for bench in "${benchmarks[@]}"; do
        local benchmarkScript="wrk/bench.sh"
        local sanitizedServiceScriptName=$(echo "$serviceScript" | tr '/' '_')
        local resultFile="result${bench}_${sanitizedServiceScriptName}.txt"
        
        bash "test_query${bench}.sh" "$graphqlEndpoint"
        
        # Warmup run
        bash "$benchmarkScript" "$graphqlEndpoint" "$bench" >/dev/null
        sleep 1
        bash "$benchmarkScript" "$graphqlEndpoint" "$bench" >/dev/null
        sleep 1
        bash "$benchmarkScript" "$graphqlEndpoint" "$bench" >/dev/null
        sleep 1
        
        # Actual benchmark run
        echo "Running benchmark $bench for $serviceScript"
        bash "$benchmarkScript" "$graphqlEndpoint" "$bench" >"bench${bench}_${resultFile}"
    done
    
    # Stop the service
    if [[ "$serviceScript" == *"apollo_server"* ]]; then
        cd graphql/apollo_server/
        npm stop
        cd ../../
    elif [[ "$serviceScript" == *"hasura"* ]]; then
        bash "graphql/hasura/kill.sh"
    else
        killServerOnPort 8000
    fi
}

# Main script execution
if [ $# -eq 0 ]; then
    echo "Usage: $0 <service_name>"
    echo "Available services: apollo_server, caliban, netflix_dgs, gqlgen, tailcall, async_graphql, hasura, graphql_jit"
    exit 1
fi

service="$1"
service_script="graphql/${service}/run.sh"

if [ ! -f "$service_script" ]; then
    echo "Error: Service script not found for $service"
    exit 1
fi

killServerOnPort 3000
sh nginx/run.sh

rm -f "results.md"

runBenchmark "$service_script"

echo "Benchmark completed for $service"
