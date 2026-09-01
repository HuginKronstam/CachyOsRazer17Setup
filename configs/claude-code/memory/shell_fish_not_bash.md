---
name: shell-fish-not-bash
description: "User's interactive shell is fish, not bash - avoid bash-only syntax in commands given for them to paste into their terminal"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 447ee8ed-79fb-475a-8bf3-6c82788795b9
  modified: 2026-08-06T19:34:48.860Z
---

The user's interactive login shell is **fish** (prompt style `~/path branch ❯`), not bash, even though my own Bash tool runs bash. Any command I hand to the user to paste into their own terminal must be fish-compatible, not just bash-compatible.

**Why:** Twice this caused real confusion/failed commands:
- A multi-line `git filter-repo ...` command using bash `\` line-continuation got mangled when pasted into fish, silently dropping all the `--path` flags and running a no-op.
- A `sudo tee file << 'EOF' ... EOF` heredoc failed outright with `fish: Expected a string, but found a redirection` - fish has no heredoc (`<<`) syntax at all.

**How to apply:** When giving the user a command to run themselves (as opposed to something I run via my own Bash tool, which is fine as bash):
- Never use heredocs (`<<`). Use `echo "line" | sudo tee file` (first line) and `echo "line" | sudo tee -a file` (subsequent lines) instead - one plain line per command, no continuation needed.
- Avoid multi-line commands with trailing `\` continuation. If a command is long, prefer writing it to a script file (via my Write tool) and giving them a single `bash /path/to/script.sh` to run - this fully sidesteps shell-syntax differences since the script itself is interpreted by bash regardless of their login shell.
- If a multi-line block is unavoidable, test that it's POSIX/fish-safe, or explicitly tell them to run it with `bash -c '...'` rather than pasting raw into fish.
