You are reviewing a plan written by another Claude Code session, as a senior AI engineer. Do not edit any files. Review only.

First read CLAUDE.md and agent/BUILD_LOG.md for the project's rules and past decisions. Then review the plan below. If it is a file path, read the plan from that file. Otherwise, treat it as the plan text itself:

$ARGUMENTS

For every claim the plan makes about the code (file paths, line numbers, function names, current behavior, test counts), check it against the actual files and say whether it's accurate.

Then report, ranked by severity:
1. Correctness bugs in any proposed code.
2. Conflicts with CLAUDE.md rules or earlier decisions in BUILD_LOG.
3. Security, privacy, or cost risks.
4. Anything that would make eval results misleading, such as a change that makes a scorer pass for the wrong reason.
5. Missing tests.

Only report real issues. If the plan is sound, say so plainly. Don't invent nitpicks to seem thorough. No em dashes.

Finish with a verdict: approve, approve with changes, or send back. Then write one paste-ready message to the building session that lists only the required changes, numbered, in plain language. If a change needs my decision, give me the options and your recommendation above the message. Keep the whole review under 400 words unless there are correctness bugs that need more.
