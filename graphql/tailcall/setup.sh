#!/bin/bash

# Start timing
start_time=$(date +%s)

# For tailcall:
cd graphql/tailcall
npm install
cd ../../

# End timing
end_time=$(date +%s)

# Calculate duration
duration=$((end_time - start_time))

# Convert seconds to minutes and seconds
minutes=$((duration / 60))
seconds=$((duration % 60))

echo "SETUP.sh >>> Script execution time: $minutes minutes and $seconds seconds"