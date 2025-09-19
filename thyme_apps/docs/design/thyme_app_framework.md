# ThymeOS Application Framework Design

## Core Principles

### 1. Memory Efficiency
- Target: <100MB total for all applications combined
- Shared libraries between applications
- Lazy loading of features
- Optimized for MacBook2,1 (2GB RAM)

### 2. MacBook Hardware Integration
- **Right-click**: Alt+Click+Release (no Ctrl interference)
- **Keyboard shortcuts**: Optimized for MacBook layout
- **Single-button trackpad**: Full gesture support
- **Low-power operation**: Battery-conscious design

### 3. Performance Goals
- **Startup time**: <2 seconds for any application
- **Memory footprint**: ThymeEdit <20MB, ThymeCalc <50MB
- **File operations**: Instant for files <10MB
- **Responsiveness**: 60fps UI on Intel GMA 950

## Application Architecture

### Shared Framework Components
```
thyme_apps/shared/
├── ui/           # Common UI elements and themes
├── utils/        # File I/O, memory management
├── themes/       # Consistent visual design
└── macbook_compat/ # Hardware-specific features
```

### Individual Applications
```
thyme_edit/       # Advanced text editor (nano replacement)
thyme_calc/       # Spreadsheet with macro support
thyme_word/       # Future: Word processor
thyme_present/    # Future: Presentation software
```

## Technology Stack

### Primary: Qt6 + C++
- **Why**: Native performance, cross-platform, mature
- **Memory usage**: Excellent for resource-constrained systems
- **Integration**: Perfect XFCE compatibility
- **Development**: Large community, excellent documentation

### Build System
- **CMake**: Modern, cross-platform build system
- **Ninja**: Fast incremental builds
- **Git**: Version control with feature branches

## Design Language

### Visual Identity
- **Colors**: Earth tones (thyme green primary)
- **Typography**: Clear, readable fonts for small screens
- **Icons**: Minimalist, high contrast for vintage displays
- **Layout**: Clean, uncluttered interface

### Interaction Patterns
- **Single-click**: Primary actions
- **Alt+Click**: Right-click menu (MacBook compatible)
- **Keyboard-first**: Extensive shortcuts for efficiency
- **Contextual**: Smart menus based on current action

## Development Workflow

### Phase 1: Foundation (Current)
1. ✅ Directory structure created
2. ⏳ Qt6 development environment setup
3. ⏳ Shared framework creation
4. ⏳ ThymeEdit prototype

### Quality Standards
- **Code coverage**: >80% for core functions
- **Documentation**: Complete API docs
- **Performance**: Profiling on MacBook2,1 hardware
- **Testing**: Unit tests + integration tests on target hardware

## File Format Strategy

### Native Formats
- **ThymeEdit**: .thyme (enhanced text with metadata)
- **ThymeCalc**: .thymesheet (optimized spreadsheet format)

### Compatibility Formats
- **Text**: UTF-8, ASCII, common encodings
- **Spreadsheet**: Excel (.xlsx), CSV, OpenDocument
- **Import/Export**: Seamless conversion utilities

This framework ensures all ThymeOS applications share common DNA while being perfectly optimized for MacBook hardware constraints.