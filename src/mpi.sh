#!/bin/bash
#SBATCH --account=f202500010hpcvlabuminhoa
#SBATCH --partition=normal-arm
#SBATCH --ntasks=2
#SBATCH --time=00:04:00

mpirun -np 2 ./zpic
