# GCC options
CC = gcc
CFLAGS = -Ofast -g -std=c99 -fopenmp -pedantic -Wall -march=native -fno-omit-frame-pointer
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

DOCS = $(DOCSBASE)/html/index.html

OBJ = $(SOURCE:.c=.o)

export OMP_NUM_THREADS ?= 13

all : $(TARGET)

docs : $(DOCS)

$(TARGET) : $(OBJ)
	$(CC) $(CFLAGS) $(OBJ) $(LDFLAGS) -o $@

%.o: %.c
	$(CC) -c $(CFLAGS) $< -o $@

$(DOCS) : $(SOURCE)
	@cd .. && doxygen ./Doxyfile

run: all
	./$(TARGET)

clean:
	rm -f $(TARGET) $(OBJ)
	rm -rf $(DOCSBASE)