#!/bin/bash
# Thyme OS Enhanced Text Editor Installation Script
# Installs Micro editor as a nano alternative with syntax highlighting

set -e

EDITOR_DIR="/usr/local/bin"
CONFIG_DIR="/etc/thyme/editor"
USER_CONFIG_DIR="$HOME/.config/micro"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

info() {
    echo -e "${BLUE}[SETUP]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if running as root for system installation
check_permissions() {
    if [[ $EUID -ne 0 ]]; then
        warn "This script should be run as root for system-wide installation"
        warn "Running user installation instead..."
        EDITOR_DIR="$HOME/.local/bin"
        mkdir -p "$EDITOR_DIR"
    fi
}

# Install Micro editor binary
install_micro() {
    log "Installing Micro editor..."
    
    local script_dir="$(dirname "$(realpath "$0")")"
    local micro_binary="$script_dir/micro-binary/micro-2.0.13/micro"
    
    if [[ ! -f "$micro_binary" ]]; then
        echo "Error: Micro binary not found at $micro_binary"
        exit 1
    fi
    
    # Copy binary to system location
    cp "$micro_binary" "$EDITOR_DIR/micro"
    chmod +x "$EDITOR_DIR/micro"
    
    # Create convenient aliases
    ln -sf "$EDITOR_DIR/micro" "$EDITOR_DIR/thyme-edit" 2>/dev/null || true
    ln -sf "$EDITOR_DIR/micro" "$EDITOR_DIR/te" 2>/dev/null || true
    
    log "✅ Micro editor installed to $EDITOR_DIR"
}

# Create Thyme OS specific configuration
create_thyme_config() {
    info "Creating Thyme OS editor configuration..."
    
    # Create system config directory
    if [[ $EUID -eq 0 ]]; then
        mkdir -p "$CONFIG_DIR"
        
        # System-wide settings
        cat > "$CONFIG_DIR/settings.json" << 'EOF'
{
    "autoclose": true,
    "autoindent": true,
    "autosave": 2,
    "colorscheme": "monokai",
    "cursorline": true,
    "diff": true,
    "ignorecase": false,
    "indentsize": 4,
    "ruler": true,
    "scrollmargin": 3,
    "scrollspeed": 2,
    "softwrap": false,
    "splitRight": true,
    "statusline": true,
    "syntax": true,
    "tabsize": 4,
    "tabstospaces": true,
    "useprimary": true
}
EOF
        log "✅ System configuration created"
    fi
    
    # Create user config directory and settings
    mkdir -p "$USER_CONFIG_DIR"
    
    cat > "$USER_CONFIG_DIR/settings.json" << 'EOF'
{
    "autoclose": true,
    "autoindent": true,
    "autosave": 2,
    "colorscheme": "solarized-tc",
    "cursorline": true,
    "diff": true,
    "ignorecase": false,
    "indentsize": 4,
    "ruler": true,
    "scrollmargin": 3,
    "scrollspeed": 2,
    "softwrap": false,
    "splitRight": true,
    "statusline": true,
    "syntax": true,
    "tabsize": 4,
    "tabstospaces": true,
    "useprimary": true,
    "fileformat": "unix"
}
EOF
    
    log "✅ User configuration created"
}

# Create helpful documentation
create_documentation() {
    info "Creating Thyme Editor documentation..."
    
    local doc_dir
    if [[ $EUID -eq 0 ]]; then
        doc_dir="/usr/share/doc/thyme-editor"
        mkdir -p "$doc_dir"
    else
        doc_dir="$HOME/.local/share/thyme-editor"
        mkdir -p "$doc_dir"
    fi
    
    cat > "$doc_dir/README.md" << 'EOF'
# 🍃 Thyme OS Enhanced Text Editor

## Overview
Thyme OS includes the Micro text editor as an enhanced replacement for nano, featuring syntax highlighting for 130+ programming languages and modern editing features.

## Quick Start
```bash
# Edit a file
thyme-edit filename.py
# or
te filename.py
# or
micro filename.py
```

## Key Features
- ✅ Syntax highlighting for Python, Bash, HTML, CSS, JavaScript, and more
- ✅ Multiple cursors (Ctrl+mouse click)
- ✅ Split panes (Ctrl+e to split vertically)
- ✅ Tabs support (Ctrl+t for new tab)
- ✅ Find and replace (Ctrl+f to find, Ctrl+r to replace)
- ✅ Auto-completion and auto-indentation
- ✅ Mouse support for clicking and scrolling
- ✅ Common keybindings (Ctrl+s, Ctrl+c, Ctrl+v, Ctrl+z)

## Essential Keybindings
- `Ctrl+s` - Save file
- `Ctrl+o` - Open file
- `Ctrl+q` - Quit
- `Ctrl+c/v/x` - Copy/Paste/Cut
- `Ctrl+z/y` - Undo/Redo
- `Ctrl+f` - Find
- `Ctrl+r` - Find and replace
- `Ctrl+g` - Go to line
- `Ctrl+a` - Select all
- `Ctrl+e` - Split editor vertically
- `Ctrl+t` - New tab
- `Ctrl+w` - Close tab/pane
- `Alt+,/Alt+.` - Previous/Next tab

## MacBook Specific
- Optimized for MacBook keyboards
- Mouse support works with trackpad
- Efficient for low-memory systems

## Color Schemes
- `solarized-tc` (default for Thyme OS)
- `monokai`
- `zenburn`
- `gruvbox`

Change with: `Ctrl+e` → `set colorscheme solarized-tc`

## Language Support
Full syntax highlighting for:
- Python (.py)
- Shell scripts (.sh, .bash)
- HTML, CSS, JavaScript
- JSON, YAML, XML
- Markdown (.md)
- C, C++, Java
- And 120+ more languages

## Configuration
User settings: `~/.config/micro/settings.json`
System settings: `/etc/thyme/editor/settings.json`

## Getting Help
- Press `Ctrl+g` in micro for help
- Or visit: https://github.com/zyedidia/micro/blob/master/runtime/help/keybindings.md
EOF
    
    log "✅ Documentation created at $doc_dir"
}

# Main installation function
main() {
    echo "🍃 Thyme OS Enhanced Text Editor Installer"
    echo "=========================================="
    
    check_permissions
    install_micro
    create_thyme_config
    create_documentation
    
    echo
    log "🎉 Thyme Editor installation completed!"
    echo
    info "Usage:"
    info "  thyme-edit filename.py   # Full command"
    info "  te filename.py          # Short alias"
    info "  micro filename.py       # Direct micro command"
    echo
    info "Features:"
    info "  ✅ Syntax highlighting for 130+ languages"
    info "  ✅ Multiple cursors and split panes"
    info "  ✅ Common keyboard shortcuts (Ctrl+s, Ctrl+c, etc.)"
    info "  ✅ Mouse support and auto-completion"
    info "  ✅ Optimized for MacBook compatibility"
    echo
    info "Try it now: thyme-edit $HOME/test-syntax.py"
}

# Run installation
main "$@"