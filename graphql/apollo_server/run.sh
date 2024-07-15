#!/bin/bash

# Start the timer
start_time=$(date +%s.%N)

pwd
cd graphql/apollo_server
npm i
npm start

# End the timer
end_time=$(date +%s.%N)

# Calculate the duration
duration=$(echo "$end_time - $start_time" | bc)

# Convert to hours, minutes, and seconds
hours=$(echo "$duration / 3600" | bc)
minutes=$(echo "($duration % 3600) / 60" | bc)
seconds=$(echo "$duration % 60" | bc)

# Print the execution time
printf "Execution time: %d hours, %d minutes, and %.2f seconds\n" $hours $minutes $seconds