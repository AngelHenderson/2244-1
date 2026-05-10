#!/bin/bash
# Fix iOS Simulator audio by restarting macOS CoreAudio daemon.
# The daemon auto-respawns immediately — all Mac audio resumes within ~1 second.
# Run this whenever simulator audio stops working instead of restarting the simulator.
#
# Usage:  ./scripts/fix-sim-audio.sh

echo "🔄 Restarting CoreAudio daemon..."
sudo killall coreaudiod
echo "✅ CoreAudio restarted — simulator audio should work on next app launch."
echo "   (If the app is already running, rebuild and relaunch.)"
