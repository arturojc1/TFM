#!/bin/bash

# This script is used to run TranSiesta bias calculation.

# Work flow:

# 1. Make a new directory for the calculation and move to it.
# 2. Copy the pseudopotentials to the new directory.
# 3. Run siesta with the input file in the previous directory. $ siesta -V v:eV ../RUN.fdf > TS_v.out where v is the bias.
# 4. Copy the output .TSDE file to the next new directory. 
# 5. Repeat the process for all the bias values.

# Check if help is requested
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    echo "TranSiesta Bias Calculation Script"
    echo "=================================="
    echo
    echo "Usage: $0 <input_fdf_file> <pseudo_dir> <num_steps> [max_bias]"
    echo
    echo "Arguments:"
    echo "  <input_fdf_file>  : Path to the input FDF file"
    echo "  <pseudo_dir>      : Directory containing pseudopotential files (.psf or .vps)"
    echo "  <num_steps>       : Number of steps for bias calculation (minimum 2)"
    echo "  [max_bias]        : Maximum bias value in eV (default: 1.0)"
    echo
    echo "Examples:"
    echo "  $0 RUN.fdf ./pseudo 5"
    echo "    Will calculate biases: 0, 0.25, 0.5, 0.75, 1.0"
    echo
    echo "  $0 RUN.fdf ./pseudo 5 2.0"
    echo "    Will calculate biases: 0, 0.5, 1.0, 1.5, 2.0"
    exit 0
fi

# Check if required arguments are provided
if [ "$#" -lt 3 ] || [ "$#" -gt 4 ]; then
    echo "Usage: $0 <input_fdf_file> <pseudo_dir> <num_steps> [max_bias]"
    exit 1
fi

# Get the arguments
INPUT_FDF="$1"
PSEUDO_DIR="$2"
NUM_STEPS="$3"
MAX_BIAS="${4:-1.0}"  # Default to 1.0 if not specified

# Check if the number of steps is valid
if ! [[ "$NUM_STEPS" =~ ^[0-9]+$ ]]; then
    echo "Error: Number of steps must be a positive integer."
    exit 1
fi

if [ "$NUM_STEPS" -lt 2 ]; then
    echo "Error: Number of steps must be at least 2."
    exit 1
fi

# Check if max_bias is a valid number
if ! [[ "$MAX_BIAS" =~ ^[0-9]*\.?[0-9]+$ ]]; then
    echo "Error: Maximum bias must be a positive number."
    exit 1
fi

# Function to format time (converts seconds to HH:MM:SS)
format_time() {
    local seconds=$1
    local hours=$((seconds / 3600))
    local minutes=$(((seconds % 3600) / 60))
    local secs=$((seconds % 60))
    printf "%02d:%02d:%02d" $hours $minutes $secs
}

# Function to calculate and display time estimates
show_time_estimate() {
    local current_index=$1
    local total_count=$2
    local elapsed_seconds=$3
    
    if [ "$current_index" -eq 0 ]; then
        echo "First calculation, no time estimate available yet."
        return
    fi
    
    # Calculate average time per calculation
    local avg_time=$((elapsed_seconds / current_index))
    
    # Calculate remaining time
    local remaining_calcs=$((total_count - current_index))
    local remaining_seconds=$((remaining_calcs * avg_time))
    
    # Format times for display
    local elapsed_formatted=$(format_time $elapsed_seconds)
    local remaining_formatted=$(format_time $remaining_seconds)
    local avg_formatted=$(format_time $avg_time)
    local total_estimated=$(format_time $((elapsed_seconds + remaining_seconds)))
    
    echo "Time Summary:"
    echo "  Elapsed time: $elapsed_formatted"
    echo "  Average time per calculation: $avg_formatted"
    echo "  Estimated remaining time: $remaining_formatted"
    echo "  Estimated total time: $total_estimated"
    echo "  Progress: $current_index/$total_count ($(( current_index * 100 / total_count ))%)"
}

# Define bias range and step
MIN_BIAS=0.0
STEP=$(echo "scale=6; $MAX_BIAS / ($NUM_STEPS - 1)" | bc)

# Generate bias values, always starting with 0
BIAS_VALUES=()
for ((i=0; i<NUM_STEPS; i++)); do
    BIAS=$(echo "scale=6; $i * $STEP" | bc)
    # Remove trailing zeros
    BIAS=$(echo $BIAS | sed 's/\.0*$//' | sed 's/\.\([0-9]*[1-9]\)0*$/\.\1/')
    if [ -z "$BIAS" ]; then BIAS="0"; fi
    BIAS_VALUES+=("$BIAS")
done

echo "Generated bias values: ${BIAS_VALUES[*]}"

# Convert to absolute paths
INPUT_FDF="$(readlink -f "$INPUT_FDF")"
PSEUDO_DIR="$(readlink -f "$PSEUDO_DIR")"

# Check if input file exists
if [ ! -f "$INPUT_FDF" ]; then
    echo "Error: Input file $INPUT_FDF does not exist!"
    exit 1
fi

# Check if pseudopotential directory exists
if [ ! -d "$PSEUDO_DIR" ]; then
    echo "Error: Pseudopotential directory $PSEUDO_DIR does not exist!"
    exit 1
fi

