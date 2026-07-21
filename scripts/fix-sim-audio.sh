#!/bin/bash
# Automatically fix iOS Simulator audio.
#
# Modes:
#   --auto    Called by LaunchAgent when marker file appears. Restarts the sim.
#   --check   Called from Xcode build phase. Checks for stale marker.
#   (none)    Manual mode. Restarts the booted simulator immediately.

MARKER="/private/tmp/sim-audio-broken"
LOG="/private/tmp/sim-audio-fix.log"

restart_simulator() {
    local UDID
    UDID=$(xcrun simctl list devices booted 2>/dev/null | grep -oE '[A-F0-9a-f-]{36}' | head -1)
    
    if [ -z "$UDID" ]; then
        echo "$(date): No booted simulator found" >> "$LOG"
        rm -f "$MARKER"
        return
    fi
    
    echo "$(date): Restarting simulator $UDID" >> "$LOG"
    xcrun simctl shutdown "$UDID" 2>/dev/null
    sleep 2
    xcrun simctl boot "$UDID" 2>/dev/null
    
    # Wait for boot
    for i in $(seq 1 10); do
        if xcrun simctl list devices booted 2>/dev/null | grep -q "$UDID"; then
            echo "$(date): ✅ Simulator $UDID rebooted — audio fixed" >> "$LOG"
            echo "✅ Simulator rebooted — rebuild (Cmd+R) to get audio back"
            break
        fi
        sleep 1
    done
    
    rm -f "$MARKER"
}

case "${1:-}" in
    --auto)
        # Called by LaunchAgent — wait a moment for the app to settle
        sleep 2
        if [ -f "$MARKER" ]; then
            echo "$(date): 🔄 LaunchAgent triggered — audio broken detected" >> "$LOG"
            restart_simulator
        fi
        ;;
    --check)
        # Called from Xcode build phase — check for stale marker from previous run
        if [ -f "$MARKER" ]; then
            if find "$MARKER" -mmin -120 2>/dev/null | grep -q .; then
                echo "$(date): 🔄 Build phase detected audio marker" >> "$LOG"
                restart_simulator
            else
                rm -f "$MARKER"
            fi
        fi
        ;;
    *)
        # Manual mode
        echo "🔄 Restarting booted simulator..."
        restart_simulator
        ;;
esac
