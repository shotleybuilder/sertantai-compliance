End the current lightweight session:

1. Check `.claude/sessions/.current-session` for active session
2. If no active session, inform user there's nothing to end
3. Append simple end marker to session file:
   ```
   **Ended**: [timestamp]
   ```
4. Empty `.claude/sessions/.current-session` file
5. Remind user to update the GitHub Issue with any important details/outcomes

**No heavy summaries needed** - session is just a lightweight tracker.
