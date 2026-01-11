#!/bin/bash
#SBATCH --account=f202500010hpcvlabuminhoa
#SBATCH --partition=normal-arm
#SBATCH --nodes=1
#SBATCH --ntasks=2
#SBATCH --time=00:30:00

# Load MPI module
ml OpenMPI

# Build
make clean
make

# Run
mpirun -np 2 ./zpic
