End session with git commit:

1. Check `.claude/sessions/.current-session` for active session
2. If no active session, inform user there's nothing to end
3. Git commit changes with brief message referencing the Issue #
4. Append end marker to session file:
   ```
   **Ended**: [timestamp]
   **Committed**: [commit hash]
   ```
5. Empty `.claude/sessions/.current-session` file
6. Remind user to update GitHub Issue with outcomes

**Keep it lightweight** - no comprehensive summaries needed.
