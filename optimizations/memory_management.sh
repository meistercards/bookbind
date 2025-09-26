#!/bin/bash
# BookBind Memory Management Optimizations
# Prevents freezing and improves performance on 2-4GB MacBook systems
# Based on analysis from mintbook freezing_sleep_fixes

# Configure memory management for low-RAM MacBook systems
configure_memory_management() {
    local root_mount="$1"
    
    log "Configuring memory management optimizations for MacBook..."
    
    # Create memory optimization configuration
    sudo mkdir -p "$root_mount/etc/sysctl.d"
    sudo tee "$root_mount/etc/sysctl.d/99-bookbind-memory.conf" > /dev/null << 'EOF'
# BookBind Memory Optimizations for MacBooks
# Prevents freezing on systems with 2-4GB RAM

# Reduce swappiness - use RAM more aggressively before swap
vm.swappiness=10

# Optimize dirty page handling for responsiveness
vm.dirty_ratio=15
vm.dirty_background_ratio=5

# Reduce VFS cache pressure for better memory utilization
vm.vfs_cache_pressure=50

# Optimize memory allocation for small systems
vm.min_free_kbytes=32768

# Prevent memory overcommit issues
vm.overcommit_memory=2
vm.overcommit_ratio=80

# Optimize page allocation for older hardware
vm.zone_reclaim_mode=0
EOF
    
    # Create memory monitoring service for early warning
    sudo tee "$root_mount/etc/systemd/system/bookbind-memory-monitor.service" > /dev/null << 'EOF'
[Unit]
Description=BookBind Memory Monitor
After=multi-user.target

[Service]
Type=simple
ExecStart=/usr/local/bin/bookbind-memory-monitor
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF
    
    # Create memory monitoring script
    sudo tee "$root_mount/usr/local/bin/bookbind-memory-monitor" > /dev/null << 'EOF'
#!/bin/bash
# BookBind Memory Monitor - Prevents system freezing
# Monitors memory usage and takes action before critical levels

LOG_FILE="/var/log/bookbind-memory.log"
MEMORY_WARNING_THRESHOLD=85
MEMORY_CRITICAL_THRESHOLD=95
CHECK_INTERVAL=30

log_memory() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

check_memory() {
    local mem_total=$(free | awk '/^Mem:/ {print $2}')
    local mem_used=$(free | awk '/^Mem:/ {print $3}')
    local mem_percent=$((mem_used * 100 / mem_total))
    
    if [[ $mem_percent -gt $MEMORY_CRITICAL_THRESHOLD ]]; then
        log_memory "CRITICAL: Memory usage at ${mem_percent}% - Taking emergency action"
        
        # Kill memory-heavy processes to prevent freeze
        pkill -f firefox 2>/dev/null || true
        pkill -f thunderbird 2>/dev/null || true
        pkill -f libreoffice 2>/dev/null || true
        
        # Force garbage collection
        sync
        echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
        
        log_memory "Emergency memory cleanup completed"
        
    elif [[ $mem_percent -gt $MEMORY_WARNING_THRESHOLD ]]; then
        log_memory "WARNING: Memory usage at ${mem_percent}%"
        
        # Gentle cleanup
        echo 1 > /proc/sys/vm/drop_caches 2>/dev/null || true
    fi
}

# Main monitoring loop
while true; do
    check_memory
    sleep $CHECK_INTERVAL
done
EOF
    
    sudo chmod +x "$root_mount/usr/local/bin/bookbind-memory-monitor"
    
    # Enable memory monitoring service
    sudo chroot "$root_mount" systemctl enable bookbind-memory-monitor.service 2>/dev/null || true
    
    # Configure zram (compressed RAM) for low-memory systems
    setup_zram_optimization "$root_mount"
    
    # Optimize browser memory usage
    configure_browser_memory_limits "$root_mount"
    
    log "✅ Memory management optimizations configured"
}

