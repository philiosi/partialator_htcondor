# CrystFEL Partialator HTCondor Submission Scripts

This project provides a set of scripts to run CrystFEL's `partialator` on multiple `.stream` files using HTCondor, where each stream file is processed as an individual HTCondor job.

## Scripts

1.  **`CrystFEL_partialator.sh`**:
    * This script is executed by each HTCondor job.
    * It takes a single `.stream` file path as an argument, along with symmetry, number of cores, and base output/log directories.
    * It sources the CrystFEL environment (specifically `/pal/lib/setup_crystfel-0.9.1_hdf5-1.10.5.sh`) and adds `/pal/htcondor/lib` to `LD_LIBRARY_PATH`.
    * Runs `partialator` on the given stream file.
    * Outputs `.hkl` file to `<output_dir_base>/<stream_basename>.hkl`.
    * Writes `partialator`'s stdout and stderr to `<log_dir_base>/<stream_basename>.out` and `<log_dir_base>/<stream_basename>.err` respectively.

2.  **`submit_partialator_htcondor.sh`**:
    * The main submission script to be run by the user.
    * Scans an input directory for `.stream` files.
    * For each `.stream` file found, it submits an HTCondor job that will execute `CrystFEL_partialator.sh`.
    * Creates base output and log directories if they don't exist.
    * HTCondor's own log files for each job (e.g., `job.condor.out`, `job.condor.err`, `job.condor.log`) are stored in a subdirectory `<log_dir_base>/condor_job_logs/`.

## Directory Structure
```
crystfel_partialator_htcondor/
├── CrystFEL_partialator.sh
├── submit_partialator_htcondor.sh
├── file_stream/
│   ├── example1.stream
│   └── example2.stream
├── output_hkl/
├── logs_partialator_multi/
│   ├── condor_job_logs/
│   │   ├── example1.condor.out
│   │   └── example1.condor.err
│   └── example1.out
└── README.md
```
## Prerequisites

* HTCondor environment configured and accessible.
* CrystFEL installed and the environment setup script (`/pal/lib/setup_crystfel-0.9.1_hdf5-1.10.5.sh`) available on HTCondor worker nodes.
* Shared filesystem between the submission node and worker nodes, so that stream files (accessed via absolute paths) and the executable script are accessible.

## Usage

1.  Place `CrystFEL_partialator.sh` and `submit_partialator_htcondor.sh` in the same directory.
2.  Make them executable:
    ```bash
    chmod +x CrystFEL_partialator.sh
    chmod +x submit_partialator_htcondor.sh
    ```
3.  Run the submission script:
    ```bash
    ./submit_partialator_htcondor.sh <input_stream_dir> <symmetry> <num_cores> [output_dir_base] [log_dir_base]
    ```
    * `<input_stream_dir>`: Directory containing your input `.stream` files.
    * `<symmetry>`: Symmetry argument for `partialator` (e.g., `p1`, `c2mm`).
    * `<num_cores>`: Number of CPU cores to request for each `partialator` job.
    * `[output_dir_base]` (Optional): Base directory where `.hkl` files will be stored. Defaults to `output_hkl`.
    * `[log_dir_base]` (Optional): Base directory for all logs. Defaults to `logs_partialator_multi`.

**Example:**

```bash
# Create a directory for your input stream files
mkdir -p ./my_experiment/stream_files
# (Copy your .stream files into ./my_experiment/stream_files)

# Submit jobs
./submit_partialator_htcondor.sh <input_stream_dir> <symmetry> <num_cores> [output_dir_base] [log_dir_base]
./submit_partialator_htcondor.sh ./my_experiment/stream_files p1 72 ./my_experiment/hkl_output ./my_experiment/all_logs
```

## Understanding Variables in the Scripts

### Variables in `CrystFEL_partialator_executor.sh`

This script uses variables to manage file paths, script arguments, and environment settings.

*   **Script Arguments:** When `CrystFEL_partialator_executor.sh` is run (typically by an HTCondor job), it receives five arguments. These are assigned to the following variables at the beginning of the script:
    *   `STREAM_FILE_PATH`: The absolute path to the input `.stream` file to be processed. (From `$1`)
    *   `SYMMETRY`: The symmetry argument required by the `partialator` command (e.g., `p1`, `c2mm`). (From `$2`)
    *   `NUM_CORES`: The number of CPU cores allocated for the `partialator` job. (From `$3`)
    *   `OUTPUT_DIR_BASE`: The base directory where the output `.hkl` file will be saved. (From `$4`)
    *   `LOG_DIR_BASE`: The base directory where `partialator`'s own log files (stdout and stderr for this specific stream) will be stored. (From `$5`)

*   **Key Internal Variables:**
    *   `SETUP_SCRIPT`: Defines the path to the CrystFEL environment setup script (e.g., `/pal/lib/setup_crystfel-0.9.1_hdf5-1.10.5.sh`). This script is sourced to initialize the necessary environment for `partialator`.
    *   `BASENAME`: Derived from `STREAM_FILE_PATH` (e.g., if `STREAM_FILE_PATH` is `/data/run1/my.stream`, `BASENAME` becomes `my`). This is used to create unique names for output and log files.
    *   `OUTPUT_HKL_FILE`: The full path for the output `.hkl` file, constructed as `${OUTPUT_DIR_BASE}/${BASENAME}.hkl`.
    *   `LOG_STDOUT_PARTIALATOR`: The full path for the file that captures `partialator`'s standard output, constructed as `${LOG_DIR_BASE}/${BASENAME}.out`.
    *   `LOG_STDERR_PARTIALATOR`: The full path for the file that captures `partialator`'s standard error, constructed as `${LOG_DIR_BASE}/${BASENAME}.err`.
    *   `EXIT_STATUS`: Stores the exit code of the `partialator` command to determine if it ran successfully.

