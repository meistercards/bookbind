# MacBook Hardware Compatibility Features

## Input Handling

### Right-Click Support
- **Implementation**: Alt + Click + Release
- **Rationale**: Avoids interference with Ctrl+Click multi-selection
- **Target**: Single-button trackpad MacBooks (MacBook2,1, etc.)
- **Configuration**: System-wide via xbindkeys + xdotool

### Keyboard Mapping
- **Cmd key mapping** to Ctrl for familiar shortcuts
- **Function key handling** for brightness/volume
- **Power button behavior** customization

### Trackpad Features
- **Scroll simulation** via two-finger motion detection
- **Gesture support** where hardware allows
- **Acceleration curves** optimized for MacBook trackpads

## Hardware Optimization
- **Memory management** for 2GB systems
- **Thermal monitoring** and fan control
- **Battery optimization** for older batteries
- **Display calibration** for MacBook LCD panels

## Implementation Notes
- All features must work "out of the box" 
- No network dependencies
- Graceful fallbacks for missing hardware
- User-configurable via simple config files