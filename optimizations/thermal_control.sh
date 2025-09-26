#!/bin/bash
# BookBind Thermal Control Optimizations
# Prevents overheating and system freezing on MacBook hardware
# Based on thermal monitoring insights from mintbook freezing analysis

# Configure thermal management for MacBook systems
configure_thermal_management() {
    local root_mount="$1"
    
    log "Configuring thermal management for MacBook..."
    
    # Create thermal monitoring and control service
    create_thermal_service "$root_mount"
    
    # Configure CPU governor for thermal stability
    configure_cpu_governor "$root_mount"
    
    # Set up thermal emergency procedures
    setup_thermal_emergency "$root_mount"
    
    # Configure kernel thermal parameters
    configure_thermal_kernel_params "$root_mount"
    
    log "✅ Thermal management configured"
}

# Create comprehensive thermal monitoring service
create_thermal_service() {
    local root_mount="$1"
    
    log "Setting up thermal monitoring service..."
    
    # Create thermal control service
    sudo tee "$root_mount/etc/systemd/system/bookbind-thermal.service" > /dev/null << 'EOF'
[Unit]
Description=BookBind Thermal Management
After=multi-user.target
Before=graphical.target

[Service]
Type=simple
ExecStart=/usr/local/bin/bookbind-thermal-monitor
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    # Create comprehensive thermal monitoring script
    sudo tee "$root_mount/usr/local/bin/bookbind-thermal-monitor" > /dev/null << 'EOF'
#!/bin/bash
# BookBind Thermal Monitor - Prevents overheating and freezing
# Based on MacBook2,1 thermal analysis

LOG_FILE="/var/log/bookbind-thermal.log"
TEMP_WARNING=70
TEMP_CRITICAL=80
TEMP_EMERGENCY=85
CHECK_INTERVAL=15

log_thermal() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

get_cpu_temp() {
    local temp=0
    
    # Try multiple temperature sources
    if [[ -f /sys/class/thermal/thermal_zone0/temp ]]; then
        temp=$(cat /sys/class/thermal/thermal_zone0/temp)
        temp=$((temp / 1000))  # Convert from millidegrees
    elif command -v sensors >/dev/null 2>&1; then
        temp=$(sensors | grep -E "Core|CPU" | grep -o '[0-9]\+°C' | head -1 | grep -o '[0-9]\+' || echo "0")
    fi
    
    echo "$temp"
}

get_system_load() {
    local load=$(cat /proc/loadavg | awk '{print $1}')
    echo "$load"
}

apply_thermal_throttling() {
    local level="$1"
    
    case "$level" in
        "warning")
            log_thermal "WARNING: Applying conservative thermal throttling"
            # Set conservative CPU governor
            echo "conservative" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || true
            echo "conservative" > /sys/devices/system/cpu/cpu1/cpufreq/scaling_governor 2>/dev/null || true
            ;;
        "critical")
            log_thermal "CRITICAL: Applying aggressive thermal throttling"
            # Reduce CPU frequency to 75% of max
            if [[ -f /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq ]]; then
                local max_freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq)
                local throttle_freq=$((max_freq * 75 / 100))
                echo $throttle_freq > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq 2>/dev/null || true
                echo $throttle_freq > /sys/devices/system/cpu/cpu1/cpufreq/scaling_max_freq 2>/dev/null || true
            fi
            
            # Kill heavy processes
            pkill -f firefox 2>/dev/null || true
            pkill -f thunderbird 2>/dev/null || true
            ;;
        "emergency")
            log_thermal "EMERGENCY: System overheating - taking emergency action"
            # Set minimum CPU frequency
            if [[ -f /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_min_freq ]]; then
                local min_freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_min_freq)
                echo $min_freq > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq 2>/dev/null || true
                echo $min_freq > /sys/devices/system/cpu/cpu1/cpufreq/scaling_max_freq 2>/dev/null || true
            fi
            
            # Kill all non-essential processes
            pkill -f -TERM firefox thunderbird libreoffice 2>/dev/null || true
            sleep 2
            pkill -f -KILL firefox thunderbird libreoffice 2>/dev/null || true
            
            # Sync and drop caches to reduce I/O heat
            sync
            echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
            ;;
    esac
}

restore_normal_operation() {
    log_thermal "Temperature normalized - restoring normal operation"
    
    # Restore normal CPU governor
    echo "ondemand" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || true
    echo "ondemand" > /sys/devices/system/cpu/cpu1/cpufreq/scaling_governor 2>/dev/null || true
    
    # Restore maximum CPU frequency
    if [[ -f /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq ]]; then
        local max_freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq)
        echo $max_freq > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq 2>/dev/null || true
        echo $max_freq > /sys/devices/system/cpu/cpu1/cpufreq/scaling_max_freq 2>/dev/null || true
    fi
}

