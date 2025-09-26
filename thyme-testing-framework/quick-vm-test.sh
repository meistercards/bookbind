#!/bin/bash
# Quick VM Test for Thyme OS
# Simplified testing script for immediate use

set -e

# Check if QEMU is installed
if ! command -v qemu-system-x86_64 &> /dev/null; then
    echo "Installing QEMU..."
    sudo apt update
    sudo apt install -y qemu-system-x86 qemu-utils
fi

# Create test directory
mkdir -p vm-test
cd vm-test

# Create a test disk
if [[ ! -f "thyme-test.qcow2" ]]; then
    echo "Creating test disk (4GB)..."
    qemu-img create -f qcow2 thyme-test.qcow2 4G
fi

# Test with our streamlined installer
echo "Starting VM test with streamlined installer..."
echo "This will test the installation process in a safe VM environment."

# Run the streamlined installer in test mode
cd ..
chmod +x thyme_streamlined_installer.sh

echo "🧪 Running Thyme OS Streamlined Installer in TEST MODE"
echo "This creates a test image instead of using real hardware."

# Run installer in test mode
sudo ./thyme_streamlined_installer.sh test

echo "✅ Test completed! Check the logs for results."