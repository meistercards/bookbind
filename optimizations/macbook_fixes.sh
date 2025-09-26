#!/bin/bash
# BookBind MacBook Hardware Fixes
# Specific fixes for MacBook 2006-2009 hardware compatibility
# Based on mintbook thyme_installer.sh MacBook configuration

# Configure MacBook-specific hardware fixes
configure_macbook_hardware_fixes() {
    local root_mount="$1"
    
    log "Configuring MacBook hardware fixes..."
    
    # Configure input device fixes
    configure_input_device_fixes "$root_mount"
    
    # Configure EFI and boot fixes
    configure_efi_boot_fixes "$root_mount"
    
    # Configure graphics and display fixes
    configure_graphics_fixes "$root_mount"
    
    # Configure audio fixes
    configure_audio_fixes "$root_mount"
    
    # Configure network device fixes
    configure_network_fixes "$root_mount"
    
    # Configure power management fixes
    configure_power_management_fixes "$root_mount"
    
    log "✅ MacBook hardware fixes configured"
}

# Configure input device fixes for MacBook keyboard and trackpad
configure_input_device_fixes() {
    local root_mount="$1"
    
    log "Configuring MacBook input device fixes..."
    
    # Create modprobe configuration for input devices
    sudo mkdir -p "$root_mount/etc/modprobe.d"
    sudo tee "$root_mount/etc/modprobe.d/99-bookbind-macbook.conf" > /dev/null << 'EOF'
# BookBind MacBook Input Device Configuration
# Fixes for MacBook 2006-2009 keyboard and trackpad issues

# Disable USB autosuspend for input devices (prevents keyboard/mouse freezing)
options usbcore autosuspend=-1

# USB HID configuration for Apple devices
options usbhid mousepoll=0
# Quirks for specific MacBook models
options usbhid quirks=0x05ac:0x020b:0x01,0x05ac:0x021a:0x01,0x05ac:0x0229:0x01,0x05ac:0x022a:0x01

# PS/2 controller fixes for internal keyboard/trackpad
options i8042 reset=1 nomux=1 nopnp=1 noloop=1 direct=1

# PS/2 mouse configuration for trackpad
options psmouse proto=imps rate=100 resetafter=5

# Apple keyboard specific fixes
options hid_apple fnmode=2 iso_layout=0
EOF
    
    # Create udev rules for MacBook input devices
    sudo mkdir -p "$root_mount/etc/udev/rules.d"
    sudo tee "$root_mount/etc/udev/rules.d/99-bookbind-macbook-input.rules" > /dev/null << 'EOF'
# BookBind MacBook Input Device Rules

# Apple keyboard power management
SUBSYSTEM=="usb", ATTR{idVendor}=="05ac", ATTR{idProduct}=="020*", ATTR{power/autosuspend}="-1"
SUBSYSTEM=="usb", ATTR{idVendor}=="05ac", ATTR{idProduct}=="021*", ATTR{power/autosuspend}="-1"
SUBSYSTEM=="usb", ATTR{idVendor}=="05ac", ATTR{idProduct}=="022*", ATTR{power/autosuspend}="-1"

# Apple trackpad power management
SUBSYSTEM=="usb", ATTR{idVendor}=="05ac", ATTR{idProduct}=="030*", ATTR{power/autosuspend}="-1"

# Set trackpad sensitivity
KERNEL=="event*", ATTRS{name}=="*trackpad*", ENV{LIBINPUT_ACCEL_SPEED}="0.3"
KERNEL=="event*", ATTRS{name}=="*Trackpad*", ENV{LIBINPUT_ACCEL_SPEED}="0.3"
EOF
    
    # Configure X11 input for MacBook
    sudo mkdir -p "$root_mount/etc/X11/xorg.conf.d"
    sudo tee "$root_mount/etc/X11/xorg.conf.d/30-bookbind-macbook-input.conf" > /dev/null << 'EOF'
# BookBind MacBook Input Configuration

# Apple keyboard configuration
Section "InputClass"
    Identifier "Apple Keyboard"
    MatchProduct "Apple|Keyboard"
    Driver "libinput"
    Option "XkbOptions" "apple:alupckeys"
    Option "XkbModel" "apple"
EndSection

# Apple trackpad configuration
Section "InputClass"
    Identifier "Apple Trackpad" 
    MatchProduct "trackpad|Trackpad"
    Driver "libinput"
    Option "Tapping" "on"
    Option "TappingButtonMap" "lrm"
    Option "ClickMethod" "clickfinger"
    Option "DisableWhileTyping" "on"
    Option "AccelSpeed" "0.3"
    Option "NaturalScrolling" "true"
EndSection
EOF
    
    # Create keyboard fix service for function keys
    sudo tee "$root_mount/etc/systemd/system/bookbind-keyboard-fix.service" > /dev/null << 'EOF'
[Unit]
Description=BookBind MacBook Keyboard Fix
After=graphical.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/bookbind-keyboard-fix
RemainAfterExit=yes

[Install]
WantedBy=graphical.target
EOF
    
    # Create keyboard fix script
    sudo tee "$root_mount/usr/local/bin/bookbind-keyboard-fix" > /dev/null << 'EOF'
#!/bin/bash
# BookBind MacBook Keyboard Fix Script

# Enable function keys on Apple keyboards
if [[ -f /sys/module/hid_apple/parameters/fnmode ]]; then
    echo 2 > /sys/module/hid_apple/parameters/fnmode 2>/dev/null || true
fi

# Set keyboard repeat rate for better responsiveness
if command -v xset >/dev/null 2>&1; then
    export DISPLAY=:0
    xset r rate 200 25 2>/dev/null || true
fi

# Configure Alt key behavior for MacBook
if command -v setxkbmap >/dev/null 2>&1; then
    export DISPLAY=:0
    setxkbmap -option apple:alupckeys 2>/dev/null || true
fi
EOF
    
    sudo chmod +x "$root_mount/usr/local/bin/bookbind-keyboard-fix"
    sudo chroot "$root_mount" systemctl enable bookbind-keyboard-fix.service 2>/dev/null || true
    
    log "✅ MacBook input device fixes configured"
}

