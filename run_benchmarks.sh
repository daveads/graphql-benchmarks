#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status

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

  # Function to run a single benchmark
  function runSingleBenchmark() {
    local bench="$1"
    local benchmarkScript="wrk/bench.sh"
    local resultFiles=("result1_${sanitizedServiceScriptName}.txt" "result2_${sanitizedServiceScriptName}.txt" "result3_${sanitizedServiceScriptName}.txt")

    echo "Starting benchmark $bench for $serviceScript"
    
    bash "test_query${bench}.sh" "$graphqlEndpoint"

    # Warmup run
    bash "$benchmarkScript" "$graphqlEndpoint" "$bench" >/dev/null
    sleep 2 # Increased sleep time
    bash "$benchmarkScript" "$graphqlEndpoint" "$bench" >/dev/null
    sleep 2
    bash "$benchmarkScript" "$graphqlEndpoint" "$bench" >/dev/null
    sleep 2

    # 3 benchmark runs
    for resultFile in "${resultFiles[@]}"; do
        echo "Running benchmark $bench for $serviceScript"
        bash "$benchmarkScript" "$graphqlEndpoint" "$bench" >"bench${bench}_${resultFile}"
        sleep 1  # Add a small delay between runs
    done

    echo "Finished benchmark $bench for $serviceScript"
  }

  # Run benchmarks in parallel with a timeout
  timeout 600s runSingleBenchmark 1 &
  pid1=$!
  timeout 600s runSingleBenchmark 2 &
  pid2=$!
  timeout 600s runSingleBenchmark 3 &
  pid3=$!

  # Wait for all benchmarks to complete or timeout
  wait $pid1 $pid2 $pid3

  # Check if any of the benchmarks timed out
  if ! ps -p $pid1 > /dev/null; then
    echo "Benchmark 1 timed out or failed"
  fi
  if ! ps -p $pid2 > /dev/null; then
    echo "Benchmark 2 timed out or failed"
  fi
  if ! ps -p $pid3 > /dev/null; then
    echo "Benchmark 3 timed out or failed"
  fi

  # Collect results
  for bench in 1 2 3; do
    for resultFile in "result1_${sanitizedServiceScriptName}.txt" "result2_${sanitizedServiceScriptName}.txt" "result3_${sanitizedServiceScriptName}.txt"; do
      if [ -f "bench${bench}_${resultFile}" ]; then
        if [ "$bench" == "1" ]; then
          bench1Results+=("bench1_${resultFile}")
        elif [ "$bench" == "2" ]; then
          bench2Results+=("bench2_${resultFile}")
        elif [ "$bench" == "3" ]; then
          bench3Results+=("bench3_${resultFile}")
        fi
      else
        echo "Missing result file: bench${bench}_${resultFile}"
      fi
    done
  done
}

rm -f "results.md"

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

# Display results
for bench in 1 2 3; do
  echo "Benchmark $bench"
  for result in $(eval echo \${bench${bench}Results[@]}); do
    if [ -f "$result" ]; then
      cat "$result"
    else
      echo "Missing result file: $result"
    fi
  done
  echo "End of Benchmark $bench"
  echo ""
done

if [ "$service" == "apollo_server" ]; then
    cd graphql/apollo_server/
    npm stop
    cd ../../
elif [ "$service" == "hasura" ]; then
    bash "graphql/hasura/kill.sh"
fi