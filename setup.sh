#!/bin/bash

# Start timer for total execution time
total_start_time=$(date +%s)

# Function to measure and print execution time
measure_time() {
    local start_time=$1
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    echo "Execution time: $duration seconds"
}

# For gqlgen:
echo "Building gqlgen..."
start_time=$(date +%s)
cd graphql/gqlgen
go build -o main main.go
cd ../../
measure_time $start_time

# For apollo server:
echo "Installing apollo server dependencies..."
start_time=$(date +%s)
cd graphql/apollo_server
npm i
cd ../../
measure_time $start_time

# For netflix dgs
echo "Building netflix dgs..."
start_time=$(date +%s)
cd graphql/netflix_dgs
./gradlew build
cd ../../
measure_time $start_time

# For tailcall:
echo "Installing tailcall dependencies..."
start_time=$(date +%s)
cd graphql/tailcall
npm install
cd ../../
measure_time $start_time

# For caliban
echo "Compiling caliban..."
start_time=$(date +%s)
cd graphql/caliban
./sbt compile
cd ../../
measure_time $start_time

# For async-graphql
echo "Building async-graphql..."
start_time=$(date +%s)
./graphql/async_graphql/build.sh
measure_time $start_time

# For hasura
echo "Installing hasura dependencies..."
start_time=$(date +%s)
cd graphql/hasura
npm install
cd ../../
measure_time $start_time

# For graphql_jit
echo "Installing graphql_jit dependencies..."
start_time=$(date +%s)
cd graphql/graphql_jit
npm install
cd ../../
measure_time $start_time

# Calculate and print total execution time
total_end_time=$(date +%s)
total_duration=$((total_end_time - total_start_time))
echo "setup.sh >>> Total execution time: $total_duration seconds"