End session with git commit and BRIEF summary:

1. Check `.claude/sessions/.current-session` for active session
2. If no active session, inform user there's nothing to end
3. Git commit changes with message referencing Issue #
4. Append MINIMAL summary to session file:
   ```
   **Ended**: [timestamp]
   **Committed**: [commit hash]

   ## Summary
   - Completed: [X of Y todos]
   - Files: [list key files only, no code]
   - Outcome: [1-2 sentence summary]
   - Next: [what's left for the Issue]
   ```
5. Empty `.claude/sessions/.current-session` file
6. Remind user to update GitHub Issue with detailed outcomes

**IMPORTANT**:
- Summary under 10 lines
- NO code blocks or diffs
- Just high-level outcome
- Detailed documentation goes in the GitHub Issue, not the session
