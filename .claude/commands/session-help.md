## Session Management - Lightweight Workflow

**Philosophy**: Sessions are LIGHTWEIGHT trackers tied to GitHub Issues. The Issue is the detailed, persistent documentation. Sessions are ephemeral todo lists and quick notes.

### Available Commands:

- `/project:session-start` - Start session (asks for GitHub Issue #)
- `/project:session-update [brief note]` - Add quick update
- `/project:session-current` - Show status
- `/project:session-list` - List all sessions
- `/project:session-end` - End session (basic)
- `/project:session-end-git-only` - End + git commit
- `/project:session-end-desc-only` - End + brief summary
- `/project:session-end-git-and-desc` - End + commit + summary
- `/project:session-help` - Show this help

### How It Works:

1. One session ties to one GitHub Issue
2. Session = lightweight tracker (todos, quick notes, file refs)
3. GitHub Issue = detailed documentation (full context, decisions, code examples)
4. Session ends when work stops, even if Issue isn't closed

### What Goes in Sessions:

✅ **DO include**:
- Brief todos/task list
- Quick status updates ("Fixed X", "Working on Y")
- File paths and line numbers (lib/foo.ex:42)
- Brief decisions or blockers
- Time-stamped notes

❌ **DON'T include**:
- Full code blocks (use snippets/refs only)
- Detailed explanations (→ GitHub Issue)
- Comprehensive summaries
- Git diffs or full change lists

### Example Session Content:

```markdown
# Issue #123: Add User Authentication

**Started**: 2025-11-15 14:00
**Issue**: https://github.com/org/repo/issues/123

## Todo
- [x] Add User resource
- [x] Add authentication plug
- [ ] Add tests
- [ ] Update docs

## Notes
**14:15** Created User resource - lib/app/auth/user.ex
**14:30** Using Guardian for JWT - see Issue for rationale
**15:00** Blocked on Ash relationship - checking with team
**15:45** Resolved - used belongs_to pattern from docs

**Ended**: 2025-11-15 16:00
```

### Best Practices:

- Start session when beginning work on an Issue
- Keep updates minimal (1 line per update)
- Reference files, don't paste code
- Save detailed docs for the GitHub Issue
- End session when you stop working (even if Issue ongoing)

### Example Workflow:

```bash
/project:session-start              # Asks for Issue #, creates session
/project:session-update Added User resource
/project:session-update Fixed relationship issue - see lib/auth/user.ex:42
/project:session-end-git-and-desc   # Commits + brief summary
# Then update GitHub Issue with detailed outcomes
```
