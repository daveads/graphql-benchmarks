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

# Function to run benchmark for a specific service
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
    
    for bench in "${benchmarks[@]}"; do
        local benchmarkScript="wrk/bench.sh"
        # Replace / with _
        local sanitizedServiceScriptName=$(echo "$serviceScript" | tr '/' '_')
        local resultFile="result${bench}_${sanitizedServiceScriptName}.txt"
        
        bash "test_query${bench}.sh" "$graphqlEndpoint"
        
        # Warmup run
        bash "$benchmarkScript" "$graphqlEndpoint" "$bench" >/dev/null
        sleep 1 # Give some time for apps to finish in-flight requests from warmup
        bash "$benchmarkScript" "$graphqlEndpoint" "$bench" >/dev/null
        sleep 1
        bash "$benchmarkScript" "$graphqlEndpoint" "$bench" >/dev/null
        sleep 1
        
        # Actual benchmark run
        echo "Running benchmark $bench for $serviceScript"
        bash "$benchmarkScript" "$graphqlEndpoint" "$bench" >"bench${bench}_${resultFile}"
    done
}

# Check if a service name is provided
if [ $# -eq 0 ]; then
    echo "Please provide a service name as an argument."
    echo "Usage: ./run_benchmarks.sh <service_name>"
    exit 1
fi

service="$1"
serviceScript="graphql/${service}/run.sh"

# Check if the service script exists
if [ ! -f "$serviceScript" ]; then
    echo "Service script not found: $serviceScript"
    exit 1
fi

# Run nginx
killServerOnPort 3000
sh nginx/run.sh

# Run benchmark for the specified service
runBenchmark "$serviceScript"

# Stop the service if needed
if [ "$service" == "apollo_server" ]; then
    cd graphql/apollo_server/
    npm stop
    cd ../../
elif [ "$service" == "hasura" ]; then
    bash "graphql/hasura/kill.sh"
fi

# Analyze results
bash analyze.sh bench1_result1_${serviceScript}.txt bench1_result2_${serviceScript}.txt bench1_result3_${serviceScript}.txt
bash analyze.sh bench2_result1_${serviceScript}.txt bench2_result2_${serviceScript}.txt bench2_result3_${serviceScript}.txt
bash analyze.sh bench3_result1_${serviceScript}.txt bench3_result2_${serviceScript}.txt bench3_result3_${serviceScript}.txt