# Configure EFI and boot fixes for MacBook
configure_efi_boot_fixes() {
    local root_mount="$1"
    
    log "Configuring MacBook EFI and boot fixes..."
    
    # Create EFI boot fix script
    sudo tee "$root_mount/usr/local/bin/bookbind-efi-fix" > /dev/null << 'EOF'
#!/bin/bash
# BookBind MacBook EFI Boot Fixes

# Ensure EFI variables are accessible
if [[ -d /sys/firmware/efi ]]; then
    echo "EFI system detected"
    
    # Check if we're on 32-bit EFI (MacBook 2006-2009)
    if [[ -f /sys/firmware/efi/fw_platform_size ]]; then
        platform_size=$(cat /sys/firmware/efi/fw_platform_size)
        if [[ "$platform_size" == "32" ]]; then
            echo "32-bit EFI detected - MacBook compatibility mode active"
            
            # Ensure 32-bit EFI boot files are in place
            if [[ -f /boot/efi/EFI/BOOT/bootia32.efi ]]; then
                echo "32-bit EFI bootloader confirmed"
            else
                echo "Warning: 32-bit EFI bootloader missing"
            fi
        fi
    fi
else
    echo "Legacy BIOS system"
fi

# Fix EFI boot issues
if [[ -d /boot/efi ]]; then
    # Ensure proper permissions on EFI partition
    chmod 755 /boot/efi 2>/dev/null || true
    chmod -R 755 /boot/efi/EFI 2>/dev/null || true
fi
EOF
    
    sudo chmod +x "$root_mount/usr/local/bin/bookbind-efi-fix"
    
    # Create initramfs modules configuration for MacBook
    sudo mkdir -p "$root_mount/etc/initramfs-tools"
    sudo tee "$root_mount/etc/initramfs-tools/modules" > /dev/null << 'EOF'
# BookBind MacBook Boot Modules
# Essential modules for MacBook boot process

# USB and input device modules (critical for MacBook input)
usbhid
hid
hid_apple
hid_generic

# PS/2 controller modules for internal devices
i8042
atkbd
psmouse

# USB host controller modules
ohci_hcd
uhci_hcd
ehci_hcd
xhci_hcd

# Storage modules
usb_storage
uas

# Network modules for boot
e1000e
sky2
EOF
    
    log "✅ MacBook EFI and boot fixes configured"
}

