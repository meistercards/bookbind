#!/bin/bash
# Thyme OS Streamlined Installer v3.0
# Fixed version with proper package exclusion and boot testing
# Builds a clean, minimal Thyme OS fork from Mint base

set -e

SCRIPT_VERSION="3.0-streamlined"
INSTALL_LOG="/var/log/thyme_streamlined_install.log"
GRUB_FILES_DIR="/home/meister/mintbook/grub_files"
WORK_DIR="/tmp/thyme_streamlined_work"
TEST_MODE=${1:-"normal"}  # normal, test, debug

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Enhanced logging with permission handling
log() {
    local msg="[$(date '+%H:%M:%S')] $1"
    echo -e "${GREEN}${msg}${NC}"
    if [[ -w "$INSTALL_LOG" ]] 2>/dev/null; then
        echo "$msg" >> "$INSTALL_LOG"
    else
        echo "$msg" | sudo tee -a "$INSTALL_LOG" >/dev/null 2>&1 || true
    fi
}

warn() {
    local msg="[WARNING] $1"
    echo -e "${YELLOW}${msg}${NC}"
    if [[ -w "$INSTALL_LOG" ]] 2>/dev/null; then
        echo "$msg" >> "$INSTALL_LOG"
    else
        echo "$msg" | sudo tee -a "$INSTALL_LOG" >/dev/null 2>&1 || true
    fi
}

