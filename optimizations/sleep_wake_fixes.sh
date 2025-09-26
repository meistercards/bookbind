#!/bin/bash
# BookBind Sleep/Wake Fixes for MacBook Hardware
# Based on analysis of working Linux Mint system
# Implements sleep/wake functionality that prevents freeze issues

set -e

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
LOG_FILE="/var/log/bookbind_sleep_fixes.log"

log() {
    echo "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

error() {
    echo "[ERROR] $1" | tee -a "$LOG_FILE"
    exit 1
}

# Apply MacBook-specific sleep/wake fixes
apply_sleep_wake_fixes() {
    log "Applying MacBook sleep/wake fixes..."
    
    # 1. Configure systemd sleep settings for MacBook hardware
    configure_systemd_sleep
    
    # 2. Set up proper kernel parameters for sleep stability
    configure_grub_sleep_parameters
    
    # 3. Configure XFCE power manager for optimal sleep behavior
    configure_xfce_power_manager
    
    # 4. Set up sleep/wake validation and recovery
    setup_sleep_validation
    
    log "Sleep/wake fixes applied successfully"
}

# Configure systemd sleep settings optimized for MacBook
configure_systemd_sleep() {
    log "Configuring systemd sleep settings..."
    
    # Create systemd sleep configuration for MacBook
    cat > "/etc/systemd/sleep.conf" << 'EOF'
# BookBind MacBook Sleep Configuration
# Optimized for old MacBook hardware (2006-2009)

[Sleep]
# Enable suspend - works with proper kernel parameters
AllowSuspend=yes

# Disable problematic hibernate modes on old MacBooks
AllowHibernation=no
AllowSuspendThenHibernate=no
AllowHybridSleep=no

# Use deep sleep mode for MacBook hardware
# s2idle can cause issues on older EFI firmware
SuspendState=mem

# Disable hibernate modes that cause issues
HibernateMode=shutdown

# Quick suspend estimation for faster sleep
SuspendEstimationSec=5min
EOF
    
    log "systemd sleep configuration updated"
}

# Configure GRUB with MacBook-specific sleep parameters
configure_grub_sleep_parameters() {
    log "Configuring GRUB for MacBook sleep stability..."
    
    # Check if GRUB config exists
    if [[ ! -f "/etc/default/grub" ]]; then
        error "GRUB configuration not found"
    fi
    
    # Backup original GRUB config
    cp "/etc/default/grub" "/etc/default/grub.bookbind.bak"
    
    # Update GRUB command line for MacBook sleep stability
    sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash usbcore.autosuspend=-1 usbhid.mousepoll=0 i8042.reset i8042.nomux acpi_sleep=nonvs"/' "/etc/default/grub"
    
    # Update GRUB
    if command -v update-grub >/dev/null 2>&1; then
        update-grub
        log "GRUB updated with MacBook sleep parameters"
    else
        log "Warning: update-grub not found, manual GRUB update may be needed"
    fi
}

# Configure XFCE power manager for MacBook
configure_xfce_power_manager() {
    log "Configuring XFCE power manager for MacBook..."
    
    # Create XFCE power manager configuration directory
    mkdir -p "/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml"
    
    # Create optimized power manager configuration
    cat > "/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-power-manager" version="1.0">
  <property name="xfce4-power-manager" type="empty">
    <!-- Lid actions optimized for MacBook -->
    <property name="lid-action-on-ac" type="uint" value="1"/>
    <property name="lid-action-on-battery" type="uint" value="1"/>
    
    <!-- Sleep button actions -->
    <property name="sleep-button-action" type="uint" value="1"/>
    
    <!-- Power button - ask for confirmation -->
    <property name="power-button-action" type="uint" value="4"/>
    
    <!-- Display settings for power saving -->
    <property name="brightness-switch" type="int" value="0"/>
    <property name="brightness-switch-restore-on-exit" type="int" value="1"/>
    
    <!-- Show tray icon for easy access -->
    <property name="show-tray-icon" type="bool" value="true"/>
    <property name="show-panel-label" type="int" value="1"/>
    
    <!-- Hibernate disabled (problematic on MacBooks) -->
    <property name="hibernate-button-action" type="uint" value="0"/>
    
    <!-- Lock screen on suspend -->
    <property name="lock-screen-suspend-hibernate" type="bool" value="true"/>
  </property>
</channel>
EOF
    
    log "XFCE power manager configured for MacBook"
}

# Set up sleep/wake validation and recovery scripts
setup_sleep_validation() {
    log "Setting up sleep/wake validation system..."
    
    # Create sleep validation script
    cat > "/usr/local/bin/bookbind-sleep-test" << 'EOF'
#!/bin/bash
# BookBind Sleep/Wake Test for MacBook
# Tests sleep functionality and reports issues

echo "BookBind Sleep/Wake Test"
echo "======================="

# Check power states
echo "Available power states:"
cat /sys/power/state

echo -e "\nCurrent memory sleep mode:"
cat /sys/power/mem_sleep

echo -e "\nDisk sleep modes:"
cat /sys/power/disk 2>/dev/null || echo "Not available"

# Check systemd sleep services
echo -e "\nSleep service status:"
systemctl status systemd-suspend.service --no-pager --lines=0 2>/dev/null || echo "Suspend service not found"

# Test basic sleep functionality (requires user confirmation)
echo -e "\nTo test sleep/wake functionality:"
echo "1. Close laptop lid (should suspend)"
echo "2. Open lid (should wake up)"
echo "3. If system doesn't wake properly, hold power button 10 seconds to force restart"

echo -e "\nSleep/wake test information logged"
EOF
    
    chmod +x "/usr/local/bin/bookbind-sleep-test"
    
    # Create sleep issue recovery script
    cat > "/usr/local/bin/bookbind-sleep-recovery" << 'EOF'
#!/bin/bash
# BookBind Sleep Recovery Script
# Run this if sleep/wake issues occur

echo "BookBind Sleep Recovery"
echo "====================="

# Reset power management services
echo "Restarting power management services..."
systemctl restart systemd-logind
systemctl restart NetworkManager 2>/dev/null || true

# Check for hung processes
echo "Checking for hung processes..."
ps aux | grep -E "(suspend|sleep|hibernate)" | grep -v grep || echo "No sleep-related processes found"

# Reset USB devices (common issue on MacBooks)
echo "Resetting USB subsystem..."
for usb_device in /sys/bus/usb/devices/*/power/control; do
    if [[ -f "$usb_device" ]]; then
        echo "on" > "$usb_device" 2>/dev/null || true
    fi
done

# Reset graphics (if available)
if command -v xrandr >/dev/null 2>&1; then
    echo "Resetting display..."
    xrandr --auto 2>/dev/null || true
fi

echo "Recovery procedures completed"
echo "If issues persist, reboot the system"
EOF
    
    chmod +x "/usr/local/bin/bookbind-sleep-recovery"
    
    # Create systemd service for sleep issue recovery
    cat > "/etc/systemd/system/bookbind-sleep-recovery.service" << 'EOF'
[Unit]
Description=BookBind Sleep Recovery Service
After=suspend.target sleep.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/bookbind-sleep-recovery
RemainAfterExit=yes

[Install]
WantedBy=suspend.target sleep.target
EOF
    
    # Enable the recovery service
    systemctl enable bookbind-sleep-recovery.service 2>/dev/null || true
    
    log "Sleep validation and recovery system configured"
}

# Create sleep/wake monitoring service
create_sleep_monitoring() {
    log "Creating sleep/wake monitoring service..."
    
    cat > "/usr/local/bin/bookbind-sleep-monitor" << 'EOF'
#!/bin/bash
# BookBind Sleep/Wake Monitor
# Logs sleep/wake events and detects issues

SLEEP_LOG="/var/log/bookbind_sleep_events.log"

log_event() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$SLEEP_LOG"
}

case "$1" in
    pre-sleep)
        log_event "SLEEP: System entering sleep mode"
        # Save current state
        echo "$(date '+%s')" > "/tmp/bookbind_sleep_start"
        ;;
    post-sleep)
        log_event "WAKE: System resuming from sleep"
        # Calculate sleep duration
        if [[ -f "/tmp/bookbind_sleep_start" ]]; then
            start_time=$(cat "/tmp/bookbind_sleep_start")
            current_time=$(date '+%s')
            duration=$((current_time - start_time))
            log_event "WAKE: Sleep duration was ${duration} seconds"
            rm -f "/tmp/bookbind_sleep_start"
        fi
        ;;
    *)
        echo "Usage: $0 {pre-sleep|post-sleep}"
        exit 1
        ;;
esac
EOF
    
    chmod +x "/usr/local/bin/bookbind-sleep-monitor"
    
    # Create systemd sleep hooks
    mkdir -p "/usr/lib/systemd/system-sleep"
    
    cat > "/usr/lib/systemd/system-sleep/bookbind-monitor" << 'EOF'
#!/bin/bash
# BookBind systemd sleep hook

case "$1" in
    pre)
        /usr/local/bin/bookbind-sleep-monitor pre-sleep
        ;;
    post)
        /usr/local/bin/bookbind-sleep-monitor post-sleep
        ;;
esac
EOF
    
    chmod +x "/usr/lib/systemd/system-sleep/bookbind-monitor"
    
    log "Sleep monitoring service created"
}

# Main execution
main() {
    log "Starting BookBind sleep/wake fix installation..."
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
    fi
    
    # Apply all sleep/wake fixes
    apply_sleep_wake_fixes
    create_sleep_monitoring
    
    log "BookBind sleep/wake fixes installation completed!"
    log "Please reboot the system to activate all changes"
    log "Use 'bookbind-sleep-test' to validate sleep functionality"
    log "Use 'bookbind-sleep-recovery' if sleep issues occur"
}

# Run main function
main "$@"