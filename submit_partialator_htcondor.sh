#!/bin/bash
###################################################################################################
#
# submit_partialator_htcondor.sh 
#
# This script generates a list of stream files from a given input directory and
# submits a separate HTCondor job for each stream file to be processed by
# CrystFEL_partialator_executor.sh.
# 
# (c) 2025 Sang-Ho Na(KISTI)
# Contact: shna@kisti.re.kr
# Assisted by Google's AI language model.
#
# Usage:
#   ./submit_partialator_htcondor.sh <input_stream_dir> <symmetry> <num_cores> [output_dir_base] [log_dir_base]
#
# Arguments:
#   <input_stream_dir>: Directory containing input .stream files
#   <symmetry>: Symmetry argument for partialator (e.g., p1, c2mm)
#   <num_cores>: Number of CPU cores to request for each job
#   [output_dir_base]: (Optional) Base directory for output .hkl files (default: output_hkl)
#   [log_dir_base]: (Optional) Base directory for all logs (default: logs_partialator_multi)
#
# File History:
#   - submit_partialator_htcondor.sh (Initial Version) : 2025/05/21 by Sang-Ho Na
#
# Last Modified Data : 2025/05/21
#
###################################################################################################

# --- Debug Option ---
DEBUG=0 # Set to 1 for verbose debug messages

# --- Default Configuration ---
# You can set your default directory paths and settings in the variables below. 
DEFAULT_OUTPUT_DIR_BASE="output_hkl"
DEFAULT_LOG_DIR_BASE="logs_partialator_condor"
# Default variables for Condor  jobs (Do not modify)
DEFAULT_REQUEST_MEMORY="4GB" # Default memory request for Condor jobs
DEFAULT_REQUEST_DISK="2GB"   # Default disk request for Condor jobs
TEMP_STREAM_LIST_FILENAME="all_stream_files.tmp.lst" # Temporary file listing all streams

# --- Function Definitions ---
usage() {
    echo "Usage: $0 <input_stream_dir> <symmetry> <num_cores> [output_dir_base] [log_dir_base]"
    echo ""
    echo "Arguments:"
    echo "  <input_stream_dir> : Directory containing input .stream files"
    echo "  <symmetry>         : Symmetry argument for partialator (e.g., p1, c2mm)"
    echo "  <num_cores>        : Number of CPU cores to request for each job (e.g., 4, 8)"
    echo "  [output_dir_base]  : (Optional) Base directory for output .hkl files. Default: $DEFAULT_OUTPUT_DIR_BASE"
    echo "  [log_dir_base]     : (Optional) Base directory for all logs. Default: $DEFAULT_LOG_DIR_BASE"
    echo ""
    echo "Example:"
    echo "  $0 ./my_streams p1 8 ./results/hkl ./results/logs"
}

err_msg() {
    echo "[ERROR] $@" >&2
}

# --- Argument Parsing & Validation ---
if [ "$#" -lt 3 ] || [ "$#" -gt 5 ]; then
    usage
    exit 1
fi

INPUT_STREAM_DIR="$1"
SYMMETRY="$2"
NUM_CORES="$3"
OUTPUT_DIR_BASE="${4:-$DEFAULT_OUTPUT_DIR_BASE}"
LOG_DIR_BASE="${5:-$DEFAULT_LOG_DIR_BASE}"

if [ $DEBUG -eq 1 ]; then
    echo "[DEBUG] --- Input Parameters ---"
    echo "[DEBUG] Input Stream Directory: $INPUT_STREAM_DIR"
    echo "[DEBUG] Symmetry            : $SYMMETRY"
    echo "[DEBUG] Number of Cores     : $NUM_CORES"
    echo "[DEBUG] Output Directory Base: $OUTPUT_DIR_BASE"
    echo "[DEBUG] Log Directory Base    : $LOG_DIR_BASE"
    echo "[DEBUG] ------------------------"
fi

if [ ! -d "$INPUT_STREAM_DIR" ]; then
    err_msg "Input stream directory not found: '$INPUT_STREAM_DIR'"
    usage
    exit 1
fi
if ! [[ "$NUM_CORES" =~ ^[0-9]+$ ]] || [ "$NUM_CORES" -le 0 ]; then
    err_msg "Number of cores must be a positive integer. Got: '$NUM_CORES'"
    usage
    exit 1
fi

# --- Directory Setup ---
# Get absolute path of the directory where this script is located
PROCDIR=$(realpath "$(dirname "$0")")

# Resolve absolute paths for output and log directories
ABS_OUTPUT_DIR_BASE=$(realpath -m "$OUTPUT_DIR_BASE") # -m: no error if path doesn't exist yet
ABS_LOG_DIR_BASE=$(realpath -m "$LOG_DIR_BASE")

