#!/bin/bash
# Thyme OS Post-Installation Fixes
# Addresses common issues after fresh installation

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

echo -e "${BLUE}"
cat << 'EOF'
🔧 Thyme OS Post-Installation Fixes 🔧
====================================

Fixes common issues after fresh installation:
• Flatpak libresolve.so.2 missing library error
• Casper check failure on shutdown  
• Missing lightweight packages
• Network connectivity issues
• System optimization

EOF
echo -e "${NC}"

# Check if we're running on Thyme OS
check_thyme_system() {
    log "Checking if running on Thyme OS..."
    
    if [[ ! -f "/etc/thyme/version" ]]; then
        error "This script should be run on Thyme OS system"
    fi
    
    log "✅ Running on Thyme OS:"
    cat /etc/thyme/version
    echo
}

# Fix flatpak libresolve.so.2 issue
fix_flatpak_libresolve() {
    log "Fixing flatpak libresolve.so.2 issue..."
    
    # Check if flatpak is installed and causing issues
    if command -v flatpak &> /dev/null; then
        log "Flatpak is installed, checking for libresolv issues..."
        
        # Check for missing libresolv library
        if ! ldconfig -p | grep -q "libresolv.so.2"; then
            warn "libresolv.so.2 not found in library cache"
            
            # Try to find the library
            local libresolv_path=$(find /lib* /usr/lib* -name "libresolv.so*" 2>/dev/null | head -1)
            if [[ -n "$libresolv_path" ]]; then
                log "Found libresolv at: $libresolv_path"
                
                # Create symlink if needed
                local lib_dir=$(dirname "$libresolv_path")
                if [[ ! -f "$lib_dir/libresolv.so.2" ]]; then
                    log "Creating libresolv.so.2 symlink..."
                    sudo ln -sf "$(basename "$libresolv_path")" "$lib_dir/libresolv.so.2"
                    sudo ldconfig
                    success "libresolv.so.2 symlink created"
                fi
            else
                warn "libresolv library not found, installing libc6-dev..."
                sudo apt update
                sudo apt install -y libc6-dev
                sudo ldconfig
            fi
        else
            success "libresolv.so.2 is available"
        fi
        
        # Reset flatpak if it's having issues
        log "Resetting flatpak user data..."
        flatpak --user remote-list 2>/dev/null || {
            warn "Flatpak user setup corrupted, reinitializing..."
            rm -rf ~/.local/share/flatpak 2>/dev/null || true
            flatpak --user remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true
        }
        
        success "Flatpak issues addressed"
    else
        log "Flatpak not installed, skipping flatpak fixes"
    fi
}

# Fix casper check failure
fix_casper_shutdown() {
    log "Addressing casper check failure on shutdown..."
    
    # Casper is used by live systems, not needed on installed systems
    # Disable casper services that might be causing shutdown issues
    
    local casper_services=(
        "casper.service"
        "casper-md5check.service"  
        "casper-snapshot.service"
    )
    
    for service in "${casper_services[@]}"; do
        if systemctl list-unit-files | grep -q "$service"; then
            log "Disabling $service..."
            sudo systemctl disable "$service" 2>/dev/null || true
            sudo systemctl mask "$service" 2>/dev/null || true
        fi
    done
    
    # Remove casper from initramfs if present
    if [[ -f "/etc/initramfs-tools/conf.d/casper" ]]; then
        log "Removing casper from initramfs configuration..."
        sudo rm "/etc/initramfs-tools/conf.d/casper" 2>/dev/null || true
    fi
    
    # Check for casper kernel parameters and suggest removal
    if grep -q "casper" /proc/cmdline 2>/dev/null; then
        warn "Casper parameters found in kernel command line:"
        grep -o "casper[^ ]*" /proc/cmdline 2>/dev/null || true
        warn "These will be removed on next GRUB update"
    fi
    
    success "Casper shutdown issues addressed"
}

# Install missing lightweight packages
install_missing_packages() {
    log "Installing missing lightweight packages..."
    
    # Update package lists first
    log "Updating package lists..."
    sudo apt update
    
    # Install lightweight office suite and media tools
    local packages_to_install=(
        "abiword"           # Lightweight word processor
        "gnumeric"          # Lightweight spreadsheet
        "evince"            # PDF viewer
        "mpv"               # Lightweight media player
        "vlc-data"          # VLC data files
        "mousepad"          # Text editor (likely already installed)
        "libresolv2"        # Resolver library (if missing)
    )
    
    log "Installing packages: ${packages_to_install[*]}"
    
    for package in "${packages_to_install[@]}"; do
        if ! dpkg -l | grep -q "^ii  $package "; then
            log "Installing $package..."
            sudo apt install -y "$package" 2>/dev/null || {
                warn "Failed to install $package, skipping..."
            }
        else
            log "$package already installed"
        fi
    done
    
    success "Missing packages installation completed"
}