# Main thermal monitoring loop
current_state="normal"
consecutive_normal=0

while true; do
    cpu_temp=$(get_cpu_temp)
    system_load=$(get_system_load)
    
    # Log current status every 5 minutes
    if [[ $(($(date +%s) % 300)) -eq 0 ]]; then
        log_thermal "STATUS: CPU ${cpu_temp}°C, Load ${system_load}, State ${current_state}"
    fi
    
    # Thermal management logic
    if [[ $cpu_temp -ge $TEMP_EMERGENCY ]]; then
        if [[ "$current_state" != "emergency" ]]; then
            current_state="emergency"
            apply_thermal_throttling "emergency"
        fi
        consecutive_normal=0
        
    elif [[ $cpu_temp -ge $TEMP_CRITICAL ]]; then
        if [[ "$current_state" != "critical" ]]; then
            current_state="critical"
            apply_thermal_throttling "critical"
        fi
        consecutive_normal=0
        
    elif [[ $cpu_temp -ge $TEMP_WARNING ]]; then
        if [[ "$current_state" == "normal" ]]; then
            current_state="warning"
            apply_thermal_throttling "warning"
        fi
        consecutive_normal=0
        
    else
        # Temperature is normal
        consecutive_normal=$((consecutive_normal + 1))
        
        # Only restore if temperature has been normal for 2 minutes
        if [[ $consecutive_normal -ge 8 ]] && [[ "$current_state" != "normal" ]]; then
            current_state="normal"
            restore_normal_operation
        fi
    fi
    
    sleep $CHECK_INTERVAL
done
EOF
    
    sudo chmod +x "$root_mount/usr/local/bin/bookbind-thermal-monitor"
    sudo chroot "$root_mount" systemctl enable bookbind-thermal.service 2>/dev/null || true
    
    log "✅ Thermal monitoring service created"
}

# Configure CPU governor for thermal stability
configure_cpu_governor() {
    local root_mount="$1"
    
    log "Configuring CPU governor for thermal stability..."
    
    # Create CPU governor setup service
    sudo tee "$root_mount/etc/systemd/system/bookbind-cpu-governor.service" > /dev/null << 'EOF'
[Unit]
Description=BookBind CPU Governor Setup
After=multi-user.target
Before=bookbind-thermal.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/bookbind-cpu-governor-setup
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    
    # Create CPU governor setup script
    sudo tee "$root_mount/usr/local/bin/bookbind-cpu-governor-setup" > /dev/null << 'EOF'
#!/bin/bash
# BookBind CPU Governor Setup for MacBook thermal stability

# Set conservative CPU governor for thermal stability
set_cpu_governor() {
    local governor="$1"
    
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        if [[ -f "$cpu" ]]; then
            echo "$governor" > "$cpu" 2>/dev/null || true
        fi
    done
    
    echo "CPU governor set to: $governor"
}

# Configure CPU frequency scaling for thermal management
configure_cpu_scaling() {
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/; do
        if [[ -d "$cpu" ]]; then
            # Set scaling thresholds for conservative governor
            echo "75" > "${cpu}scaling_up_threshold" 2>/dev/null || true
            echo "25" > "${cpu}scaling_down_threshold" 2>/dev/null || true
            
            # Set reasonable frequency limits (85% max for thermal headroom)
            if [[ -f "${cpu}cpuinfo_max_freq" ]]; then
                local max_freq=$(cat "${cpu}cpuinfo_max_freq")
                local safe_freq=$((max_freq * 85 / 100))
                echo $safe_freq > "${cpu}scaling_max_freq" 2>/dev/null || true
            fi
        fi
    done
}

# Main execution
if [[ -d /sys/devices/system/cpu/cpu0/cpufreq ]]; then
    set_cpu_governor "conservative"
    configure_cpu_scaling
    echo "CPU governor and scaling configured for MacBook thermal management"
else
    echo "CPU frequency scaling not available"
fi
EOF
    
    sudo chmod +x "$root_mount/usr/local/bin/bookbind-cpu-governor-setup"
    sudo chroot "$root_mount" systemctl enable bookbind-cpu-governor.service 2>/dev/null || true
    
    log "✅ CPU governor configuration complete"
}

