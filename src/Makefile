# GCC options
CC = mpicc
CFLAGS = -O3 -ffast-math -g -std=c99 -pedantic -Wall -fno-omit-frame-pointer
#CFLAGS = -Kfast -std=c99 
LDFLAGS = -lm

#Debug options
#CFLAGS = -g -Og -std=c99 -pedantic -fsanitize=undefined -fsanitize=address

# Intel icc compiler
#CC = icc
#CFLAGS = -restrict -Ofast -std=c99 -pedantic
#LDFLAGS =

# Clang options
#CC = clang
#CFLAGS = -Ofast -std=c99 -pedantic
#LDFLAGS = -lm


SOURCE = current.c emf.c particles.c random.c timer.c main.c simulation.c zdf.c

TARGET = zpic

DOCSBASE = ../docs

SBATCH_FILE = mpi.sh

DOCS = $(DOCSBASE)/html/index.html

OBJ = $(SOURCE:.c=.o)

all : $(TARGET)

docs : $(DOCS)

$(TARGET) : $(OBJ)
	$(CC) $(CFLAGS) $(OBJ) $(LDFLAGS) -o $@

.c.o:
	$(CC) -c $(CFLAGS) $< -o $@

$(DOCS) : $(SOURCE)
	@doxygen ./Doxyfile

run: ./$(TARGET)
	sbatch $(SBATCH_FILE)

clean:
	@touch $(TARGET) $(OBJ)
	rm -f $(TARGET) $(OBJ) slurm-*.out slurm-*.err
	rm -f $(TARGET) $(OBJ)
	rm -rf $(DOCSBASE)
