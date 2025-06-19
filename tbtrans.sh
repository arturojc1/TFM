#!/bin/bash

# This script is used to run TranSiesta simulations.


# Work flow:
# 1. Make a new directory for the calculation and move to it. Make new directories for each bias value.
# 2. Move to the directory and run $ tbtrans -V v:eV ../RUN.fdf > TBT_v.out where v is the bias.
# 3. Repeat the process for all the bias values.

# Help function
show_help() {
    echo "TBTrans Calculation Script"
    echo "=========================="
    echo
    echo "Description:"
    echo "  This script automates TBTrans calculations by"
    echo "  running a series of calculations with different bias values."
    echo
    echo "Usage:"
    echo "  $0 <input_fdf_file> <num_steps> [max_bias]"
    echo
    echo "Arguments:"
    echo "  <input_fdf_file>  : Path to the input FDF file"
    echo "  <num_steps>       : Number of steps for bias calculation (minimum 2)"
    echo "  [max_bias]        : Maximum bias value in eV (default: 1.0)"
    echo
    echo "Options:"
    echo "  -h, --help        : Display this help message and exit"
    echo
    echo "Examples:"
    echo "  $0 RUN.fdf 7 3.0"
    echo "  This will calculate with bias values: 0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0"
    echo
    echo "  $0 RUN.fdf 5"
    echo "  This will calculate with bias values: 0.0, 0.25, 0.5, 0.75, 1.0"
    echo
    echo "Output:"
    echo "  - Creates a directory for each bias value under TBT_calculations_*"
    echo "  - Each directory will contain the TBTrans calculation results"
    echo
    echo "Note:"
    echo "  - The .TSHS files should be properly configured in the RUN.fdf file."
    exit 0
}

# Check for help flag
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_help
fi

# Function to check if a value is a valid number
is_number() {
    [[ "$1" =~ ^[0-9]*\.?[0-9]+$ ]]
}