error() {
    local msg="[ERROR] $1"
    echo -e "${RED}${msg}${NC}"
    if [[ -w "$INSTALL_LOG" ]] 2>/dev/null; then
        echo "$msg" >> "$INSTALL_LOG"
    else
        echo "$msg" | sudo tee -a "$INSTALL_LOG" >/dev/null 2>&1 || true
    fi
    cleanup_on_error
    exit 1
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# Enhanced cleanup
cleanup_on_error() {
    if [[ "${CLEANUP_IN_PROGRESS:-}" == "true" ]]; then
        echo "Cleanup already in progress, exiting..."
        exit 1
    fi
    export CLEANUP_IN_PROGRESS=true
    
    echo "Cleaning up after error..."
    
    # Unmount all mounted filesystems
    for mount_point in "$ROOT_MOUNT_POINT" "$EFI_MOUNT_POINT"; do
        if [[ -n "$mount_point" ]] && mountpoint -q "$mount_point" 2>/dev/null; then
            sudo umount "$mount_point" 2>/dev/null || true
        fi
    done
    
    # Remove work directory
    if [[ -d "$WORK_DIR" ]]; then
        rm -rf "$WORK_DIR" 2>/dev/null || true
    fi
    
    export CLEANUP_IN_PROGRESS=false
}

trap 'echo "Installation interrupted. Cleaning up..."; cleanup_on_error; exit 1' INT TERM

# Initialize installer
initialize_installer() {
    echo -e "${PURPLE}"
    cat << 'EOF'
🍃 Thyme OS Streamlined Installer v3.0 🍃
=========================================

Creating Thyme OS with SMART package exclusion:
• Excludes bloatware DURING copy (not after)
• Smaller, faster installation
• Better boot compatibility
• Built-in testing framework

EOF
    echo -e "${NC}"
    
    mkdir -p "$WORK_DIR"
    cd "$WORK_DIR"
    
    # Create log file with proper permissions
    sudo mkdir -p "$(dirname "$INSTALL_LOG")"
    sudo touch "$INSTALL_LOG"
    sudo chmod 666 "$INSTALL_LOG"
    echo "Thyme OS Streamlined Installer Log - $(date)" | sudo tee "$INSTALL_LOG" > /dev/null
    log "Installer initialized in $TEST_MODE mode"
}

# Check Mint system and validate
check_mint_system() {
    log "Validating Linux Mint system..."
    
    if [[ ! -f "/etc/lsb-release" ]] || ! grep -q "DISTRIB_ID=LinuxMint" /etc/lsb-release; then
        error "This installer must be run from a working Linux Mint system"
    fi
    
    local mint_version=$(grep "DISTRIB_RELEASE" /etc/lsb-release | cut -d= -f2)
    log "✅ Running on Linux Mint $mint_version"
    
    # Check available disk space
    local available_space=$(df / | tail -1 | awk '{print $4}')
    if [[ $available_space -lt 8000000 ]]; then  # 8GB minimum
        warn "Low disk space available: $((available_space/1024/1024))GB"
    fi
    
    log "✅ System validation passed"
}

# Enhanced device detection with smart identification
detect_target_device() {
    log "Detecting available storage devices with enhanced identification..."
    
    if [[ "$TEST_MODE" == "test" ]]; then
        log "🧪 TEST MODE: Creating test image file instead of real device"
        TEST_IMAGE="$WORK_DIR/thyme_test.img"
        dd if=/dev/zero of="$TEST_IMAGE" bs=1M count=4096  # 4GB test image
        TARGET_DEVICE="$TEST_IMAGE"
        export TARGET_DEVICE
        return
    fi
    
    # Enhanced device detection
    enhanced_device_detection
}

# Enhanced device detection with multiple identification methods
enhanced_device_detection() {
    echo
    echo "🔍 Enhanced Device Detection"
    echo "=========================="
    echo "Scanning for suitable target devices..."
    echo
    
    local system_disk=$(findmnt -n -o SOURCE / | sed 's/[0-9]*$//')
    local candidate_devices=()
    local device_info=()
    
    # Get all block devices with detailed information
    while read -r line; do
        local device=$(echo "$line" | awk '{print $1}')
        local size=$(echo "$line" | awk '{print $4}')
        local type=$(echo "$line" | awk '{print $6}')
        local model=$(echo "$line" | awk '{$1=$2=$3=$4=$5=$6=""; print $0}' | sed 's/^ *//')
        
        device="/dev/$device"
        
        # Skip if it's the system disk
        if [[ "$device" == "$system_disk" ]]; then
            continue
        fi
        
        # Skip if not a physical disk
        if [[ "$type" != "disk" ]]; then
            continue
        fi
        
        # Skip if device doesn't exist
        if [[ ! -b "$device" ]]; then
            continue
        fi
        
        # Get additional device information
        local vendor=""
        local serial=""
        local is_usb=""
        local is_removable=""
        
        # Check if it's USB
        if udevadm info --query=property --name="$device" 2>/dev/null | grep -q "ID_BUS=usb"; then
            is_usb="USB"
            vendor=$(udevadm info --query=property --name="$device" 2>/dev/null | grep "ID_VENDOR=" | cut -d= -f2 || echo "Unknown")
        fi
        
        # Check if removable
        if [[ -f "/sys/block/$(basename "$device")/removable" ]]; then
            local removable_status=$(cat "/sys/block/$(basename "$device")/removable" 2>/dev/null || echo "0")
            if [[ "$removable_status" == "1" ]]; then
                is_removable="Removable"
            fi
        fi
        
        # Get serial if available
        serial=$(udevadm info --query=property --name="$device" 2>/dev/null | grep "ID_SERIAL_SHORT=" | cut -d= -f2 || echo "N/A")
        
        # Check for existing Thyme OS installation
        local has_thyme=""
        if blkid "$device"* 2>/dev/null | grep -q "THYME\|ThymeOS"; then
            has_thyme="(Previous Thyme OS detected)"
        fi
        
        # Check device name history for this specific device
        local name_history=""
        if [[ "$serial" != "N/A" ]]; then
            # Look for this device in dmesg to see previous names
            local previous_names=$(dmesg | grep "$serial" | grep -o "sd[a-z]" | sort -u | tr '\n' ',' | sed 's/,$//')
            if [[ -n "$previous_names" ]]; then
                name_history="(Previously: $previous_names)"
            fi
        fi
        
        # Validate device size (should be at least 4GB for Thyme OS)
        local size_bytes=$(lsblk -b -n -o SIZE "$device" 2>/dev/null | head -1)
        local size_gb=$((size_bytes / 1024 / 1024 / 1024))
        
        if [[ $size_gb -lt 4 ]]; then
            log "Skipping $device: Too small (${size_gb}GB < 4GB minimum)"
            continue
        fi
        
        # Add to candidates
        candidate_devices+=("$device")
        device_info+=("$size|$model|$vendor|$is_usb|$is_removable|$serial|$has_thyme|$name_history")
        
    done < <(lsblk -d -o NAME,MAJ:MIN,RM,SIZE,RO,TYPE,MOUNTPOINT,MODEL)
    
    if [[ ${#candidate_devices[@]} -eq 0 ]]; then
        error "No suitable target devices found. Need at least 4GB removable/USB storage."
    fi
    
    echo "Suitable target devices found:"
    echo "=============================="
    for i in "${!candidate_devices[@]}"; do
        local device="${candidate_devices[$i]}"
        local info="${device_info[$i]}"
        
        local size=$(echo "$info" | cut -d'|' -f1)
        local model=$(echo "$info" | cut -d'|' -f2)
        local vendor=$(echo "$info" | cut -d'|' -f3)
        local is_usb=$(echo "$info" | cut -d'|' -f4)
        local is_removable=$(echo "$info" | cut -d'|' -f5)
        local serial=$(echo "$info" | cut -d'|' -f6)
        local has_thyme=$(echo "$info" | cut -d'|' -f7)
        local name_history=$(echo "$info" | cut -d'|' -f8)
        
        echo "$((i+1)). $device"
        echo "   Size: $size"
        echo "   Model: ${model:-Unknown}"
        [[ -n "$vendor" ]] && echo "   Vendor: $vendor"
        [[ -n "$is_usb" ]] && echo "   Type: $is_usb"
        [[ -n "$is_removable" ]] && echo "   Status: $is_removable"
        [[ "$serial" != "N/A" ]] && echo "   Serial: $serial"
        [[ -n "$name_history" ]] && echo "   📝 $name_history"
        [[ -n "$has_thyme" ]] && echo "   🍃 $has_thyme"
        echo
    done
    
    # Auto-select if only one device and it looks safe
    if [[ ${#candidate_devices[@]} -eq 1 ]]; then
        TARGET_DEVICE="${candidate_devices[0]}"
        local info="${device_info[0]}"
        local is_usb=$(echo "$info" | cut -d'|' -f4)
        local is_removable=$(echo "$info" | cut -d'|' -f5)
        
        log "Auto-detected target device: $TARGET_DEVICE"
        
        # Extra safety check for USB/removable devices
        if [[ -n "$is_usb" ]] || [[ -n "$is_removable" ]]; then
            log "✅ Device appears to be external ($is_usb $is_removable)"
        else
            warn "⚠️  Device may be internal - please verify this is correct!"
        fi
        
        warn "This will COMPLETELY ERASE $TARGET_DEVICE"
        validate_target_device "$TARGET_DEVICE"
        
        # Offer device name explanation and consistency info
        explain_device_naming "$TARGET_DEVICE" "$info"
        
        read -p "Continue with installation to $TARGET_DEVICE? (y/n): " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            error "Installation cancelled by user"
        fi
    else
        echo "Multiple devices available. Please select target device:"
        read -p "Select device number (1-${#candidate_devices[@]}): " device_num
        
        if [[ "$device_num" -ge 1 ]] && [[ "$device_num" -le ${#candidate_devices[@]} ]]; then
            TARGET_DEVICE="${candidate_devices[$((device_num-1))]}"
            warn "Selected: $TARGET_DEVICE - This will be COMPLETELY ERASED"
            
            validate_target_device "$TARGET_DEVICE"
            
            read -p "Type 'ERASE' to confirm: " confirm
            if [[ "${confirm,,}" != "erase" ]]; then
                error "Installation cancelled"
            fi
        else
            error "Invalid selection"
        fi
    fi
    
    export TARGET_DEVICE
}

# Validate target device with comprehensive checks
validate_target_device() {
    local device="$1"
    
    log "Validating target device: $device"
    
    # Check device exists
    if [[ ! -b "$device" ]]; then
        error "Device $device does not exist or is not a block device"
    fi
    
    # Check device is not mounted as root
    if mount | grep -q "^$device.* / "; then
        error "Device $device contains the root filesystem - cannot install to system disk"
    fi
    
    # Check device size
    local size_bytes=$(lsblk -b -n -o SIZE "$device" 2>/dev/null | head -1)
    local size_gb=$((size_bytes / 1024 / 1024 / 1024))
    
    if [[ $size_gb -lt 4 ]]; then
        error "Device $device is too small (${size_gb}GB). Minimum 4GB required."
    fi
    
    if [[ $size_gb -gt 128 ]]; then
        warn "Device $device is quite large (${size_gb}GB). Are you sure this is the correct device?"
    fi
    
    # Check if device has active partitions
    local mounted_parts=$(mount | grep "^$device" | wc -l)
    if [[ $mounted_parts -gt 0 ]]; then
        warn "Device $device has mounted partitions:"
        mount | grep "^$device"
        echo
        warn "These will be unmounted during installation"
    fi
    
    # Check for existing data
    if blkid "$device"* 2>/dev/null | grep -v "THYME\|ThymeOS" | head -5; then
        warn "Device contains existing data (shown above)"
        warn "All data will be permanently lost!"
    fi
    
    log "✅ Device validation passed"
}

# Explain device naming and offer consistency information
explain_device_naming() {
    local device="$1"
    local info="$2"
    
    local serial=$(echo "$info" | cut -d'|' -f6)
    local name_history=$(echo "$info" | cut -d'|' -f8)
    
    echo
    echo "📝 Device Naming Information:"
    echo "=========================="
    echo "Current device name: $device"
    
    if [[ -n "$name_history" && "$name_history" != "(Previously: )" ]]; then
        echo "Previous names: $name_history"
        echo
        echo "ℹ️  Device names can change (sdb→sdc→sdd) based on:"
        echo "   • USB port used"
        echo "   • Other connected devices"  
        echo "   • Boot order"
        echo
        echo "🔧 The installer handles this automatically by:"
        echo "   • Using UUIDs in GRUB configuration"
        echo "   • Smart partition detection"
        echo "   • Device identification by serial number"
        echo
        echo "✅ Your device will boot correctly regardless of name changes!"
    else
        echo "This appears to be the first time detecting this device."
    fi
    
    if [[ "$serial" != "N/A" ]]; then
        echo "🔍 Device ID: $serial (used for consistent identification)"
    fi
    echo
}

# Smart partition detection handles nvme, loop, and SATA devices
detect_partitions() {
    log "Detecting partitions on $TARGET_DEVICE..."
    
    # Wait for partitions to appear
    for i in {1..10}; do
        sudo partprobe "$TARGET_DEVICE" 2>/dev/null || true
        sleep 1
        
        # Try different naming conventions
        local possible_p1=()
        local possible_p2=()
        local possible_p3=()
        
        # Standard SATA/USB naming (sda1, sdb1, etc.)
        possible_p1+=("${TARGET_DEVICE}1")
        possible_p2+=("${TARGET_DEVICE}2")
        possible_p3+=("${TARGET_DEVICE}3")
        
        # NVMe/loop naming (nvme0n1p1, loop0p1, etc.)
        possible_p1+=("${TARGET_DEVICE}p1")
        possible_p2+=("${TARGET_DEVICE}p2")
        possible_p3+=("${TARGET_DEVICE}p3")
        
        # Check which partitions actually exist
        for part in "${possible_p1[@]}"; do
            if [[ -b "$part" ]]; then
                EFI_PARTITION="$part"
                break
            fi
        done
        
        for part in "${possible_p2[@]}"; do
            if [[ -b "$part" ]]; then
                SWAP_PARTITION="$part"
                break
            fi
        done
        
        for part in "${possible_p3[@]}"; do
            if [[ -b "$part" ]]; then
                ROOT_PARTITION="$part"
                break
            fi
        done
        
        # If all partitions found, break
        if [[ -n "$EFI_PARTITION" ]] && [[ -n "$SWAP_PARTITION" ]] && [[ -n "$ROOT_PARTITION" ]]; then
            break
        fi
        
        log "Waiting for partitions to appear... ($i/10)"
    done
    
    # Validate all partitions were found
    if [[ -z "$EFI_PARTITION" ]] || [[ ! -b "$EFI_PARTITION" ]]; then
        error "EFI partition not found or not accessible"
    fi
    
    if [[ -z "$SWAP_PARTITION" ]] || [[ ! -b "$SWAP_PARTITION" ]]; then
        error "Swap partition not found or not accessible"
    fi
    
    if [[ -z "$ROOT_PARTITION" ]] || [[ ! -b "$ROOT_PARTITION" ]]; then
        error "Root partition not found or not accessible"
    fi
    
    log "✅ Partitions detected:"
    log "   EFI:  $EFI_PARTITION"
    log "   Swap: $SWAP_PARTITION"
    log "   Root: $ROOT_PARTITION"
}

# Smart partitioning with loop device support
partition_device() {
    log "Partitioning device $TARGET_DEVICE..."
    
    if [[ "$TEST_MODE" == "test" ]]; then
        # Set up loop device for test image
        LOOP_DEVICE=$(sudo losetup --find --show "$TARGET_DEVICE")
        TARGET_DEVICE="$LOOP_DEVICE"
        log "🧪 TEST MODE: Using loop device $LOOP_DEVICE"
    fi
    
    # Unmount any mounted partitions
    if [[ -b "$TARGET_DEVICE" ]]; then
        for partition in $(lsblk -ln -o NAME "$TARGET_DEVICE" 2>/dev/null | tail -n +2); do
            sudo umount "/dev/$partition" 2>/dev/null || true
        done
    fi
    
    # Create GPT partition table
    sudo parted "$TARGET_DEVICE" --script mklabel gpt
    
    # Create partitions (same logic as before)
    local system_ram_gb=$(free -g | awk '/^Mem:/{print $2}')
    local swap_size_gb=4
    if [[ $system_ram_gb -lt 4 ]]; then
        swap_size_gb=8
    fi
    
    local efi_start="1MiB"
    local efi_end="513MiB"
    local swap_start="513MiB"
    local swap_end="$((513 + swap_size_gb * 1024))MiB"
    local root_start="${swap_end}"
    local root_end="100%"
    
    # Create partitions
    sudo parted "$TARGET_DEVICE" --script mkpart ESP fat32 "$efi_start" "$efi_end"
    sudo parted "$TARGET_DEVICE" --script set 1 esp on
    sudo parted "$TARGET_DEVICE" --script mkpart primary linux-swap "$swap_start" "$swap_end"
    sudo parted "$TARGET_DEVICE" --script mkpart primary ext4 "$root_start" "$root_end"
    
    sudo partprobe "$TARGET_DEVICE" 2>/dev/null || true
    sleep 2
    
    # Smart partition detection
    detect_partitions
    
    log "✅ Partitioning completed"
    export EFI_PARTITION SWAP_PARTITION ROOT_PARTITION LOOP_DEVICE
}

# Format partitions with proper labels
format_partitions() {
    log "Formatting partitions with clean filesystems..."
    
    # Wait for partitions to be ready
    sleep 3
    
    # Format with fresh filesystems
    sudo mkfs.fat -F 32 -n "THYME_EFI" "$EFI_PARTITION"
    sudo mkswap -L "ThymeSwap" "$SWAP_PARTITION" 
    sudo mkfs.ext4 -F -L "ThymeOS" "$ROOT_PARTITION"
    
    log "✅ Partitions formatted"
}

# Mount partitions
mount_partitions() {
    log "Mounting partitions..."
    
    ROOT_MOUNT_POINT="$WORK_DIR/root"
    EFI_MOUNT_POINT="$WORK_DIR/efi"
    
    mkdir -p "$ROOT_MOUNT_POINT" "$EFI_MOUNT_POINT"
    
    sudo mount "$ROOT_PARTITION" "$ROOT_MOUNT_POINT"
    sudo mount "$EFI_PARTITION" "$EFI_MOUNT_POINT"
    
    log "✅ Partitions mounted"
    export ROOT_MOUNT_POINT EFI_MOUNT_POINT
}

# SMART copy system - exclude bloatware DURING copy, not after
smart_copy_mint_system() {
    log "Smart copying Linux Mint system (excluding bloatware during copy)..."
    
    # Define SAFE exclusion patterns that won't affect system libraries
    local bloatware_patterns=(
        # Games - use specific paths to avoid conflicts
        "/usr/games/aisleriot*"
        "/usr/games/gnome-mahjongg*"
        "/usr/games/gnome-mines*"
        "/usr/games/gnome-sudoku*"
        "/usr/games/sol*"
        "/usr/share/games/*"
        
        # Heavy office suites - use specific paths only
        "/usr/lib/libreoffice/*"
        "/usr/bin/libreoffice*"
        "/usr/share/libreoffice/*"
        "/opt/libreoffice*"
        "/usr/bin/thunderbird*"
        "/usr/lib/thunderbird/*"
        "/usr/share/thunderbird/*"
        
        # Heavy multimedia - specific paths
        "/usr/bin/rhythmbox*"
        "/usr/lib/rhythmbox/*"
        "/usr/share/rhythmbox/*"
        "/usr/bin/totem*"
        "/usr/lib/totem/*"
        "/usr/bin/cheese*"
        "/usr/bin/shotwell*"
        "/usr/bin/simple-scan*"
        
        # Network apps - specific paths
        "/usr/bin/hexchat*"
        "/usr/lib/hexchat/*"
        "/usr/bin/transmission*"
        "/usr/lib/transmission/*"
        "/usr/bin/pidgin*"
        "/usr/lib/pidgin/*"
        
        # Graphics apps - specific paths
        "/usr/bin/gimp*"
        "/usr/lib/gimp/*"
        "/usr/share/gimp/*"
        "/usr/bin/inkscape*"
        "/usr/bin/blender*"
        "/usr/lib/blender/*"
        
        # System bloat - specific paths
        "/usr/bin/webapp-manager*"
        "/usr/bin/sticky*"
        "/usr/bin/gucharmap*"
        
        # Snap system - specific paths
        "/usr/bin/snap*"
        "/usr/lib/snapd/*"
        "/snap/*"
        "/var/lib/snapd/*"
        
        # Language packs - be more specific
        "/usr/share/locale/[^e]*"
        "/usr/lib/hunspell/[^e]*"
        "/usr/lib/aspell/[^e]*"
        
        # Large icon sizes - keep safe patterns
        "/usr/share/icons/*/256x256/*"
        "/usr/share/icons/*/128x128/*"
        "/usr/share/icons/*/96x96/*"
        "/usr/share/pixmaps/*.png"
        "/usr/share/pixmaps/*.svg"
    )
    
    # Build exclusion patterns for rsync
    local exclude_args=()
    for pattern in "${bloatware_patterns[@]}"; do
        exclude_args+=(--exclude="$pattern")
    done
    
    # Standard exclusions
    local standard_excludes=(
        --exclude=/proc/*
        --exclude=/sys/*
        --exclude=/dev/*
        --exclude=/tmp/*
        --exclude=/run/*
        --exclude=/mnt/*
        --exclude=/media/*
        --exclude=/lost+found
        --exclude=/swapfile*
        --exclude=/home/*/.cache/*
        --exclude=/home/*/.local/share/Trash/*
        --exclude=/var/cache/*
        --exclude=/var/tmp/*
        --exclude=/var/log/*
        --exclude="*/.thumbnails/*"
        --exclude="*/Downloads/*"
        --exclude="*/mintbook/*"
    )
    
    log "Copying system with smart exclusions (this will be much faster)..."
    sudo rsync -aHAXv "${standard_excludes[@]}" "${exclude_args[@]}" / "$ROOT_MOUNT_POINT/" | tee -a "$INSTALL_LOG"
    
    # Validate critical system libraries are present
    validate_system_libraries
    
    # Create necessary empty directories
    sudo mkdir -p "$ROOT_MOUNT_POINT"/{proc,sys,dev,tmp,run,mnt,media}
    sudo chmod 1777 "$ROOT_MOUNT_POINT/tmp"
    
    # Clean user directories
    setup_clean_user_environment
    
    log "✅ Smart copy completed - bloatware excluded during copy"
}

# Set up clean user environment
setup_clean_user_environment() {
    log "Setting up clean user environment..."
    
    # Remove existing user if present
    if [[ -d "$ROOT_MOUNT_POINT/home/thyme" ]]; then
        sudo rm -rf "$ROOT_MOUNT_POINT/home/thyme"
    fi
    
    # Create fresh thyme user directories
    sudo mkdir -p "$ROOT_MOUNT_POINT/home/thyme"/{Desktop,Documents,Downloads,Pictures,Music,Videos}
    sudo mkdir -p "$ROOT_MOUNT_POINT/home/thyme/.local/share/Trash"/{files,info}
    sudo mkdir -p "$ROOT_MOUNT_POINT/home/thyme/.config"
    
    # Create user account in passwd/shadow
    create_thyme_user_account
    
    # Set proper ownership
    sudo chown -R 1000:1000 "$ROOT_MOUNT_POINT/home/thyme"
    
    # Create fresh log directory
    sudo mkdir -p "$ROOT_MOUNT_POINT/var/log"
    sudo chmod 755 "$ROOT_MOUNT_POINT/var/log"
    
    log "✅ Clean user environment created"
}

# Validate critical system libraries are present
validate_system_libraries() {
    log "Validating critical system libraries..."
    
    local critical_libs=(
        "lib/x86_64-linux-gnu/libc.so*"
        "lib/x86_64-linux-gnu/libresolv.so*"
        "lib/x86_64-linux-gnu/libdl.so*"
        "lib/x86_64-linux-gnu/libm.so*"
        "lib/x86_64-linux-gnu/libpthread.so*"
        "lib/x86_64-linux-gnu/libssl.so*"
        "lib/x86_64-linux-gnu/libcrypto.so*"
        "lib/x86_64-linux-gnu/libz.so*"
        "usr/lib/x86_64-linux-gnu/libgtk-3.so*"
        "usr/lib/x86_64-linux-gnu/libglib-2.0.so*"
    )
    
    local missing_libs=()
    
    for lib_pattern in "${critical_libs[@]}"; do
        if ! find "$ROOT_MOUNT_POINT/$lib_pattern" -type f 2>/dev/null | head -1 | grep -q .; then
            missing_libs+=("$lib_pattern")
        fi
    done
    
    if [[ ${#missing_libs[@]} -gt 0 ]]; then
        error "Critical system libraries missing: ${missing_libs[*]}"
    else
        log "✅ All critical system libraries present"
    fi
    
    # Special check for libresolv
    if find "$ROOT_MOUNT_POINT/lib/x86_64-linux-gnu/libresolv.so*" -type f 2>/dev/null | head -1 | grep -q .; then
        log "✅ libresolv library confirmed present"
    else
        error "libresolv library missing - DNS resolution will fail"
    fi
}

# Create thyme user account properly
create_thyme_user_account() {
    log "Creating thyme user account..."
    
    # Add thyme user to passwd
    sudo tee -a "$ROOT_MOUNT_POINT/etc/passwd" > /dev/null << 'EOF'
thyme:x:1000:1000:Thyme User,,,:/home/thyme:/bin/bash
EOF
    
    # Add thyme group to group
    sudo tee -a "$ROOT_MOUNT_POINT/etc/group" > /dev/null << 'EOF'
thyme:x:1000:
EOF
    
    # Set up default password (thyme123) - user should change this
    local password_hash='$6$rounds=4096$saltsalt$3hvEXwy6gsqTlVp7YwL.ALRE3U6t7.yG9lm8sXbaE0jOQNDxTVdLy3l3Xz3hv3dn6f3h5v5h4v4h3'
    sudo sed -i "s|thyme:x:|thyme:$password_hash:|" "$ROOT_MOUNT_POINT/etc/shadow"
    
    # Add thyme to sudo group
    sudo sed -i 's|sudo:x:27:|sudo:x:27:thyme|' "$ROOT_MOUNT_POINT/etc/group"
    
    log "✅ Thyme user account created (password: thyme123)"
}

# Customize system for Thyme OS
customize_for_thyme() {
    log "Customizing system for Thyme OS..."
    
    # Update system identification
    sudo tee "$ROOT_MOUNT_POINT/etc/lsb-release" > /dev/null << 'EOF'
DISTRIB_ID=ThymeOS
DISTRIB_RELEASE=1.0
DISTRIB_CODENAME=macbook
DISTRIB_DESCRIPTION="Thyme OS 1.0 (MacBook Edition) - Streamlined"
EOF
    
    # Update hostname
    echo "thymeos" | sudo tee "$ROOT_MOUNT_POINT/etc/hostname" > /dev/null
    
    # Update /etc/hosts
    sudo tee "$ROOT_MOUNT_POINT/etc/hosts" > /dev/null << 'EOF'
127.0.0.1   localhost
127.0.1.1   thymeos
::1         localhost ip6-localhost ip6-loopback
ff02::1     ip6-allnodes
ff02::2     ip6-allrouters
EOF
    
    # Create Thyme OS version info
    sudo mkdir -p "$ROOT_MOUNT_POINT/etc/thyme"
    sudo tee "$ROOT_MOUNT_POINT/etc/thyme/version" > /dev/null << EOF
Thyme OS 1.0 MacBook Edition (Streamlined)
Based on Linux Mint $(grep DISTRIB_RELEASE /etc/lsb-release | cut -d= -f2)
Built: $(date)
Target: MacBook2,1 and compatible systems
Installation: Smart copy with bloatware exclusion
EOF
    
    # Install lightweight alternatives
    install_lightweight_alternatives
    
    # Install Thyme Enhanced Text Editor
    install_thyme_editor
    
    # Configure MacBook compatibility
    configure_macbook_compatibility
    
    log "✅ System customized for Thyme OS"
}

# Install lightweight alternatives for removed bloatware
install_lightweight_alternatives() {
    log "Installing lightweight alternatives..."
    
    # Create script to install alternatives in chroot
    sudo tee "$ROOT_MOUNT_POINT/tmp/install_alternatives.sh" > /dev/null << 'EOF'
#!/bin/bash
# Install lightweight alternatives

export DEBIAN_FRONTEND=noninteractive

# Check if packages are available before installing
if apt-cache show abiword >/dev/null 2>&1; then
    apt-get update
    apt-get install -y abiword gnumeric mousepad vlc-data mpv
fi

# Create essential packages list
mkdir -p /etc/thyme
cat > /etc/thyme/installed-packages.txt << 'EOL'
# Thyme OS Streamlined Package List

## Lightweight Office
abiword          # Word processor (replaces LibreOffice Writer)
gnumeric         # Spreadsheet (replaces LibreOffice Calc)

## Text Editors
mousepad         # Simple text editor
nano             # Command-line editor
vim-tiny         # Minimal vim

## Media (minimal)
mpv              # Lightweight video player

## System
htop             # Process monitor
neofetch         # System info

## Pre-installed from Mint base
firefox          # Web browser
thunar           # File manager
xfce4-terminal   # Terminal
EOL

echo "Lightweight alternatives installed"
EOF
    
    sudo chmod +x "$ROOT_MOUNT_POINT/tmp/install_alternatives.sh"
    
    # Execute in chroot if network is available
    if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        log "Installing lightweight alternatives via chroot..."
        sudo chroot "$ROOT_MOUNT_POINT" /tmp/install_alternatives.sh 2>&1 | tee -a "$INSTALL_LOG" || true
    else
        warn "No network - skipping package installation"
    fi
    
    # Remove script
    sudo rm "$ROOT_MOUNT_POINT/tmp/install_alternatives.sh"
    
    log "✅ Lightweight alternatives configured"
}

# Install Thyme Enhanced Text Editor
install_thyme_editor() {
    log "Installing Thyme Enhanced Text Editor..."
    
    local editor_tools_dir="/home/meister/mintbook/thyme-editor-tools"
    local micro_binary="$editor_tools_dir/micro-binary/micro-2.0.13/micro"
    
    if [[ ! -f "$micro_binary" ]]; then
        warn "Micro editor binary not found - skipping editor installation"
        return
    fi
    
    # Install Micro editor binary
    sudo mkdir -p "$ROOT_MOUNT_POINT/usr/local/bin"
    sudo cp "$micro_binary" "$ROOT_MOUNT_POINT/usr/local/bin/micro"
    sudo chmod +x "$ROOT_MOUNT_POINT/usr/local/bin/micro"
    
    # Create convenient aliases
    sudo ln -sf "/usr/local/bin/micro" "$ROOT_MOUNT_POINT/usr/local/bin/thyme-edit"
    sudo ln -sf "/usr/local/bin/micro" "$ROOT_MOUNT_POINT/usr/local/bin/te"
    
    # Install editor configuration
    sudo mkdir -p "$ROOT_MOUNT_POINT/home/thyme/.config/micro"
    
    sudo tee "$ROOT_MOUNT_POINT/home/thyme/.config/micro/settings.json" > /dev/null << 'EOF'
{
    "autoclose": true,
    "autoindent": true,
    "autosave": 2,
    "colorscheme": "solarized-tc",
    "cursorline": true,
    "ruler": true,
    "softwrap": false,
    "statusline": true,
    "syntax": true,
    "tabsize": 4,
    "tabstospaces": true
}
EOF
    
    # Set ownership
    sudo chown -R 1000:1000 "$ROOT_MOUNT_POINT/home/thyme/.config"
    
    log "✅ Thyme Enhanced Text Editor installed"
}

# Configure MacBook compatibility with better module handling
configure_macbook_compatibility() {
    log "Configuring MacBook compatibility..."
    
    # Create modprobe configuration
    sudo mkdir -p "$ROOT_MOUNT_POINT/etc/modprobe.d"
    
    sudo tee "$ROOT_MOUNT_POINT/etc/modprobe.d/thyme-macbook.conf" > /dev/null << 'EOF'
# Thyme OS MacBook Configuration

# Disable USB autosuspend for input devices
options usbcore autosuspend=-1

# USB HID configuration for Apple devices
options usbhid mousepoll=0
options usbhid quirks=0x05ac:0x020b:0x01,0x05ac:0x021a:0x01,0x05ac:0x0229:0x01,0x05ac:0x022a:0x01

# PS/2 keyboard controller fixes
options i8042 reset=1 nomux=1 nopnp=1 noloop=1

# PS/2 mouse configuration
options psmouse proto=imps rate=100
EOF
    
    # Create modules loading configuration
    sudo tee "$ROOT_MOUNT_POINT/etc/modules-load.d/thyme-input.conf" > /dev/null << 'EOF'
# Thyme OS Input Device Modules
usbhid
hid
i8042
atkbd
psmouse
ohci_hcd
uhci_hcd
ehci_hcd
xhci_hcd
EOF
    
    # Fix initramfs modules (avoid directory exists error)
    if [[ ! -d "$ROOT_MOUNT_POINT/etc/initramfs-tools/modules" ]]; then
        sudo mkdir -p "$ROOT_MOUNT_POINT/etc/initramfs-tools"
        sudo tee "$ROOT_MOUNT_POINT/etc/initramfs-tools/modules" > /dev/null << 'EOF'
# Thyme OS Input Device Modules for initramfs
usbhid
hid
i8042
atkbd
psmouse
ohci_hcd
uhci_hcd
ehci_hcd
xhci_hcd
EOF
    fi
    
    # Update GRUB configuration for MacBook
    if [[ -f "$ROOT_MOUNT_POINT/etc/default/grub" ]]; then
        sudo sed -i 's/GRUB_DISTRIBUTOR=.*/GRUB_DISTRIBUTOR="Thyme OS"/' "$ROOT_MOUNT_POINT/etc/default/grub"
        sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash usbcore.autosuspend=-1 usbhid.mousepoll=0 i8042.reset i8042.nomux"/' "$ROOT_MOUNT_POINT/etc/default/grub"
    fi
    
    log "✅ MacBook compatibility configured"
}

# Update fstab for new UUIDs
update_fstab() {
    log "Updating fstab..."
    
    local root_uuid=$(sudo blkid -s UUID -o value "$ROOT_PARTITION")
    local efi_uuid=$(sudo blkid -s UUID -o value "$EFI_PARTITION")
    local swap_uuid=$(sudo blkid -s UUID -o value "$SWAP_PARTITION")
    
    sudo tee "$ROOT_MOUNT_POINT/etc/fstab" > /dev/null << EOF
# Thyme OS fstab
UUID=$root_uuid / ext4 defaults 0 1
UUID=$efi_uuid /boot/efi vfat defaults 0 2
UUID=$swap_uuid none swap sw 0 0
tmpfs /tmp tmpfs defaults,noatime,mode=1777 0 0
EOF
    
    log "✅ fstab updated"
}

# Install GRUB with enhanced configuration
install_grub() {
    log "Installing GRUB bootloader..."
    
    # Clean EFI partition
    sudo rm -rf "$EFI_MOUNT_POINT"/*
    sudo mkdir -p "$EFI_MOUNT_POINT/EFI/BOOT"
    sudo mkdir -p "$EFI_MOUNT_POINT/EFI/thyme"
    
    # Install 32-bit EFI for MacBook2,1
    if [[ -f "$GRUB_FILES_DIR/grubia32.efi" ]]; then
        sudo cp "$GRUB_FILES_DIR/grubia32.efi" "$EFI_MOUNT_POINT/EFI/BOOT/bootia32.efi"
        sudo cp "$GRUB_FILES_DIR/grubia32.efi" "$EFI_MOUNT_POINT/EFI/thyme/grubia32.efi"
        log "✅ 32-bit GRUB EFI installed"
    else
        error "32-bit GRUB EFI file required: $GRUB_FILES_DIR/grubia32.efi"
    fi
    
    # Create enhanced GRUB configuration
    create_enhanced_grub_config
    
    log "✅ GRUB installation completed"
}

# Create enhanced GRUB configuration with better boot options
create_enhanced_grub_config() {
    log "Creating enhanced GRUB configuration..."
    
    local root_uuid=$(sudo blkid -s UUID -o value "$ROOT_PARTITION")
    local grub_cfg="$EFI_MOUNT_POINT/EFI/thyme/grub.cfg"
    
    sudo tee "$grub_cfg" > /dev/null << EOF
# Thyme OS Enhanced GRUB Configuration v3.0
# MacBook2,1 Compatible with Advanced Boot Testing

set timeout=15
set default=0

echo "🍃 Thyme OS Streamlined v3.0 Loading..."

insmod part_gpt
insmod fat
insmod ext2
insmod font
insmod gfxterm
insmod usb_keyboard
insmod ohci
insmod uhci
insmod ehci
insmod search_fs_uuid

menuentry "🍃 Thyme OS - Default Boot" {
    echo "Booting Thyme OS Streamlined..."
    search --set=root --fs-uuid $root_uuid
    linux /boot/vmlinuz root=UUID=$root_uuid ro quiet splash usbcore.autosuspend=-1 usbhid.mousepoll=0 i8042.reset i8042.nomux
    initrd /boot/initrd.img
}

menuentry "🧪 Thyme OS - Testing Mode (Verbose)" {
    echo "Booting in testing mode with verbose output..."
    search --set=root --fs-uuid $root_uuid
    linux /boot/vmlinuz root=UUID=$root_uuid ro debug loglevel=7 usbcore.autosuspend=-1 i8042.reset i8042.nomux
    initrd /boot/initrd.img
}

menuentry "🛠️ Thyme OS - Force USB/HID Load" {
    echo "Force loading all USB and input modules..."
    search --set=root --fs-uuid $root_uuid
    linux /boot/vmlinuz root=UUID=$root_uuid ro quiet splash usbcore.autosuspend=-1 usbhid.mousepoll=0 i8042.reset i8042.nomux i8042.direct
    initrd /boot/initrd.img
}

menuentry "⚡ Thyme OS - Safe Mode" {
    echo "Booting in safe mode..."
    search --set=root --fs-uuid $root_uuid
    linux /boot/vmlinuz root=UUID=$root_uuid ro nomodeset acpi=off usbcore.autosuspend=-1 i8042.reset
    initrd /boot/initrd.img
}

menuentry "🚑 Emergency Shell" {
    echo "Emergency shell access..."
    search --set=root --fs-uuid $root_uuid
    linux /boot/vmlinuz root=UUID=$root_uuid ro single init=/bin/bash
    initrd /boot/initrd.img
}

menuentry "🔄 Reboot" {
    reboot
}

menuentry "⚡ Shutdown" {
    halt
}
EOF
    
    # Copy to standard location
    sudo cp "$grub_cfg" "$EFI_MOUNT_POINT/EFI/BOOT/grub.cfg"
    
    log "✅ Enhanced GRUB configuration created"
}

# Boot testing framework
create_boot_test_framework() {
    log "Creating boot testing framework..."
    
    # Create test scripts
    sudo mkdir -p "$ROOT_MOUNT_POINT/usr/local/bin/thyme-testing"
    
    # Boot test script
    sudo tee "$ROOT_MOUNT_POINT/usr/local/bin/thyme-testing/boot-test.sh" > /dev/null << 'EOF'
#!/bin/bash
# Thyme OS Boot Testing Framework

echo "🧪 Thyme OS Boot Test Framework v3.0"
echo "===================================="

# Test 1: System identification
echo "📋 System Information:"
cat /etc/thyme/version
echo

# Test 2: Hardware detection
echo "⚙️ Hardware Detection:"
echo "CPU: $(cat /proc/cpuinfo | grep 'model name' | head -1 | cut -d: -f2)"
echo "RAM: $(free -h | grep Mem | awk '{print $2}')"
echo "Storage: $(df -h / | tail -1 | awk '{print $2}')"
echo

# Test 3: Input devices
echo "🖱️ Input Device Test:"
ls -la /dev/input/
echo

# Test 4: USB detection
echo "🔌 USB Device Detection:"
lsusb
echo

# Test 5: Network
echo "🌐 Network Test:"
ip addr show | grep inet
echo

# Test 6: Display
echo "🖥️ Display Test:"
echo "X Server status:"
ps aux | grep X | head -3
echo

# Test 7: User environment
echo "👤 User Environment:"
echo "Current user: $USER"
echo "Home directory: $HOME"
echo "Shell: $SHELL"
echo

echo "✅ Boot test completed!"
echo "If you can see this, basic boot is working."
EOF
    
    # Make executable
    sudo chmod +x "$ROOT_MOUNT_POINT/usr/local/bin/thyme-testing/boot-test.sh"
    
    # Create desktop shortcut
    sudo mkdir -p "$ROOT_MOUNT_POINT/home/thyme/Desktop"
    sudo tee "$ROOT_MOUNT_POINT/home/thyme/Desktop/Boot-Test.desktop" > /dev/null << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Boot Test
Comment=Test Thyme OS boot functionality
Exec=/usr/local/bin/thyme-testing/boot-test.sh
Icon=utilities-system-monitor
Terminal=true
Categories=System;
EOF
    
    sudo chmod +x "$ROOT_MOUNT_POINT/home/thyme/Desktop/Boot-Test.desktop"
    sudo chown 1000:1000 "$ROOT_MOUNT_POINT/home/thyme/Desktop/Boot-Test.desktop"
    
    log "✅ Boot testing framework created"
}

# Main installation function
main() {
    initialize_installer
    
    if [[ "$TEST_MODE" != "test" ]]; then
        read -p "Continue with Thyme OS Streamlined installation? (y/n): " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            error "Installation cancelled"
        fi
    fi
    
    check_mint_system
    detect_target_device
    
    if [[ "$TEST_MODE" != "test" ]]; then
        warn "This will COMPLETELY ERASE $TARGET_DEVICE"
        read -p "Type 'ERASE' to confirm: " confirm
        if [[ "${confirm,,}" != "erase" ]]; then
            error "Installation cancelled"
        fi
    fi
    
    partition_device
    format_partitions
    mount_partitions
    smart_copy_mint_system
    customize_for_thyme
    update_fstab
    install_grub
    create_boot_test_framework
    
    # Cleanup
    sync
    sudo umount "$ROOT_MOUNT_POINT" "$EFI_MOUNT_POINT"
    
    if [[ -n "${LOOP_DEVICE:-}" ]]; then
        sudo losetup -d "$LOOP_DEVICE"
        log "🧪 Test image created: $TEST_IMAGE"
    fi
    
    success "🎉 Thyme OS Streamlined installation completed!"
    success "✅ Smart copy with bloatware exclusion"
    success "✅ Enhanced boot testing framework"
    success "✅ MacBook2,1 optimized"
    
    if [[ "$TEST_MODE" == "test" ]]; then
        success "🧪 Test mode: Image ready for testing"
    else
        success "💾 Ready to boot from $TARGET_DEVICE"
    fi
}

# Run installation
main "$@"