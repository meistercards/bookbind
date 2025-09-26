#!/bin/bash
# Keyboard Fix Script for Thyme OS
# Run this during boot if keyboard doesn't work

echo "🔧 Thyme OS Keyboard Fix"
echo "========================"

# Check keyboard device files
echo "Checking keyboard devices..."
ls -la /dev/input/ 2>/dev/null || echo "No input devices found"

# Try to reset keyboard
echo "Resetting keyboard..."
kbd_mode -u 2>/dev/null || echo "kbd_mode not available"
loadkeys us 2>/dev/null || echo "loadkeys not available"

# Load keyboard drivers
echo "Loading keyboard drivers..."
modprobe i8042 2>/dev/null || echo "i8042 module not available"
modprobe atkbd 2>/dev/null || echo "atkbd module not available"
modprobe usbhid 2>/dev/null || echo "usbhid module not available"
modprobe hid_apple 2>/dev/null || echo "hid_apple module not available"

# Check what's loaded
echo "Loaded modules:"
lsmod | grep -E "(i8042|atkbd|usbhid|hid_apple)" || echo "No keyboard modules loaded"

# Try different keyboard initialization
echo "Trying keyboard initialization..."
for i in /dev/input/event*; do
    if [ -e "$i" ]; then
        echo "Found input device: $i"
    fi
done

echo "Keyboard fix complete. Try typing now."