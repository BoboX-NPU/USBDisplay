# iPhoneUSBDisplay Project Collaboration Guidelines

All Markdown files in this project must be written in English. Every Git commit title and body must also be written in English. Filenames, code identifiers, commands, and technical terms should retain their original spelling.

## Before Starting a Task

- Read `doc/current.md` first and use the current project state recorded there as the working baseline.
- Review `doc/devlog.md` when historical changes, previous validation, or earlier issues are relevant.
- Treat the code, configuration, and current validation results as the source of truth. If the documentation does not match the project, correct it as part of the task.

## After Every Project Update

Every completed change to code, configuration, scripts, tests, resources, or project documentation must include the following work in the same task:

1. Append a factual record of the change to `doc/devlog.md`.
2. Update `doc/current.md` when the resulting current project state has changed. Do not edit it merely to add history.
3. Create one focused Git commit after the documentation and validation are complete.

## Git Commit Format

- Begin every commit message with a short English title that summarizes the completed change.
- Add one or more of the following English sections to the commit body when applicable:

```text
New Features

- xxx

Improvements

- xxx

Bug Fixes

- xxx
```

- Include only sections that contain at least one completed item. Omit every empty section and its heading.
- Use `New Features` only for newly added user-facing or project capabilities.
- Use `Improvements` only for meaningful enhancements to existing behavior, structure, tooling, or documentation.
- Use `Bug Fixes` only for defects actually fixed in the current change.
- Keep every item concise, specific, and factual. Do not claim work or validation that was not completed.
- Stage only files that belong to the completed change. Inspect the staged diff and run `git diff --cached --check` before committing.

## Documentation Rules

- `doc/current.md` describes only the currently valid project state, capabilities, constraints, and outstanding work. Replace obsolete information instead of accumulating history.
- `doc/devlog.md` is append-only. Add each new entry at the end; do not rewrite or delete earlier entries. If an earlier entry needs correction, append a correction entry.
- Every devlog entry must include the date, summary, affected files, validation performed, and remaining risks or follow-up work.
- Record validation accurately. Write `Not run` when no build or tests were run, and write `None` when there are no known remaining items.

## Scope and Safety

- Keep each change focused on the user's request and preserve unrelated worktree changes.
- Do not make destructive repository or filesystem changes unless the user explicitly requests them.
- Do not conceal failures, skipped validation, or unresolved risks.

## Temporary Build Artifacts

- Run application tests through `./script/test.sh`. It owns an isolated temporary build directory and removes its caches and test results after success, failure, or HUP/INT/TERM interruption. Use `-only-testing:` or `-skip-testing:` to narrow the test scope.
- Keep `.build/Xcode` for the canonical build/run and packaging workflows, and preserve `.build/Distribution` release packages.
- Do not create permanent per-task build directories such as `.build/Audit` or `.build/FinalTests`. Other one-off validation commands must use a unique temporary directory and clean it up in the same task, including on failure. Preserve an artifact only when the user requests it or it is a requested deliverable.
- Test output remains in the terminal. Save a text log explicitly when needed; detailed `.xcresult` bundles are temporary. Forced termination (SIGKILL), a shell crash, or power loss can prevent cleanup; remove only the abandoned run's directory after confirming it is no longer active.
