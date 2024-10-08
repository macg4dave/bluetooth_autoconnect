<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body>
  <h1>Error Logging Script</h1>
  <p>A shell script for error logging, designed to log error messages and maintain log files efficiently.</p>

  <h2>Features</h2>
  <ul>
    <li>Checks if the log path exists, creates directories if needed</li>
    <li>Writes log entries with timestamps</li>
    <li>Supports different verbosity levels</li>
  </ul>

  <h2>Usage</h2>
  <pre><code>

# Source the script
source /path/to/error-logging.sh

# Set global verbose level
log_verbose=2 #This would show errors and normal messages

# Specify log file path
log_file="/path/to/logfile.log"

# Write log messages
log_write 1 "This is an ERROR message"
log_write 2 "This is a NORMAL message"
log_write 3 "This is an INFO message"
log_write 4 "This is an DEBUG message"
  </code></pre>

  <h2>License</h2>
  <p>MIT License</p>
</body>
</html>
