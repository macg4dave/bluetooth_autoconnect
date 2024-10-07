#!/bin/bash

# Bluetooth device MAC address
DEVICE_MAC="82:BA:BE:67:DE:D2"

# Wait for Bluetooth service to be ready
sleep 2

# Turn Bluetooth on
bluetoothctl power on

# Set the device as trusted
bluetoothctl trust "$DEVICE_MAC"

# Connect to the device
bluetoothctl connect "$DEVICE_MAC"

# You can add more checks here, for example:
# if connection fails, you can retry or handle errors as needed
