#!/bin/bash

# Start the timer
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
        
        # End the timer and calculate duration
        end_time=$(date +%s)
        duration=$((end_time - start_time))
        
        # Convert seconds to minutes and seconds
        minutes=$((duration / 60))
        seconds=$((duration % 60))
        
        echo "Script execution time: $minutes minutes and $seconds seconds"
        
        exit 0
    fi
done

echo "tailcall executable not found."

# End the timer and calculate duration even if the executable wasn't found
end_time=$(date +%s)
duration=$((end_time - start_time))

# Convert seconds to minutes and seconds
minutes=$((duration / 60))
seconds=$((duration % 60))

echo "tailcall :: run.sh >>> Script execution time: $minutes minutes and $seconds seconds"

exit 1