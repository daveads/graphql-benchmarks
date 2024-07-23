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

# Function to run all benchmarks for a service
function runBenchmark() {
  local serviceScript="$1"
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

  # Run benchmarks in parallel
  parallel --jobs 3 ./run_single_benchmark.sh "$serviceScript" {1} "$graphqlEndpoint" ::: 1 2 3
}

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

rm -f "results.md"
killServerOnPort 3000
sh nginx/run.sh

# Run the benchmark and capture the result filenames
resultFiles=$(runBenchmark "graphql/${service}/run.sh")

# Display results
echo "Results for $service:"
for file in $resultFiles; do
  echo "Contents of $file:"
  cat "$file"
  echo ""
done

# Cleanup
if [ "$service" == "apollo_server" ]; then
    cd graphql/apollo_server/
    npm stop
    cd ../../
elif [ "$service" == "hasura" ]; then
    bash "graphql/hasura/kill.sh"
fi