# Parse positional arguments
if [ $# -lt 2 ] || [ $# -gt 3 ]; then
    echo "Error: Incorrect number of arguments."
    echo "Usage: $0 <input_fdf_file> <num_steps> [max_bias]"
    echo "Use '$0 -h' for more detailed help."
    exit 1
fi

INPUT_FDF="$1"
NUM_STEPS="$2"
MAX_BIAS="${3:-1.0}"  # Default to 1.0 if not specified

# Validate input
if ! [[ "$NUM_STEPS" =~ ^[0-9]+$ ]]; then
    echo "Error: Number of steps must be a positive integer."
    exit 1
fi

if [ "$NUM_STEPS" -lt 2 ]; then
    echo "Error: Number of steps must be at least 2."
    exit 1
fi

# Check if max_bias is a valid number
if ! is_number "$MAX_BIAS"; then
    echo "Error: Maximum bias must be a positive number."
    exit 1
fi

# Define bias range
MIN_BIAS=0.0

# Function to format time in a human-readable way
format_time() {
    local seconds=$1
    local hours=$((seconds / 3600))
    local minutes=$(((seconds % 3600) / 60))
    local secs=$((seconds % 60))
    
    if [ $hours -gt 0 ]; then
        echo "${hours}h ${minutes}m ${secs}s"
    elif [ $minutes -gt 0 ]; then
        echo "${minutes}m ${secs}s"
    else
        echo "${secs}s"
    fi
}

# Function to calculate and show time estimates
show_time_estimate() {
    local current_idx=$1
    local total_count=$2
    local start_time=$3
    local current_time=$(date +%s)
    local elapsed=$((current_time - start_time))
    
    # Don't calculate estimates for the first calculation
    if [ $current_idx -le 0 ]; then
        echo "Starting calculations..."
        return
    fi
    
    local avg_time=$((elapsed / current_idx))
    local remaining_count=$((total_count - current_idx))
    local estimated_remaining=$((avg_time * remaining_count))
    
    echo "---------------------------------------------"
    echo "Progress: $((current_idx * 100 / total_count))% ($current_idx/$total_count)"
    echo "Time for this calculation: $(format_time $avg_time)"
    echo "Elapsed time: $(format_time $elapsed)"
    
    if [ $remaining_count -gt 0 ]; then
        echo "Estimated remaining time: $(format_time $estimated_remaining)"
        echo "Estimated completion: $(date -d "@$((current_time + estimated_remaining))" '+%H:%M:%S')"
    fi
    echo "---------------------------------------------"
}

# Generate evenly spaced bias values
BIAS_VALUES=()
BIAS_VALUES_FORMATTED=()  # For formatted filenames with consistent decimal places
BIAS_RANGE=$(echo "scale=6; $MAX_BIAS - $MIN_BIAS" | bc)
STEP_SIZE=$(echo "scale=6; $BIAS_RANGE / ($NUM_STEPS - 1)" | bc)

for ((i=0; i<$NUM_STEPS; i++)); do
    # Calculate bias with 6 decimal places
    BIAS=$(echo "scale=6; $MIN_BIAS + ($i * $STEP_SIZE)" | bc)
    
    # Format with 1 decimal place for filenames (e.g., 0.0, 0.5, 1.0)
    BIAS_FORMATTED=$(printf "%.1f" $(echo "$BIAS" | sed 's/^\./0./'))
    
    # Remove trailing zeros for display and calculations
    BIAS_DISPLAY=$(echo $BIAS | sed 's/\.0*$//' | sed 's/\.\([0-9]*[1-9]\)0*$/\.\1/')
    
    # Add to arrays
    BIAS_VALUES+=("$BIAS_DISPLAY")
    BIAS_VALUES_FORMATTED+=("$BIAS_FORMATTED")
done

echo "Generated bias values: ${BIAS_VALUES_FORMATTED[*]}"

# Convert to absolute paths
INPUT_FDF="$(readlink -f "$INPUT_FDF")"

# Check if input file exists
if [ ! -f "$INPUT_FDF" ]; then
    echo "Error: Input file $INPUT_FDF does not exist!"
    exit 1
fi

# Get the absolute path of the current directory
SCRIPT_DIR="$(pwd)"

# Create base directory for all calculations with absolute path
BASE_DIR="$SCRIPT_DIR/TBT_calculations_$(date +%Y%m%d_%H%M)"
mkdir -p "$BASE_DIR"
echo "Created base directory: $BASE_DIR"

# Copy the input file to the base directory
cp "$INPUT_FDF" "$BASE_DIR/"
echo "Copied $INPUT_FDF to $BASE_DIR/"

# Start time for overall calculation
START_TIME=$(date +%s)

# Loop through each bias value
for idx in "${!BIAS_VALUES[@]}"; do
    bias="${BIAS_VALUES[$idx]}"
    bias_formatted="${BIAS_VALUES_FORMATTED[$idx]}"
    
    echo "======================="
    echo "Processing bias: $bias_formatted eV (${idx+1}/${#BIAS_VALUES[@]})"
    echo "======================="
    
    # Show time estimate before starting this calculation (except for first iteration)
    if [ $idx -gt 0 ]; then
        show_time_estimate $idx ${#BIAS_VALUES[@]} $START_TIME
    fi
    
    # Record start time for this specific calculation
    CALC_START_TIME=$(date +%s)
    
    # Create directory for this bias value with consistent formatting
    CURRENT_DIR="$BASE_DIR/bias_${bias_formatted}"
    mkdir -p "$CURRENT_DIR"
    echo "Created directory: $CURRENT_DIR"
    
    # Move to calculation directory
    cd "$CURRENT_DIR" || exit 1
    echo "Changed directory to: $(pwd)"
    
    # Run tbtrans with the specified bias
    echo "Running tbtrans with bias $bias_formatted eV"
    tbtrans -V "$bias_formatted:eV" "$INPUT_FDF" > "TBT_${bias_formatted}.out"
    
    # Check if tbtrans completed successfully
    if [ $? -ne 0 ]; then
        echo "Error: tbtrans calculation failed for bias $bias_formatted eV!"
        exit 1
    fi
    
    # Return to the base directory
    cd "$BASE_DIR" || exit 1
    
    # Calculate and show the time taken for this specific calculation
    CALC_END_TIME=$(date +%s)
    CALC_DURATION=$((CALC_END_TIME - CALC_START_TIME))
    
    echo "Calculation for bias $bias_formatted eV completed successfully in $(format_time $CALC_DURATION)."
    
    # Show overall progress and time estimate
    show_time_estimate $((idx + 1)) ${#BIAS_VALUES[@]} $START_TIME
    echo ""
done

# Calculate total execution time
END_TIME=$(date +%s)
TOTAL_DURATION=$((END_TIME - START_TIME))

echo "All TBTrans calculations completed successfully!"
echo "Total execution time: $(format_time $TOTAL_DURATION)"
echo "Results are stored in: $BASE_DIR"

# Create or check for a directory to collect results
RESULTS_DIR="$SCRIPT_DIR/TBT_results"

# Check if directory already exists
if [ -d "$RESULTS_DIR" ]; then
    echo "Relevant files copied to the directory: $RESULTS_DIR"
else
    mkdir -p "$RESULTS_DIR"
    echo "Created directory for results: $RESULTS_DIR"
fi

# Copy and rename relevant results (.nc files) to the results directory
# Clean up any existing results to avoid confusion
rm -f "$RESULTS_DIR"/*.nc 2>/dev/null

# Go through each bias directory and copy the result files with bias-based names
FILES_COPIED=0
for idx in "${!BIAS_VALUES[@]}"; do
    bias="${BIAS_VALUES[$idx]}"
    bias_formatted="${BIAS_VALUES_FORMATTED[$idx]}"
    
    BIAS_DIR="$BASE_DIR/bias_${bias_formatted}"
    if [ -d "$BIAS_DIR" ]; then
        # Find .nc files in this directory
        NC_FILES=$(find "$BIAS_DIR" -name "*.nc" 2>/dev/null)
        for nc_file in $NC_FILES; do
            # Extract just the base filename without directory
            base_name=$(basename "$nc_file")
            # Create new name with formatted bias value (e.g., 0.0, 0.5, 1.0)
            new_name="${bias_formatted}_${base_name%.nc}.nc"
            
            # Copy with new name
            cp "$nc_file" "$RESULTS_DIR/$new_name" 2>/dev/null
            if [ $? -eq 0 ]; then
                #echo "Copied and renamed: $nc_file → $RESULTS_DIR/$new_name"
                ((FILES_COPIED++))
            fi
        done
    fi
done

echo "Successfully copied $FILES_COPIED results files."
echo ""
echo "Finished processing all bias values!!"
echo "All results are available in: $RESULTS_DIR"


