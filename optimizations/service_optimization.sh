#!/bin/bash
# BookBind Service Optimization
# Reduces system load and prevents freezing by optimizing services
# Based on high CPU load analysis from mintbook freezing_sleep_fixes

# Configure service optimizations for MacBook systems
configure_service_optimization() {
    local root_mount="$1"
    
    log "Configuring service optimizations for MacBook..."
    
    # Disable resource-intensive services
    disable_heavy_services "$root_mount"
    
    # Optimize systemd performance
    optimize_systemd_performance "$root_mount"
    
    # Configure lightweight alternatives
    configure_lightweight_services "$root_mount"
    
    # Set up service monitoring
    setup_service_monitoring "$root_mount"
    
    log "✅ Service optimizations configured"
}

# Disable services that cause high CPU load on MacBooks
disable_heavy_services() {
    local root_mount="$1"
    
    log "Disabling resource-intensive services..."
    
    # Services known to cause high load on old MacBooks
    local heavy_services=(
        # Snap system (heavy and not needed)
        "snapd.service"
        "snapd.socket"
        "snapd.seeded.service"
        "snapd.apparmor.service"
        
        # Bluetooth (often problematic on old MacBooks)
        "bluetooth.service"
        "bluetooth.target"
        
        # Mobile broadband (not applicable to MacBooks)
        "ModemManager.service"
        
        # Print services (start on demand instead)
        "cups.service"
        "cups-browsed.service"
        
        # Network discovery (unnecessary load)
        "avahi-daemon.service"
        "avahi-daemon.socket"
        
        # Error reporting (resource intensive)
        "whoopsie.service"
        "apport.service"
        "apport-autoreport.service"
        
        # Ubuntu advantage (not needed)
        "ubuntu-advantage.service"
        "ua-timer.timer"
        
        # Unnecessary system services
        "packagekit.service"
        "fwupd.service"
        "thermald.service"  # We have our own thermal management
        
        # Heavy desktop services
        "tracker-store.service"
        "tracker-miner-fs.service"
        "tracker-extract.service"
        
        # Speech dispatcher (usually not needed)
        "speech-dispatcher.service"
    )
    
    for service in "${heavy_services[@]}"; do
        sudo chroot "$root_mount" systemctl disable "$service" 2>/dev/null || true
        sudo chroot "$root_mount" systemctl mask "$service" 2>/dev/null || true
        log "Disabled service: $service"
    done
    
    # Create service disable documentation
    sudo tee "$root_mount/etc/bookbind/disabled-services.txt" > /dev/null << 'EOF'
# BookBind Disabled Services
# Services disabled to reduce CPU load and prevent freezing on MacBooks

# To re-enable a service:
# sudo systemctl unmask <service-name>
# sudo systemctl enable <service-name>

# Snap System - Heavy package management system
snapd.service
snapd.socket
snapd.seeded.service

# Bluetooth - Often problematic on old MacBooks
bluetooth.service

# Mobile/Modem - Not applicable to MacBooks
ModemManager.service

# Print Services - Start on demand instead
cups.service (use 'sudo systemctl start cups' when needed)
cups-browsed.service

# Network Discovery - Unnecessary CPU load
avahi-daemon.service

# Error Reporting - Resource intensive
whoopsie.service
apport.service

# File Indexing - Heavy background scanning
tracker-store.service
tracker-miner-fs.service
tracker-extract.service

# Thermal Management - Using BookBind thermal system instead
thermald.service
EOF
    
    sudo mkdir -p "$root_mount/etc/bookbind"
    
    log "✅ Heavy services disabled"
}

