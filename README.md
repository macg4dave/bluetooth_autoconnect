
# Bluetooth Auto-Connect Script

## Overview

This script automatically manages the connection of Bluetooth devices on a Linux system using `bluetoothctl`. It continuously checks for paired devices, connects to them if they are not already connected, and monitors the connection status. If a device disconnects, the script will log the event and attempt to reconnect when appropriate.

### Features
- Automatically connect paired Bluetooth devices on system startup.
- Monitor and reconnect devices if they get disconnected.
- Timeout logic for handling connection attempts.
- Gracefully handle termination signals (`Ctrl+C` or `SIGTERM`).
- Integrated logging for debugging and status tracking.

## Requirements

- **Linux system** with `systemd`.
- **BlueZ** Bluetooth stack installed (`bluetoothctl`).
- **jq** for parsing JSON (used for managing device list).
  
To install these on Debian/Ubuntu-based systems, run:

```bash
sudo apt-get install bluez jq```

## Pre-Requisites: Pairing and Trusting Devices
Before using the script, ensure that the Bluetooth devices you want to auto-connect are paired and trusted. You can do this using `bluetoothctl`:

1. Start `bluetoothctl`:

'''bash
bluetoothctl
'''

2. Turn on the Bluetooth agent and scan for devices:

'''bash
agent on
scan on
'''

3. Once the device is found (e.g., `82:BA:BE:67:DE:D2`), pair and trust it:

'''bash
pair 82:BA:BE:67:DE:D2
trust 82:BA:BE:67:DE:D2
'''

4. Confirm that the device is paired and trusted:

'''bash
info 82:BA:BE:67:DE:D2
'''

## Script Installation

### Step 1: Clone the Repository
Clone the repository to your local machine:

'''bash
git clone https://github.com/yourusername/bluetooth-autoconnect.git
cd bluetooth-autoconnect
'''

### Step 2: Configure the Bluetooth Devices
Create or modify the `bluetooth_devices.json` file located in `/usr/local/share/bluetooth_autoconnect/bluetooth_devices.json`. Add the MAC addresses of the Bluetooth devices you want to auto-connect:

'''json
{
  "devices": [
    "82:BA:BE:67:DE:D2",
    "XX:XX:XX:XX:XX:XX"
  ]
}
'''

### Step 3: Make the Script Executable
Ensure the script is executable:

'''bash
chmod +x /usr/local/share/bluetooth_autoconnect/bin/auto_connect_bluetooth.sh
'''

## Systemd Service Setup

### Step 1: Create the Systemd Service File
To ensure the script starts automatically after the system boots, create a systemd service file:

'''bash
sudo nano /etc/systemd/system/bluetooth-autoconnect.service
'''

Paste the following content into the file:

'''ini
[Unit]
Description=Bluetooth Auto-Connect Service
After=multi-user.target

[Service]
ExecStart=/usr/local/share/bluetooth_autoconnect/bin/auto_connect_bluetooth.sh
Restart=on-failure
User=root

[Install]
WantedBy=multi-user.target
'''

### Step 2: Enable and Start the Service
Reload the systemd manager configuration, then enable and start the service:

'''bash
sudo systemctl daemon-reload
sudo systemctl enable bluetooth-autoconnect.service
sudo systemctl start bluetooth-autoconnect.service
'''

### Step 3: Check the Service Status
You can check if the service is running properly with:

'''bash
sudo systemctl status bluetooth-autoconnect.service
'''

## Usage

Once the system boots or the service is started manually, the script will continuously monitor and attempt to connect to the Bluetooth devices listed in the `bluetooth_devices.json` file.

To stop the service:

'''bash
sudo systemctl stop bluetooth-autoconnect.service
'''

To disable the service from starting on boot:

'''bash
sudo systemctl disable bluetooth-autoconnect.service
'''

## Troubleshooting

- **Failed to connect errors**: If you encounter `org.bluez.Error.Failed` or connection timeouts, ensure that:
  - The devices are within range.
  - Bluetooth on the system is powered on.
  - The devices are paired and trusted.
  
- **Logs**: Check the logs for detailed error messages or status updates:
  
  '''bash
  journalctl -u bluetooth-autoconnect.service
  '''

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for more details.