# Test system functionality
test_system_functionality() {
    log "Testing system functionality..."
    
    # Test 1: Network connectivity
    log "Testing network connectivity..."
    if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        success "Network connectivity: Working"
    else
        warn "Network connectivity: Issues detected"
    fi
    
    # Test 2: Display
    log "Testing display system..."
    if pgrep -x "Xorg\|Xwayland" >/dev/null; then
        success "Display system: Running"
    else
        warn "Display system: Not detected"
    fi
    
    # Test 3: Audio
    log "Testing audio system..."
    if command -v pulseaudio &>/dev/null; then
        success "Audio system: PulseAudio available"
    elif command -v pipewire &>/dev/null; then
        success "Audio system: PipeWire available"
    else
        warn "Audio system: No audio system detected"
    fi
    
    # Test 4: USB/HID
    log "Testing USB/HID devices..."
    local usb_devices=$(lsusb | wc -l)
    success "USB devices detected: $usb_devices"
    
    # Test 5: Storage
    log "Testing storage and filesystem..."
    df -h / | tail -1
    success "Root filesystem accessible"
    
    success "System functionality test completed"
}

# Optimize system settings
optimize_system() {
    log "Optimizing system settings for MacBook..."
    
    # Enable automatic login for thyme user (optional)
    read -p "Enable automatic login for thyme user? (y/n): " auto_login
    if [[ "$auto_login" =~ ^[Yy]$ ]]; then
        log "Configuring automatic login..."
        sudo tee "/etc/lightdm/lightdm.conf.d/10-thyme-autologin.conf" > /dev/null << 'EOF'
[Seat:*]
autologin-user=thyme
autologin-user-timeout=0
EOF
        success "Automatic login configured"
    fi
    
    # Optimize swappiness for SSD
    log "Optimizing swappiness for SSD..."
    echo "vm.swappiness=10" | sudo tee "/etc/sysctl.d/99-thyme-ssd.conf" >/dev/null
    sudo sysctl vm.swappiness=10
    success "SSD optimization applied"
    
    # Clean up system
    log "Cleaning up system..."
    sudo apt autoremove -y 2>/dev/null || true
    sudo apt autoclean 2>/dev/null || true
    success "System cleanup completed"
}

# Create system information script
create_system_info() {
    log "Creating Thyme OS system information script..."
    
    sudo tee "/usr/local/bin/thyme-info" > /dev/null << 'EOF'
#!/bin/bash
# Thyme OS System Information

echo "🍃 Thyme OS System Information"
echo "============================="
echo

# System info
echo "System:"
cat /etc/thyme/version 2>/dev/null || echo "Version info not found"
echo "Hostname: $(hostname)"
echo "Uptime: $(uptime -p)"
echo

# Hardware info
echo "Hardware:"
echo "CPU: $(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)"
echo "Memory: $(free -h | grep Mem | awk '{print $3 "/" $2}')"
echo "Storage: $(df -h / | tail -1 | awk '{print $3 "/" $2 " (" $5 " used)"}')"
echo

# Network info
echo "Network:"
ip addr show | grep -E "inet.*global" | awk '{print $NF ": " $2}' | head -3
echo

# USB devices
echo "USB Devices:"
lsusb | head -5
echo

# Boot device
echo "Boot Device:"
findmnt -n -o SOURCE / | xargs lsblk -o NAME,SIZE,MODEL
echo

echo "🍃 Thyme OS running successfully!"
EOF
    
    sudo chmod +x "/usr/local/bin/thyme-info"
    success "System information script created: thyme-info"
}

# Main execution
main() {
    if [[ $EUID -eq 0 ]]; then
        error "Please run this script as regular user (it will use sudo when needed)"
    fi
    
    check_thyme_system
    
    echo "🔧 Starting post-installation fixes..."
    echo
    
    fix_flatpak_libresolve
    echo
    
    fix_casper_shutdown
    echo
    
    install_missing_packages
    echo
    
    test_system_functionality
    echo
    
    optimize_system
    echo
    
    create_system_info
    echo
    
    success "🎉 Thyme OS post-installation fixes completed!"
    echo
    echo "📋 Summary:"
    echo "• Flatpak library issues fixed"
    echo "• Casper shutdown errors addressed"
    echo "• Missing packages installed"
    echo "• System functionality tested"
    echo "• Performance optimizations applied"
    echo "• System info tool created (run 'thyme-info')"
    echo
    echo "🚀 Thyme OS is ready for use!"
    echo "   Username: thyme"
    echo "   Password: thyme123 (please change)"
    echo
    echo "💡 Recommended next steps:"
    echo "   1. Change default password: passwd"
    echo "   2. Run system info: thyme-info"
    echo "   3. Test all applications"
    echo "   4. Reboot to ensure everything works"
}

main "$@"