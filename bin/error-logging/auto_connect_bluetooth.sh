#!/bin/bash

# Source error logging script
source /usr/local/share/bluetooth_autoconnect/bin/error-logging/error-logging.sh

log_file="/var/log/bluetooth_autoconnect.log"
log_verbose=4

# Path to JSON file containing Bluetooth MAC addresses
DEVICE_JSON="/usr/local/share/bluetooth_autoconnect/bluetooth_devices.json"

# Array to track background monitoring processes
declare -A MONITOR_PIDS

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

# Function to connect to the device
connect_device() {
  local device_mac=$1
  log_write 3 "Attempting to connect to device: $device_mac"
  bluetoothctl connect "$device_mac"
  if [ $? -eq 0 ]; then
    log_write 3 "Successfully connected to device: $device_mac"
    return 0
  else
    log_write 1 "Failed to connect to device: $device_mac"
    return 1
  fi
}

# Function to listen for disconnection events for each device in the background
monitor_device_events() {
  local device_mac=$1

  log_write 3 "Starting event monitoring for device: $device_mac"

  # Monitor events for the specific device using bluetoothctl in a background process
  bluetoothctl monitor | while read line; do
    if echo "$line" | grep -q "Device $device_mac Disconnected"; then
      log_write 2 "Device $device_mac disconnected"
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
    unset MONITOR_PIDS["$device_mac"]
  done
}

# Function to process each device
process_device() {
  local device_mac=$1

  log_write 3 "Processing device: $device_mac"

  # Check if the device is already connected
  if check_connected "$device_mac"; then
    log_write 3 "Device $device_mac is already connected. Starting event monitoring."
    monitor_device_events "$device_mac"
  else
    # If the device is not connected, scan for the device
    if scan_device "$device_mac"; then
      # If found, attempt to connect
      if connect_device "$device_mac"; then
        # Once connected, start event monitoring
        monitor_device_events "$device_mac"
      else
        log_write 1 "Failed to connect to $device_mac. Skipping to next device."
      fi
    else
      log_write 1 "Device $device_mac not found. Skipping connection attempt."
    fi
  fi
}

# Main loop to continuously check devices and handle events
main_loop() {
  while true; do
    log_write 3 "Starting Bluetooth auto-connect cycle"

    # Read devices from the JSON file
    read_devices_from_json

    # Iterate over each MAC address
    for DEVICE_MAC in $DEVICE_MACS; do
      process_device "$DEVICE_MAC"
    done

    log_write 3 "Bluetooth auto-connect cycle complete. Waiting 5 seconds before next cycle..."
    
    # Wait for 5 seconds before running the cycle again
    sleep 5
  done
}

# Trap to stop all monitoring processes when the script is terminated
trap stop_all_monitors SIGINT SIGTERM

# Start the main loop
main_loop
