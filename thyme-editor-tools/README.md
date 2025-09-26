# 🍃 Thyme OS Editor Tools

This directory contains the enhanced text editor for Thyme OS - a modern nano alternative with syntax highlighting.

## Contents

- `micro-binary/` - Contains the Micro editor executable
- `thyme-editor-config/` - Thyme OS specific configurations
- `install-editor.sh` - Installation script for Thyme OS
- `test-syntax.py` - Test file for syntax highlighting

## Features

### 🎨 Syntax Highlighting
- **130+ languages supported** including Python, Bash, HTML, CSS, JavaScript, JSON, YAML, Markdown
- **Thyme OS color scheme** optimized for readability
- **Real-time syntax highlighting** as you type

### ⌨️ Enhanced Editing
- **Multiple cursors** (Ctrl+mouse click)
- **Split panes** (Ctrl+e for vertical split)
- **Tabs support** (Ctrl+t for new tab)
- **Find and replace** (Ctrl+f to find, Ctrl+r to replace)
- **Auto-completion** and auto-indentation
- **Mouse support** for clicking and scrolling

### 🖥️ MacBook Optimized
- **Nano-like interface** but with modern features
- **Common keybindings** (Ctrl+s, Ctrl+c, Ctrl+v, Ctrl+z)
- **Lightweight** - works well on vintage MacBooks
- **Terminal-based** - no GUI dependencies

## Installation

### Standalone Installation
```bash
sudo ./install-editor.sh
```

### Integration with Thyme OS
The installer automatically includes this editor when creating Thyme OS installations.

## Usage

### Basic Commands
```bash
# Edit a file (full command)
thyme-edit myfile.py

# Short alias
te myfile.py

# Direct micro command
micro myfile.py
```

### Essential Keybindings
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

### Advanced Features
- **Multiple cursors**: Ctrl+mouse click to add cursors
- **Split editing**: Ctrl+e to split vertically, Ctrl+w to close
- **Tab management**: Ctrl+t for new tab, Alt+,/. to switch tabs
- **Block selection**: Alt+Shift+arrow keys
- **Go to line**: Ctrl+g then enter line number

## Configuration

### User Configuration
Location: `~/.config/micro/settings.json`

### System Configuration  
Location: `/etc/thyme/editor/settings.json` (if installed system-wide)

### Color Schemes
- `thyme` (default) - Optimized for Thyme OS
- `solarized-tc` - Solarized with true color
- `monokai` - Popular dark theme
- `zenburn` - Low contrast theme

Change color scheme: `Ctrl+e` → `set colorscheme thyme`

## Language Support

Full syntax highlighting support for:

**Scripts & Shell**
- Python (.py)  
- Bash/Shell (.sh, .bash, .zsh)
- PowerShell (.ps1)

**Web Development**
- HTML (.html, .htm)
- CSS (.css, .scss, .sass)
- JavaScript (.js, .jsx, .ts, .tsx)
- PHP (.php)

**Data & Config**
- JSON (.json)
- YAML (.yml, .yaml)
- XML (.xml)
- TOML (.toml)
- INI (.ini, .conf)

**Documentation**
- Markdown (.md)
- reStructuredText (.rst)
- LaTeX (.tex)

**Programming**
- C (.c, .h)
- C++ (.cpp, .hpp, .cc)
- Java (.java)
- Go (.go)
- Rust (.rs)
- And 100+ more!

## Troubleshooting

### Editor Won't Start
1. Check if binary is executable: `ls -la /usr/local/bin/micro`
2. Try running directly: `./micro-binary/micro-2.0.13/micro --version`
3. Check PATH includes installation directory

### No Syntax Highlighting
1. Ensure file has proper extension (e.g., `.py` for Python)
2. Check syntax is enabled: Inside micro, `Ctrl+e` → `set syntax on`
3. Verify colorscheme: `Ctrl+e` → `set colorscheme thyme`

### Keybindings Not Working
1. Check terminal supports the key combinations
2. Some terminals may intercept certain Ctrl combinations
3. Try alternative bindings listed in documentation

## Comparison with Nano

| Feature | Nano | Thyme Editor (Micro) |
|---------|------|---------------------|
| Syntax Highlighting | Basic (40 languages) | Advanced (130+ languages) |
| Multiple Cursors | ❌ | ✅ |
| Split Panes | ❌ | ✅ |
| Tabs | ❌ | ✅ |
| Mouse Support | Limited | Full |
| Auto-completion | ❌ | ✅ |
| Plugin System | ❌ | ✅ (Lua) |
| Memory Usage | Very Low | Low |
| Learning Curve | Minimal | Low |

## Development

The Micro editor is developed by Zachary Yedidia and the community:
- **GitHub**: https://github.com/zyedidia/micro
- **Documentation**: https://github.com/zyedidia/micro/tree/master/runtime/help
- **Version**: 2.0.13 (included in Thyme OS)

## License

- **Micro Editor**: MIT License (see micro-binary/LICENSE)
- **Thyme OS Integration**: Same as Thyme OS project