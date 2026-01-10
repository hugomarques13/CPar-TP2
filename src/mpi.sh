#!/bin/bash
#SBATCH --job-name=zpic-mpi
#SBATCH --account=f202500010hpcvlabuminhoa
#SBATCH --partition=normal-arm
#SBATCH --nodes=1
#SBATCH --ntasks=2
#SBATCH --cpus-per-task=1
#SBATCH --time=00:04:00
#SBATCH --output=slurm-%j.out
#SBATCH --error=slurm-%j.err

srun ./zpic
