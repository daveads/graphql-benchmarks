#!/bin/bash

# Record start time
start_time=$(date +%s)

# Base directory
cd graphql/tailcall

current_dir=$(pwd)
echo "Current directory: $current_dir"

base_dir="./node_modules"

# Pick the tailcall executable
for core_dir in $(find "$base_dir" -type d -name "core-*"); do
    tailcall_executable="${core_dir}/bin/tailcall"

    # Check if the tailcall executable exists
    if [[ -x "$tailcall_executable" ]]; then
        echo "Executing $tailcall_executable"

        # Run the executable with the specified arguments
        TAILCALL_LOG_LEVEL=error TC_TRACKER=false "$tailcall_executable" start $current_dir/benchmark.graphql
        
        # Record end time
        end_time=$(date +%s)
        
        # Calculate and print execution time
        execution_time=$((end_time - start_time))
        echo "Script execution time: $execution_time seconds"
        
        exit 0
    fi
done

echo "tailcall executable not found."

# Record end time even if executable is not found
end_time=$(date +%s)

# Calculate and print execution time
execution_time=$((end_time - start_time))
echo "tailcall RUN.sh >>> Script execution time: $execution_time seconds"

exit 1