# Optimize systemd performance for MacBooks
optimize_systemd_performance() {
    local root_mount="$1"
    
    log "Optimizing systemd performance..."
    
    # Create systemd performance configuration
    sudo mkdir -p "$root_mount/etc/systemd/system.conf.d"
    sudo tee "$root_mount/etc/systemd/system.conf.d/99-bookbind-performance.conf" > /dev/null << 'EOF'
# BookBind systemd Performance Optimizations for MacBooks

[Manager]
# Reduce timeouts for faster boot/shutdown
DefaultTimeoutStartSec=10s
DefaultTimeoutStopSec=5s
DefaultRestartSec=1s
DefaultDeviceTimeoutSec=10s

# Optimize service management
DefaultLimitNOFILE=32768
DefaultLimitNPROC=4096

# Reduce memory usage
RuntimeMaxSec=12h
RuntimeMaxUse=100M

# Optimize for single-user desktop
KillUserProcesses=yes
EOF
    
    # Create journald optimization for reduced I/O
    sudo mkdir -p "$root_mount/etc/systemd/journald.conf.d"
    sudo tee "$root_mount/etc/systemd/journald.conf.d/99-bookbind.conf" > /dev/null << 'EOF'
# BookBind journald optimizations for MacBooks

[Journal]
# Reduce journal size to save storage and I/O
SystemMaxUse=50M
RuntimeMaxUse=50M
SystemMaxFileSize=10M
RuntimeMaxFileSize=10M

# Reduce sync frequency for better performance
SyncIntervalSec=60

# Optimize for desktop use
Storage=volatile
Compress=yes
EOF
    
    # Create logind optimization
    sudo mkdir -p "$root_mount/etc/systemd/logind.conf.d"
    sudo tee "$root_mount/etc/systemd/logind.conf.d/99-bookbind.conf" > /dev/null << 'EOF'
# BookBind logind optimizations for MacBooks

[Login]
# Optimize session management
KillUserProcesses=yes
KillOnlyUsers=

# Reduce session timeouts
InhibitDelayMaxSec=5
UserStopDelaySec=10

# Optimize for laptop use
HandlePowerKey=suspend
HandleLidSwitch=suspend
HandleLidSwitchExternalPower=suspend
IdleAction=ignore
EOF
    
    log "✅ systemd performance optimized"
}

# Configure lightweight service alternatives
configure_lightweight_services() {
    local root_mount="$1"
    
    log "Configuring lightweight service alternatives..."
    
    # Create NetworkManager optimization
    sudo mkdir -p "$root_mount/etc/NetworkManager/conf.d"
    sudo tee "$root_mount/etc/NetworkManager/conf.d/99-bookbind.conf" > /dev/null << 'EOF'
# BookBind NetworkManager optimizations

[main]
# Reduce background scanning
no-auto-default=*

[device]
# Optimize WiFi scanning
wifi.scan-rand-mac-address=no
wifi.powersave=3

[connection]
# Reduce connection timeouts
ipv6.method=ignore
EOF
    
    # Create PulseAudio optimization
    sudo mkdir -p "$root_mount/etc/pulse/system.pa.d"
    sudo tee "$root_mount/etc/pulse/system.pa.d/bookbind.pa" > /dev/null << 'EOF'
# BookBind PulseAudio optimizations for MacBooks

# Reduce CPU usage
load-module module-suspend-on-idle timeout=10
load-module module-switch-on-port-available

# Optimize for lower latency
set-default-sink-volume 65536
set-default-source-volume 65536
EOF
    
    # Create X11 optimization
    sudo mkdir -p "$root_mount/etc/X11/xorg.conf.d"
    sudo tee "$root_mount/etc/X11/xorg.conf.d/20-bookbind-performance.conf" > /dev/null << 'EOF'
# BookBind X11 performance optimizations for MacBooks

Section "Device"
    Identifier "Intel Graphics"
    Driver "intel"
    Option "AccelMethod" "sna"
    Option "TearFree" "true"
    Option "DRI" "3"
EndSection

Section "Extensions"
    Option "Composite" "Enable"
EndSection
EOF
    
    log "✅ Lightweight service alternatives configured"
}

