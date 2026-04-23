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

Detect the git platform from the remote URL:

| Remote URL pattern | Skill         |
| ------------------ | ------------- |
| `github.com`       | `checking-pr` |
| `dev.azure.com`    | `azure-pr`    |
| `gitlab.com`       | `checking-pr` |
| `bitbucket.org`    | `checking-pr` |
| anything else      | `checking-pr` |

Check `.feature-marker.json` for a `pr_skill` override. If set, use that instead.

If `skip_pr` is `true` in `.feature-marker.json`, skip PR creation and log instructions for manual creation.

Invoke the selected skill. If the skill is unavailable, commit only and show the manual PR command.

---

## Outputs

Save the PR URL to `.claude/feature-state/{slug}/pr-url.txt`.

Update checkpoint: `current_phase=pr`, `phase_status=completed`.

Show the PR URL to the user and confirm the feature is complete.
