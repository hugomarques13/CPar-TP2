#!/bin/bash
#SBATCH --account=f202500010hpcvlabuminhoa
#SBATCH --partition=normal-arm
#SBATCH --ntasks=32
#SBATCH --time=00:30:00

# Output file for results
OUTPUT_FILE="mpi_benchmark_results.txt"
echo "MPI Benchmark Results - $(date)" > $OUTPUT_FILE
echo "=================================" >> $OUTPUT_FILE

# Number of runs for averaging
NUM_RUNS=5

# Loop through thread counts from 2 to 32
for NPROCS in 2 4 8 16 32; do
    echo "" >> $OUTPUT_FILE
    echo "Testing with $NPROCS MPI processes:" >> $OUTPUT_FILE
    
    TOTAL_TIME=0
    
    for RUN in $(seq 1 $NUM_RUNS); do
        echo "  Run $RUN of $NUM_RUNS with $NPROCS processes..."
        
        # Run and capture the time output
        START_TIME=$(date +%s.%N)
        srun --ntasks=$NPROCS ./zpic > /dev/null 2>&1
        END_TIME=$(date +%s.%N)
        
        # Calculate elapsed time
        ELAPSED=$(echo "$END_TIME - $START_TIME" | bc)
        TOTAL_TIME=$(echo "$TOTAL_TIME + $ELAPSED" | bc)
        
        echo "    Run $RUN: ${ELAPSED}s" >> $OUTPUT_FILE
    done
    
    # Calculate average
    AVERAGE=$(echo "scale=4; $TOTAL_TIME / $NUM_RUNS" | bc)
    echo "  Average time for $NPROCS processes: ${AVERAGE}s" >> $OUTPUT_FILE
    echo "  ----------------------------------------" >> $OUTPUT_FILE
    
    echo "  Completed $NPROCS processes - Average: ${AVERAGE}s"
done

echo "" >> $OUTPUT_FILE
echo "Benchmark completed at $(date)" >> $OUTPUT_FILE
echo "Results saved to $OUTPUT_FILE"