mkdir -p "$ABS_OUTPUT_DIR_BASE"
mkdir -p "$ABS_LOG_DIR_BASE"

CONDOR_SYSTEM_LOG_SUBDIR="condor_job_logs" # Subdirectory for HTCondor's own logs
mkdir -p "${ABS_LOG_DIR_BASE}/${CONDOR_SYSTEM_LOG_SUBDIR}"

echo "[INFO] Output .hkl files will be saved under: $ABS_OUTPUT_DIR_BASE"
echo "[INFO] Partialator-specific logs (from executor script) will be under: $ABS_LOG_DIR_BASE"
echo "[INFO] HTCondor system logs for each job will be under: ${ABS_LOG_DIR_BASE}/${CONDOR_SYSTEM_LOG_SUBDIR}"

# --- Path to Executable Script ---
EXECUTABLE_SCRIPT_NAME="CrystFEL_partialator_executor.sh" # Renamed for clarity
ABS_EXECUTABLE_PATH="${PROCDIR}/${EXECUTABLE_SCRIPT_NAME}"

if [ ! -f "$ABS_EXECUTABLE_PATH" ]; then
    err_msg "Executable script '$EXECUTABLE_SCRIPT_NAME' not found in '$PROCDIR'."
    exit 1
fi
if [ ! -x "$ABS_EXECUTABLE_PATH" ]; then
    err_msg "Executable script '$ABS_EXECUTABLE_PATH' does not have execute permissions."
    exit 1
fi

# --- 1. Generate list of stream files ---
ABS_INPUT_STREAM_DIR=$(realpath "$INPUT_STREAM_DIR")
TEMP_STREAM_LIST_PATH="${PROCDIR}/${TEMP_STREAM_LIST_FILENAME}"

echo "[INFO] Generating list of stream files from: $ABS_INPUT_STREAM_DIR"
find "$ABS_INPUT_STREAM_DIR" -type f -name "*.stream" > "$TEMP_STREAM_LIST_PATH"

if [ ! -s "$TEMP_STREAM_LIST_PATH" ]; then
    err_msg "No .stream files found in '$ABS_INPUT_STREAM_DIR'. Cannot submit jobs."
    rm -f "$TEMP_STREAM_LIST_PATH" # Clean up temp file
    exit 1
fi
if [ $DEBUG -eq 1 ]; then
    echo "[DEBUG] Temporary stream file list created: $TEMP_STREAM_LIST_PATH"
    echo "[DEBUG] Content of stream list:"
    cat "$TEMP_STREAM_LIST_PATH"
fi

# --- 2. Submit HTCondor Job for each stream file ---
echo "[INFO] Submitting HTCondor jobs for each stream file..."
JOB_COUNT=0
SUCCESS_COUNT=0
FAILURE_COUNT=0

