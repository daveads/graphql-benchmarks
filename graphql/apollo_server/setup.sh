#!/bin/bash

# Start the timer
start_time=$(date +%s.%N)

# For apollo server:
cd graphql/apollo_server
npm i
cd ../../

# End the timer
end_time=$(date +%s.%N)

# Calculate the duration
duration=$(echo "$end_time - $start_time" | bc)

# Convert to minutes and seconds
minutes=$(echo "$duration / 60" | bc)
seconds=$(echo "$duration % 60" | bc)

# Print the execution time
printf "Apollo Setup.sh >>> Execution time: %d minutes and %.2f seconds\n" $minutes $seconds