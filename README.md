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

crystfel_partialator_htcondor/
├── CrystFEL_partialator.sh        # Execution script for HTCondor jobs
├── submit_partialator_htcondor.sh # Main job submission script
├── file_stream/                     # EXAMPLE: Place your input .stream files here
│   ├── run001_chunk001.stream
│   └── run001_chunk002.stream
├── output_hkl/                      # DEFAULT: Output .hkl files (created automatically)
├── logs_partialator_multi/          # DEFAULT: All logs (created automatically)
│   ├── condor_job_logs/             # HTCondor system logs per job (created automatically)
│   │   ├── run001_chunk001.condor.out
│   │   ├── run001_chunk001.condor.err
│   │   └── run001_chunk001.condor.log
│   ├── run001_chunk001.out          # Stdout from CrystFEL_partialator.sh
│   └── run001_chunk001.err          # Stderr from CrystFEL_partialator.sh
└── README.md                        # This file

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
./submit_partialator_htcondor.sh ./my_experiment/stream_files p1 8 ./my_experiment/hkl_output ./my_experiment/all_logs