while IFS= read -r SINGLE_STREAM_FILE_PATH; do
    SINGLE_STREAM_FILE_PATH=$(echo "$SINGLE_STREAM_FILE_PATH" | awk '{$1=$1};1') # Trim whitespace
    [[ -z "$SINGLE_STREAM_FILE_PATH" ]] && continue # Skip empty lines

    STREAM_BASENAME=$(basename "$SINGLE_STREAM_FILE_PATH" .stream)
    # Sanitize basename for use in log file names (replace non-alphanumeric/dot/hyphen with underscore)
    SANITIZED_STREAM_BASENAME=$(echo "$STREAM_BASENAME" | tr -cs 'a-zA-Z0-9_.-' '_')

    JOB_COUNT=$((JOB_COUNT + 1))
    if [ $DEBUG -eq 1 ]; then
        echo "[DEBUG] Preparing job ${JOB_COUNT} for stream file: $SINGLE_STREAM_FILE_PATH"
    fi

    # Define HTCondor log file paths for this specific job
    CONDOR_OUT_LOG="${ABS_LOG_DIR_BASE}/${CONDOR_SYSTEM_LOG_SUBDIR}/${SANITIZED_STREAM_BASENAME}.condor.out"
    CONDOR_ERR_LOG="${ABS_LOG_DIR_BASE}/${CONDOR_SYSTEM_LOG_SUBDIR}/${SANITIZED_STREAM_BASENAME}.condor.err"
    CONDOR_LOG_FILE="${ABS_LOG_DIR_BASE}/${CONDOR_SYSTEM_LOG_SUBDIR}/${SANITIZED_STREAM_BASENAME}.condor.log"

    # Submit job using a "here document", similar to 2_submit_condor_indexing.sh
    # Capture stdout and stderr of condor_submit for logging, but rely on exit code.
    submission_output_for_log=$(condor_submit - <<EOF 2>&1
# HTCondor Submission File for: ${SINGLE_STREAM_FILE_PATH}
# Generated by: $0

universe                = vanilla
executable              = ${ABS_EXECUTABLE_PATH}
arguments               = "${SINGLE_STREAM_FILE_PATH} ${SYMMETRY} ${NUM_CORES} ${ABS_OUTPUT_DIR_BASE} ${ABS_LOG_DIR_BASE}"

should_transfer_files   = YES
transfer_input_files    = ${ABS_EXECUTABLE_PATH}
# Stream files are accessed via absolute paths on a shared filesystem (assumed).

output                  = ${CONDOR_OUT_LOG}
error                   = ${CONDOR_ERR_LOG}
log                     = ${CONDOR_LOG_FILE}

request_cpus            = ${NUM_CORES}
request_memory          = ${DEFAULT_REQUEST_MEMORY}
request_disk            = ${DEFAULT_REQUEST_DISK}

# requirements            = (OpSys == "LINUX" && Arch == "X86_64")
# getenv                  = True # If executor needs full submission environment

queue 1
EOF
)
    submission_exit_code=$?

    if [ $submission_exit_code -eq 0 ]; then
        cluster_id_msg=""
        # Try to extract Cluster ID from the condor_submit output
        if echo "$submission_output_for_log" | grep -q "job(s) submitted to cluster"; then
            cluster_id_line=$(echo "$submission_output_for_log" | grep "job(s) submitted to cluster")
            num_jobs_submitted=$(echo "$cluster_id_line" | awk '{print $1}')
            cluster_id=$(echo "$cluster_id_line" | sed -n 's/.*cluster //p' | sed 's/\.$//')
            cluster_id_msg=" ($num_jobs_submitted job(s), Cluster ID: ${cluster_id:-N/A})"
        elif echo "$submission_output_for_log" | grep -q "ClusterId = "; then # Fallback for ClassAd output
             cluster_id=$(echo "$submission_output_for_log" | grep "ClusterId = " | head -n 1 | awk '{print $3}')
             cluster_id_msg=" (Cluster ID from Ad: ${cluster_id:-N/A})"
        fi
        echo "[SUCCESS] Job ${JOB_COUNT} for $SINGLE_STREAM_FILE_PATH submitted.${cluster_id_msg}"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
        echo "[ERROR] Failed to submit job ${JOB_COUNT} for $SINGLE_STREAM_FILE_PATH. Exit code: $submission_exit_code"
        if [ $DEBUG -eq 1 ]; then # Show full output only in debug mode
            echo "[DEBUG] Submission output (stdout & stderr):"
            echo "$submission_output_for_log"
        else
            echo "[ERROR] Enable DEBUG=1 for full submission output."
        fi
        FAILURE_COUNT=$((FAILURE_COUNT + 1))
    fi

done < "$TEMP_STREAM_LIST_PATH"

# Clean up the temporary stream list file
rm -f "$TEMP_STREAM_LIST_PATH"
if [ $DEBUG -eq 1 ]; then
    echo "[DEBUG] Temporary stream file list '$TEMP_STREAM_LIST_PATH' removed."
fi

echo ""
echo "[INFO] --- Submission Summary ---"
echo "[INFO] Total stream files processed for submission: $JOB_COUNT"
echo "[INFO] Successfully submitted jobs              : $SUCCESS_COUNT"
echo "[INFO] Failed submissions                       : $FAILURE_COUNT"

if [ "$FAILURE_COUNT" -gt 0 ]; then
    echo "[WARNING] Some jobs failed to submit. Check the output messages above and HTCondor logs."
fi
if [ "$SUCCESS_COUNT" -eq 0 ] && [ "$JOB_COUNT" -gt 0 ]; then
    echo "[ERROR] No jobs were successfully submitted, though stream files were found."
    # exit 1 # Optionally exit with error if no jobs succeed
fi
if [ "$JOB_COUNT" -eq 0 ]; then # This case is handled earlier by exiting if no streams found.
    echo "[INFO] No stream files were found to process."
fi

echo ""
echo "[INFO] All processing attempts finished."
echo "[INFO] Check job status with: condor_q"
echo "[INFO] CrystFEL output .hkl files will be in: $ABS_OUTPUT_DIR_BASE (named as <stream_basename>.hkl)"
echo "[INFO] Partialator-specific logs (from executor) in: $ABS_LOG_DIR_BASE (named as <stream_basename>.out/err)"
echo "[INFO] HTCondor system logs for each job in: ${ABS_LOG_DIR_BASE}/${CONDOR_SYSTEM_LOG_SUBDIR}/"
echo "[INFO] Script finished."