*   **Environment Variables:**
    *   `LD_LIBRARY_PATH`: This standard Linux environment variable is appended with `/pal/htcondor/lib` if it's not already present. This ensures that necessary shared libraries for the HTCondor environment are found.

Understanding these variables can be helpful if you need to debug the script's execution or trace how file paths are constructed.

### Variables in `submit_partialator_htcondor.sh`

This script manages the submission of multiple jobs to HTCondor. It uses variables for configuration, path management, and looping through stream files.

*   **Script Arguments:** The script accepts three mandatory and two optional arguments:
    *   `INPUT_STREAM_DIR`: Directory containing the input `.stream` files. (From `$1`)
    *   `SYMMETRY`: Symmetry argument for `partialator`. (From `$2`)
    *   `NUM_CORES`: Number of CPU cores for each job. (From `$3`)
    *   `OUTPUT_DIR_BASE`: (Optional) Base directory for output `.hkl` files. If not provided, it defaults to the value of `DEFAULT_OUTPUT_DIR_BASE` (which is `output_hkl` in the script). This is achieved using shell parameter expansion: `OUTPUT_DIR_BASE="${4:-$DEFAULT_OUTPUT_DIR_BASE}"`. (From `$4`)
    *   `LOG_DIR_BASE`: (Optional) Base directory for all logs. Defaults to `DEFAULT_LOG_DIR_BASE` (which is `logs_partialator_condor`). Uses the same default value mechanism: `LOG_DIR_BASE="${5:-$DEFAULT_LOG_DIR_BASE}"`. (From `$5`)

*   **Default Configuration Variables:**
    *   `DEFAULT_OUTPUT_DIR_BASE`: Stores the default name for the base output directory (`output_hkl`).
    *   `DEFAULT_LOG_DIR_BASE`: Stores the default name for the base log directory (`logs_partialator_condor`).
    *   `DEFAULT_REQUEST_MEMORY`, `DEFAULT_REQUEST_DISK`: Define default memory and disk requests for HTCondor jobs.
    *   `TEMP_STREAM_LIST_FILENAME`: Name for a temporary file that lists all found `.stream` files.

*   **Path and File Management Variables:**
    *   `PROCDIR`: Stores the absolute path of the directory where `submit_partialator_htcondor.sh` itself is located. This is determined using `realpath "$(dirname "$0")"`.
    *   `ABS_OUTPUT_DIR_BASE`, `ABS_LOG_DIR_BASE`: Store the absolute paths for the output and log directories, resolved using `realpath -m`. This ensures consistent path understanding, even if relative paths are given as input.
    *   `CONDOR_SYSTEM_LOG_SUBDIR`: Defines the name of the subdirectory (`condor_job_logs`) within `ABS_LOG_DIR_BASE` where HTCondor's own log files for each job (e.g., `.condor.out`, `.condor.err`) are stored.
    *   `EXECUTABLE_SCRIPT_NAME`: The name of the executor script (`CrystFEL_partialator_executor.sh`).
    *   `ABS_EXECUTABLE_PATH`: The absolute path to the `CrystFEL_partialator_executor.sh` script, constructed as `${PROCDIR}/${EXECUTABLE_SCRIPT_NAME}`. This is passed to HTCondor.
    *   `ABS_INPUT_STREAM_DIR`: The absolute path of the input stream directory.
    *   `TEMP_STREAM_LIST_PATH`: The full path to the temporary file listing all stream files, created within `PROCDIR`.

*   **Loop and Submission Variables (within the `while` loop that processes each stream file):**
    *   `SINGLE_STREAM_FILE_PATH`: In each iteration of the loop, this variable holds the path to one `.stream` file read from `TEMP_STREAM_LIST_PATH`.
    *   `STREAM_BASENAME`: The base name of the current `.stream` file (e.g., `my_stream` from `my_stream.stream`).
    *   `SANITIZED_STREAM_BASENAME`: The `STREAM_BASENAME` sanitized to replace characters that might be problematic in filenames (non-alphanumeric, dot, or hyphen are replaced with underscores). This is used for naming HTCondor's specific log files.
    *   `CONDOR_OUT_LOG`, `CONDOR_ERR_LOG`, `CONDOR_LOG_FILE`: Full paths for the HTCondor output, error, and log files for the specific job being submitted. These are constructed using `ABS_LOG_DIR_BASE`, `CONDOR_SYSTEM_LOG_SUBDIR`, and `SANITIZED_STREAM_BASENAME`.
    *   `submission_output_for_log`, `submission_exit_code`: Capture the output and exit status of the `condor_submit` command for logging and error checking.

*   **Debugging Variable:**
    *   `DEBUG`: Set to `1` at the top of the script to enable more verbose output, which can be helpful for diagnosing issues with the submission process. Defaults to `0` (off).

*   **Counter Variables:**
    *   `JOB_COUNT`, `SUCCESS_COUNT`, `FAILURE_COUNT`: Used to track the number of jobs processed, successfully submitted, and failed submissions, respectively. A summary is printed at the end.

These variables are crucial for the script's ability to find stream files, construct paths correctly, submit jobs to HTCondor, and manage logging.

### A Note on Variable Scope

In these shell scripts (`CrystFEL_partialator_executor.sh` and `submit_partialator_htcondor.sh`), variables are generally "global" within the script where they are defined. This means that once a variable is set, it can be accessed and modified from anywhere else within that same script. These scripts do not use shell functions with the `local` keyword, which would otherwise create variables with a more limited scope (i.e., only accessible within that specific function).
