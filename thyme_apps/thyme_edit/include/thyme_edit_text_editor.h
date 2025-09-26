#ifndef THYME_EDIT_TEXT_EDITOR_H
#define THYME_EDIT_TEXT_EDITOR_H

#include <QPlainTextEdit>
#include <QTextDocument>
#include <QSyntaxHighlighter>
#include <QCompleter>
#include <QTimer>
#include <QMouseEvent>
#include <QKeyEvent>
#include <QContextMenuEvent>

class ThymeEditSyntaxHighlighter;

/**
 * Enhanced text editor widget with advanced features
 * Optimized for MacBook hardware and vintage displays
 * 
 * Features:
 * - Alt+Click right-click support for MacBook trackpads
 * - Advanced text selection modes (block, column)
 * - Syntax highlighting for 20+ languages
 * - Line numbers and code folding
 * - Auto-completion and smart indentation
 * - Memory-efficient operation for 2GB systems
 */
class ThymeEditTextEditor : public QPlainTextEdit
{
    Q_OBJECT

public:
    explicit ThymeEditTextEditor(QWidget *parent = nullptr);
    ~ThymeEditTextEditor();
    
    // File operations
    bool loadFile(const QString &fileName);
    bool saveFile(const QString &fileName);
    bool isModified() const { return document()->isModified(); }
    
    QString currentFileName() const { return m_fileName; }
    void setFileName(const QString &fileName);
    
    // Text operations
    void findText(const QString &text, bool forward = true, bool caseSensitive = false);
    void replaceText(const QString &find, const QString &replace, bool replaceAll = false);
    void goToLine(int lineNumber);
    
    // Selection modes
    enum SelectionMode {
        NormalSelection,
        BlockSelection,
        ColumnSelection
    };
    
    void setSelectionMode(SelectionMode mode);
    SelectionMode selectionMode() const { return m_selectionMode; }
    
    // Language and syntax
    void setLanguage(const QString &language);
    QString currentLanguage() const { return m_currentLanguage; }
    QStringList availableLanguages() const;
    
    // Editor preferences
    void setTabWidth(int width);
    void setAutoIndent(bool enabled);
    void setLineNumbers(bool visible);
    void setWordWrap(bool enabled);
    void setFont(const QFont &font);

signals:
    void fileNameChanged(const QString &fileName);
    void modificationChanged(bool modified);
    void cursorPositionChanged(int line, int column);
    void selectionChanged(const QString &selectedText);

protected:
    void mousePressEvent(QMouseEvent *event) override;
    void mouseReleaseEvent(QMouseEvent *event) override;
    void mouseMoveEvent(QMouseEvent *event) override;
    void keyPressEvent(QKeyEvent *event) override;
    void contextMenuEvent(QContextMenuEvent *event) override;
    void paintEvent(QPaintEvent *event) override;
    void resizeEvent(QResizeEvent *event) override;
    void wheelEvent(QWheelEvent *event) override;

private slots:
    void updateLineNumberArea(const QRect &rect, int dy);
    void highlightCurrentLine();
    void onCursorPositionChanged();
    void onSelectionChanged();
    void autoComplete();

private:
    void setupEditor();
    void setupSyntaxHighlighter();
    void setupCompleter();
    void setupMacBookFeatures();
    
    // MacBook-specific input handling
    void handleAltClick(QMouseEvent *event);
    void showContextMenu(const QPoint &position);
    
    // Selection handling
    void updateBlockSelection(const QPoint &position);
    void updateColumnSelection(const QPoint &position);
    
    // Line number area
    void updateLineNumberAreaWidth();
    void paintLineNumbers(QPaintEvent *event);
    int lineNumberAreaWidth() const;
    
    // Auto-completion
    void insertCompletion(const QString &completion);
    QString textUnderCursor() const;
    
    // File and document state
    QString m_fileName;
    bool m_isModified;
    QString m_currentLanguage;
    
    // Selection state
    SelectionMode m_selectionMode;
    QPoint m_selectionStart;
    bool m_altKeyPressed;
    
    // UI components
    QWidget *m_lineNumberArea;
    ThymeEditSyntaxHighlighter *m_syntaxHighlighter;
    QCompleter *m_completer;
    
    // Timers for performance optimization
    QTimer *m_highlightTimer;
    QTimer *m_autoCompleteTimer;
    
    // Editor settings
    int m_tabWidth;
    bool m_autoIndent;
    bool m_lineNumbersVisible;
    QFont m_editorFont;
    
    friend class LineNumberArea;
};

/**
 * Helper widget for line numbers
 */
class LineNumberArea : public QWidget
{
public:
    LineNumberArea(ThymeEditTextEditor *editor) : QWidget(editor), m_textEditor(editor) {}
    
    QSize sizeHint() const override {
        return QSize(m_textEditor->lineNumberAreaWidth(), 0);
    }

protected:
    void paintEvent(QPaintEvent *event) override {
        m_textEditor->paintLineNumbers(event);
    }

private:
    ThymeEditTextEditor *m_textEditor;
};

#endif // THYME_EDIT_TEXT_EDITOR_H