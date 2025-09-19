#!/bin/bash
# Thyme OS Drive Wiper
# Completely wipes a drive clean before installation

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# Display header
echo -e "${PURPLE}"
cat << 'EOF'
🧹 Thyme OS Drive Wiper 🧹
=========================

Completely wipes a drive clean by:
• Unmounting all partitions
• Wiping partition table
• Overwriting filesystem signatures  
• Zeroing boot sectors
• Creating clean state for installation

⚠️  DESTRUCTIVE OPERATION ⚠️
This will PERMANENTLY ERASE ALL DATA

EOF
echo -e "${NC}"

# Enhanced device detection (same as installer)
detect_target_device() {
    log "Detecting available storage devices..."
    
    echo
    echo "🔍 Available storage devices:"
    echo "============================"
    
    local system_disk=$(findmnt -n -o SOURCE / | sed 's/[0-9]*$//')
    local candidate_devices=()
    local device_info=()
    
    echo "System disk (protected): $system_disk"
    echo
    
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
        local current_partitions=""
        
        # Check if it's USB
        if udevadm info --query=property --name="$device" 2>/dev/null | grep -q "ID_BUS=usb"; then
            is_usb="USB"
            vendor=$(udevadm info --query=property --name="$device" 2>/dev/null | grep "ID_VENDOR=" | cut -d= -f2 || echo "Unknown")
        fi
        
        # Get serial if available
        serial=$(udevadm info --query=property --name="$device" 2>/dev/null | grep "ID_SERIAL_SHORT=" | cut -d= -f2 || echo "N/A")
        
        # Check current partitions and their usage
        current_partitions=$(lsblk -n -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINT "$device" 2>/dev/null | tail -n +2 | head -10)
        
        # Validate device size 
        local size_bytes=$(lsblk -b -n -o SIZE "$device" 2>/dev/null | head -1)
        local size_gb=$((size_bytes / 1024 / 1024 / 1024))
        
        # Add to candidates
        candidate_devices+=("$device")
        device_info+=("$size|$model|$vendor|$is_usb|$serial|$current_partitions")
        
    done < <(lsblk -d -o NAME,MAJ:MIN,RM,SIZE,RO,TYPE,MOUNTPOINT,MODEL)
    
    if [[ ${#candidate_devices[@]} -eq 0 ]]; then
        error "No suitable target devices found."
    fi
    
    echo "Available devices to wipe:"
    echo "========================="
    for i in "${!candidate_devices[@]}"; do
        local device="${candidate_devices[$i]}"
        local info="${device_info[$i]}"
        
        local size=$(echo "$info" | cut -d'|' -f1)
        local model=$(echo "$info" | cut -d'|' -f2)
        local vendor=$(echo "$info" | cut -d'|' -f3)
        local is_usb=$(echo "$info" | cut -d'|' -f4)
        local serial=$(echo "$info" | cut -d'|' -f5)
        local current_partitions=$(echo "$info" | cut -d'|' -f6)
        
        echo "$((i+1)). $device"
        echo "   Size: $size"
        echo "   Model: ${model:-Unknown}"
        [[ -n "$vendor" ]] && echo "   Vendor: $vendor"
        [[ -n "$is_usb" ]] && echo "   Type: $is_usb"
        [[ "$serial" != "N/A" ]] && echo "   Serial: $serial"
        
        if [[ -n "$current_partitions" ]]; then
            echo "   📋 Current partitions:"
            while IFS= read -r part_line; do
                [[ -n "$part_line" ]] && echo "      $part_line"
            done <<< "$current_partitions"
        else
            echo "   📋 No current partitions"
        fi
        echo
    done
    
    # Device selection
    if [[ ${#candidate_devices[@]} -eq 1 ]]; then
        TARGET_DEVICE="${candidate_devices[0]}"
        warn "Auto-selected: $TARGET_DEVICE"
    else
        read -p "Select device number to WIPE (1-${#candidate_devices[@]}): " device_num
        
        if [[ "$device_num" -ge 1 ]] && [[ "$device_num" -le ${#candidate_devices[@]} ]]; then
            TARGET_DEVICE="${candidate_devices[$((device_num-1))]}"
        else
            error "Invalid selection"
        fi
    fi
    
    # Final safety check
    if [[ "$TARGET_DEVICE" == "$system_disk" ]]; then
        error "Cannot wipe system disk $TARGET_DEVICE"
    fi
    
    export TARGET_DEVICE
}

# Completely wipe the drive
wipe_drive() {
    local device="$TARGET_DEVICE"
    
    log "Starting complete drive wipe of $device..."
    
    # Step 1: Unmount all partitions
    log "Step 1: Unmounting all partitions..."
    for partition in $(lsblk -ln -o NAME "$device" 2>/dev/null | tail -n +2); do
        local part_path="/dev/$partition"
        if mountpoint -q "$part_path" 2>/dev/null; then
            log "Unmounting $part_path..."
            sudo umount "$part_path" 2>/dev/null || true
        fi
        
        # Also try with full device path prefix
        local full_part_path="$device$partition"
        if [[ "$partition" =~ ^[0-9]+$ ]]; then
            full_part_path="${device}${partition}"
        elif [[ "$partition" =~ ^p[0-9]+$ ]]; then
            full_part_path="${device}${partition}"
        fi
        
        if mountpoint -q "$full_part_path" 2>/dev/null; then
            log "Unmounting $full_part_path..."
            sudo umount "$full_part_path" 2>/dev/null || true
        fi
    done
    
    # Also try unmounting any partitions that might be named differently
    for part in "${device}"* "${device}p"*; do
        if [[ -b "$part" ]] && [[ "$part" != "$device" ]]; then
            if mountpoint -q "$part" 2>/dev/null; then
                log "Unmounting $part..."
                sudo umount "$part" 2>/dev/null || true
            fi
        fi
    done
    
    success "All partitions unmounted"
    
    # Step 2: Disable swap if any partition is swap
    log "Step 2: Disabling any swap partitions..."
    sudo swapoff "${device}"* 2>/dev/null || true
    sudo swapoff "${device}p"* 2>/dev/null || true
    success "Swap disabled"
    
    # Step 3: Wipe filesystem signatures
    log "Step 3: Wiping filesystem signatures..."
    sudo wipefs -af "$device" 2>/dev/null || true
    
    # Wipe signatures from all existing partitions
    for part in "${device}"* "${device}p"*; do
        if [[ -b "$part" ]] && [[ "$part" != "$device" ]]; then
            log "Wiping signatures from $part..."
            sudo wipefs -af "$part" 2>/dev/null || true
        fi
    done
    success "Filesystem signatures wiped"
    
    # Step 4: Zero out partition table and boot sectors
    log "Step 4: Zeroing partition table and boot sectors..."
    sudo dd if=/dev/zero of="$device" bs=1M count=100 2>/dev/null || true
    success "Boot sectors zeroed"
    
    # Step 5: Create fresh partition table
    log "Step 5: Creating fresh GPT partition table..."
    sudo parted "$device" --script mklabel gpt
    success "Fresh GPT partition table created"
    
    # Step 6: Force kernel to re-read partition table
    log "Step 6: Refreshing kernel partition table..."
    sudo partprobe "$device" 2>/dev/null || true
    sync
    sleep 2
    success "Partition table refreshed"
    
    # Step 7: Verify clean state
    log "Step 7: Verifying clean state..."
    local remaining_parts=$(lsblk -n -o NAME "$device" 2>/dev/null | tail -n +2 | wc -l)
    if [[ $remaining_parts -eq 0 ]]; then
        success "Drive is completely clean - no partitions remain"
    else
        warn "Some partitions may still be visible (kernel cache)"
        log "Current partition table:"
        lsblk "$device" || true
    fi
    
    success "🧹 Drive wipe completed successfully!"
    log "Device $device is now ready for fresh installation"
}

# Main function
main() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (use sudo)"
    fi
    
    detect_target_device
    
    echo
    warn "🚨 FINAL WARNING 🚨"
    warn "This will PERMANENTLY ERASE ALL DATA on $TARGET_DEVICE"
    warn "Including:"
    warn "• All files and folders"
    warn "• All partitions" 
    warn "• Boot sectors"
    warn "• Partition table"
    warn "• Filesystem signatures"
    echo
    warn "This action is IRREVERSIBLE!"
    echo
    
    read -p "Type 'WIPE' to confirm complete drive erasure: " confirm
    if [[ "${confirm}" != "WIPE" ]]; then
        error "Drive wipe cancelled"
    fi
    
    echo
    log "Starting drive wipe in 3 seconds..."
    sleep 1
    log "2..."
    sleep 1  
    log "1..."
    sleep 1
    
    wipe_drive
    
    echo
    success "🎉 Drive wipe completed successfully!"
    echo
    log "Next steps:"
    log "1. Run the Thyme OS installer: sudo ./thyme_installer.sh"
    log "2. The drive should now be detected cleanly"
    log "3. Installation should proceed without partition conflicts"
}

main "$@"