# Get the absolute path of the current directory
SCRIPT_DIR="$(pwd)"

# Create base directory for all calculations with absolute path
BASE_DIR="$SCRIPT_DIR/TS_calculations_$(date +%Y%m%d_%H%M)"
mkdir -p "$BASE_DIR"
echo "Created base directory: $BASE_DIR"

# Copy the input file to the base directory
cp "$INPUT_FDF" "$BASE_DIR/"
echo "Copied $INPUT_FDF to $BASE_DIR/"

# Previous calculation directory (initially none)
PREV_DIR=""

# Total number of bias calculations
TOTAL_CALCS=${#BIAS_VALUES[@]}

# Start time of the script
SCRIPT_START_TIME=$(date +%s)

# Loop through each bias value
for index in "${!BIAS_VALUES[@]}"; do
    bias="${BIAS_VALUES[$index]}"
    echo "======================="
    echo "Processing bias: $bias eV ($(($index+1))/$TOTAL_CALCS)"
    echo "======================="
    
    # Record start time for this calculation
    CURRENT_CALC_START_TIME=$(date +%s)
    
    # Create directory for this bias value
    CURRENT_DIR="$BASE_DIR/bias_${bias}"
    mkdir -p "$CURRENT_DIR"
    echo "Created directory: $CURRENT_DIR"
    
    # Copy pseudopotentials
    echo "Copying pseudopotentials from $PSEUDO_DIR to $CURRENT_DIR"
    cp "$PSEUDO_DIR"/*.psf "$CURRENT_DIR/" 2>/dev/null
    cp "$PSEUDO_DIR"/*.vps "$CURRENT_DIR/" 2>/dev/null
    
    # Move to calculation directory
    cd "$CURRENT_DIR" || exit 1
    echo "Changed directory to: $(pwd)"
    
    # If there was a previous calculation, copy the TSDE file
    if [ -n "$PREV_DIR" ]; then
        echo "Copying TSDE file from previous calculation"
        cp "$PREV_DIR"/*.TSDE ./ 2>/dev/null || echo "Warning: No TSDE file found in $PREV_DIR"
    fi
    
    # Run siesta with the specified bias
    echo "Running TranSiesta with bias $bias eV"
    siesta -V "$bias:eV" "$INPUT_FDF" > "TS_${bias}.out"
    
    # Check if siesta completed successfully
    if [ $? -ne 0 ]; then
        echo "Error: TranSiesta calculation failed for bias $bias eV!"
        exit 1
    fi
    
    # Store current directory path as previous for next iteration
    PREV_DIR="$CURRENT_DIR"
    
    # Return to the base directory directly with absolute path
    cd "$BASE_DIR" || exit 1
    
    # Calculate timing for this calculation
    CALC_END_TIME=$(date +%s)
    CALC_DURATION=$((CALC_END_TIME - CURRENT_CALC_START_TIME))
    CALC_DURATION_FORMATTED=$(format_time $CALC_DURATION)
    
    # Calculate and show overall time estimate
    CURRENT_TIME=$(date +%s)
    ELAPSED_TIME=$((CURRENT_TIME - SCRIPT_START_TIME))
    show_time_estimate $((index + 1)) "$TOTAL_CALCS" "$ELAPSED_TIME"
    
    echo "Time for this calculation: $CALC_DURATION_FORMATTED"
    
    echo "Calculation for bias $bias eV completed successfully."
    echo ""
done

echo "All TranSiesta calculations completed successfully!"
echo "Results are stored in: $BASE_DIR"

# Create or check for a directory with a fixed name for all TSHS files
TSHS_DIR="$SCRIPT_DIR/TSHS_files"

# Check if directory already exists
if [ -d "$TSHS_DIR" ]; then
    echo "TSHS files saved at $TSHS_DIR"
else
    mkdir -p "$TSHS_DIR"
    echo "Created directory for TSHS files: $TSHS_DIR"
fi

# Copy and rename TSHS files to the dedicated directory
echo "Copying and renaming TSHS files to $TSHS_DIR"
# Remove old TSHS files if they exist
rm -f "$TSHS_DIR"/*.TSHS 2>/dev/null

# Initialize counter for copied files
TSHS_COUNT=0

# Go through each bias directory and copy the TSHS file with the bias value as name
for bias in "${BIAS_VALUES[@]}"; do
    BIAS_DIR="$BASE_DIR/bias_${bias}"
    if [ -d "$BIAS_DIR" ]; then
        # Find the TSHS file in this directory
        TSHS_FILES=$(find "$BIAS_DIR" -name "*.TSHS" 2>/dev/null)
        if [ -n "$TSHS_FILES" ]; then
            # Copy and rename the file(s)
            for tshs_file in $TSHS_FILES; do
                cp "$tshs_file" "$TSHS_DIR/${bias}.TSHS" 2>/dev/null
                if [ $? -eq 0 ]; then
                    echo "Copied and renamed: $tshs_file → $TSHS_DIR/${bias}.TSHS"
                    ((TSHS_COUNT++))
                fi
            done
        fi
    fi
done

if [ "$TSHS_COUNT" -gt 0 ]; then
    echo "Successfully copied $TSHS_COUNT TSHS files to $TSHS_DIR"
else
    echo "No TSHS files were found in the calculation directories"
fi
