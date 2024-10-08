#!/bin/bash

# Source error logging script
# NOTE: This path should be valid on your system; modify accordingly if needed.
source /usr/local/share/bluetooth_autoconnect/bin/error-logging/error-logging.sh

log_file="/var/log/bluetooth_autoconnect.log"
log_verbose=4

# Path to JSON file containing Bluetooth MAC addresses
DEVICE_JSON="/usr/local/share/bluetooth_autoconnect/bluetooth_devices.json"

# Array to track background monitoring processes
declare -A MONITOR_PIDS

# Variable to track termination requests
terminate_script=0

# Function to handle SIGINT and SIGTERM signals
handle_termination() {
  log_write 3 "Termination signal received. Stopping all monitoring processes..."
  terminate_script=1
  stop_all_monitors
  exit 0
}

# Trap to stop all monitoring processes and clean up on Ctrl+C or termination
trap handle_termination SIGINT SIGTERM

# Function to check if Bluetooth is powered on
check_bluetooth_power() {
  log_write 3 "Checking if Bluetooth is powered on"
  if bluetoothctl show | grep -q "Powered: yes"; then
    log_write 3 "Bluetooth is powered on"
    return 0
  else
    log_write 1 "Bluetooth is not powered on"
    return 1
  fi
}

# Function to power on Bluetooth if it's off
power_on_bluetooth() {
  log_write 3 "Powering on Bluetooth"
  if bluetoothctl power on; then
    log_write 3 "Bluetooth powered on successfully"
    return 0
  else
    log_write 1 "Failed to power on Bluetooth"
    return 1
  fi
}

# Function to retrieve MAC addresses from JSON file
read_devices_from_json() {
  if [ ! -f "$DEVICE_JSON" ]; then
    log_write 1 "Bluetooth devices JSON file not found at $DEVICE_JSON"
    exit 1
  fi

  DEVICE_MACS=$(jq -r '.devices[]' "$DEVICE_JSON")

  if [ -z "$DEVICE_MACS" ]; then
    log_write 1 "No devices found in JSON file"
    exit 1
  fi

  log_write 3 "Successfully read devices from JSON file"
}

# Function to check if the device is already connected
check_connected() {
  local device_mac=$1
  device_status=$(bluetoothctl info "$device_mac" | grep "Connected: yes")
  if [ -n "$device_status" ]; then
    log_write 3 "Device $device_mac is already connected"
    return 0
  else
    log_write 3 "Device $device_mac is not connected"
    return 1
  fi
}

# Function to scan for the device
scan_device() {
  local device_mac=$1
  log_write 3 "Scanning for device: $device_mac"
  scan_result=$(bluetoothctl devices | grep "$device_mac")

  if [ -n "$scan_result" ]; then
    log_write 3 "Device $device_mac found"
    return 0
  else
    log_write 1 "Device $device_mac not found during scan"
    return 1
  fi
}

# Function for connection timeout logic
wait_for_connection() {
  local device_mac=$1
  local timeout=$2
  local start_time current_time elapsed_time

  start_time=$(date +%s)

  while true; do
    # Check if device is connected
    if check_connected "$device_mac"; then
      return 0
    fi

    # Check for timeout
    current_time=$(date +%s)
    elapsed_time=$((current_time - start_time))
    if [ "$elapsed_time" -ge "$timeout" ]; then
      return 1
    fi

    sleep 1  # Wait before checking again
  done
}

# Function to connect to the device and wait for confirmation
connect_device() {
  local device_mac=$1
  local timeout=10  # Timeout duration (in seconds)

  log_write 3 "Attempting to connect to device: $device_mac"
  bluetoothctl connect "$device_mac" &

  # Use the wait_for_connection function for easier debugging and timeout control
  if wait_for_connection "$device_mac" "$timeout"; then
    log_write 3 "Successfully connected to device: $device_mac"
    return 0
  else
    log_write 1 "Timeout: Failed to connect to $device_mac within $timeout seconds."
    return 1
  fi
}

# Function to listen for disconnection events for each device in the background
monitor_device_events() {
  local device_mac=$1

  log_write 3 "Starting event monitoring for device: $device_mac"

  # Monitor events for the specific device using bluetoothctl in a background process
  bluetoothctl monitor | while read -r line; do
    if echo "$line" | grep -q "Device $device_mac Disconnected"; then
      log_write 1 "Device $device_mac disconnected"
    fi
  done &

  # Store the PID of the background process
  MONITOR_PIDS["$device_mac"]=$!
  log_write 3 "Monitoring process for device $device_mac started with PID ${MONITOR_PIDS[$device_mac]}"
}

# Function to stop monitoring processes
stop_all_monitors() {
  log_write 3 "Stopping all monitoring processes..."
  for device_mac in "${!MONITOR_PIDS[@]}"; do
    log_write 3 "Stopping monitor for device $device_mac with PID ${MONITOR_PIDS[$device_mac]}"
    kill "${MONITOR_PIDS[$device_mac]}" 2>/dev/null
    unset "MONITOR_PIDS[$device_mac]"
  done
}

# Function to process each device
process_device() {
  local device_mac=$1

  log_write 3 "Processing device: $device_mac"

  # Check if the device is already connected, and skip further logic if it is
  if check_connected "$device_mac"; then
    log_write 3 "Device $device_mac is already connected. Skipping further checks."
    return 0
  fi

  # If the device is not connected, scan for the device
  if scan_device "$device_mac"; then
    # If found, attempt to connect and wait for the event
    if connect_device "$device_mac"; then
      # Once connected, start event monitoring
      monitor_device_events "$device_mac"
    else
      log_write 1 "Failed to connect to $device_mac. Skipping to next device."
    fi
  else
    log_write 1 "Device $device_mac not found. Skipping connection attempt."
  fi
}

# Main loop to continuously check devices and handle events
main_loop() {
  while [ "$terminate_script" -eq 0 ]; do
    log_write 3 "Starting Bluetooth auto-connect cycle"

    # Check if Bluetooth is powered on before proceeding
    if ! check_bluetooth_power; then
      log_write 1 "Bluetooth is not powered on. Attempting to power it on..."
      if ! power_on_bluetooth; then
        log_write 1 "Failed to power on Bluetooth. Retrying in 5 seconds..."
        sleep 5
        continue
      fi
    fi

    # Read devices from the JSON file
    read_devices_from_json

    # Iterate over each MAC address
    for DEVICE_MAC in $DEVICE_MACS; do
      # Break the loop immediately if termination signal is received
      if [ "$terminate_script" -eq 1 ]; then
        break
      fi
      process_device "$DEVICE_MAC"
    done

    log_write 3 "Bluetooth auto-connect cycle complete. Waiting 5 seconds before next cycle..."
    
    # Wait for 5 seconds before running the cycle again
    sleep 5
  done
}

# Start the main loop
main_loop
