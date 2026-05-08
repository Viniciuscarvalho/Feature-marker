# PR Phase

Commit changes and create a Pull Request.

---

## Commit

Check if `~/.claude/commands/commit.md` exists.

- **Exists** → invoke `/commit` (handles pre-commit checks, conventional format, smart staging). The `/commit` command does not add a Co-Authored-By footer.
- **Missing** → copy from `~/.claude/skills/feature-marker/resources/commit.md`, then invoke `/commit`
- **Copy fails** → generate a commit message from `progress.md`, stage relevant files, and commit directly using conventional commit format

---

## PR Creation

Resolve the PR skill using this priority order:

1. `pr_skill` field in `.feature-marker.json` — highest priority override
2. `PR_SKILL` env var — exported by `feature-marker.sh` after platform detection
3. Re-detect from git remote URL using `~/.claude/skills/feature-marker/lib/platform-detector.sh`

If `skip_pr` is `true` in `.feature-marker.json`, skip PR creation and log instructions for manual creation.

Invoke the selected skill. If the skill is unavailable, commit only and show the manual PR command.

---

## Outputs

After invoking the PR skill, read `.claude/feature-state/{slug}/pr-url.txt`.

If the file is missing or its content does not start with `https://`: the PR creation failed. Show the raw skill output to the user. Do **not** update the checkpoint. Ask: "Retry PR creation or create the PR manually?"

If the URL is valid:

- Update checkpoint: `current_phase=pr`, `phase_status=completed`.
- Show the PR URL to the user and confirm the feature is complete.