# Set up zram for additional virtual memory
setup_zram_optimization() {
    local root_mount="$1"
    
    log "Setting up zram optimization..."
    
    # Create zram setup service
    sudo tee "$root_mount/etc/systemd/system/bookbind-zram.service" > /dev/null << 'EOF'
[Unit]
Description=BookBind zram Setup
DefaultDependencies=false
After=local-fs.target
Before=swap.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/bookbind-zram-setup
RemainAfterExit=yes

[Install]
WantedBy=swap.target
EOF
    
    # Create zram setup script
    sudo tee "$root_mount/usr/local/bin/bookbind-zram-setup" > /dev/null << 'EOF'
#!/bin/bash
# BookBind zram Setup - Compressed RAM for low-memory systems

# Check if zram is available
if [[ ! -e /dev/zram0 ]]; then
    modprobe zram 2>/dev/null || exit 0
fi

# Get total RAM
total_ram=$(free -b | awk '/^Mem:/ {print $2}')

# Use 25% of RAM for zram on systems with <4GB
if [[ $total_ram -lt 4294967296 ]]; then  # Less than 4GB
    zram_size=$((total_ram / 4))
    
    # Configure zram device
    echo $zram_size > /sys/block/zram0/disksize
    mkswap /dev/zram0
    swapon /dev/zram0 -p 10  # High priority
    
    echo "zram enabled: $(($zram_size / 1024 / 1024))MB"
fi
EOF
    
    sudo chmod +x "$root_mount/usr/local/bin/bookbind-zram-setup"
    sudo chroot "$root_mount" systemctl enable bookbind-zram.service 2>/dev/null || true
    
    log "✅ zram optimization configured"
}

# Configure browser memory limits to prevent freezing
configure_browser_memory_limits() {
    local root_mount="$1"
    
    log "Configuring browser memory limits..."
    
    # Create Firefox memory optimization
    sudo mkdir -p "$root_mount/etc/skel/.mozilla/firefox"
    sudo tee "$root_mount/etc/skel/.mozilla/firefox/user.js" > /dev/null << 'EOF'
// BookBind Firefox Memory Optimizations for MacBooks
user_pref("browser.cache.memory.capacity", 32768);  // 32MB cache
user_pref("browser.sessionhistory.max_entries", 10);  // Limit history
user_pref("browser.tabs.remote.autostart", false);  // Disable e10s on low RAM
user_pref("dom.ipc.processCount", 1);  // Single content process
user_pref("browser.tabs.remote.autostart.2", false);
user_pref("layers.acceleration.disabled", true);  // Disable hardware acceleration
EOF
    
    # Create application launcher with memory limits
    sudo mkdir -p "$root_mount/usr/local/bin"
    sudo tee "$root_mount/usr/local/bin/bookbind-firefox" > /dev/null << 'EOF'
#!/bin/bash
# Firefox with memory limits for MacBooks

# Set memory limits for Firefox
ulimit -v 1048576  # 1GB virtual memory limit

# Launch Firefox with low-memory flags
exec firefox \
    --new-instance \
    --no-remote \
    --memory-pressure-off \
    "$@"
EOF
    
    sudo chmod +x "$root_mount/usr/local/bin/bookbind-firefox"
    
    log "✅ Browser memory limits configured"
}

# Get memory information for optimization decisions
get_memory_info() {
    local total_ram_gb=$(free -g | awk '/^Mem:/{print $2}')
    local total_ram_mb=$(free -m | awk '/^Mem:/{print $2}')
    
    echo "System RAM: ${total_ram_gb}GB (${total_ram_mb}MB)"
    
    if [[ $total_ram_gb -lt 3 ]]; then
        echo "Memory class: Low (aggressive optimization needed)"
        return 1
    elif [[ $total_ram_gb -lt 5 ]]; then
        echo "Memory class: Medium (standard optimization)"
        return 2
    else
        echo "Memory class: High (minimal optimization needed)"
        return 3
    fi
}

# Validate memory optimizations
validate_memory_optimizations() {
    local root_mount="$1"
    
    log "Validating memory optimizations..."
    
    # Check if sysctl configuration exists
    if [[ -f "$root_mount/etc/sysctl.d/99-bookbind-memory.conf" ]]; then
        log "✅ Memory sysctl configuration installed"
    else
        error "❌ Memory sysctl configuration missing"
    fi
    
    # Check if memory monitor is installed
    if [[ -f "$root_mount/usr/local/bin/bookbind-memory-monitor" ]]; then
        log "✅ Memory monitor installed"
    else
        error "❌ Memory monitor missing"
    fi
    
    # Check if zram setup is installed
    if [[ -f "$root_mount/usr/local/bin/bookbind-zram-setup" ]]; then
        log "✅ zram optimization installed"
    else
        error "❌ zram optimization missing"
    fi
    
    log "✅ Memory optimization validation complete"
}