# Set up service monitoring and management
setup_service_monitoring() {
    local root_mount="$1"
    
    log "Setting up service monitoring..."
    
    # Create service monitoring script
    sudo tee "$root_mount/usr/local/bin/bookbind-service-monitor" > /dev/null << 'EOF'
#!/bin/bash
# BookBind Service Monitor - Manages resource-intensive services

LOG_FILE="/var/log/bookbind-services.log"
LOAD_THRESHOLD=1.5  # High load threshold for 2-core CPU
CHECK_INTERVAL=60

log_service() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

get_system_load() {
    local load=$(cat /proc/loadavg | awk '{print $1}')
    echo "$load"
}

check_heavy_services() {
    local load=$(get_system_load)
    local load_int=$(echo "$load * 100" | bc -l 2>/dev/null | cut -d. -f1)
    local threshold_int=$(echo "$LOAD_THRESHOLD * 100" | bc -l 2>/dev/null | cut -d. -f1)
    
    if [[ $load_int -gt $threshold_int ]]; then
        log_service "HIGH LOAD: System load $load > $LOAD_THRESHOLD"
        
        # Check for resource-intensive processes
        local heavy_processes=$(ps aux --sort=-%cpu | head -10 | awk 'NR>1 {print $11}' | grep -E "(firefox|thunderbird|libreoffice|gimp)" | head -3)
        
        if [[ -n "$heavy_processes" ]]; then
            log_service "Heavy processes detected: $heavy_processes"
            
            # Optionally reduce priority of heavy processes
            pkill -f -STOP firefox 2>/dev/null || true
            sleep 5
            pkill -f -CONT firefox 2>/dev/null || true
            
            log_service "Applied process throttling"
        fi
        
        # Check for runaway services
        local cpu_intensive=$(systemctl list-units --type=service --state=running --no-pager | grep -E "(tracker|packagekit|fwupd)" | awk '{print $1}')
        
        if [[ -n "$cpu_intensive" ]]; then
            log_service "CPU intensive services detected: $cpu_intensive"
            for service in $cpu_intensive; do
                systemctl stop "$service" 2>/dev/null || true
                log_service "Stopped service: $service"
            done
        fi
    fi
}

# Create service restart script for common issues
create_service_tools() {
    cat > "/usr/local/bin/bookbind-restart-services" << 'SCRIPT_EOF'
#!/bin/bash
# BookBind Service Restart Tool

echo "BookBind Service Management"
echo "=========================="

case "$1" in
    "audio")
        echo "Restarting audio services..."
        systemctl --user restart pulseaudio
        systemctl restart alsa-state
        echo "Audio services restarted"
        ;;
    "network")
        echo "Restarting network services..."
        systemctl restart NetworkManager
        systemctl restart systemd-resolved
        echo "Network services restarted"
        ;;
    "display")
        echo "Restarting display services..."
        systemctl restart lightdm
        echo "Display services restarted"
        ;;
    "all")
        echo "Restarting common services..."
        systemctl --user restart pulseaudio
        systemctl restart NetworkManager
        echo "Common services restarted"
        ;;
    *)
        echo "Usage: $0 {audio|network|display|all}"
        echo ""
        echo "Restart specific service groups:"
        echo "  audio   - PulseAudio and ALSA"
        echo "  network - NetworkManager and DNS"
        echo "  display - Display manager"
        echo "  all     - Common services"
        exit 1
        ;;
esac
SCRIPT_EOF
    
    chmod +x "/usr/local/bin/bookbind-restart-services"
}

# Main monitoring loop
create_service_tools

while true; do
    check_heavy_services
    sleep $CHECK_INTERVAL
done
EOF
    
    sudo chmod +x "$root_mount/usr/local/bin/bookbind-service-monitor"
    
    # Create service monitoring systemd service
    sudo tee "$root_mount/etc/systemd/system/bookbind-service-monitor.service" > /dev/null << 'EOF'
[Unit]
Description=BookBind Service Monitor
After=multi-user.target

[Service]
Type=simple
ExecStart=/usr/local/bin/bookbind-service-monitor
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF
    
    sudo chroot "$root_mount" systemctl enable bookbind-service-monitor.service 2>/dev/null || true
    
    # Create service management desktop shortcut
    sudo mkdir -p "$root_mount/etc/skel/Desktop"
    sudo tee "$root_mount/etc/skel/Desktop/Service-Manager.desktop" > /dev/null << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Service Manager
Comment=Manage BookBind system services
Exec=xterm -e '/usr/local/bin/bookbind-restart-services all; read -p "Press Enter to close..."'
Icon=preferences-system
Terminal=false
Categories=System;
EOF
    
    sudo chmod +x "$root_mount/etc/skel/Desktop/Service-Manager.desktop"
    
    log "✅ Service monitoring configured"
}

# Validate service optimizations
validate_service_optimizations() {
    local root_mount="$1"
    
    log "Validating service optimizations..."
    
    # Check if systemd configurations exist
    if [[ -f "$root_mount/etc/systemd/system.conf.d/99-bookbind-performance.conf" ]]; then
        log "✅ systemd performance configuration installed"
    else
        error "❌ systemd performance configuration missing"
    fi
    
    # Check if service monitor is installed
    if [[ -f "$root_mount/usr/local/bin/bookbind-service-monitor" ]]; then
        log "✅ Service monitor installed"
    else
        error "❌ Service monitor missing"
    fi
    
    # Check if disabled services documentation exists
    if [[ -f "$root_mount/etc/bookbind/disabled-services.txt" ]]; then
        log "✅ Disabled services documented"
    else
        error "❌ Disabled services documentation missing"
    fi
    
    # Verify some heavy services are actually disabled
    local test_services=("snapd.service" "bluetooth.service" "cups.service")
    for service in "${test_services[@]}"; do
        if sudo chroot "$root_mount" systemctl is-enabled "$service" 2>/dev/null | grep -q "masked\|disabled"; then
            log "✅ Service $service properly disabled"
        else
            warn "⚠️  Service $service may not be disabled"
        fi
    done
    
    log "✅ Service optimization validation complete"
}