# Configure graphics fixes for MacBook
configure_graphics_fixes() {
    local root_mount="$1"
    
    log "Configuring MacBook graphics fixes..."
    
    # Create X11 graphics configuration for MacBook
    sudo tee "$root_mount/etc/X11/xorg.conf.d/20-bookbind-macbook-graphics.conf" > /dev/null << 'EOF'
# BookBind MacBook Graphics Configuration
# Optimized for MacBook 2006-2009 Intel graphics

Section "Device"
    Identifier "Intel Graphics"
    Driver "intel"
    
    # Acceleration settings for old Intel graphics
    Option "AccelMethod" "sna"
    Option "TearFree" "true"
    Option "DRI" "3"
    
    # Backlight control
    Option "Backlight" "intel_backlight"
    
    # Stability settings for old hardware
    Option "TripleBuffer" "true"
    Option "ColorKey" "0x101010"
    Option "VideoKey" "0x101010"
EndSection

Section "Screen"
    Identifier "Default Screen"
    Device "Intel Graphics"
    Monitor "Default Monitor"
    DefaultDepth 24
    
    SubSection "Display"
        Depth 24
        Modes "1280x800" "1024x768" "800x600"
    EndSubSection
EndSection

Section "Monitor"
    Identifier "Default Monitor"
    
    # MacBook display settings
    DisplaySize 286 179  # 13.3" display size in mm
    
    # Gamma correction for MacBook displays
    Gamma 1.0 1.0 1.0
EndSection
EOF
    
    # Create backlight control script
    sudo tee "$root_mount/usr/local/bin/bookbind-backlight" > /dev/null << 'EOF'
#!/bin/bash
# BookBind MacBook Backlight Control

BACKLIGHT_PATH="/sys/class/backlight/intel_backlight"

if [[ ! -d "$BACKLIGHT_PATH" ]]; then
    echo "Intel backlight not available"
    exit 1
fi

get_brightness() {
    cat "$BACKLIGHT_PATH/brightness"
}

get_max_brightness() {
    cat "$BACKLIGHT_PATH/max_brightness"
}

set_brightness() {
    local value="$1"
    local max_brightness=$(get_max_brightness)
    
    if [[ "$value" -gt "$max_brightness" ]]; then
        value="$max_brightness"
    elif [[ "$value" -lt 1 ]]; then
        value=1
    fi
    
    echo "$value" > "$BACKLIGHT_PATH/brightness" 2>/dev/null || {
        echo "Error: Cannot set brightness (need root privileges)"
        exit 1
    }
}

case "$1" in
    "up")
        current=$(get_brightness)
        max_brightness=$(get_max_brightness)
        new_brightness=$((current + max_brightness / 10))
        set_brightness "$new_brightness"
        echo "Brightness: $(get_brightness)/$(get_max_brightness)"
        ;;
    "down")
        current=$(get_brightness)
        max_brightness=$(get_max_brightness)
        new_brightness=$((current - max_brightness / 10))
        set_brightness "$new_brightness"
        echo "Brightness: $(get_brightness)/$(get_max_brightness)"
        ;;
    "set")
        if [[ -n "$2" ]]; then
            set_brightness "$2"
            echo "Brightness set to: $(get_brightness)/$(get_max_brightness)"
        else
            echo "Usage: $0 set <value>"
        fi
        ;;
    *)
        echo "BookBind MacBook Backlight Control"
        echo "Usage: $0 {up|down|set <value>}"
        echo "Current: $(get_brightness)/$(get_max_brightness)"
        ;;
esac
EOF
    
    sudo chmod +x "$root_mount/usr/local/bin/bookbind-backlight"
    
    log "✅ MacBook graphics fixes configured"
}

# Configure audio fixes for MacBook
configure_audio_fixes() {
    local root_mount="$1"
    
    log "Configuring MacBook audio fixes..."
    
    # Create ALSA configuration for MacBook
    sudo tee "$root_mount/etc/modprobe.d/99-bookbind-macbook-audio.conf" > /dev/null << 'EOF'
# BookBind MacBook Audio Configuration

# Intel HDA audio fixes for MacBook
options snd-hda-intel model=macbook
options snd-hda-intel enable_msi=1
options snd-hda-intel power_save=0

# Prevent audio power management issues
options snd-hda-intel power_save_controller=N
EOF
    
    # Create PulseAudio configuration for MacBook
    sudo mkdir -p "$root_mount/etc/pulse/default.pa.d"
    sudo tee "$root_mount/etc/pulse/default.pa.d/bookbind-macbook.pa" > /dev/null << 'EOF'
# BookBind MacBook PulseAudio Configuration

# Load MacBook-specific modules
load-module module-switch-on-port-available

# Optimize for MacBook audio hardware
set-default-sink-volume 65536
set-default-source-volume 65536

# Prevent audio dropouts
load-module module-suspend-on-idle timeout=5
EOF
    
    log "✅ MacBook audio fixes configured"
}

