#!/bin/bash
# Fix simulator audio by restarting the simulator device.
# Called from Xcode build phase OR manually from terminal.
#
# Usage: ./scripts/fix-sim-audio.sh
#
# When called from build phase: checks for marker file, restarts sim if needed.
# When called manually: always restarts the booted simulator.

MARKER="/private/tmp/sim-audio-broken"
LOG="/private/tmp/sim-audio-fix.log"

# If called with --check flag (from build phase), only act if marker exists
if [ "$1" = "--check" ]; then
    if [ ! -f "$MARKER" ]; then
        exit 0  # No marker = audio was fine, nothing to do
    fi
    # Check marker is recent (less than 2 hours old)
    if ! find "$MARKER" -mmin -120 2>/dev/null | grep -q .; then
        rm -f "$MARKER"
        exit 0  # Stale marker, just clean up
    fi
    echo "🔄 Audio marker detected — restarting simulator..." | tee "$LOG"
fi

# Find the booted simulator
UDID=$(xcrun simctl list devices booted 2>/dev/null | grep -oE '[A-F0-9a-f-]{36}' | head -1)

if [ -z "$UDID" ]; then
    echo "⚠️ No booted simulator found" | tee -a "$LOG"
    rm -f "$MARKER"
    exit 0
fi

echo "📱 Restarting simulator: $UDID" | tee -a "$LOG"

# Shutdown
xcrun simctl shutdown "$UDID" 2>/dev/null
sleep 2

# Boot
xcrun simctl boot "$UDID" 2>/dev/null
sleep 2

# Wait for the simulator to be ready
for i in $(seq 1 10); do
    STATE=$(xcrun simctl list devices "$UDID" 2>/dev/null | grep "$UDID" | grep -o "Booted")
    if [ "$STATE" = "Booted" ]; then
        echo "✅ Simulator $UDID booted successfully" | tee -a "$LOG"
        break
    fi
    sleep 1
done

# Clean up marker
rm -f "$MARKER"
echo "🎵 Audio should work on next launch" | tee -a "$LOG"
