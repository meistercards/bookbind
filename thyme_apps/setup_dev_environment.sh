#!/bin/bash
# ThymeOS Development Environment Setup Script

echo "🍃 Setting up ThymeOS Application Development Environment"
echo "========================================================"

# Update package list
echo "📦 Updating package lists..."
sudo apt update

# Install Qt6 development environment
echo "🔧 Installing Qt6 development packages..."
sudo apt install -y \
    qt6-base-dev \
    qt6-base-dev-tools \
    qt6-tools-dev \
    qt6-tools-dev-tools \
    cmake \
    ninja-build \
    build-essential \
    git \
    pkg-config

# Install additional Qt6 modules for advanced features
echo "📚 Installing additional Qt6 modules..."
sudo apt install -y \
    qt6-wayland-dev \
    libqt6svg6-dev \
    qt6-image-formats-plugins \
    qt6-multimedia-dev

# Install development tools
echo "🛠️ Installing development tools..."
sudo apt install -y \
    gdb \
    valgrind \
    clang-format \
    doxygen \
    graphviz

# Create symbolic links for common Qt tools
echo "🔗 Creating convenient tool links..."
sudo ln -sf /usr/lib/qt6/bin/qmake /usr/local/bin/qmake6
sudo ln -sf /usr/lib/qt6/bin/moc /usr/local/bin/moc6
sudo ln -sf /usr/lib/qt6/bin/uic /usr/local/bin/uic6
sudo ln -sf /usr/lib/qt6/bin/rcc /usr/local/bin/rcc6

# Verify installation
echo "✅ Verifying Qt6 installation..."
qmake6 --version
cmake --version
ninja --version

echo ""
echo "🎉 Development environment setup complete!"
echo ""
echo "Next steps:"
echo "1. cd /home/meister/mintbook/thyme_apps"
echo "2. Start developing ThymeEdit prototype"
echo "3. Test builds with: cmake -B build -G Ninja && ninja -C build"
echo ""
echo "Qt6 Documentation: /usr/share/qt6/doc/"
echo "Examples: /usr/share/qt6/examples/"