# Configure network fixes for MacBook WiFi
configure_network_fixes() {
    local root_mount="$1"
    
    log "Configuring MacBook network fixes..."
    
    # Create WiFi power management fixes
    sudo tee "$root_mount/etc/modprobe.d/99-bookbind-macbook-wifi.conf" > /dev/null << 'EOF'
# BookBind MacBook WiFi Configuration

# Broadcom WiFi fixes (common in MacBooks)
options b43 qos=0
options b43legacy qos=0

# Intel WiFi fixes
options iwlwifi power_save=0 swcrypto=1
options iwl3945 swcrypto=1

# Disable WiFi power management to prevent disconnections
options mac80211 ieee80211_default_rc_algo=minstrel_ht
EOF
    
    # Create NetworkManager configuration for MacBook
    sudo mkdir -p "$root_mount/etc/NetworkManager/conf.d"
    sudo tee "$root_mount/etc/NetworkManager/conf.d/99-bookbind-macbook.conf" > /dev/null << 'EOF'
# BookBind MacBook NetworkManager Configuration

[main]
# Optimize for MacBook WiFi hardware
no-auto-default=*

[device]
# Disable WiFi power saving
wifi.powersave=2
wifi.scan-rand-mac-address=no

[connection]
# Optimize connection handling
ipv6.method=ignore
connection.autoconnect-retries=3
EOF
    
    log "✅ MacBook network fixes configured"
}

# Configure power management fixes
configure_power_management_fixes() {
    local root_mount="$1"
    
    log "Configuring MacBook power management fixes..."
    
    # Create power management configuration
    sudo mkdir -p "$root_mount/etc/systemd/sleep.conf.d"
    sudo tee "$root_mount/etc/systemd/sleep.conf.d/99-bookbind-macbook.conf" > /dev/null << 'EOF'
# BookBind MacBook Sleep Configuration

[Sleep]
# Use mem sleep state for MacBook compatibility
SuspendState=mem

# Disable problematic sleep modes
AllowHibernation=no
AllowSuspendThenHibernate=no
AllowHybridSleep=no
EOF
    
    # Create TLP configuration for MacBook (if TLP is installed)
    sudo mkdir -p "$root_mount/etc/tlp.d"
    sudo tee "$root_mount/etc/tlp.d/99-bookbind-macbook.conf" > /dev/null << 'EOF'
# BookBind MacBook TLP Configuration

# CPU frequency scaling
CPU_SCALING_GOVERNOR_ON_AC=ondemand
CPU_SCALING_GOVERNOR_ON_BAT=conservative

# Disable USB autosuspend for input devices
USB_BLACKLIST="05ac:020b 05ac:021a 05ac:0229 05ac:022a"

# WiFi power management
WIFI_PWR_ON_AC=off
WIFI_PWR_ON_BAT=off

# Audio power management
SOUND_POWER_SAVE_ON_AC=0
SOUND_POWER_SAVE_ON_BAT=1
EOF
    
    log "✅ MacBook power management fixes configured"
}

# Validate MacBook hardware fixes
validate_macbook_fixes() {
    local root_mount="$1"
    
    log "Validating MacBook hardware fixes..."
    
    # Check modprobe configurations
    if [[ -f "$root_mount/etc/modprobe.d/99-bookbind-macbook.conf" ]]; then
        log "✅ MacBook modprobe configuration installed"
    else
        error "❌ MacBook modprobe configuration missing"
    fi
    
    # Check X11 configurations
    if [[ -f "$root_mount/etc/X11/xorg.conf.d/30-bookbind-macbook-input.conf" ]]; then
        log "✅ MacBook X11 input configuration installed"
    else
        error "❌ MacBook X11 input configuration missing"
    fi
    
    # Check keyboard fix service
    if [[ -f "$root_mount/etc/systemd/system/bookbind-keyboard-fix.service" ]]; then
        log "✅ MacBook keyboard fix service installed"
    else
        error "❌ MacBook keyboard fix service missing"
    fi
    
    # Check sleep configuration
    if [[ -f "$root_mount/etc/systemd/sleep.conf.d/99-bookbind-macbook.conf" ]]; then
        log "✅ MacBook sleep configuration installed"
    else
        error "❌ MacBook sleep configuration missing"
    fi
    
    log "✅ MacBook hardware fix validation complete"
}