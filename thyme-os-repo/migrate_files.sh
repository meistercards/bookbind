#!/bin/bash
# Thyme OS Repository File Migration Script

set -e

echo "🔄 Copying development files to repository structure..."

# Copy files according to mapping
# Note: Update these paths based on your actual development directory structure

REPO_ROOT="thyme-os-repo"
DEV_ROOT="."

# Function to copy file if it exists
copy_if_exists() {
    local src="$1"
    local dst="$2"
    
    if [ -f "$DEV_ROOT/$src" ]; then
        cp "$DEV_ROOT/$src" "$REPO_ROOT/$dst"
        echo "✅ Copied $src -> $dst"
    else
        echo "⚠️  Source file not found: $src"
    fi
}

# Copy all mapped files
copy_if_exists "installer_override.py" "bootstrap/ssd_swap/installer_override.py"
copy_if_exists "macos_grub_installer.sh" "bootstrap/macos_installer/macos_grub_installer.sh"
copy_if_exists "network_installer.py" "bootstrap/network/network_installer.py"
# ... (add all other file mappings)

echo "✅ Repository file migration complete"
echo "🔍 Review the copied files and commit to initialize the repository"
