# Thyme OS Release Features

## Core Installation & Boot Management
- [x] SSD installer with GRUB support (`thyme_os_ssd_installer.sh`)
- [ ] SSD installer with rEFInd support (future: macOS version)
- [ ] Target Disk Mode installer for MacBook series
- [ ] Netboot infrastructure (BSDP/TFTP/NFS/HTTP)

## User Experience & Setup
- [ ] User setup choice: during installation OR first boot
- [ ] Username, password, computer name configuration
- [ ] Desktop environment installation (XFCE for MacBook compatibility)
- [ ] First-boot setup wizard

## Memory Management & System Stability
- [ ] Dynamic memory freezing interface
- [ ] Memory pressure detection and alerts
- [ ] Auto-process management for low-RAM systems
- [ ] Swap optimization for older MacBooks (MacBook2,1 targeted)
- [ ] System stability monitoring

## Essential Applications
- [ ] Word processor (LibreOffice Writer or equivalent)
- [ ] Spreadsheet application (LibreOffice Calc or equivalent)
- [ ] Image editing (GIMP or lightweight alternative)
- [ ] Web browser (Firefox/Chromium)
- [ ] Email client (Thunderbird or lightweight alternative)
- [ ] Terminal emulator with good defaults

## MacBook Hardware Compatibility
- [ ] Right-click support via Ctrl+Click (xbindkeys + xdotool)
- [ ] Single-button trackpad configuration
- [ ] MacBook keyboard mapping optimizations
- [ ] Power management for older MacBook hardware

## User Documentation & Terminal Guide
- [ ] Terminal basics documentation covering:
  - `ps aux` - Process monitoring
  - `lsblk` - Block device listing
  - `grep` - Text searching
  - `|` - Piping commands
  - `cd` - Directory navigation
  - `nano` - Text editing
  - `dd` - Disk operations
  - `ssh` - Remote access
  - `scp` - Secure file transfer
  - `sudo` - Administrative privileges
  - `ip addr` - Network configuration
- [ ] User settings and admin guide
- [ ] Basic system administration walkthrough

## Target Hardware
- Primary: MacBook2,1 (Core 2 Duo, 2GB RAM)
- Secondary: Similar vintage MacBooks with limited RAM
- Boot methods: Target Disk Mode, SSD installation, netboot

## Installation Methods Priority
1. **SSD Installer** (current focus) - Linux host
2. **Target Disk Mode** (backup method) - FireWire required
3. **macOS SSD Installer** (future) - macOS host
4. **Netboot** (infrastructure ready) - Complex setup

## Notes
- Memory management is critical for low-RAM systems
- Documentation should be accessible to non-technical users
- Terminal guide should build confidence in command-line usage
- Applications should be lightweight but functional equivalents