#!/bin/bash

# Start the timer
start_time=$(date +%s)

pwd
cd graphql/apollo_server
npm i
npm start

# End the timer
end_time=$(date +%s)

# Calculate the duration
duration=$((end_time - start_time))

# Convert to hours, minutes, and seconds
hours=$((duration / 3600))
minutes=$(( (duration % 3600) / 60 ))
seconds=$((duration % 60))

# Print the execution time
printf " apollo_server Run.sh >>> Execution time: %d hours, %d minutes, and %d seconds\n" $hours $minutes $seconds