# Set up thermal emergency procedures
setup_thermal_emergency() {
    local root_mount="$1"
    
    log "Setting up thermal emergency procedures..."
    
    # Create thermal emergency script
    sudo tee "$root_mount/usr/local/bin/bookbind-thermal-emergency" > /dev/null << 'EOF'
#!/bin/bash
# BookBind Thermal Emergency Response
# Manual intervention for overheating situations

echo "BookBind Thermal Emergency Response"
echo "=================================="

# Get current temperature
if [[ -f /sys/class/thermal/thermal_zone0/temp ]]; then
    temp=$(cat /sys/class/thermal/thermal_zone0/temp)
    temp_c=$((temp / 1000))
    echo "Current CPU temperature: ${temp_c}°C"
else
    echo "Temperature sensor not available"
fi

# Emergency cooling actions
echo "Applying emergency cooling measures..."

# Kill all non-essential processes
echo "Stopping resource-intensive applications..."
pkill -f -TERM firefox thunderbird libreoffice gimp 2>/dev/null || true
sleep 3
pkill -f -KILL firefox thunderbird libreoffice gimp 2>/dev/null || true

# Set minimum CPU frequency
echo "Setting minimum CPU frequency..."
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/; do
    if [[ -d "$cpu" && -f "${cpu}cpuinfo_min_freq" ]]; then
        min_freq=$(cat "${cpu}cpuinfo_min_freq")
        echo $min_freq > "${cpu}scaling_max_freq" 2>/dev/null || true
    fi
done

# Clear system caches to reduce I/O
echo "Clearing system caches..."
sync
echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true

# Display thermal status
echo ""
echo "Emergency cooling applied. Monitor temperature:"
echo "  - Normal operation: < 70°C"
echo "  - Warning level: 70-80°C"  
echo "  - Critical level: 80-85°C"
echo "  - Emergency level: > 85°C"
echo ""
echo "If temperature remains high:"
echo "1. Ensure MacBook vents are not blocked"
echo "2. Use compressed air to clean internal dust"
echo "3. Consider undervolting CPU if supported"
echo "4. Check for runaway processes with 'htop'"

# Wait and restore if temperature drops
sleep 30
if [[ -f /sys/class/thermal/thermal_zone0/temp ]]; then
    temp=$(cat /sys/class/thermal/thermal_zone0/temp)
    temp_c=$((temp / 1000))
    if [[ $temp_c -lt 75 ]]; then
        echo "Temperature decreased to ${temp_c}°C - restoring normal operation"
        /usr/local/bin/bookbind-cpu-governor-setup
    else
        echo "Temperature still high (${temp_c}°C) - keeping emergency settings"
    fi
fi
EOF
    
    sudo chmod +x "$root_mount/usr/local/bin/bookbind-thermal-emergency"
    
    # Create desktop shortcut for thermal emergency
    sudo mkdir -p "$root_mount/etc/skel/Desktop"
    sudo tee "$root_mount/etc/skel/Desktop/Thermal-Emergency.desktop" > /dev/null << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Thermal Emergency
Comment=Emergency cooling for overheating MacBook
Exec=xterm -e 'sudo /usr/local/bin/bookbind-thermal-emergency; read -p "Press Enter to close..."'
Icon=utilities-system-monitor
Terminal=false
Categories=System;
EOF
    
    sudo chmod +x "$root_mount/etc/skel/Desktop/Thermal-Emergency.desktop"
    
    log "✅ Thermal emergency procedures configured"
}

# Configure kernel thermal parameters
configure_thermal_kernel_params() {
    local root_mount="$1"
    
    log "Configuring kernel thermal parameters..."
    
    # Create thermal kernel parameter configuration
    sudo mkdir -p "$root_mount/etc/sysctl.d"
    sudo tee "$root_mount/etc/sysctl.d/99-bookbind-thermal.conf" > /dev/null << 'EOF'
# BookBind Thermal Kernel Parameters for MacBooks

# Enable thermal management
kernel.printk = 3 3 3 3

# Optimize scheduler for thermal management
kernel.sched_migration_cost_ns = 500000

# Reduce timer frequency to lower heat generation
kernel.timer_migration = 1

# Optimize power management
kernel.nmi_watchdog = 0
EOF
    
    log "✅ Kernel thermal parameters configured"
}

# Validate thermal optimizations
validate_thermal_optimizations() {
    local root_mount="$1"
    
    log "Validating thermal optimizations..."
    
    # Check thermal monitoring service
    if [[ -f "$root_mount/etc/systemd/system/bookbind-thermal.service" ]]; then
        log "✅ Thermal monitoring service installed"
    else
        error "❌ Thermal monitoring service missing"
    fi
    
    # Check CPU governor service
    if [[ -f "$root_mount/etc/systemd/system/bookbind-cpu-governor.service" ]]; then
        log "✅ CPU governor service installed"
    else
        error "❌ CPU governor service missing"
    fi
    
    # Check thermal emergency script
    if [[ -f "$root_mount/usr/local/bin/bookbind-thermal-emergency" ]]; then
        log "✅ Thermal emergency script installed"
    else
        error "❌ Thermal emergency script missing"
    fi
    
    # Check kernel parameters
    if [[ -f "$root_mount/etc/sysctl.d/99-bookbind-thermal.conf" ]]; then
        log "✅ Thermal kernel parameters configured"
    else
        error "❌ Thermal kernel parameters missing"
    fi
    
    log "✅ Thermal optimization validation complete"
}