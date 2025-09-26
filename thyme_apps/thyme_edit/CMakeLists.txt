cmake_minimum_required(VERSION 3.20)
project(ThymeEdit VERSION 1.0.0 LANGUAGES CXX)

# C++ Standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Find Qt6 components
find_package(Qt6 REQUIRED COMPONENTS Core Widgets Gui)

# Enable Qt6's automatic MOC, UIC, and RCC
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTOUIC ON)
set(CMAKE_AUTORCC ON)

# Include directories
include_directories(include)
include_directories(../shared)

# Source files
set(SOURCES
    src/main.cpp
    src/thyme_edit_main_window.cpp
    src/thyme_edit_text_editor.cpp
    src/thyme_edit_file_manager.cpp
    src/thyme_edit_syntax_highlighter.cpp
)

# Header files
set(HEADERS
    include/thyme_edit_main_window.h
    include/thyme_edit_text_editor.h
    include/thyme_edit_file_manager.h
    include/thyme_edit_syntax_highlighter.h
)

# Create executable
add_executable(ThymeEdit ${SOURCES} ${HEADERS})

# Link Qt6 libraries
target_link_libraries(ThymeEdit Qt6::Core Qt6::Widgets Qt6::Gui)

# Compiler flags for optimization
target_compile_options(ThymeEdit PRIVATE
    -O2              # Optimize for performance
    -ffunction-sections   # Enable dead code elimination
    -fdata-sections
)

# Linker flags for size optimization
target_link_options(ThymeEdit PRIVATE
    -Wl,--gc-sections    # Remove unused sections
)

# Install target
install(TARGETS ThymeEdit
    RUNTIME DESTINATION bin
)

# Create desktop entry
configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/resources/thyme_edit.desktop.in
    ${CMAKE_CURRENT_BINARY_DIR}/thyme_edit.desktop
    @ONLY
)

install(FILES ${CMAKE_CURRENT_BINARY_DIR}/thyme_edit.desktop
    DESTINATION share/applications
)