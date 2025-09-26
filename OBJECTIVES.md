# Objective File Writing Guide

This guide explains how to write effective objective files for the `.dev/objectives/` directory.

## Structure

Every objective file should have the objective and task list, with optional code snippets and important notes sections if applicable:

### 1. OBJECTIVE
- **Single clear sentence** describing what you're working on
- **Brief context paragraph** explaining the background and motivation
- Keep it focused and concise - this is the "why" not the "how"

### 2. CODE SNIPPETS (Optional)
- **Include only if applicable** - when specific code patterns need to be followed
- **Suggested implementation patterns** with proper syntax highlighting
- **Key data structures or interfaces** that guide the implementation
- Keep snippets concise but complete enough to be useful

### 3. IMPORTANT NOTES (Optional)
- **Include only if applicable** - when critical implementation details exist
- **Architectural constraints** and dependencies that must be preserved
- **Performance considerations** or compatibility requirements
- **Complex systems** that must be maintained during changes

### 4. TASK LIST
- **Hierarchical checklist** using `- [ ]` format for all tasks
- **Organized by phases** with nested sub-tasks
- **Specific and actionable** items that can be directly copied to TodoWrite tool
- **File paths included** where tasks involve code changes

## Critical Guidelines for Task Lists and Notes

**IMPORTANT DISTINCTION:**
- **Task List** contains ONLY actionable tasks that can be checked off when completed
- **Important Notes** contains ALL non-actionable information including:
  - Tips and suggestions
  - Warnings about potential issues
  - Dependencies or prerequisites information
  - Context about why certain approaches are taken
  - References to documentation
  - Performance considerations
  - Any other helpful information that isn't a task

**Tasks must be actionable** - If it's not something you can DO and check off, it belongs in Important Notes

### Critical Testing Guidelines
**IMPORTANT:** Unless explicitly instructed otherwise when creating the objective:
- **Always include unit test tasks** - Write new unit tests or update existing ones for all code changes
- **Unit tests are the ONLY programs to run** - Run test suites to validate implementation
- **DO NOT include tasks to run other programs** such as:
  - Storybook servers
  - Development servers
  - Build processes (except for test builds)
  - Demo applications
  - Any other runtime programs
- **Exception only when explicitly stated** - Only include non-test runtime tasks if specifically requested in the objective instructions

## Example Format

```markdown
# OBJECTIVE
You're working on consolidating the adapter pattern across all database implementations.

The current codebase has inconsistent adapter interfaces that make it difficult to add new database backends.


# CODE SNIPPETS
These are suggested code snippets to follow/guide the implementation:

`crates/sqlkit-adapter/src/database_adapter.rs`
```rs
pub trait DatabaseAdapter {
    type Connection;
    type Error;

    fn connect(&self, url: &str) -> Result<Self::Connection, Self::Error>;
    fn execute_query(&self, conn: &mut Self::Connection, query: &str) -> Result<Vec<Row>, Self::Error>;
}
```


# IMPORTANT NOTES
- **Adapter Isolation**: Each adapter must be completely independent with no shared state
- **Error Handling**: All adapters must use the unified error type system for consistent error propagation
- **Connection Pooling**: Preserve existing connection pool implementations during migration
- **Backward Compatibility**: Existing client code must continue working without changes


# TASK LIST
- [ ] Phase 1: Foundation
  - [ ] Create unified `DatabaseAdapter` trait in `crates/sqlkit-adapter/src/database_adapter.rs`
  - [ ] Define common error types in `crates/sqlkit-adapter/src/errors.rs`
  - [ ] Add shared column type system in `crates/sqlkit-adapter/src/column_types.rs`
  - [ ] Write unit tests for error types in `crates/sqlkit-adapter/src/errors_test.rs`
  - [ ] Write unit tests for column types in `crates/sqlkit-adapter/src/column_types_test.rs`
- [ ] Phase 2: Implementation
  - [ ] Update Postgres adapter in `crates/sqlkit-diesel/src/postgres_adapter.rs`
  - [ ] Update SQLite adapter in `crates/sqlkit-rusqlite/src/sync_adapter.rs`
  - [ ] Write unit tests for Postgres adapter in `crates/sqlkit-diesel/src/postgres_adapter_test.rs`
  - [ ] Write unit tests for SQLite adapter in `crates/sqlkit-rusqlite/src/sync_adapter_test.rs`
- [ ] Phase 3: Integration
  - [ ] Update CLI to use unified adapters in `crates/sqlkit-cli/src/adapter_selector.rs`
  - [ ] Write integration tests in `crates/sqlkit-cli/tests/adapter_integration_test.rs`
  - [ ] Run full test suite with `cargo test`
  - [ ] Fix any breaking changes identified by tests
  - [ ] Send completion notification
```


## Writing Guidelines

### Objective Statement
- Start with "You're working on [specific goal]"
- Explain the problem being solved, not the solution
- Keep to 1-3 sentences maximum
- Focus on the business/technical value

### Task Organization
- Break work into **logical phases** based on dependencies and workflow
- Use **action verbs** (Create, Update, Implement, Test, etc.)
- Include **exact file paths** for code changes
- Tasks should be **specific and actionable** - clear enough to execute directly
- Every task must be something you can complete and check off
- Include unit test tasks for all code changes (unless explicitly exempted)
- Always end with "Send completion notification using `notify-send "<objective> <phase>" "Work Completed"`"

### Checklist Format
- Use `- [ ]` for all tasks, and `- [x]` for completed (not `✅`)
- Nest sub-tasks with proper indentation
- Keep task descriptions concise but specific
- Include file paths in backticks when relevant
- No runtime program tasks unless explicitly requested

### Code Snippets (Optional)
- Include relevant code snippets when they help guide implementation
- Use proper syntax highlighting with language tags
- Focus on key data structures, interfaces, or architectural patterns
- Keep snippets concise but complete enough to be useful
- Only include if there are specific code patterns to follow
- Must be placed in the `# CODE SNIPPETS` section

### Important Notes (Optional)
- Capture critical implementation details that don't belong in task lists
- Include architectural constraints, dependencies, or gotchas
- Note performance considerations, security requirements, or compatibility issues
- Highlight complex systems that must be preserved during changes
- Keep notes focused on technical implementation rather than general advice
- Remember: if it's not actionable, it belongs here not in the task list
- Must be placed in the `# IMPORTANT NOTES` section


## File Naming
* Use descriptive kebab-case names,
* DO NOT INCLUDE DATES IN THE OBJECTIVE NAMES:

### Example File names:
- `.dev/objectives/adapter-pattern-consolidation.md`
- `.dev/objectives/async-wrapper-implementation.md`


## Conclusion

This compact format integrates seamlessly with TodoWrite/TodoRead tools and serves as a living document that can be updated as work progresses.