#!/bin/bash
###################################################################################################
#
# CrystFEL_partialator_executor.sh
#
# This script processes a single stream file using CrystFEL's partialator.
# It is intended to be called by an HTCondor job.
#
# (c) 2025 Sang-Ho Na(KISTI)
# Contact: shna@kisti.re.kr
# Assisted by Google's AI language model.
#
# Usage:
#   ./CrystFEL_partialator_executor.sh <stream_file_path> <symmetry> <num_cores> <output_dir_base> <log_dir_base>
#
# Arguments:
#   <stream_file_path>: Absolute path to the input .stream file
#   <symmetry>: Symmetry argument for partialator (e.g., p1, c2mm)
#   <num_cores>: Number of CPU cores for partialator
#   <output_dir_base>: Base directory for output .hkl files (absolute path)
#   <log_dir_base>: Base directory for partialator's own logs (stdout/stderr for this stream)
#
# Last Modified Data : 2025/05/21
#
###################################################################################################

# --- Environment Setup ---
# As specified in existing PAL-XFEL scripts
SETUP_SCRIPT="/pal/lib/setup_crystfel-0.9.1_hdf5-1.10.5.sh"

if [ -f "$SETUP_SCRIPT" ]; then
    echo "[INFO] Sourcing CrystFEL environment: $SETUP_SCRIPT"
    source "$SETUP_SCRIPT"
else
    echo "[ERROR] CrystFEL setup script not found: $SETUP_SCRIPT"
    echo "[ERROR] Partialator might not run correctly. Please ensure the script exists."
    exit 1
fi

# Add PAL HTCondor library path
if [[ ":$LD_LIBRARY_PATH:" != *":/pal/htcondor/lib:"* ]]; then
    echo "[INFO] Adding /pal/htcondor/lib to LD_LIBRARY_PATH"
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/pal/htcondor/lib
else
    echo "[INFO] /pal/htcondor/lib already in LD_LIBRARY_PATH"
fi

# --- Argument Parsing & Validation ---
if [ "$#" -ne 5 ]; then
    echo "[ERROR] Usage: $0 <stream_file_path> <symmetry> <num_cores> <output_dir_base> <log_dir_base>"
    echo "[ERROR] Received $# arguments: $@"
    exit 1
fi

STREAM_FILE_PATH="$1"
SYMMETRY="$2"
NUM_CORES="$3"
OUTPUT_DIR_BASE="$4" # Absolute path
LOG_DIR_BASE="$5"    # Absolute path

if ! command -v partialator &> /dev/null; then
    echo "[ERROR] partialator command not found after attempting to source setup script."
    echo "[ERROR] Please verify the CrystFEL installation and the setup script: $SETUP_SCRIPT"
    exit 1
fi

if [ ! -f "$STREAM_FILE_PATH" ]; then
    echo "[ERROR] Input stream file not found: '$STREAM_FILE_PATH'"
    exit 1
fi

if ! [[ "$NUM_CORES" =~ ^[0-9]+$ ]] || [ "$NUM_CORES" -le 0 ]; then
    echo "[ERROR] Number of cores must be a positive integer. Got: '$NUM_CORES'"
    exit 1
fi

# --- Directory Preparation ---
# Base directories should be created by the submission script.
# mkdir -p is safe here to ensure they exist if somehow not created.
mkdir -p "$OUTPUT_DIR_BASE"
mkdir -p "$LOG_DIR_BASE"

# --- File Naming ---
BASENAME=$(basename "$STREAM_FILE_PATH" .stream)
OUTPUT_HKL_FILE="${OUTPUT_DIR_BASE}/${BASENAME}.hkl"
LOG_STDOUT_PARTIALATOR="${LOG_DIR_BASE}/${BASENAME}.out" # Partialator's stdout
LOG_STDERR_PARTIALATOR="${LOG_DIR_BASE}/${BASENAME}.err" # Partialator's stderr

# --- Execution ---
echo "[INFO] Starting partialator processing for: $STREAM_FILE_PATH"
echo "[INFO]   Symmetry         : $SYMMETRY"
echo "[INFO]   Number of Cores  : $NUM_CORES"
echo "[INFO]   Output HKL File  : $OUTPUT_HKL_FILE"
echo "[INFO]   Stdout Log       : $LOG_STDOUT_PARTIALATOR"
echo "[INFO]   Stderr Log       : $LOG_STDERR_PARTIALATOR"
# echo "[INFO]   LD_LIBRARY_PATH: $LD_LIBRARY_PATH" # Optional: for debugging

# Command similar to the original CrystFEL_partialator.sh and 3_exec_indexing.sh
time partialator -i "$STREAM_FILE_PATH" -o "$OUTPUT_HKL_FILE" \
    -y "$SYMMETRY" --iterations=1 --model=unity --push-res=0.5 -j "$NUM_CORES" \
    > "$LOG_STDOUT_PARTIALATOR" 2> "$LOG_STDERR_PARTIALATOR"

EXIT_STATUS=$?

if [ $EXIT_STATUS -ne 0 ]; then
    echo "[WARNING] partialator command failed for '$STREAM_FILE_PATH' with exit status $EXIT_STATUS."
    echo "[WARNING] Check partialator logs: '$LOG_STDERR_PARTIALATOR'"
else
    echo "[SUCCESS] partialator finished successfully for '$STREAM_FILE_PATH'."
fi

echo "[INFO] Finished partialator processing for '$STREAM_FILE_PATH'."
exit $EXIT_STATUS