#!/bin/bash
set -e

CONFIG_FILE="/etc/amnezia/amneziawg/awg0.conf"

# Use environment variables
INTERFACE="${AMNEZIAWG_INTERFACE:-awg0}"

# Trap SIGTERM (Docker stop) or SIGINT, then bring down awg0
cleanup() {
    echo "Caught stop signal, bringing down $INTERFACE..."
    awg-quick down "$INTERFACE" || true
    pkill -f "^amneziawg-go ${INTERFACE}$" 2>/dev/null || true
    ip link del dev "$INTERFACE" 2>/dev/null || true
    exit 0
}
trap cleanup SIGTERM SIGINT

# Start the AmneziaWG interface
echo "Starting AmneziaWG interface: $INTERFACE..."
awg-quick up $INTERFACE

echo "All done!"

# Start tail in the background
tail -f /dev/null &
TAIL_PID=$!
# Wait in the shell foreground so it can receive signals
wait $TAIL_PID