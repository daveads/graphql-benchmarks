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
    graphqlEndpoint=http://$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' graphql-engine):8080/v1/graphql
  fi

  for bench in "${benchmarks[@]}"; do
    local benchmarkScript="wrk/bench.sh"

    # Replace / with _
    local sanitizedServiceScriptName=$(echo "$serviceScript" | tr '/' '_')

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
    done
}

rm "results.md"

for service in "apollo_server" "caliban" "netflix_dgs" "gqlgen" "tailcall" "async_graphql" "hasura" "graphql_jit"; do
  runBenchmark "graphql/${service}/run.sh"

    # If the server is tailcall, output the results for each benchmark
  if [ "$server" == "tailcall" ]; then
      echo "Benchmark 1"
      cat ./bench1_result1_graphql_tailcall_run.sh.txt
      cat ./bench1_result2_graphql_tailcall_run.sh.txt
      cat ./bench1_result3_graphql_tailcall_run.sh.txt
      echo "End of Benchmark 1"
      echo ""
      echo "Benchmark 2"
      cat ./bench2_result1_graphql_tailcall_run.sh.txt
      cat ./bench2_result2_graphql_tailcall_run.sh.txt
      cat ./bench2_result3_graphql_tailcall_run.sh.txt
      echo "End of Benchmark 2"
      echo ""
      echo "Benchmark 3"
      cat ./bench3_result1_graphql_tailcall_run.sh.txt
      cat ./bench3_result2_graphql_tailcall_run.sh.txt
      cat ./bench3_result3_graphql_tailcall_run.sh.txt
      echo "End of Benchmark 3"
      echo ""
  fi
  
  if [ "$service" == "apollo_server" ]; then
    cd graphql/apollo_server/
    npm stop
    cd ../../
  elif [ "$service" == "hasura" ]; then
    bash "graphql/hasura/kill.sh"
  fi
done

bash analyze.sh "${bench1Results[@]}"
bash analyze.sh "${bench2Results[@]}"
bash analyze.sh "${bench3Results[@]}"
