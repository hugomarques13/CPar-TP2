/*
Copyright (C) 2017 Instituto Superior Tecnico

This file is part of the ZPIC Educational code suite

The ZPIC Educational code suite is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

The ZPIC Educational code suite is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with the ZPIC Educational code suite. If not, see <http://www.gnu.org/licenses/>.
*/

#include <stdio.h>
#include <stdlib.h>

#include <math.h>

#include "zpic.h"
#include "simulation.h"
#include "emf.h"
#include "current.h"
#include "particles.h"
#include "timer.h"

// Include Simulation parameters here
#include "../input/twostream.c"
//#include "input/magnetized.c"
//#include "input/lwfa.c"
//#include "input/beam.c"
//#include "input/laser.c"
//#include "input/laser_particles.c"
//#include "input/absorbing.c"
//#include "input/density.c"

int main (int argc, const char * argv[]) {
    
    // Initialize MPI first
    MPI_Init(&argc, (char***)&argv);
    
    int rank, size;
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &size);
    
    // Apenas o master (rank 0) faz I/O inicial
    if (rank == 0) {
        printf("Starting simulation ...\n\n");
        printf("n = 0, t = 0.0\n");
    }
    
    // Initialize simulation - todos os processos fazem isto
    t_simulation sim;
    sim_init( &sim );

    int n;
    float t;
    double en_in, en_out;

    uint64_t t0, t1;
    t0 = timer_ticks();

    // Loop de simulação - todos os processos participam
    for (n=0, t=0.0; t<=sim.tmax; n++, t=n*sim.dt) {
        
        // Apenas master faz report
        if (rank == 0 && report(n, sim.ndump)) {
            sim_report(&sim, rank, size);
        }

        sim_iter(&sim);  // spec_advance paralelizado aqui

        if (n==0) {
            sim_report_energy_ret(&sim, &en_in);
            if (rank == 0) {
                sim_report_energy(&sim);
            }
        }
    }

    t1 = timer_ticks();
    
    // Apenas master faz output final
    if (rank == 0) {
        printf("n = %i, t = %f\n", n, t);
        fprintf(stderr, "\nSimulation ended.\n\n");
        sim_report_energy(&sim);
        sim_report_energy_ret(&sim, &en_out);
        printf("Initial energy: %e, Final energy: %e\n", en_in, en_out);
        double ratio = 100 * fabs((en_in - en_out) / en_out);
        printf("\nFinal energy different from Initial Energy. Change in total energy is: %.2f %% \n", ratio);
        if (ratio > 5) {
            printf("ERROR: Large Change\n");
        }

        // Simulation times
        sim_timings(&sim, t0, t1);
    }

    // Cleanup data - todos os processos
    sim_delete(&sim);
    
    // Finalize MPI
    MPI_Finalize();

    return 0;
}
