#!/bin/bash
#SBATCH --account=f202500010hpcvlabuminhoa
#SBATCH --partition=normal-arm
#SBATCH --ntasks=32
#SBATCH --time=00:10:00

OUTPUT_FILE="zpic_scaling_results.txt"

# Clear the file if it already exists
> "$OUTPUT_FILE"

for n in $(seq 1 20); do
    echo "===== Running with $n tasks =====" >> "$OUTPUT_FILE"
    srun --ntasks=$n ./zpic >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
done
