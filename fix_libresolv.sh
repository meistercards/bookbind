#!/bin/bash
# Quick fix for missing libresolv.so.2 library
# This library was accidentally excluded during installation

set -e

echo "🔧 Fixing missing libresolv.so.2 library..."

# Check if the library is actually missing
if ldconfig -p | grep -q "libresolv.so.2"; then
    echo "✅ libresolv.so.2 is already available"
    exit 0
fi

echo "❌ libresolv.so.2 is missing, fixing..."

# Method 1: Copy from host system (if we're running the fix from host)
if [[ -f "/lib/x86_64-linux-gnu/libresolv.so.2" ]]; then
    echo "📋 Found libresolv.so.2 on host system, copying to target..."
    
    # Find the target mount point (if we're fixing from host)
    TARGET_MOUNT=$(mount | grep ThymeOS | awk '{print $3}' | head -1)
    if [[ -n "$TARGET_MOUNT" ]]; then
        echo "📁 Target mount point: $TARGET_MOUNT"
        sudo cp /lib/x86_64-linux-gnu/libresolv.so* "$TARGET_MOUNT/lib/x86_64-linux-gnu/"
        sudo chroot "$TARGET_MOUNT" ldconfig
        echo "✅ libresolv.so.2 copied and configured"
    else
        echo "❌ Target system not mounted, please mount ThymeOS partition first"
        exit 1
    fi
    
# Method 2: Install from packages (if running on target system)
elif command -v apt &>/dev/null; then
    echo "📦 Installing libc6 to restore libresolv.so.2..."
    sudo apt update
    sudo apt install --reinstall libc6
    sudo ldconfig
    echo "✅ libresolv.so.2 restored via package installation"
    
# Method 3: Create symlink if libresolv exists but symlink is missing
else
    echo "🔍 Looking for existing libresolv libraries..."
    LIBRESOLV_PATH=$(find /lib* /usr/lib* -name "libresolv.so*" -type f 2>/dev/null | head -1)
    
    if [[ -n "$LIBRESOLV_PATH" ]]; then
        echo "📁 Found libresolv at: $LIBRESOLV_PATH"
        LIB_DIR=$(dirname "$LIBRESOLV_PATH")
        
        # Create symlink
        sudo ln -sf "$(basename "$LIBRESOLV_PATH")" "$LIB_DIR/libresolv.so.2"
        sudo ldconfig
        echo "✅ libresolv.so.2 symlink created"
    else
        echo "❌ No libresolv library found, need to copy from host system"
        exit 1
    fi
fi

# Verify the fix
if ldconfig -p | grep -q "libresolv.so.2"; then
    echo "✅ Fix successful! libresolv.so.2 is now available:"
    ldconfig -p | grep libresolv
else
    echo "❌ Fix failed, library still not found"
    exit 1
fi

echo
echo "🎉 libresolv.so.2 fix completed!"
echo "You can now test thyme-edit and other applications."