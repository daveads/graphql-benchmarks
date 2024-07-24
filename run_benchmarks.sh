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

rm "results.md"

# Kill existing servers and start nginx
killServerOnPort 3000
killServerOnPort 8000
sh nginx/run.sh

# Start the service
if [[ "$service" == "hasura" ]]; then
    bash "graphql/${service}/run.sh"
else
    bash "graphql/${service}/run.sh" &
fi

sleep 15 # Give some time for the service to start up

# Set the GraphQL endpoint
graphqlEndpoint="http://localhost:8000/graphql"
if [[ "$service" == "hasura" ]]; then
    graphqlEndpoint="http://127.0.0.1:8080/v1/graphql"
fi

# Run test queries
bash "test_query1.sh" "$graphqlEndpoint"
bash "test_query2.sh" "$graphqlEndpoint"
bash "test_query3.sh" "$graphqlEndpoint"

# Prepare benchmark commands
benchmarkCommands=()
for bench in 1 2 3; do
    for run in 1 2 3; do
        resultFile="bench${bench}_result${run}_graphql_${service}_run.sh.txt"
        benchmarkCommands+=("./run_single_benchmark.sh 'graphql/${service}/run.sh' $bench $graphqlEndpoint $resultFile")
    done
done

# Run benchmarks in parallel
echo "${benchmarkCommands[@]}" | parallel -j 3

# Display results
for bench in 1 2 3; do
    echo "Benchmark $bench"
    for run in 1 2 3; do
        cat "./bench${bench}_result${run}_graphql_${service}_run.sh.txt"
    done
    echo "End of Benchmark $bench"
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

killServerOnPort 8000