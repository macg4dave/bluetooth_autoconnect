#!/bin/bash
# Enhanced error-logging script

# Default settings
log_verbose=1  # Only ERROR messages by default
log_file="./default.log"

# Function to define log level names
define_level_names() {
    if declare -A test_array >/dev/null 2>&1; then
        # Associative arrays supported
        declare -g -A level_names=(
            [1]="ERROR"
            [2]="NORMAL"
            [3]="INFO"
            [4]="DEBUG"
        )
    else
        # Associative arrays not supported; use indexed array
        level_names=("UNKNOWN" "ERROR" "NORMAL" "INFO" "DEBUG")
    fi
}

# Function to check and create log file path
log_create_path() {
    local log_file=$1
    local dir
    dir=$(dirname "$log_file")
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir" || {
            echo "Failed to create directory: $dir" >&2
            return 1  # Return failure if directory creation fails
        }
    fi
    return 0  # Return success if directory exists or was created successfully
}

# Function to write log
log_write() {
    local level=$1
    local message=$2
    local datetime
    datetime=$(date +'%Y-%m-%d %H:%M:%S')

    # Get the log level name
    local log_level_name="${level_names[$level]}"
    local formatted_message="$datetime - $log_level_name: $message"

    echo "Debug: Level=$level, Verbosity=$log_verbose"  # Debugging output

    # Write log if current level is within the verbosity level
    if [[ $level -le $log_verbose ]]; then
        if log_create_path "$log_file"; then
            # Append the formatted message as a new line to the log file
            echo "$formatted_message" >> "$log_file"
            echo "$formatted_message"  # Optionally echo to console as well
            return 0
        else
            echo "Failed to write log, directory creation failed." >&2
            return 1
        fi
    else
        echo "Log level $level is not within verbosity setting $log_verbose: $message" >&2
        return 1
    fi
}

# Call the function to define log level names
define_level_names

# Export log functions for sourcing
export -f log_write log_create_path
