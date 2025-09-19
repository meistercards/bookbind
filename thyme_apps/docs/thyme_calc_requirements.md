# ThymeCalc Spreadsheet Engine Requirements

## 🎯 Core Mission
Build a lightweight, macro-capable spreadsheet application that addresses LibreOffice macro limitations while being perfectly optimized for MacBook2,1 hardware constraints.

## 💾 Memory & Performance Requirements

### Memory Constraints
- **Total footprint**: <50MB (including all loaded data)
- **Startup memory**: <15MB initial allocation
- **Large file handling**: Streaming for files >10MB
- **Efficient data structures**: Column-sparse storage for large sheets

### Performance Targets
- **Startup time**: <3 seconds on MacBook2,1
- **Formula calculation**: 1000+ cells/second
- **File operations**: Load 10MB Excel file in <5 seconds
- **UI responsiveness**: 60fps scrolling on Intel GMA 950

## 📊 Spreadsheet Engine Features

### Core Functionality
- **Grid engine**: 1 million rows × 16,384 columns (Excel compatible)
- **Data types**: Number, Text, Date/Time, Boolean, Formula, Error
- **Cell formatting**: Font, color, borders, number formats
- **Formula engine**: 200+ Excel-compatible functions
- **Charts**: Line, bar, pie, scatter plots

### File Format Support
- **Native format**: .thymesheet (optimized binary format)
- **Excel compatibility**: .xlsx, .xls read/write
- **Interchange formats**: CSV, TSV, ODS import/export
- **Legacy support**: Lotus 1-2-3, Quattro Pro import

## 🔧 Advanced Macro System

### Macro Capabilities (LibreOffice Alternative)
- **Scripting languages**: 
  - ThymeScript (custom DSL for spreadsheets)
  - Python integration for advanced scripting
  - JavaScript for web compatibility
- **Event-driven**: Cell change, sheet events, workbook events
- **UI automation**: Create custom dialogs and forms
- **External data**: Web scraping, database connections
- **File operations**: Read/write external files

### Macro Features LibreOffice Lacks
- **Better debugging**: Step-through debugger with breakpoints
- **Performance profiling**: Identify slow macro sections
- **Version control**: Built-in macro versioning and diffing
- **Security model**: Sandboxed execution, permission system
- **Modern syntax**: Clean, readable macro language

## 🖥️ MacBook-Optimized Interface

### Input Handling
- **Alt+Click**: Right-click context menus
- **Keyboard navigation**: Full keyboard control
- **Trackpad gestures**: Scroll, zoom (where supported)
- **Single-button mouse**: Complete functionality

### Display Optimization
- **Low-DPI displays**: Crisp rendering on 1280x800 screens
- **Font rendering**: Optimized for MacBook LCD characteristics
- **Color scheme**: High contrast for aging displays
- **UI scaling**: Adaptive based on screen size

## 🧮 Formula Engine Architecture

### Core Components
- **Parser**: Convert text formulas to syntax trees
- **Evaluator**: Execute formulas with dependency tracking
- **Function library**: Excel-compatible function implementations
- **Reference system**: Handle absolute/relative cell references
- **Circular reference detection**: Prevent infinite loops

### Performance Optimizations
- **Lazy evaluation**: Calculate only when needed
- **Dependency graphs**: Smart recalculation
- **Caching**: Store calculated results
- **Multi-threading**: Parallel formula evaluation
- **Memory pooling**: Reduce allocation overhead

## 📈 Chart Engine

### Chart Types
- **Basic charts**: Line, column, bar, pie
- **Advanced charts**: Scatter, bubble, area, stock
- **Custom charts**: User-defined chart types
- **3D rendering**: Optional for capable hardware

### Chart Features
- **Interactive**: Click to select data points
- **Customization**: Colors, fonts, styles
- **Export**: SVG, PNG, PDF formats
- **Animation**: Smooth transitions (optional)

## 🔌 Data Import/Export

### Data Sources
- **Files**: CSV, XML, JSON, text files
- **Databases**: SQLite, MySQL, PostgreSQL
- **Web APIs**: REST, JSON, XML web services
- **Clipboard**: Rich paste from other applications

### Export Capabilities
- **Reports**: PDF generation with formatting
- **Web**: HTML tables with CSS styling
- **Images**: Chart export as graphics
- **Data**: Various text formats

## 🛡️ Security & Reliability

### Data Protection
- **Auto-save**: Regular background saves
- **Version history**: Built-in document versioning
- **Backup system**: Automatic backup creation
- **Crash recovery**: Restore unsaved work

### Macro Security
- **Sandboxing**: Restricted macro execution environment
- **Digital signatures**: Verify macro authenticity
- **Permission system**: User approval for sensitive operations
- **Audit logging**: Track macro execution

## 🎨 User Experience

### Ease of Use
- **Smart defaults**: Sensible initial settings
- **Context awareness**: Relevant suggestions and actions
- **Progressive disclosure**: Advanced features when needed
- **Keyboard shortcuts**: Efficient power-user workflows

### Customization
- **Themes**: Light, dark, high-contrast modes
- **Toolbars**: Customizable button layouts
- **Preferences**: Extensive configuration options
- **Plugins**: Extension architecture for add-ons

## 🔗 Integration

### ThymeOS Integration
- **File associations**: Default for spreadsheet files
- **Clipboard sharing**: With other Thyme applications
- **Print system**: Native printing support
- **Help system**: Integrated documentation

### External Integration
- **LibreOffice compatibility**: Open/save LO Calc files
- **Excel compatibility**: 95% feature compatibility
- **Web browsers**: Export to web formats
- **Email**: Send sheets as attachments

## 📚 Implementation Strategy

### Development Phases
1. **Core engine**: Basic grid, formulas, file I/O
2. **Formula library**: Implement Excel functions
3. **Macro system**: ThymeScript interpreter
4. **Chart engine**: Basic chart types
5. **Advanced features**: Import/export, themes
6. **Polish**: Performance optimization, testing

### Technology Stack
- **Framework**: Qt6 with C++ for performance
- **Formula engine**: Custom recursive descent parser
- **Macro interpreter**: ANTLR-generated parser
- **Chart rendering**: Qt Graphics View Framework
- **File formats**: Qt's XML handling + custom binary

This requirements document ensures ThymeCalc will be a superior alternative to LibreOffice Calc, specifically addressing macro limitations while being perfectly optimized for vintage MacBook hardware.