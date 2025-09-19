---
name: Hardware Compatibility
about: Report hardware testing results or request support for new MacBook model
title: '[HARDWARE] '
labels: ['hardware', 'compatibility']
assignees: ''

---

## 🖥️ MacBook Information
**Model Identifier**: (e.g., MacBook2,1 - find with `system_profiler SPHardwareDataType`)
**Marketing Name**: (e.g., "MacBook (13-inch, Late 2006)")
**Year**: 
**CPU**: 
**RAM**: 
**Graphics**: 
**Wi-Fi**: 

## 🔍 EFI Information
**EFI Type**: 
- [ ] 32-bit (check `/sys/firmware/efi/fw_platform_size`)
- [ ] 64-bit
- [ ] Unknown/Need help determining

## 🧪 Testing Status
- [ ] **Requesting Testing** - I have this hardware and want to test
- [ ] **Reporting Results** - I have test results to share
- [ ] **Requesting Support** - I need help with this hardware

## 🛠️ Bootstrap Method Testing

### SSD Swap Method
- [ ] ✅ Tested - Works
- [ ] ❌ Tested - Failed  
- [ ] ⏸️ Not tested yet
- **Details**: 

### macOS Installer Method  
- [ ] ✅ Tested - Works
- [ ] ❌ Tested - Failed
- [ ] ⏸️ Not tested yet
- [ ] 📋 No macOS available
- **macOS Version**: 
- **Details**: 

### Network Installation
- [ ] ✅ Tested - Works
- [ ] ❌ Tested - Failed
- [ ] ⏸️ Not tested yet
- **Details**: 

## ⚙️ Hardware Feature Testing

### Working Features
- [ ] Display (resolution, brightness)
- [ ] Wi-Fi connectivity
- [ ] Ethernet
- [ ] Audio (speakers, headphones)
- [ ] Trackpad (basic, gestures)
- [ ] Keyboard (including function keys)
- [ ] USB ports
- [ ] Sleep/wake functionality
- [ ] Battery monitoring
- [ ] Fan control

### Issues Found
List any hardware features that don't work properly:
- 
- 

## 📊 System Performance
**Boot Time**: 
**Memory Usage (idle)**: 
**Thermal Behavior**: (Cool/Warm/Hot under normal use)
**Fan Noise**: (Quiet/Normal/Loud)

## 🔧 Installation Experience
**Which bootstrap method worked best?**: 
**Installation time**: 
**Difficulty level** (1-10): 
**Would you recommend this method?**: 

## 📝 Additional Notes
Any other observations, issues, or success stories:

## 📎 Log Files
If reporting issues, please attach relevant log files:
- Installation logs
- System logs (`dmesg`, `/var/log/syslog`)
- Hardware detection output

---

**Community Impact**: Your testing helps other MacBook users! Results will be added to our [hardware compatibility matrix](docs/hardware/compatibility_matrix.md).
