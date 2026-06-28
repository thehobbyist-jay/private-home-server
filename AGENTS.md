# Agent Preferences (Workspace)

Purpose
- Concise workspace policies for coding agents.

Key preferences
- Use Conventional Commits for all commit messages (see https://www.conventionalcommits.org/en/v1.0.0/).
- Do not commit to protected or main branches without an authorized reviewer.

Process (brief)
1. Branching: reuse feature branches. Do not create a new branch for every small change. Create new branches only for large, independent, or long-lived work.
2. Verify: run linters and tests before creating or updating a PR.
3. PRs: open a draft PR with a short summary, tests, and any risks.
4. Review: assign authorized reviewers and await approval (≥1; high-risk may need ≥2 including a maintainer).
5. Merge: follow repo merge policy (squash/rebase) and ensure commit messages follow Conventional Commits.

Commit format (short)
- <type>[optional scope]: <description>
- Common types: feat, fix, docs, style, refactor, perf, test, chore
- Examples:
  - feat(api): add user profile endpoint
  - fix(auth): correct token refresh logic
  - docs(agents): update agent preferences
  - feat!: drop Node 10 support (BREAKING CHANGE: requires Node >=12)

Emergencies
- Emergency fixes may be applied with prior out-of-band approval from a maintainer and must be followed by a PR explaining the change.

Enforcement
- Recommend CI: linting and tests; enable branch protection requiring PR reviews.

Requesting approval
- PR should state what changed, why, how it was tested, and rollback steps. Tag reviewers.

Change log & contact
- Record preference changes with Conventional Commits (e.g., docs(agents): ...).
- Contact: (maintainer or team)
