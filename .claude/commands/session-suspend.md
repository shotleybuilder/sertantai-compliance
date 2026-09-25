Suspend the current session: pause it with a reason, capture learnings so far in a YAML frontmatter block, and leave it resumable.

Use this instead of `/session-close` when work is paused but not finished, e.g. the core is done and a dependent session should run first, or the session is blocked upstream. Open items stay open (`⬜`); nothing is deferred or abandoned.

1. **Identify the session**: The user will specify which session doc to suspend, or it will be obvious from the current conversation context. Session docs live in `.claude/sessions/` (any subdirectory).

2. **Get the reason**: A suspension needs a one-line reason (what's done, why pause now, what resumes it). Take it from the user's instruction or the conversation; ask only if it's genuinely unclear.

3. **List the open items**: Find unchecked items (`⬜`). Keep them as `⬜`. They are the resume list. Mark an item `⏸️` only if it's blocked on something external (add `(blocked — <what>)`). Tick anything actually finished (`✅`) and check dependencies (`⬜` → `✅` if resolved).

4. **Replace the skeleton frontmatter**: Replace the `---` fenced YAML block at the top (from session-start) with the learning block below. Use the same schema as `/session-close`, with these differences:
   - `status: suspended`
   - `suspended: <YYYY-MM-DD>` instead of `closed:`
   - `outcome: partial` (or `deferred` if blocked before real progress)
   - `summary:` says what's done **and** what remains/why paused

   ```yaml
   ---
   session: <session title>
   status: suspended
   opened: <YYYY-MM-DD>
   suspended: <YYYY-MM-DD>
   outcome: <partial | deferred>
   parent: <meta session, if any>

   summary: >
     2-3 sentences: what was accomplished, what remains, why it's paused.

   decisions:
     - what: <what was decided>
       why: <reasoning>
       result: <outcome>

   metrics:
     <metric_name>: { <key>: <value>, ... }

   lessons:
     - title: <one-line lesson>
       detail: <context and explanation>
       tag: <infrastructure | sync | schema | electric | baserow | data | tooling | deployment>

   artifacts:
     - <path to file created or modified>

   depends_on:
     - <session filename without path>

   enables:
     - <what future work this unblocks>
   ---
   ```

   If the session was suspended before and already has a learning block, **merge**: keep earlier decisions/lessons, add new ones, and update `suspended:`, `summary`, `metrics`, `artifacts`.

5. **Update the heading**: Change `(ACTIVE)` to `(SUSPENDED)` in the `# Session:` line, and add directly below it:
   ```markdown
   > **Suspended <YYYY-MM-DD>**: <reason>. Resume for <open items / trigger>.
   ```

6. **Update the parent meta table**, if the session belongs to one (e.g. `.claude/sessions/v0.1/meta.md`): set its status cell to `suspended`.

7. **Write directly**: Don't present the draft for review. The user can review the diff in git.

8. **Rebuild the session index**:
   ```bash
   /usr/bin/python3 scripts/maintenance/session_index.py --root /var/home/jason/Desktop/sertantai-compliance
   ```

9. **Commit locally** (don't push; pushes are batched at session end).

## Resuming

Resume with `/session-start <session>`. It sets `status: active` and `(ACTIVE)` again. Keep the learning block (decisions and lessons carry forward). Remove the `suspended:` line, and replace the `> Suspended` note with a `> Resumed <date>: <why now>` note.

## Guidelines

- Same quality bar as `/session-close`: lessons are the most valuable part. Capture what would save time next time, not a changelog.
- Don't invent lessons. A short suspension may have few or none.
- The summary must make it obvious to someone resuming cold what is left and why the session was paused.
- **Quote YAML values that start with a special character** (`` ` ``, `@`, `*`, `&`, `!`, `%`, `|`, `>`, `[`, `{`) or contain `: `. Unquoted, they break parsing, and the session silently drops out of the index. After rebuilding the index, check its output for `WARN: YAML parse error`.
