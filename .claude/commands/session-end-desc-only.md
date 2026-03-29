End session with BRIEF summary:

1. Check `.claude/sessions/.current-session` for active session
2. If no active session, inform user there's nothing to end
3. Append MINIMAL summary to session file:
   ```
   **Ended**: [timestamp]

   ## Summary
   - Completed: [X of Y todos]
   - Files touched: [list key files only, no code]
   - Outcome: [1-2 sentence summary]
   - Next: [what's left for the Issue]
   ```
4. Empty `.claude/sessions/.current-session` file
5. Remind user to add detailed documentation to the GitHub Issue

**IMPORTANT**:
- Keep summary under 10 lines
- NO code blocks
- NO detailed explanations
- Just high-level outcome
- Detailed docs go in the GitHub Issue
