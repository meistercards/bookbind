#ifndef THYME_EDIT_MAIN_WINDOW_H
#define THYME_EDIT_MAIN_WINDOW_H

#include <QMainWindow>
#include <QMenuBar>
#include <QToolBar>
#include <QStatusBar>
#include <QTabWidget>
#include <QSplitter>
#include <QVBoxLayout>
#include <QHBoxLayout>
#include <QLabel>
#include <QPushButton>
#include <QLineEdit>
#include <QProgressBar>

class ThymeEditTextEditor;
class ThymeEditFileManager;

/**
 * Main window for ThymeEdit application
 * Features:
 * - Multiple document tabs
 * - Split pane editing
 * - MacBook-optimized interface
 * - Efficient memory usage
 */
class ThymeEditMainWindow : public QMainWindow
{
    Q_OBJECT

public:
    explicit ThymeEditMainWindow(QWidget *parent = nullptr);
    ~ThymeEditMainWindow();
    
    // Public interface for opening files
    void openFile(const QString &filePath);

protected:
    void closeEvent(QCloseEvent *event) override;
    void dragEnterEvent(QDragEnterEvent *event) override;
    void dropEvent(QDropEvent *event) override;

private slots:
    // File operations
    void newFile();
    void openFile();
    void saveFile();
    void saveAsFile();
    void closeTab(int index);
    
    // Edit operations
    void undo();
    void redo();
    void cut();
    void copy();
    void paste();
    void selectAll();
    
    // Search operations
    void find();
    void findNext();
    void findPrevious();
    void replace();
    void goToLine();
    
    // View operations
    void splitHorizontally();
    void splitVertically();
    void closeSplit();
    void toggleWordWrap();
    void zoomIn();
    void zoomOut();
    void resetZoom();
    
    // Tools
    void showPreferences();
    void showAbout();
    
    // Tab management
    void onTabChanged(int index);
    void onTextChanged();
    void updateStatusBar();

private:
    void setupUi();
    void setupMenus();
    void setupToolbar();
    void setupStatusBar();
    void setupShortcuts();
    void connectSignals();
    
    ThymeEditTextEditor* getCurrentEditor();
    void addNewTab(const QString &title = "Untitled");
    void updateWindowTitle();
    bool maybeSave(int tabIndex);
    
    // UI Components
    QTabWidget *m_tabWidget;
    QSplitter *m_splitter;
    
    // Menus
    QMenu *m_fileMenu;
    QMenu *m_editMenu;
    QMenu *m_searchMenu;
    QMenu *m_viewMenu;
    QMenu *m_toolsMenu;
    QMenu *m_helpMenu;
    
    // Toolbar
    QToolBar *m_mainToolbar;
    
    // Status bar widgets
    QLabel *m_lineColumnLabel;
    QLabel *m_encodingLabel;
    QLabel *m_languageLabel;
    QProgressBar *m_progressBar;
    
    // Search bar (hidden by default)
    QWidget *m_searchWidget;
    QLineEdit *m_searchLineEdit;
    QLineEdit *m_replaceLineEdit;
    QPushButton *m_findNextButton;
    QPushButton *m_findPrevButton;
    QPushButton *m_replaceButton;
    QPushButton *m_replaceAllButton;
    QPushButton *m_closeSearchButton;
    
    // File manager (for optional sidebar)
    ThymeEditFileManager *m_fileManager;
    
    // Application state
    QString m_currentDirectory;
    int m_untitledCounter;
};

#endif // THYME_EDIT_MAIN_WINDOW_H