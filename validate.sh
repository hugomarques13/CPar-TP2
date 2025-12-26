#!/bin/bash

PROGRAM_NAME=zpic
SRUN_ARGS="-p normal-arm -A F202500010HPCVLABUMINHOA -t 5:00"

rm -rf "${TEMP_DIR}"

# Check if the correct number of arguments is provided
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 path_to_zip_file"
  exit 1
fi

ZIP_FILE="$1"
#EXPECTED_FIRST_LINE="Final energy different from Initial Energy. Change in total energy is: 0.06 % "

# Check if the input file is a zip file
if [[ "${ZIP_FILE}" != *.zip ]]; then
  echo "Error: The provided file is not a zip file."
  exit 1
fi

# Create a temporary directory for unzipping
TEMP_DIR="tmp"
echo "Unzipping file to $TEMP_DIR"

# Unzip the provided zip file
unzip -o "${ZIP_FILE}" -d "${TEMP_DIR}" 2>/dev/null

# Check if unzip was successful
if [ $? -ne 0 ]; then
  echo "Error: Failed to unzip the file."
  rm -rf "${TEMP_DIR}"
  exit 1
fi

# Find directories in the unzipped folder
for entry in "$TEMP_DIR"/*
do
  if [ -d "$entry" ]; then
    # Recursively search for Makefile or makefile in the directory
    makefile_path=$(find "$entry" -type f \( -name "Makefile" -o -name "makefile" \) | head -n 1)

    # If a Makefile is found
    if [ -n "$makefile_path" ]; then
      echo "Found Makefile in $entry"

      # Move to the directory containing the Makefile
      makefile_dir=$(dirname "$makefile_path")
      cd "$makefile_dir"

      echo $SRUN_ARGS
      # Run make 
      #ml GCC/13.3.0
      srun ${SRUN_ARGS} bash -lc "ml GCC/13.3.0; make clean; make"
  #####


      if [ $? -ne 0 ]; then
        echo "Error: Make failed in $makefile_dir"
        cd - > /dev/null
        continue
      fi

      # Check if the executable 
      if test -f "$PROGRAM_NAME"; then
        echo "$entry - exe is ok"
        
        # Run perf stat on the executable
        srun ${SRUN_ARGS} perf stat -e cycles bash -c "ml GCC/13.3.0; make run > run1.txt 2>&1"


          # Validate the first line and specific value in the output
          LINE=`cat run1.txt | grep " Final energy:"`
          VALUE=`echo "$LINE" | grep -oE 'Final energy: [0-9]+\.[0-9]+e\+02' | grep -oE '[0-9]+\.[0-9]+'`
          #Comparation value 3.001722e+02, remove e+02
          BASE_VALUE="3.001722"
          MAX=`echo "$BASE_VALUE + 0.000005" | bc -l`
          MIN=`echo "$BASE_VALUE - 0.000005" | bc -l`
          
          TEST1=`echo "$VALUE <= $MAX" | bc -l`
          TEST2=`echo "$MIN <= $VALUE" | bc -l`

          if [[ $TEST1 -ne 0 && $TEST2 -ne 0 ]]; then
            echo "Output validation passed"
            #echo "${MIN}e+02 <=  ${VALUE} <= $MAX"
          else
            echo "Output validation failed:"
            echo "Expected value: ${BASE_VALUE}e+02"
            VALUE=$(echo "$LINE" | grep -o 'Final energy: [0-9.e+-]\+' | awk '{print $NF}')
            echo "Actual value: $VALUE"
          fi

          # Output the entire contents of run1.txt
          #echo "Program output:"
          #cat run1.txt

      else
        echo "Program not found in $makefile_dir"
      fi

      # Return to the original directory
      cd - > /dev/null

    else
      echo "No Makefile found in $entry, skipping."
    fi
  fi
done

# Clean up the temporary directory
rm -rf "${TEMP_DIR}"
