/**
 * ThymeEdit - Advanced Text Editor for Thyme OS
 * Optimized for MacBook2,1 and vintage Mac hardware
 * 
 * A nano alternative with enhanced selection, syntax highlighting,
 * and MacBook-specific input handling (Alt+Click for right-click)
 */

#include <QApplication>
#include <QDir>
#include <QStyleFactory>
#include <QFont>
#include "../include/thyme_edit_main_window.h"

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    
    // Set application metadata
    app.setApplicationName("ThymeEdit");
    app.setApplicationVersion("1.0.0");
    app.setOrganizationName("ThymeOS");
    app.setApplicationDisplayName("ThymeEdit - Advanced Text Editor");
    
    // Configure for MacBook hardware optimization
    app.setAttribute(Qt::AA_UseHighDpiPixmaps, false);  // Optimize for older displays
    app.setAttribute(Qt::AA_DisableWindowContextHelpButton, true);
    
    // Set efficient font for vintage MacBook displays
    QFont defaultFont("Monaco", 11);  // MacBook-friendly monospace font
    if (!defaultFont.exactMatch()) {
        defaultFont = QFont("DejaVu Sans Mono", 11);  // Fallback for Linux
    }
    app.setFont(defaultFont);
    
    // Use native style for better MacBook integration
    QString styleName = "Fusion";  // Modern, lightweight style
    QApplication::setStyle(QStyleFactory::create(styleName));
    
    // Create main window
    ThymeEditMainWindow window;
    
    // Handle command line arguments for file opening
    QStringList args = app.arguments();
    if (args.size() > 1) {
        QString filePath = args.at(1);
        if (QDir::isAbsolutePath(filePath)) {
            window.openFile(filePath);
        } else {
            // Make relative path absolute
            QString absolutePath = QDir::currentPath() + "/" + filePath;
            window.openFile(absolutePath);
        }
    }
    
    // Show window
    window.show();
    
    return app.exec();
}